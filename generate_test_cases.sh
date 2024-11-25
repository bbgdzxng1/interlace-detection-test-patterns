#!/usr/bin/env bash
#shellcheck shell=bash

#######################################
### generate_testcase.sh
# - Test cases for testing the functionality of FFmpeg's idet and dgpulldown's soft telecine.
# - The large font with frame countup of {0-29} or {0..23} is designed to ensure that idet has sufficient changing pixels to produce an accurate idet result at 480.
# - Source is generated at yuv422p, then interlaced and finaly converted to yuv420p.  This is because yuv420p may not have sufficient horizontal resolution in the chroma plane to feed the tinterlace filter.
# - Script requires dgpulldown 1.0.11 for generation of soft telecine.  dgpulldown 1.0.11-l (linux/macOS) has some quirks on compilation on macOS.  dgpulldown seems to generate 3:2 pulldown (* citation needed) - at least when soft telecine is applied, 'repeatfields,idet' seems to produce the same result as FFmpeg's 'pulldown=pattern=32' hard telecine.  dgpulldown does not offer the option to select between [ 23 | 32 | 2332 ] pulldown patterns.  Caveat: Pulldown patterns may also depend on the version of dgpulldown.
# - Accuracy of idet was improved by focusing on the y plane, since yuv420p may not have sufficient horizontal resolution in chroma planes to produce an accurate result.  ie, 'extractplanes=planes='y',idet'
# - In theory, output files can be concatted to produce a hybrid/mixed stream.  "-seq_disp_ext:v 'always'" is specified to always write the Sequence Display Extension to aid this.
#######################################

duration='00:00:30.000'
loglevel='level+info'

#######################################
### _check_dependencies
#######################################
function _check_dependencies
{
  local -a array_of_dependencies
  array_of_dependencies=(
    ffmpeg
    mediainfo
    grep
    ffprobe
    /opt/dgpulldown/dgpulldown # Using dgpulldown 1.0.11
    # ffplay
    # mpv
    # vlc
    # jq # potentially useful in the future for FFprobe -print_format 'json' for structured data
    # dvdauthor # fun-and-games for creating DVDs.
  )
  for dependency in "${array_of_dependencies[@]}"; do
    command -v "${dependency}" 1> /dev/null || {
      printf '%s | %s %s %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'ERROR: Dependency' "${dependency}" 'not found.  Exiting.'
      exit 1
    }
  done
  return 0
}

#######################################
### _generate_bt601-525_480_interlaced_bff
#######################################
function _generate_bt601-525_480_interlaced_bff()
{
  local outfile="$1"
  local gop=15

  ffmpeg -hide_banner -loglevel "${loglevel}" \
    -f 'lavfi' -color_range:v 'tv' -colorspace:v 'smpte170m' -color_primaries:v 'smpte170m' -color_trc:v 'smpte170m' -i "color=color='Black':size='hd480':rate='(60000/1001)',drawtext=text='%{expr_int_format\\:mod(n\,60)\\:d\\:2}':fontcolor='Orange':fontsize='main_h':font='Monospace':x='((main_w-text_w)/2)':y='((main_h-text_h)/2)':y_align='font',scale=size='ntsc',setdar=ratio='16/9',format=pix_fmts='yuv422p',tinterlace='interleave_bottom',setfield=mode='bff',format=pix_fmts='yuv420p'[out]; \
  sine=frequency=440:sample_rate=48000,volume=0.01,aresample=in_chlayout='mono':out_chlayout='stereo'[out1]" \
    -map '0:v:0' -codec:v 'mpeg2video' \
    -g:v "${gop}" -bf:v 2 -b_strategy 0 -sc_threshold:v 0x7FFFFFFF \
    -q:v 2 -maxrate:v 8000000 -minrate:v 0 -bufsize:v 1835008 \
    -flags '+ilme+ildct' -gop_timecode:v '00:00:00;00' -drop_frame_timecode:v true \
    -pix_fmt:v 'yuv420p' -chroma_sample_location:v 'left' \
    -seq_disp_ext:v 'always' \
    -video_format:v 'ntsc' \
    -map '0:a:0' -codec:a 'ac3' -ac:a 2 -ar:a 48000 -b:a 192000 \
    -timecode '00:00:00;00' \
    -metadata:s:a:0 'language=eng' \
    -t "${duration}" \
    -f 'matroska' "${outfile%.*}.mkv" -y
  printf '\n'
  printf '%s | %s %s \n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'INFO: Checking mediainfo interpretation:' "${outfile%.*}.mkv"
  mediainfo "${outfile%.*}.mkv" | grep -e "Frame\ rate" -e "Original\ frame\ rate" -e "Scan\ type" -e "Scan\ order"
  printf '\n'
  printf '%s | %s %s \n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'INFO: Checking flags (no idet) for file:' "${outfile%.*}.mkv"
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${outfile%.*}.mkv" \
    -show_entries 'frame=key_frame,pict_type,interlaced_frame,top_field_first,repeat_pict' \
    -print_format 'compact' | head -n 30
  printf '\n'
  printf '%s | %s %s \n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'INFO: Checking flags+tags (after idet) for file:' "${outfile%.*}.mkv"
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${outfile%.*}.mkv,extractplanes=planes='y',idet=intl_thres=1.04:prog_thres=1.5:rep_thres=3" \
    -show_entries 'frame=key_frame,pict_type,interlaced_frame,top_field_first,repeat_pict : frame_tags=lavfi.idet.single.current_frame' \
    -print_format 'compact' | head -n 30

  return 0
}

