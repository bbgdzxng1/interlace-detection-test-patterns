#!/usr/bin/env bash
#shellcheck shell=bash
# set -x # Uncomment for debug

#######################################
### generate_testcase.sh
# - Test cases for testing the functionality of FFmpeg's idet and dgpulldown's soft telecine.
# - The large fontsize with frame-countup of {0-29} or {0..23} ensures that idet has sufficient changing pixels to produce an accurate idet result at a low resolution of 480.
# - Source is generated at yuv422p10le, then interlaced and finally converted to yuv420p.  Sunsampling in yuv420p may have sufficient vertical resolution in the chroma plane to feed the tinterlace filter.
# - Script requires dgpulldown 1.0.11 for generation of soft telecine.  dgpulldown 1.0.11-L (Linux/macOS) has some build quirks on compilation on macOS.  dgpulldown appears to generate a 3:2 pulldown pattern when soft telecine is applied (* citation needed) since 'repeatfields,idet' produces the same result as FFmpeg's 'pulldown=pattern=32' hard telecine.  dgpulldown does not offer the option to select between [ 23 | 32 | 2332 ] pulldown patterns.  Caveat: Pulldown patterns may also depend on the version of dgpulldown.
# - The accuracy of idet was improved by focusing on the y plane, since yuv420p may not have sufficient vertical resolution in chroma planes to produce an accurate result.  ie, 'extractplanes=planes='y',idet'
# - In theory, output files can be concatted to produce a hybrid/mixed stream. "-seq_disp_ext:v 'always'" is specified to always(?) write a Sequence Display Extension.
#######################################

duration='00:00:15.000'
loglevel='level+info'
quality=7 # Should be 2 for maximum quality, but it is reduced to 5 to reduce the filesize to please Github.

#######################################
### _check_dependencies
#######################################
function _check_dependencies
{
  local -a required_dependencies
  required_dependencies=(
    ffmpeg
    mediainfo
    grep
    ffprobe
    /opt/dgpulldown/dgpulldown # Using dgpulldown 1.0.11, which requires build and install.
  )
  for dependency in "${required_dependencies[@]}"; do
    command -v "${dependency}" 1> /dev/null || {
      printf '%s | %s %s %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'ERROR: Required Dependency' "${dependency}" 'not found.  Exiting.'
      exit 1
    }
  done

  local -a optional_dependencies
  optional_dependencies=(
    foo # Dummy dependency
    # MP4Box
    # mkvtoolnix
    # ffplay
    # mpv
    # vlc
    # jq # potentially useful in the future for FFprobe -print_format 'json' for structured data output & parsing
    # avmediainfo # Apple's version of mediainfo
    # dvdauthor # fun-and-games for creating DVDs.
  )
  for dependency in "${optional_dependencies[@]}"; do
    command -v "${dependency}" 1> /dev/null || {
      printf '%s | %s %s %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'ERROR: Optional Dependency' "${dependency}" 'not found.'
    }
  done
  return 0
}

