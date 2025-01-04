#!/usr/bin/env bash
#shellcheck shell=bash
#set -x																	# Uncomment for debug

outfile="./source_video.vob"
dvdauthor_control="./dvdauthor_control.xml"
dvdauthor_output_directory="./mydvd"
loglevel='level+info'

rm -rf "${outfile}" "${outfile%.*}" "${dvdauthor_control}" "${dvdauthor_output_directory}" "${dvdauthor_output_directory}.iso"

ffmpeg -hide_banner -loglevel "${loglevel}" -sws_flags '+accurate_rnd+full_chroma_int' \
  -f 'lavfi' -i "smptebars=size='sntsc':rate='(60000/1001)',format=pix_fmts='yuv422p10le',setdar=ratio='(4/3)',tinterlace=mode='interleave_top',setfield=mode='tff',scale=size='ntsc':interl=true,format=pix_fmts='yuv420p',lut[out]; \
  sine=frequency=440:sample_rate=48000,aresample=in_chlayout='mono':out_chlayout='stereo',volume=volume=0.05[out1]" \
  -map '0:v:0' -codec:v 'mpeg2video' \
  -g:v 18 -bf:v 2 -b_strategy 2 \
  -qscale:v 2 -maxrate:v 8000000 -minrate:v 0 -bufsize:v '(224*1024*8)' -dc:v 10 -non_linear_quant:v true -qmax 28 \
  -flags:v '+ildct+ilme' -alternate_scan:v true \
  -pix_fmt:v 'yuv420p' -chroma_sample_location:v 'left' -seq_disp_ext:v 'always' -video_format:v 'ntsc' \
  -map '0:a:0' -codec:a 'ac3' -b:a 192k -ar 48000 -ac 2 \
  -t 60 \
  -f 'tee' \
  "[select='v':f='mpeg2video':packetsize=2048]${outfile%.*}.m2v \
   | [select='a':f='ac3']${outfile%.*}.ac3 \
   | [select='v\,a':f='dvd':packetsize=2048]${outfile%.*}.vob \
   | [select='v\,a':f='mpegts:packetsize=2048']${outfile%.*}.ts"

TMPFILE=$(mktemp -t dvdauthor) # No error checking here, as we're going to use it anyway

printf '%s\n%s\n' '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' '<dvdauthor></dvdauthor>' > "${TMPFILE}" \
  && {
    xmlstarlet edit \
      --subnode '/dvdauthor' --type 'elem' -n 'vmgm' \
      --subnode '/dvdauthor' --type 'elem' -n 'titleset' \
      --subnode '/dvdauthor/titleset' --type 'elem' -n 'titles' \
      --subnode '/dvdauthor/titleset/titles' --type 'elem' -n 'pgc' \
      --subnode '/dvdauthor/titleset/titles/pgc' --type 'elem' -n 'vob' \
      --insert '/dvdauthor/titleset/titles/pgc/vob' --type 'attr' -n 'file' -v "${outfile}" \
      --insert '/dvdauthor/titleset/titles/pgc/vob' --type 'attr' -n 'chapters' -v "00:00:00.000,00:00:30.000" \
      "${TMPFILE}" > "${dvdauthor_control}"
  }

mkdir -p "${dvdauthor_output_directory}" \
  && VIDEO_FORMAT=NTSC dvdauthor -o "${dvdauthor_output_directory}" -x "${dvdauthor_control}"

hdiutil makehybrid -iso -joliet -o "${dvdauthor_output_directory}.iso" "${dvdauthor_output_directory}"
