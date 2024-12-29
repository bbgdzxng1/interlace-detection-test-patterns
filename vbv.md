### Validating VBV compliance with Loren "pengvado" Merritt's vbv.pl

http://akuvian.org/src/x264/vbv.pl

- vbv.pl can be used to measure VBV compliance of MPEG-2 Video, not just H.264.
- Input values are in kilobits (not bits)
- Float values are rounded UP to integer, ie 1835.008kb becomes 1836kb
- Dependencies: vbv.pl depends on mkvtoolnix's mkvinfo for matroska input (although matroska input did not work for me)
- It is common practice that encoders default to 90% initial fill.  In FFmpeg Suite, this is the `rc_init_occupancy`

```
$ ./vbv.pl       

vbv.pl [options] infile
  --fps      (required for textfile inputs)
  --bitrate  (kbit/s)
  --bufsize  (kbit)
  --init     (kbit)
  --log      (filename)
Analyzes video streams for VBV compliancy.

If you specify bitrate, bufsize, and init, it will check whether the stream is compliant.
If you specify just bitrate or bufsize, it will solve for the remaining values.

Infile can be:
  a text file containing frame sizes in bytes, 1 per line
  a text file containing the output of `x264 -v`
  matroska (only the first track is analyzed)
```


### Usage

Use FFprobe to gather what we may know about the stream from the headers...

```
$ ffprobe -hide_banner -loglevel 'level+error' \
  "${infile}" \
  -select_streams 'v:0' \
  -show_entries "stream='r_frame_rate','avg_frame_rate': stream_side_data='max_bitrate','buffer_size'" \
  -print_format default=noprint_wrappers=true

r_frame_rate=30000/1001
avg_frame_rate=30000/1001
max_bitrate=9600000
buffer_size=1835008
```

Assume that the encoder uses a default of 90% initial buffer occupancy...
```
rc_init_occupancy = 1835.008 * 90/100 = 1651.5072
```

Use FFprobe to generate _"a text file containing frame sizes in bytes, 1 per line"_

```shell
$ ffprobe -hide_banner -loglevel 'level+error' \
  "${infile}" \
  -select_streams 'v:0' -show_entries "frame='pkt_size'" \
  -print_format "default=nokey=true:noprint_wrappers=true" \
  -o "./framesizes.txt"

$ head -n10 "./framesizes.txt"
44165
14513
17361
17413
17690
13982
22852
15690
14261
18673
```

Positive example...
```shell
$ ./vbv.pl --fps 29.970 --bitrate 9600.000 --bufsize 1835.008 --init 1651.5072 --log "./vbv.log" "./framesizes.txt"    

assuming bitrate: 9600 kbit/s
assuming buffer size: 1836 kbit
assuming initial fill: 1652 kbit
passed vbv compliance
```

Negative example, lets assume the the input framerate is 1000fps and is thus likely to overflow the buffer...
```shell
% ./vbv.pl --fps 1000 --bitrate 9600.000 --bufsize 1835.008 --init 1651.5072 --log "./vbv.log" "./framesizes.txt"

assuming bitrate: 9600 kbit/s
assuming buffer size: 1836 kbit
assuming initial fill: 1652 kbit
failed vbv compliance
```

vbv.pl supports piped input (great!)...
```
$ ffprobe -hide_banner -loglevel 'level+error' \
  "${infile}" \
  -select_streams 'v:0' -show_entries "frame='pkt_size'" \
  -print_format "default=nokey=true:noprint_wrappers=true" \
  -o "pipe:1" \
  | ./vbv.pl --fps 1000 --bitrate 9600.000 --bufsize 1835.008 --init 1651.5072 --log "./vbv.log"
```

Example of quick'n'dirty bash script...

```bash
#!/usr/bin/env bash
#shellcheck shell=bash
#set -x																	# Uncomment for debug

#######################################
### Quick and dirty script to use FFprobe to gather data about mediafile and feed into vbv.pl
# Dependencies: vbv.pl, FFprobe
# - No error checking, script will fail if any of the commands fail.
# - Could use jq to run FFprobe once and parse the output, but that would be a dependency.
#######################################

infile="../bt601-525_480_interlaced_tff.ts"
logfile="./vbv.log"

r_frame_rate=$(ffprobe -hide_banner -loglevel 'level+error' \
  "${infile}" -select_streams 'v:0' \
  -show_entries "stream='r_frame_rate'" \
  -print_format default=nokey=true:noprint_wrappers=true)

read -r r_frame_rate_float < <(printf 'scale=3; %s\n' "${r_frame_rate}" | bc)

max_bitrate=$(ffprobe -hide_banner -loglevel 'level+error' \
  "${infile}" -select_streams 'v:0' \
  -show_entries "stream_side_data='max_bitrate'" \
  -print_format default=nokey=true:noprint_wrappers=true)

buffer_size=$(ffprobe -hide_banner -loglevel 'level+error' \
  "${infile}" -select_streams 'v:0' \
  -show_entries "stream_side_data='buffer_size'" \
  -print_format default=nokey=true:noprint_wrappers=true)

read -r rc_init_occupancy < <(printf '%s; %s\n' 'scale=3' "${buffer_size} * 0.9" | bc)

ffprobe -hide_banner -loglevel 'level+error' \
  "${infile}" \
  -select_streams 'v:0' -show_entries "frame='pkt_size'" \
  -print_format "default=nokey=true:noprint_wrappers=true" \
  -o "pipe:1" \
  | ./vbv.pl \
    --fps "${r_frame_rate_float}" \
    --bitrate "${max_bitrate}" \
    --bufsize "${buffer_size}" \
    --init "${rc_init_occupancy}" \
    --log "${logfile}"

exit 0
```


### Wishlist...
- Use shebang `#!/usr/bin/env perl` rather than `#!/usr/bin/perl`
- Port to Python?  What's the license? Loren "pengvado" Merritt did not include a (c)copyright or a license with vbv.pl.  Ideally:
  - input would be in bits rather than kilobits, although functionally this level of accuracy is irrelevant.  In the MPEG-2 Specification, Annex C, internally, they used real-values for bits... _"All the arithmetic in this annex is done with real-values, so that no rounding errors can propagate. For example, the number of bits in the VBV buffer is not necessarily an integer."_
  - vbv.py should set error code to be 1 if file is not compliant
  - Would be nice if it supported fractional input syntax '30000/1001', '24000/1001' and FFmpeg named constants 'ntsc', 'ntsc-film'

