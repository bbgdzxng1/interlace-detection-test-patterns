### MJPEGTools' mpeg2enc

[mpeg2enc](https://sourceforge.net/projects/mjpeg/files/mjpegtools/2.2.1/) describes itself as a _"heavily enhanced derivative of the MPEG Software Simulation Group's MPEG-2 reference encoder"_
- mpeg2enc supports pulldown; FFmpeg's mpeg2video encoder does not and thus FFmpeg requires a second pass with dgpulldown.
- mpeg2enc produces a classical 3:2 pulldown pattern, in line with dgpulldown, x264 standalone encoder and FFmpeg's 'pulldown=pattern=32' hard telecine filter.
- mpeg2enc is limited to a maximum of two B frames.
- It is noted that in mpeg2enc, the VBV Buffer Size `--video-buffer` is defined in KB, wheras with FFmpeg it is defined in bits.  The DVD maximum is understood to be 1835008 bits == 224KB
- mpeg2enc will produce WARN with both `frame-rate 1 --3-2-pulldown` (24000/1001 == ntsc-film) and `frame-rate 4 --3-2-pulldown` (30000/1001 == ntsc).
- Speed is improved with `--multi-thread 4`
- Non-linear quantization is automatically enabled when the output is MPEG-2
- Supports field encoding (if you desire)
- The templates (aka mpeg2enc "formats") seem to use alternate_scan by default, even on progressive frames.   LI & DREW in Fundamentals of Multimedia state that alternate_scan is preferable for interlaced frames with fast motion.  HASKELL, PURI and NETRAVALI in Digital Video: An introduction to MPEG-2 state the alternate scan often gives better compression for interlaced video when there is significant motion.
  - The PSNR data presented in https://www.itu.int/wftp3/av-arch/jvt-site/2002_01_Geneva/JVT-B068r1.doc does not provide comparison data for progressive frames.
  - The consensus on the doom9 forum is that alternate scan is preferable for interlaced frames and classical zig-zag scan is preferable for progressive frames.
  - Testing with ab-av1's VMAF comparison (albeit with FFmpeg's mpeg2video codec) on progressive content produced equal VMAF score at various qscales (5,6,7,10) whether alternate scan was enabled or disabled, indicating _equal quality_ for the same qscale, but zig-zag scan produced a file of 414MB compared to alternate scan of 459MB, indicating a 10% improvement in compression efficiency.  This is in line with HASKELL, PURI and NETRAVALI.


```shell
$ ffmpeg -loglevel 'error' \
  -f 'lavfi' -i smptebars=rate='ntsc-film':size='ntsc',setdar=ratio='(4/3)' -t 3 \
  -f 'yuv4mpegpipe' "pipe:1" \
    | mpeg2enc --multi-thread 4 \
    --format 3 --quantisation 5 --video-bitrate 8000 --video-buffer 224 \
    --sequence-header-every-gop --video-norm n --aspect 2 \
    --frame-rate 1 --3-2-pulldown \
    --min-gop-size 12 --max-gop-size 12 --b-per-refframe 2 \
    --intra_dc_prec 10 --reduction-4x4 1 --reduction-2x2 1 \
    --output "./test.mpg" 
```

```
$ ffprobe -hide_banner -loglevel 'error' -f 'mpegvideo' -framerate 'ntsc-film' ./test.mpg -show_entries 'frame=pict_type,interlaced_frame,top_field_first,repeat_pict' -print_format 'compact'
frame|pict_type=I|interlaced_frame=0|top_field_first=1|repeat_pict=1|
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=0|
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=1|
frame|pict_type=P|interlaced_frame=0|top_field_first=1|repeat_pict=0|
frame|pict_type=B|interlaced_frame=0|top_field_first=1|repeat_pict=1|
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=0|
frame|pict_type=P|interlaced_frame=0|top_field_first=0|repeat_pict=1|
frame|pict_type=B|interlaced_frame=0|top_field_first=1|repeat_pict=0|
frame|pict_type=P|interlaced_frame=0|top_field_first=1|repeat_pict=1|
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=0|
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=1|
frame|pict_type=P|interlaced_frame=0|top_field_first=1|repeat_pict=0|
frame|pict_type=B|interlaced_frame=0|top_field_first=1|repeat_pict=1|
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=0|
```

mpeg2enc supports format presets (or templates), including DVD and some extra support for dvd-author.  Formats 3, 8, 10 and 11 are of most interest to MPEG2 DVD and ATSC 1.0.