#######################################
### _generate_bt601-525_480_interlaced_tff
#######################################
function _generate_bt601-525_480_interlaced_tff()
{
  local outfile="$1"
  local gop=15

  ffmpeg -hide_banner -loglevel "${loglevel}" \
    -f 'lavfi' -color_range:v 'tv' -colorspace:v 'smpte170m' -color_primaries:v 'smpte170m' -color_trc:v 'smpte170m' -i "color=color='Black':size='hd480':rate='(60000/1001)',drawtext=text='%{expr_int_format\\:mod(n\,60)\\:d\\:2}':fontcolor='Yellow':fontsize='main_h':font='Monospace':x='((main_w-text_w)/2)':y='((main_h-text_h)/2)':y_align='font',scale=size='ntsc',setdar=ratio='16/9',format=pix_fmts='yuv422p',tinterlace='interleave_top',setfield=mode='tff',format=pix_fmts='yuv420p'[out]; \
  sine=frequency=440:sample_rate=48000,volume=0.01,aresample=in_chlayout='mono':out_chlayout='stereo'[out1]" \
    -map '0:v:0' -codec:v 'mpeg2video' \
    -g:v "${gop}" -bf:v 2 -b_strategy 0 -sc_threshold:v 0x7FFFFFFF \
    -q:v 2 -maxrate:v 8000000 -minrate:v 0 -bufsize:v 1835008 \
    -flags '+ilme+ildct' -gop_timecode:v '00:00:00;00' -drop_frame_timecode:v true \
    -pix_fmt:v 'yuv420p' -chroma_sample_location:v 'left' \
    -seq_disp_ext:v 'always' \
    -video_format:v 'ntsc' \
    -map '0:a:0' -codec:a 'ac3' -ac:a 2 -ar:a 48000 -b:a 192000 \
    -timecode '00:00:00;00' \
    -metadata:s:a:0 'language=eng' \
    -t "${duration}" \
    -f 'matroska' "${outfile%.*}.mkv" -y
  printf '\n'
  printf '%s | %s %s \n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'INFO: Checking mediainfo interpretation:' "${outfile%.*}.mkv"
  mediainfo "${outfile%.*}.mkv" | grep -e "Frame\ rate" -e "Original\ frame\ rate" -e "Scan\ type" -e "Scan\ order"
  printf '\n'
  printf '%s | %s %s \n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'INFO: Checking flags (no idet) for file:' "${outfile%.*}.mkv"
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${outfile%.*}.mkv" \
    -show_entries 'frame=key_frame,pict_type,interlaced_frame,top_field_first,repeat_pict' \
    -print_format 'compact' | head -n 30
  printf '\n'
  printf '%s | %s %s \n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'INFO: Checking flags+tags (after idet) for file:' "${outfile%.*}.mkv"
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${outfile%.*}.mkv,extractplanes=planes='y',idet=intl_thres=1.04:prog_thres=1.5:rep_thres=3" \
    -show_entries 'frame=key_frame,pict_type,interlaced_frame,top_field_first,repeat_pict : frame_tags=lavfi.idet.single.current_frame' \
    -print_format 'compact' | head -n 30
  return 0
}