#######################################
### _generate_bt601-525_480_interlaced_bff
#######################################
function _generate_bt601-525_480_interlaced_bff()
{
  local basename="$1"
  local gop=15

  ffmpeg -hide_banner -loglevel "${loglevel}" -sws_flags "+accurate_rnd+full_chroma_int" -bitexact \
    -f 'lavfi' -color_range:v 'tv' -colorspace:v 'smpte170m' -color_primaries:v 'smpte170m' -color_trc:v 'smpte170m' -i "color=color='Black':size='hd480':rate='(60000/1001)', format=pix_fmts='yuv422p10le', \
    il=luma_mode='deinterleave':chroma_mode='deinterleave',drawtext=text='TF':fontcolor='White':fontsize='main_h/16':box=0:boxcolor='Gray':font='Monospace':y=0:y_align='text',drawtext=text='BF':fontcolor='White':fontsize='main_h/16':box=0:boxcolor='Gray':font='Monospace':x=0:y='(main_h/2)+(text_h)':y_align='text',il=luma_mode='interleave':chroma_mode='interleave', \
    drawtext=text='%{expr_int_format\\:mod(n\,60)\\:d\\:2}':fontcolor='Orange':fontsize='main_h':font='Monospace':x='((main_w-text_w)/2)':y='((main_h-text_h)/2)':y_align='font', \
    drawtext=text=${basename}_interlaced_bff:fontcolor='Orange':fontsize='main_h/16':font='Monospace':x='((main_w-text_w)/2)':y='(main_h-text_h)':y_align='font', \
    scale=size='ntsc', setdar=ratio='16/9', \
    tinterlace='interleave_bottom', setfield=mode='bff', \
    format=pix_fmts='yuv420p', limiter=planes=1:min=16:max=235, limiter=planes=6:min=16:max=240,setparams=range='tv'[out]; \
  sine=frequency=440:sample_rate=48000, volume=0.2, aresample=in_chlayout='mono':out_chlayout='stereo'[out1]" \
    -map '0:v:0' -codec:v 'mpeg2video' \
    -g:v "${gop}" -bf:v 2 -b_strategy 0 -sc_threshold:v 0x7FFFFFFF \
    -q:v "${quality}" -maxrate:v 8000000 -minrate:v 0 -bufsize:v 1835008 \
    -flags '+ilme+ildct' -gop_timecode:v '00:00:00;00' -drop_frame_timecode:v true \
    -pix_fmt:v 'yuv420p' -chroma_sample_location:v 'left' \
    -seq_disp_ext:v 'always' \
    -video_format:v 'ntsc' \
    -map '0:a:0' -codec:a 'ac3' -ac:a 2 -ar:a 48000 -b:a 192000 \
    -timecode '00:00:00;00' \
    -metadata:s:a:0 'language=eng' \
    -t "${duration}" \
    -f 'mpegts' "${basename}_interlaced_bff.ts" -y
  return 0
}

#######################################
### _generate_bt601-525_480_interlaced_tff
#######################################
function _generate_bt601-525_480_interlaced_tff()
{
  local basename="$1"
  local gop=15

  ffmpeg -hide_banner -loglevel "${loglevel}" -sws_flags "+accurate_rnd+full_chroma_int" -bitexact \
    -f 'lavfi' -color_range:v 'tv' -colorspace:v 'smpte170m' -color_primaries:v 'smpte170m' -color_trc:v 'smpte170m' -i "color=color='Black':size='hd480':rate='(60000/1001)', format=pix_fmts='yuv422p10le', \
      il=luma_mode='deinterleave':chroma_mode='deinterleave', \
      drawtext=text='TF':fontcolor='White':fontsize='main_h/16':box=0:boxcolor='Gray':font='Monospace':y=0:y_align='text', \
      drawtext=text='BF':fontcolor='White':fontsize='main_h/16':box=0:boxcolor='Gray':font='Monospace':x=0:y='(main_h/2)+(text_h)':y_align='text', \
      il=luma_mode='interleave':chroma_mode='interleave', \
      drawtext=text='%{expr_int_format\\:mod(n\,60)\\:d\\:2}':fontcolor='Yellow':fontsize='main_h':font='Monospace':x='((main_w-text_w)/2)':y='((main_h-text_h)/2)':y_align='font', \
          drawtext=text=${basename}_interlaced_tff:fontcolor='Yellow':fontsize='main_h/16':font='Monospace':x='((main_w-text_w)/2)':y='(main_h-text_h)':y_align='font', \
      scale=size='ntsc', setdar=ratio='16/9', \
      tinterlace='interleave_top', setfield=mode='tff', \
      format=pix_fmts='yuv420p', limiter=planes=1:min=16:max=235, limiter=planes=6:min=16:max=240, setparams=range='tv'[out]; \
    sine=frequency=440:sample_rate=48000, volume=0.2, aresample=in_chlayout='mono':out_chlayout='stereo'[out1]" \
    -map '0:v:0' -codec:v 'mpeg2video' \
    -g:v "${gop}" -bf:v 2 -b_strategy 0 -sc_threshold:v 0x7FFFFFFF \
    -q:v "${quality}" -maxrate:v 8000000 -minrate:v 0 -bufsize:v 1835008 \
    -flags '+ilme+ildct' -gop_timecode:v '00:00:00;00' -drop_frame_timecode:v true \
    -pix_fmt:v 'yuv420p' -chroma_sample_location:v 'left' \
    -seq_disp_ext:v 'always' \
    -video_format:v 'ntsc' \
    -map '0:a:0' -codec:a 'ac3' -ac:a 2 -ar:a 48000 -b:a 192000 \
    -timecode '00:00:00;00' \
    -metadata:s:a:0 'language=eng' \
    -t "${duration}" \
    -f 'mpegts' "${basename}_interlaced_tff.ts" -y
  return 0
}