```
--format 1      Standard VCD.  An MPEG1 profile exactly to the VCD2.0 specification. Flag settings that would result in a non-standard stream structure are simply ignored.
--format 2      User VCD.  As for profile 2 but bitrate and video buffer size can be set to non-standard values. Frame size may also be non-standard. Bit-rate and buffer sizes default to those for standard VCD.
--format 3      Generic MPEG2.  A basic MPEG-2 profile that lets most parameters be adjusted for particular applications using the other flags. Typical applications would be to produce a MPEG-2 stream with big buffers and long GOP's for software playback on a computer.
--format 4      Standard SVCD.  An MPEG-2 profile exactly to the SVCD2.0 specification. Flag settings that would result in a non-standard stream structure are simply ignored.
--format 5      Non-standard SVCD.  As for profile 4 but bitrate, video buffer size, GOP sizes and structure can be set to non-standard values. Frame size may also be non-standard. Bit-rate and buffer sizes default to those for standard SVCD.
--format 6      VCD Stills sequence.  Encodes the special style of MPEG stream used for still images on VCDs. To use this profile you must set the target size you wish to compress the images to using the -T flag. Reasonable values are around 35KB for standard resolution stills (352 wide) and 120KB for high resolution stills (704 wide).
--format 7      SVCD Stills sequence.  Encodes the special style of MPEG stream used for still images on SVCDs. Both standard (480 wide) and high resolution (704 wide) images are supported. As with VCD stills you select how big each compressed still should be using the -T flag.
--format 8      DVD MPEG-2 for 'dvdauthor'  This version adds special dummy navigation packets into the output stream that the dvdauthor tool fills in to make a proper .VOB for authoring. Bit-rate defaults to 7500kbps, buffer sizes to the maximum permitted by the DVD specification.
--format 9      DVD MPEG-2.  Just a very basic implementation. Useful with DXR2 board and similar hardware that can decode MPEG-2 only if it is presented in a DVD like form. Bit-rate defaults to 7500kbps, buffer sizes to the maximum permitted by the DVD specification.
--format 10     ATSC 480i 
--format 11     ATSC 480p
--format 12     ATSC 720p
--format 13     ATSC 1080i 
```