#######################################
### _generate_bt601-525_480_telecined_hard
#######################################
function _generate_bt601-525_480_telecined_hard()
{
  local outfile="$1"
  local gop=15

  ffmpeg -hide_banner -loglevel "${loglevel}" \
    -f 'lavfi' -color_range:v 'tv' -colorspace:v 'smpte170m' -color_primaries:v 'smpte170m' -color_trc:v 'smpte170m' -i "color=color='Black':size='hd480':rate='ntsc-film',drawtext=text='%{expr_int_format\\:mod(n\,24)\\:d\\:2}':fontcolor='Blue':fontsize='main_h':font='Monospace':x='((main_w-text_w)/2)':y='((main_h-text_h)/2)':y_align='font',scale=size='ntsc',setdar=ratio='16/9',format=pix_fmts='yuv422p',telecine=pattern='32',setfield=mode='tff',format=pix_fmts='yuv420p'[out]; \
  sine=frequency=440:sample_rate=48000,volume=0.01,aresample=in_chlayout='mono':out_chlayout='stereo'[out1]" \
    -map '0:v:0' -codec:v 'mpeg2video' \
    -g:v "${gop}" -bf:v 2 -b_strategy 0 -sc_threshold:v 0x7FFFFFFF \
    -q:v 2 -maxrate:v 8000000 -minrate:v 0 -bufsize:v 1835008 \
    -flags '+ilme+ildct' -gop_timecode:v '00:00:00;00' -drop_frame_timecode:v true \
    -pix_fmt:v 'yuv420p' -chroma_sample_location:v 'left' \
    -seq_disp_ext:v 'always' \
    -video_format:v 'ntsc' \
    -map '0:a:0' -codec:a 'ac3' -ac:a 2 -ar:a 48000 -b:a 192000 \
    -timecode '00:00:00;00' \
    -metadata:s:a:0 'language=eng' \
    -t "${duration}" \
    -f 'matroska' "${outfile%.*}.mkv" -y
  printf '\n'
  printf '%s | %s %s \n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'INFO: Checking mediainfo interpretation:' "${outfile%.*}.mkv"
  mediainfo "${outfile%.*}.mkv" | grep -e "Frame\ rate" -e "Original\ frame\ rate" -e "Scan\ type" -e "Scan\ order"
  printf '\n'
  printf '%s | %s %s \n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'INFO: Checking flags (no idet) for file:' "${outfile%.*}.mkv"
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${outfile%.*}.mkv" \
    -show_entries 'frame=key_frame,pict_type,interlaced_frame,top_field_first,repeat_pict' \
    -print_format 'compact' | head -n 30
  printf '\n'
  printf '%s | %s %s \n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'INFO: Checking flags+tags (after idet) for file:' "${outfile%.*}.mkv"
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${outfile%.*}.mkv,extractplanes=planes='y',idet=intl_thres=1.04:prog_thres=1.5:rep_thres=3" \
    -show_entries 'frame=key_frame,pict_type,interlaced_frame,top_field_first,repeat_pict : frame_tags=lavfi.idet.repeated.current_frame' \
    -print_format 'compact' | head -n 30

  return 0
}

