#!/usr/bin/env bash
#shellcheck shell=bash
#set -x  # Uncomment for debug

########################################
# Could be enhanced with...
# - plotting time as well as frame number (top axis)
# - plotting framesize (since we already have framesize)
# - plotting frametype IPB, keyframe.  Much like FFmpeg plotframes or https://github.com/rodrigopolo/plotframes
# - if you know the framerate, it should be possible to calculate the bitrate across a GOP.  See also https://github.com/InB4DevOps/bitrate-viewer
# - Could this method be used to acheve the same as vbv.pl?  https://akuvian.org/src/x264/vbv.pl
# AT&T Video Optimizer has a buffer occupancy https://developer.att.com/video-optimizer/docs
# https://github.com/zeroepoch/plotbitrate
# https://github.com/fifonik/FFBitrateViewer
# How could you vizualize underflow/overflow
# plotframes
# plotbitrate
# plotbuffer
# https://github.com/CrypticSignal/bitrate-plotter
# https://github.com/XuebingZhao/BitratePlotter
########################################

printf '%s\n%s\n%s\n%s\n' '########################################' 'This is an EXPERIMENTAL script.' 'Results have not been verified' '########################################'

infile=$1
# infile="./out.mkv"
# infile="${HOME}/bbb_sunflower_1080p_30fps_normal.mp4"
framesizes="./framesizes.txt"
occupancy_file="./occupancy.txt"
vbv_buffer_size=1835008 # Example buffer size in bytes
plotfile="./vbv_occupancy.svg"

# Extract frame sizes and frame types
ffprobe -hide_banner -loglevel 'level+error' \
  "${infile}" \
  -select_streams 'v:0' -show_entries "frame=pkt_size,pict_type" \
  -print_format "csv=nokey=1:p=0" > "${framesizes}"

# Calculate VBV buffer occupancy
awk -F, -v vbv_buffer_size="${vbv_buffer_size}" '
BEGIN {
  occupancy = 0;
  print "Frame,Occupancy";
}
{
  frame_size = $1;
  frame_type = $2;
  occupancy += frame_size;
  if (occupancy > vbv_buffer_size) {
    occupancy = vbv_buffer_size;
  }
  occupancy_percentage = (occupancy / vbv_buffer_size) * 100;
  print NR "," occupancy_percentage;
  if (frame_type == "I") {
    occupancy = frame_size; # Reset buffer for I-frames
  }
}' "${framesizes}" > "${occupancy_file}"

# Check if occupancy file has valid data
if [[ ! -s ${occupancy_file} ]]; then
  echo "Error: No valid data in ${occupancy_file}"
  exit 1
fi

# Plot using gnuplot
gnuplot <<- EOF
  set terminal svg size 800,600
  set output "${plotfile}"
  set title "VBV Buffer Occupancy"
  set xlabel "Frame"
  set ylabel "Occupancy (%)"
  set yrange [0:100]
  set y2label "Occupancy (%)"
  set y2range [0:100]
  set y2tics
  set grid
  set datafile separator ","
  plot "${occupancy_file}" using 1:2 with lines title "VBV Occupancy" axes x1y2
EOF

printf '%s: %s\n' 'Plot saved to' "${plotfile}"

open -a Safari "${plotfile}"

exit 0