```
mpeg2enc --help --output /dev/null 
--verbose|-v num
    Level of verbosity. 0 = quiet, 1 = normal 2 = verbose/debug
--format|-f fmt
    Encoding profile
    [0 = Generic MPEG1, 1 = standard VCD, 2 = user VCD,
     3 = Generic MPEG2, 4 = standard SVCD, 5 = user SVCD,
     6 = VCD Stills sequences, 7 = SVCD Stills sequences, 8|9 = DVD,
     10 = ATSC 480i, 11 = ATSC 480p, 12 = ATSC 720p, 13 = ATSC 1080i]
--display-hsize|-x [32..16383]
   Set the the display-horizontal-size hint in MPEG-2 output to
   something other than the encoded image width
--display-vsize|-y [32..16383]
   Set the the display-vertical-size hint in MPEG-2 output to
   something other than the encoded image height
--aspect|-a num
    Set displayed image aspect ratio image (default: 2 = 4:3)
    [1 = 1:1, 2 = 4:3, 3 = 16:9, 4 = 2.21:1]
--frame-rate|-F num
    Set playback frame rate of encoded video
    (default: frame rate of input stream)
    0 = Display frame rate code table
--video-bitrate|-b num
    Set Bitrate / peak bitrate of compressed video in KBit/sec
    (Peak bitrate if a target bitrate and/or quantisation floor is set
    (default: 1152.0 for VCD, 2500.0 for SVCD, 7500.0 for DVD)
--target-video-bitrate|-t
   Set target bitrate for entire video stream in KBit/sec
--nonvideo-bitrate|-B num
    Non-video data bitrate to assume for sequence splitting
    calculations (see also --sequence-length).
--quantisation|-q num
    Image data quantisation factor [1..31] (1 is best quality, no default)
    When quantisation is set variable bit-rate encoding is activated and
    the --bitrate value sets an *upper-bound* video data-rate
--ratecontroller|-A [0..1] (default:0)
    Specify ratecontrol alorithm
--output|-o pathname
    Pathname of output file or fifo (REQUIRED!!!)
--target-still-size|-T size
    Size in KB of VCD stills
--interlace-mode|-I num
    Sets MPEG 2 motion estimation and encoding modes:
    0 = Progressive (non-interlaced)(Movies)
    1 = Interlaced source material (video)
    2 = Interlaced source material, per-field-encoding (video)
--motion-search-radius|-r num
    Motion compensation search radius [0..32] (default 16)
--reduction-4x4|-4 num
    Reduction factor for 4x4 subsampled candidate motion estimates
    [1..4] [1 = max quality, 4 = max. speed] (default: 2)
--reduction-2x2|-2 num
    Reduction factor for 2x2 subsampled candidate motion estimates
    [1..4] [1 = max quality, 4 = max. speed] (default: 3)
--min-gop-size|-g num
    Minimum size Group-of-Pictures (default depends on selected format)
--max-gop-size|-G num
    Maximum size Group-of-Pictures (default depends on selected format)
    If min-gop is less than max-gop, mpeg2enc attempts to place GOP
    boundaries to coincide with scene changes
--closed-gop|-c
    All Group-of-Pictures are closed.  Useful for authoring multi-angle DVD
--force-b-b-p|-P
    Preserve two B frames between I/P frames when placing GOP boundaries
--quantisation-reduction|-Q num
    Max. quantisation reduction for highly active blocks
    [0.0 .. 4.0] (default: 0.0)
--quant-reduction-max-var|-X num
    Luma variance below which quantisation boost (-Q) is used
    [0.0 .. 2500.0](default: 0.0)
--video-buffer|-V num
    Target decoders video buffer size in KB (default 46)
--video-norm|-n n|p|s
    Tag output to suit playback in specified video norm
    (n = NTSC, p = PAL, s = SECAM) (default: PAL)
--sequence-length|-S num
    Place a sequence boundary in the video stream so they occur every
    num Mbytes once the video is multiplexed with audio etc.
    N.b. --non-video-bitrate is used to the bitrate of the other
    data that will be multiplexed with this video stream
--3-2-pulldown|-p
    Generate header flags for 3-2 pull down of 24fps movie material
--intra_dc_prec|-D [8..11]
    Set number of bits precision for DC (base colour) of blocks in MPEG-2
--reduce-hf|-N num
    [0.0..2.0] Reduce hf resolution (increase quantization) by num (default: 0.0)
--keep-hf|-H
    Maximise high-frequency resolution - useful for high quality sources
    and/or high bit-rates)
--sequence-header-every-gop|-s
    Include a sequence header every GOP if the selected format doesn't
    do so by default.
--no-dummy-svcd-SOF|-d
    Do not generate dummy SVCD scan-data for the ISO CD image
    generator "vcdimager" to fill in.
--playback-field-order|-z b|t
    Force setting of playback field order to bottom or top first
--multi-thread|-M num
    Activate multi-threading to optimise throughput on a system with num CPU's
    [0..32], 0=no multithreading, (default: 0)
--correct-svcd-hds|-C
    Force SVCD horizontal_display_size to be 480 - standards say 540 or 720
    But many DVD/SVCD players screw up with these values.
--no-constraints
    Deactivate constraints for maximum video resolution and sample rate.
    Could expose bugs in the software at very high resolutions!
--no-altscan-mpeg2
    Deactivate the use of the alternate block pattern for MPEG-2.  This is
    A work-around for a Bug in an obscure hardware decoder.
--dualprime-mpeg2
    Turn ON use of dual-prime motion compensation. Default is OFF unless this option is used
--custom-quant-matrices|-K kvcd|tmpgenc|default|hi-res|file=inputfile|help
    Request custom or userspecified (from a file) quantization matrices
--unit-coeff-elim|-E num
    Skip picture blocks which appear to carry little information
    because they code to only unit coefficients. The number specifies
    how aggresively this should be done. A negative value means DC
    coefficients are included.  Reasonable values -40 to 40
--b-per-refframe| -R 0|1|2
    The number of B frames to generate between each I/P frame
--cbr|-u
    For MPEG-2 force the use of (suboptimal) ConstantBitRate (CBR) encoding
--chapters X[,Y[,...]]
    Specifies which frames should be chapter points (first frame is 0)
    Chapter points are I frames on closed GOP's.
--help|-?
    Print this lot out!
```

```
$ mpeg2enc --frame-rate 0
Frame-rate codes:
 1 - 24000.0/1001.0 (NTSC 3:2 pulldown converted FILM)
 2 - 24.0 (NATIVE FILM)
 3 - 25.0 (PAL/SECAM VIDEO / converted FILM)
 4 - 30000.0/1001.0 (NTSC VIDEO)
 5 - 30.0
 6 - 50.0 (PAL FIELD RATE)
 7 - 60000.0/1001.0 (NTSC FIELD RATE)
 8 - 60.0
```

### MPEG Software Simulation Group's mpeg2encode

This is the reference encoder produced by the MPEG Software Simulation Group.

Clone is available at: https://github.com/mobinsheng/mpeg2enc

MPEG-2 Encoder / Decoder, Version 1.2, July 19, 1996


### x264/x262 command line interface

This script/repo deals exclusively with mpeg2video/H.262.  However, the following is included as a quick note on the x264 command line tool, with the aim of validating the pulldown pattern with FFprobe and achieving the same pulldown pattern as mpeg2video + DGPulldown.  It is noted that FFmpeg's libx264 does not support `-x264opts pulldown=32` or `-x264-params pulldown=32`.