#######################################
### _generate_bt601-525_480_telecined_hard
#######################################
function _generate_bt601-525_480_telecined_hard()
{
  local basename="$1"
  local gop=15
  local pulldownpattern=32 # This was selected to match the output of dgpulldown, although [ 23 | 2332 ] are common.

  ffmpeg -hide_banner -loglevel "${loglevel}" -sws_flags "+accurate_rnd+full_chroma_int" -bitexact \
    -f 'lavfi' -color_range:v 'tv' -colorspace:v 'smpte170m' -color_primaries:v 'smpte170m' -color_trc:v 'smpte170m' -i "color=color='Black':size='hd480':rate='ntsc-film', format=pix_fmts='yuv422p10le', \
      drawtext=text='A':fontcolor='Red':fontsize='(main_h/8)':fontfile='Monospace':x='(main_w-(4*text_w))':y=0:y_align='text':box=false:boxcolor='Gray':enable='eq((mod(n,4)),0)', \
      drawtext=text='B':fontcolor='Blue':fontsize='(main_h/8)':fontfile='Monospace':x='(main_w-(3*text_w))':y=0:y_align='text':box=false:boxcolor='Gray':enable='eq((mod(n,4)),1)', \
      drawtext=text='C':fontcolor='Green':fontsize='(main_h/8)':fontfile='Monospace':x='(main_w-(2*text_w))':y=0:y_align='text':box=false:boxcolor='Gray':enable='eq((mod(n,4)),2)', \
      drawtext=text='D':fontcolor='Purple':fontsize='(main_h)/8':fontfile='Monospace':x='(main_w-(1*text_w))':y=0:y_align='text':box=false:boxcolor='Gray':enable='eq((mod(n,4)),3)', \
      drawtext=text='%{expr_int_format\\:mod(n\,24)\\:d\\:2}':fontcolor='Blue':fontsize='main_h':font='Monospace':x='((main_w-text_w)/2)':y='((main_h-text_h)/2)':y_align='font', \
                drawtext=text=${basename}_telecined_hard.ts:fontcolor='Blue':fontsize='main_h/16':font='Monospace':x='((main_w-text_w)/2)':y='(main_h-text_h)':y_align='font', \
      scale=size='ntsc', setdar=ratio='16/9', \
      telecine=pattern=${pulldownpattern}, setfield=mode='tff', \
      format=pix_fmts='yuv420p', limiter=planes=1:min=16:max=235, limiter=planes=6:min=16:max=240,setparams=range='tv'[out]; \
    sine=frequency=440:sample_rate=48000, volume=0.2, aresample=in_chlayout='mono':out_chlayout='stereo'[out1]" \
    -map '0:v:0' -codec:v 'mpeg2video' \
    -g:v "${gop}" -bf:v 2 -b_strategy 0 -sc_threshold:v 0x7FFFFFFF \
    -q:v "${quality}" -maxrate:v 8000000 -minrate:v 0 -bufsize:v 1835008 \
    -flags '+ilme+ildct' -gop_timecode:v '00:00:00;00' -drop_frame_timecode:v true \
    -pix_fmt:v 'yuv420p' -chroma_sample_location:v 'left' \
    -seq_disp_ext:v 'always' \
    -video_format:v 'ntsc' \
    -map '0:a:0' -codec:a 'ac3' -ac:a 2 -ar:a 48000 -b:a 192000 -frame_size:a 1024 \
    -timecode '00:00:00;00' \
    -metadata:s:a:0 'language=eng' \
    -t "${duration}" \
    -f 'mpegts' "${basename}_telecined_hard.ts" -y
  return 0
}