#######################################
### _generate_bt601-525_480_telecined_hard
# - Note that timecode format for 23.976fps progressive is 'HH:MM:SS:FF', ie non drop frame (NDF), rather than 'HH:MM:SS;FF' (DF)
#######################################
function _generate_bt601-525_480_telecined_soft()
{
  local outfile="$1"
  local gop=12 # Note that for DVD, the maximum GOP pre-soft-telecine is 12, since gop will become 15 after repeatfields expansion.
  ffmpeg -hide_banner -loglevel "${loglevel}" \
    -f 'lavfi' -color_range:v 'tv' -colorspace:v 'smpte170m' -color_primaries:v 'smpte170m' -color_trc:v 'smpte170m' -i "color=color='Black':size='hd480':rate='ntsc-film',drawtext=text='%{expr_int_format\\:mod(n\,24)\\:d\\:2}':fontcolor='Green':fontsize='main_h':font='Monospace':x='((main_w-text_w)/2)':y='((main_h-text_h)/2)':y_align='font',scale=size='ntsc',setdar=ratio='16/9',format=pix_fmts='yuv420p'[out]; \
  sine=frequency=440:sample_rate=48000,volume=0.01,aresample=in_chlayout='mono':out_chlayout='stereo'[out1]" \
    -map '0:v:0' -codec:v 'mpeg2video' \
    -g:v "${gop}" -bf:v 2 -b_strategy 0 -sc_threshold:v 0x7FFFFFFF \
    -q:v 2 -maxrate:v 8000000 -minrate:v 0 -bufsize:v 1835008 \
    -gop_timecode:v '00:00:00:00' -drop_frame_timecode:v false \
    -pix_fmt:v 'yuv420p' -chroma_sample_location:v 'left' \
    -seq_disp_ext:v 'always' \
    -video_format:v 'ntsc' \
    -map '0:a:0' -codec:a 'ac3' -ac:a 2 -ar:a 48000 -b:a 192000 \
    -timecode '00:00:00:00' \
    -t "${duration}" \
    -f tee "[select='v':f='mpeg2video']./${outfile%.*}.m2v \
    | [select='a':f='ac3']./${outfile%.*}.ac3" -y

  /opt/dgpulldown/dgpulldown "./${outfile%.*}.m2v" -o "./${outfile%.*}.pulldown.m2v" -srcfps 24000/1001 -destfps 29.970

  ffmpeg -hide_banner \
    -f 'mpegvideo' -framerate 'ntsc-film' -fflags '+genpts' -i "./${outfile%.*}.pulldown.m2v" \
    -f 'ac3' -fflags '+genpts' -i "./${outfile%.*}.ac3" \
    -map '0:v:0' -codec:v 'copy' \
    -map '1:a:0' -codec:a 'copy' \
    -metadata:s:a:0 'language=eng' \
    -f 'matroska' "${outfile%.*}.mkv" -y
  printf '\n'
  printf '%s | %s %s \n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'INFO: Checking mediainfo interpretation:' "${outfile%.*}.mkv"
  mediainfo "${outfile%.*}.mkv" | grep -e "Frame\ rate" -e "Original\ frame\ rate" -e "Scan\ type" -e "Scan\ order"
  printf '\n'
  printf '%s | %s %s \n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'INFO: Checking flags (no idet) for file:' "${outfile%.*}.mkv"
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${outfile%.*}.mkv" \
    -show_entries 'frame=key_frame,pict_type,interlaced_frame,top_field_first,repeat_pict' \
    -print_format 'compact' | head -n 24
  printf '\n'
  printf '%s | %s %s \n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 'INFO: Checking flags+tags (after repeatfields, idet) for file:' "${outfile%.*}.mkv"
  ffprobe -hide_banner -loglevel 'error' \
    -f 'lavfi' "movie=filename=${outfile%.*}.mkv,repeatfields,extractplanes=planes='y',idet=intl_thres=1.04:prog_thres=1.5:rep_thres=3" \
    -show_entries 'frame=key_frame,pict_type,interlaced_frame,top_field_first,repeat_pict : frame_tags=lavfi.idet.repeated.current_frame' \
    -print_format 'compact' | head -n 30

  rm -f "./${outfile%.*}.m2v" "./${outfile%.*}.ac3" "./${outfile%.*}.pulldown.m2v" # Housekeeping
  return 0
}

#######################################
### Main function.
#######################################
function main()
{
  _check_dependencies true
  _generate_bt601-525_480_interlaced_bff "bt601-525_480_interlaced_bff.mkv"
  _generate_bt601-525_480_interlaced_tff "bt601-525_480_interlaced_tff.mkv"
  _generate_bt601-525_480_telecined_hard "bt601-525_480_telecined_hard.mkv"
  _generate_bt601-525_480_telecined_soft "bt601-525_480_telecined_soft.mkv"
}

main "${@}"
exit 0