There is an unfinished x262 encoder, based on x264... [https://www.videolan.org/developers/x262.html](https://www.videolan.org/developers/x262.html)

```bash
$ ffmpeg -hide_banner -loglevel 'error' -f 'lavfi' -i "testsrc2=rate='ntsc-film'" -frames:v 24 -f 'yuv4mpegpipe' - \
  | x264 --quiet --demuxer 'y4m' --keyint 12 --crf 23 --bframes 2 --pulldown 32 -o - - \
  | ffprobe -hide_banner -loglevel 'error' -f 'h264' -framerate 'ntsc-film' - -show_entries 'frame=pict_type,interlaced_frame,top_field_first,repeat_pict' -print_format 'compact' 
                                                                               
frame|pict_type=I|interlaced_frame=0|top_field_first=1|repeat_pict=1
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=0
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=1
frame|pict_type=P|interlaced_frame=0|top_field_first=1|repeat_pict=0
frame|pict_type=B|interlaced_frame=0|top_field_first=1|repeat_pict=1
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=0
frame|pict_type=P|interlaced_frame=0|top_field_first=0|repeat_pict=1
frame|pict_type=B|interlaced_frame=0|top_field_first=1|repeat_pict=0
frame|pict_type=B|interlaced_frame=0|top_field_first=1|repeat_pict=1
frame|pict_type=P|interlaced_frame=0|top_field_first=0|repeat_pict=0
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=1
frame|pict_type=P|interlaced_frame=0|top_field_first=1|repeat_pict=0
frame|pict_type=I|interlaced_frame=0|top_field_first=1|repeat_pict=1
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=0
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=1
frame|pict_type=P|interlaced_frame=0|top_field_first=1|repeat_pict=0
frame|pict_type=B|interlaced_frame=0|top_field_first=1|repeat_pict=1
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=0
frame|pict_type=P|interlaced_frame=0|top_field_first=0|repeat_pict=1
frame|pict_type=B|interlaced_frame=0|top_field_first=1|repeat_pict=0
frame|pict_type=B|interlaced_frame=0|top_field_first=1|repeat_pict=1
frame|pict_type=P|interlaced_frame=0|top_field_first=0|repeat_pict=0
frame|pict_type=B|interlaced_frame=0|top_field_first=0|repeat_pict=1
frame|pict_type=P|interlaced_frame=0|top_field_first=1|repeat_pict=0
```

### y262 by Ralf Willenbacher

https://github.com/rwillenbacher/y262

https://forum.doom9.org/showthread.php?t=171543

Supports pulldown...

```
$ /opt/y262/y262 

y262 usage:
	y262app -in <420yuv> -size <width> <height> -out <m2vout>

	-frames <number>    :  number of frames to encode, 0 for all
	-threads <on> <cnt> :  threading enabled and number of concurrent slices
	-profile <profile>  :  simple, main, high or 422 profile
	-level <level>      :  low main high1440 high 422main or 422high level
	-chromaf            :  chroma format, 420, 422 or 444
	-rec <reconfile>    :  write reconstructed frames to <reconfile>
	-rcmode <pass>      :  0 = CQ, 1 = 1st pass, 2 = subsequent pass
	-mpin <statsfile>   :  stats file of previous pass
	-mpout <statsfile>  :  output stats file of current pass
	-bitrate <kbps>     :  average bitrate
	-vbvrate <kbps>     :  maximum bitrate
	-vbv <kbps>         :  video buffer size
	-quant <quantizer>  :  quantizer for CQ
	-interlaced         :  enable field macroblock modes
	-bff                :  first input frame is bottom field first
	-pulldown_frcode <num>:frame rate code to pull input up to
	-quality <number>   :  encoder complexity, negative faster, positive slower
	-frcode <number>    :  frame rate code, see mpeg2 spec
	-arinfo <number>    :  aspect ratio information, see mpeg2 spec
	-qscale0            :  use more linear qscale type
	-nump <number>      :  number of p frames between i frames
	-numb <number>      :  number of b frames between i/p frames
	-closedgop          :  bframes after i frames use only backwards prediction
	-noaq               :  disable variance based quantizer modulation
	-psyrd <number>     :  psy rd strength
	-avamat6            :  use avamat6 quantization matrices
	-flatmat            :  use flat quantization matrices <for high rate>
	-intramat <textfile>:  use the 64 numbers in the file as intra matrix
	-intermat <textfile>:  use the 64 numbers in the file as inter matrix
	-videoformat <fmt>  :  pal, secam, ntsc, 709 or unknown 
	-mpeg1              :  output mpeg1 instead mpeg2, constraints apply
```