#######################################
### _generate_bt601-525_480_telecined_soft
# - Note that timecode format for 23.976fps progressive is 'HH:MM:SS:FF', ie non drop frame (NDF), rather than 'HH:MM:SS;FF' (DF)
#######################################
function _generate_bt601-525_480_telecined_soft()
{
  local basename="$1"
  local gop=12 # Note that for DVD, the maximum GOP pre-soft-telecine is 12, since gop will become 15 after repeatfields expansion.
  ffmpeg -hide_banner -loglevel "${loglevel}" -sws_flags "+accurate_rnd+full_chroma_int" -bitexact \
    -f 'lavfi' -color_range:v 'tv' -colorspace:v 'smpte170m' -color_primaries:v 'smpte170m' -color_trc:v 'smpte170m' -i "color=color='Black':size='hd480':rate='ntsc-film', format=pix_fmts='yuv422p10le',\
      drawtext=text='A':fontcolor='Red':fontsize='(main_h/8)':fontfile='Monospace':x='(main_w-(4*text_w))':y=0:y_align='text':box=false:boxcolor='Gray':enable='eq((mod(n,4)),0)', \
      drawtext=text='B':fontcolor='Blue':fontsize='(main_h/8)':fontfile='Monospace':x='(main_w-(3*text_w))':y=0:y_align='text':box=false:boxcolor='Gray':enable='eq((mod(n,4)),1)', \
      drawtext=text='C':fontcolor='Green':fontsize='(main_h/8)':fontfile='Monospace':x='(main_w-(2*text_w))':y=0:y_align='text':box=false:boxcolor='Gray':enable='eq((mod(n,4)),2)', \
      drawtext=text='D':fontcolor='Purple':fontsize='(main_h)/8':fontfile='Monospace':x='(main_w-(1*text_w))':y=0:y_align='text':box=false:boxcolor='Gray':enable='eq((mod(n,4)),3)', \
      drawtext=text='%{expr_int_format\\:mod(n\,24)\\:d\\:2}':fontcolor='Green':fontsize='main_h':font='Monospace':x='((main_w-text_w)/2)':y='((main_h-text_h)/2)':y_align='font', \
      drawtext=text=${basename}_telecined_soft.ts:fontcolor='Green':fontsize='main_h/16':font='Monospace':x='((main_w-text_w)/2)':y='(main_h-text_h)':y_align='font', \
      scale=size='ntsc', setdar=ratio='16/9', format=pix_fmts='yuv420p', limiter=planes=1:min=16:max=235, limiter=planes=6:min=16:max=240,setparams=range='tv'[out]; \
    sine=frequency=440:sample_rate=48000, volume=0.2, aresample=in_chlayout='mono':out_chlayout='stereo'[out1]" \
    -map '0:v:0' -codec:v 'mpeg2video' \
    -g:v "${gop}" -bf:v 2 -b_strategy 0 -sc_threshold:v 0x7FFFFFFF \
    -q:v "${quality}" -maxrate:v 8000000 -minrate:v 0 -bufsize:v 1835008 \
    -gop_timecode:v '00:00:00:00' -drop_frame_timecode:v false \
    -pix_fmt:v 'yuv420p' -chroma_sample_location:v 'left' \
    -seq_disp_ext:v 'always' \
    -video_format:v 'ntsc' \
    -map '0:a:0' -codec:a 'ac3' -ac:a 2 -ar:a 48000 -b:a 192000 -frame_size 1024 \
    -metadata:s:a:0 'language=eng' \
    -timecode '00:00:00:00' \
    -t "${duration}" \
    -f tee "[select='v':f='mpeg2video']./${basename}_progressive.m2v \
    | [select='a':f='ac3']./${basename}_audio.ac3 \
    | [select='v,a':f='mpegts']./${basename}_progressive.ts" -y

  /opt/dgpulldown/dgpulldown "./${basename}_progressive.m2v" -o "./${basename}_pulldown.m2v" -srcfps 24000/1001 -destfps 29.970

  ffmpeg -hide_banner -loglevel "${loglevel}" -sws_flags "+accurate_rnd+full_chroma_int" -bitexact \
    -f 'mpegvideo' -framerate 'ntsc-film' -fflags '+genpts' -i "./${basename}_pulldown.m2v" \
    -f 'ac3' -fflags '+genpts' -i "./${basename}_audio.ac3" \
    -map '0:v:0' -codec:v 'copy' \
    -map '1:a:0' -codec:a 'copy' \
    -metadata:s:a:0 'language=eng' \
    -f 'mpegts' "./${basename}_telecined_soft.ts" -y

  rm -f "./${basename}_progressive.m2v" "./${basename}_audio.ac3" "./${basename}_pulldown.m2v" # Housekeeping
  return 0
}

#######################################
### _remux function.
# Ideally, this would be done with tee muxer.
# Ideally, would also add MP4, but H.262 in MP4 is a little funky and generates errors with Apple avmediainfo.
# https://developer.apple.com/library/archive/technotes/tn2429/_index.html
#######################################
function _remux()
{
  local infile="$1"
  # Oh matroska, how do I hate thee? Let me count the ways.
  ffmpeg -hide_banner -loglevel "${loglevel}" -sws_flags "+accurate_rnd+full_chroma_int" -bitexact \
    -i "${infile}" \
    -map '0:v:0' -codec:v 'copy' \
    -map '0:a:0' -codec:a 'copy' "./${infile%.*}.mkv" -y
  return 0
}

#######################################
### _analyse function.
#######################################
function _analyse()
{
  local infile="$1"
  mediainfo --output=JSON --LogFile="${infile%.*}.mediainfo.json" "${infile}"
  mediainfo "${infile}" | grep -e "Frame\ rate" -e "Original\ frame\ rate" -e "Scan\ type" -e "Scan\ order" > "${infile%.*}.mediainfo.txt"
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${infile}" \
    -show_entries 'frame' \
    -print_format 'json' -o "${infile%.*}.ffprobe.json"
  # Would be better to use jq on the json
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${infile}" \
    -show_entries 'frame=key_frame,pict_type,interlaced_frame,top_field_first,repeat_pict' \
    -print_format 'compact' | head -n 30 > "${infile%.*}.ffprobe.compact.txt"
  # avmediainfo "${infile}" > "${infile%.*}.avmediainfo.txt" # Error analysis is not supported for format public.mpeg-2-transport-stream.
  return 0
}

#######################################
### _analyse_idet function.
#######################################
function _analyse_idet()
{
  local infile="$1"
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${infile},extractplanes=planes='y',idet=intl_thres=1.04:prog_thres=1.5:rep_thres=3" \
    -show_entries 'frame' \
    -print_format 'json' -o "${infile%.*}.ffprobe.idet.json"
  # Would be better to use jq on the json
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${infile},extractplanes=planes='y',idet=intl_thres=1.04:prog_thres=1.5:rep_thres=3" \
    -show_entries 'frame=key_frame,pict_type,interlaced_frame,top_field_first,repeat_pict : frame_tags=lavfi.idet.single.current_frame' \
    -print_format 'compact' | head -n 30 > "${infile%.*}.ffprobe.idet.compact.txt"
  return 0
}

#######################################
### _analyse_repeatfields_idet function.
#######################################
function _analyse_repeatfields_idet()
{
  local infile="$1"
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${infile}, repeatfields, extractplanes=planes='y', idet=intl_thres=1.04:prog_thres=1.5:rep_thres=3" \
    -show_entries 'frame' \
    -print_format 'json' -o "${infile%.*}.ffprobe.repeatfields.idet.json"
  # Would be better to use jq on the json
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${infile}, repeatfields, extractplanes=planes='y', idet=intl_thres=1.04:prog_thres=1.5:rep_thres=3" \
    -show_entries 'frame=key_frame,pict_type,interlaced_frame,top_field_first,repeat_pict : frame_tags=lavfi.idet.single.current_frame' \
    -print_format 'compact' | head -n 30 > "${infile%.*}.ffprobe.repeatfields.idet.compact.txt"
  return 0
}

#######################################
### Main function.
#######################################
function main()
{
  _check_dependencies
  _generate_bt601-525_480_interlaced_bff "bt601-525_480"
  _generate_bt601-525_480_interlaced_tff "bt601-525_480"
  _generate_bt601-525_480_telecined_hard "bt601-525_480"
  _generate_bt601-525_480_telecined_soft "bt601-525_480"
  _analyse "bt601-525_480_interlaced_bff.ts"
  _analyse_idet "bt601-525_480_interlaced_bff.ts"
  _analyse "bt601-525_480_interlaced_tff.ts"
  _analyse_idet "bt601-525_480_interlaced_tff.ts"
  _analyse "bt601-525_480_telecined_hard.ts"
  _analyse_idet "bt601-525_480_telecined_hard.ts"
  _analyse "bt601-525_480_telecined_soft.ts"
  _analyse_idet "bt601-525_480_telecined_soft.ts"
  _analyse_repeatfields_idet "bt601-525_480_telecined_soft.ts"
  _remux "bt601-525_480_interlaced_bff.ts"
  _remux "bt601-525_480_interlaced_tff.ts"
  _remux "bt601-525_480_telecined_hard.ts"
  _remux "bt601-525_480_progressive.ts"
  _remux "bt601-525_480_telecined_soft.ts"
}

main "${@}"
exit 0
