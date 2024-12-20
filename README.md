# Test patterns for deinterlace and inverse-telecine

These test patterns are useful for:
- Testing FFmpeg's idet (interlace detect) filter
- Testing dgpulldown's soft telecine tool
- Testing media analyzers (FFprobe, mediainfo, wader/fq, https://media-analyzer.pro/app etc)
- Evaluating deinterlacers (bwdif, yadif, nnedi) and inverse telecine (pullup, fieldmatch) processes
- Aid in the development of an authomated interlace/inverse telecine detection method using FFmpeg's idet
  - https://github.com/mpv-player/mpv/blob/master/TOOLS/idet.sh
  - https://github.com/utahjohnnymontana/DVD-Rip-Prep
  - https://www.mistralsolutions.com/newsletter/Jul13/Field_Dominance_Algorithm.pdf


#### Notes
- The test patterns include a frame-countup of {0-29} or {0..23} front-and-center stage.  The large font ensures that there are sufficient carying pixels for FFmpeg's idet to produce an accurate result.
- The two interlace test patterns include Top & Bottom Field visual indicators.
- The two telecine test patterns include ABCD cadence pattern visual indicators.
- The source is generated at yuv422p10le.  The drawtext and tinterlace filters produce better output when operating with a yuv422p (8 or 10bit) source.  After interlacing or telecining, files are finally converted to a yuv420p "consumer" format.  
- The script contains almost no error checking of success.  That is intentional to make the script readable & accessible.
- The accuracy of FFmpeg's idet filter can be improved by using 'extractplanes=planes='y',idet' to focus on the y plane, since yuv420p may not have sufficient vertical resolution in the chroma planes to produce an accurate result
- In theory, output files could be concatenated to produce a hybrid/mixed stream. "-seq_disp_ext:v 'always'" is specified to aid concatenation by always(?) writing a Sequence Display Extension, 
- Files are first generated as MPEG2-TS and remuxed to MKV.  MPEG-TS is a more "broadcast" format, but MKV is included to mimic the output produced from MakeMKV DVD rip.

### DGPulldown
- This script uses DGPulldown 1.0.11 by Donald A. Graft & others to generate the soft telecine test pattern.
- Caveat: The dgpulldown 1.0.11-L (Linux/macOS) port has some build quirks on compilation on macOS.
- dgpulldown appears to generate a 3:2 pulldown pattern when soft telecine is applied (* citation needed) since 'repeatfields,idet' produces the same result as FFmpeg's 'pulldown=pattern=32' hard telecine.  dgpulldown does not offer an option to specify [ 23 | 32 | 2332 ] pulldown patterns.  Caveat: The pulldown pattern may also depend on the version of dgpulldown.


#### TODO

- [ ] Add an interlaced tff "untagged" test case. 
- [x] Overlay the names of the test cases into each video.  WARNING: progressive test case has the wrong overlay.  Really needs a separate progressive function.
- [ ] Only analyse if optional dependency is installed (WIP)
- [ ] Use `jq` for parsing and summarizing the json (WIP)
- [x] -flags:v '+bitexact' # so as to avoid unnecessry git changes
- [x] -flags:a '+bitexact' # so as to avoid unnecessry git changes
- [ ] Add gnuplot graphs to plot csv/tsv to svg.
- [ ] Investigate audio frame_size.
- [ ] Add Github release(s) of output media.
- [ ] If someone wants to add PAL / 625 / 576 outputs they are welcome.
- [ ] mediainfo has separate fields for "FrameRate_Original" and "FrameRate" - although I have not yet got DGPulldown to trigger this behavior.  Needs further digging.

## Notes

### MJPEGTools' mpeg2enc

mpeg2enc claims to be a _"heavily enhanced derivative of the MPEG Software Simulation Group's MPEG-2 reference encoder"_

While FFmpeg's mpeg2video encoder does not support pulldown, MJPEGTool's mpeg2enc does.

https://sourceforge.net/projects/mjpeg/files/mjpegtools/2.2.1/


```shell
$ ffmpeg -loglevel 'error' \
  -f 'lavfi' -i smptebars=rate='ntsc-film':size='ntsc',setdar=ratio='(4/3)' -t 3 \
  -f 'yuv4mpegpipe' "pipe:1" \
    | mpeg2enc --multi-thread 4 \
    --format 3 --quantisation 1 --video-bitrate 8000 --video-buffer 1835 \
    --sequence-header-every-gop --video-norm n --aspect 2 \
    --frame-rate 4 --3-2-pulldown \
    --min-gop-size 12 --max-gop-size 12 --b-per-refframe 2 \
    --motion-search-radius 32 --custom-quant-matrices 'hi-res' --reduction-4x4 1 --reduction-2x2 1 \
    --output "./test.mpg" 
```

This produces a 3:2 pulldown pattern, in line with dgpulldown and x264 standalone.

It does not support more than two B frames.

```
ffprobe -hide_banner -loglevel 'error' -f 'mpegvideo' -framerate 'ntsc-film' ./test.mpg -show_entries 'frame=pict_type,interlaced_frame,top_field_first,repeat_pict' -print_format 'compact'
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

It does support format presets, including DVD and some extra support for dvd-author.

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


### MPEG Software Simulation Group's mpeg2enc

Clone is available at: https://github.com/mobinsheng/mpeg2enc

MPEG-2 Encoder / Decoder, Version 1.2, July 19, 1996



### TFF vs BFF

- The general consensus (citation needed) seems to be:
  - High Definition BT.709 is top field first
  - Standard definition DV (PAL or NTSC) is bottom field first
  - Standard definition D1 PAL is top field first
  - Standard Definition D1 NTSC is usually (but not always) bottom field first
  - What about ATSC1.0?  Modern ATSC 1.0 Standard Definition HDHomeRun captures seem to be TFF.
  - What about DVB-T?
  - What about PAL & NTSC DVDs?  Does it stand that the convention is that PAL DVDs are TFF and NTSC DVDs are BFF?

### FFmpeg bwdif & yadif
- These extreme-case interlace test patterns expose one of the weaknesses of the bwdif deinterlacer.  For general use, bwdif remains superior to yadif, but the particular characteristics of the content exposes bwdif's weakness.
  - bwdif is a selective, block-based deinterlacer.  It decides on a block-level whether to either line-double (bob) or weave.  The algorithm struggles with very rapid changes between fields.  bwdif will leave artifacts with these test patterns.
  - yadif is a more unselective, field-based deinterlacer and can handle very rapid changes between fields.

### MPEG2Video/H.262 in MP4 (macOS & FFmpeg compatibility)

At the time of writing FFmpeg (7.x) cannot write mpeg2video & ac3 to an mp4 in a way that is compatible with Apple Quicktime Player / Apple avmediainfo...

```
$ ffmpeg -f lavfi -i "testsrc2=size=ntsc:rate=ntsc[out]" -c:v mpeg2video -t 30 ./test.mp4 -y

$ avmediainfo ./test.mp4 
Asset: ./test.mp4
Duration: 29.997 seconds (29997/1000)
Track count: 0

> Movie analyzed with 2 errors.
> Error in Track ID 1 'vide' Error when generating format descriptions.
> Error in Track ID 1 'vide' Omitting a track that encountered an error during atom parsing.
```

But, FFmpeg can write mpeg2video & ac3 to a mov, which is compatible with Apple Quicktime Player / Apple avmediainfo...

```
$ ffmpeg -f lavfi -i "testsrc2=size=ntsc:rate=ntsc[out]" -c:v mpeg2video -t 30 ./test.mov -y

$ avmediainfo ./test.mov
>  Movie analyzed with 0 error.
```

Workaround: GPAC/MP4Box can remux that mov to an mp4. This performs a true remux, not just a mov>mp4 rename.
```
$ MP4Box -add ./test.mov -new ./test.mp4

$ avmediainfo ./test.mov
>  Movie analyzed with 0 error.
```

Will need further investigation:
- `-tag:v` vs `-codec_tag` Unsupported
- MOV vs MP4 vs ISOBMFF boxes and atoms

```
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from './test.mp4':
  Metadata:
    major_brand     : isom
    minor_version   : 512
    compatible_brands: isomiso2mp41
    encoder         : Lavf61.7.100
  Duration: 00:00:30.00, start: 0.000000, bitrate: 548 kb/s
  Stream #0:0[0x1](und): Video: mpeg2video (Main) (mp4v / 0x7634706D), yuv420p(tv, progressive), 720x480 [SAR 1:1 DAR 3:2], 546 kb/s, 29.97 fps, 29.97 tbr, 30k tbn (default)
      Metadata:
        handler_name    : VideoHandler
        vendor_id       : [0][0][0][0]
        encoder         : Lavc61.19.100 mpeg2video
```
vs
```
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from './test.mov':
  Metadata:
    major_brand     : qt  
    minor_version   : 512
    compatible_brands: qt  
    encoder         : Lavf61.7.100
  Duration: 00:00:30.00, start: 0.000000, bitrate: 548 kb/s
  Stream #0:0[0x1]: Video: mpeg2video (Main) (m2v1 / 0x3176326D), yuv420p(tv, progressive), 720x480 [SAR 1:1 DAR 3:2], 546 kb/s, 29.97 fps, 29.97 tbr, 30k tbn (default)
      Metadata:
        handler_name    : VideoHandler
        vendor_id       : FFMP
        encoder         : Lavc61.19.100 mpeg2video
```

### Progressive segmented-Frame (PsF) & Quasi-interlace

Poynton in "Digital Video and HDTV Algorithms and Interfaces" states *"24PsF Image format is typically 1920×1080" and "A scheme called Progressive segmented-Frame has been adopted to adapt HDTV equipment to handle images at 24 frames per second. The scheme, denoted 24PsF, samples in progressive fashion: Both fields represent the same instant in time, and vertical filtering to reduce twitter is both unnecessary and undesirable. However, lines are rearranged to interlaced order for studio distribution and recording."*

*"The Progressive segmented-Frame (PsF) technique is known in consumer SDTV systems as quasi-interlace."

Quasi-Interlace is a *"Term in consumer electronics denoting progressive segmented frame"* and *"Quasi-interlace in consumer SDTV is comparable to Progressive segmented-Frame (PsF) in HDTV, though at 25 or 29.97 frames per second instead of 24"*

### Pulldown with x264 command line interface [Informational]

This script/repo deals exclusively with mpeg2video/H.262.  However, the following is included as a quick note on the x264 command line tool, with the aim of validating the pulldown pattern with FFprobe and achieving the same pulldown pattern as mpeg2video + DGPulldown.  It is noted that FFmpeg's libx264 foes not support `-x264opts pulldown=32` or `-x264-params pulldown=32`.

```bash
$ ffmpeg -hide_banner -loglevel 'error' -f 'lavfi' -i "testsrc2=rate='ntsc-film'" -frames:v 24 -f 'yuv4mpegpipe' - \
  | x264 --quiet --demuxer 'y4m' --keyint 12 --crf 23 --bframes 2 --pulldown 32 -o - - \
  | ffprobe -hide_banner -loglevel 'error' -f 'h264' -framerate 'ntsc-film' - -show_entries 'frame=pict_type,interlaced_frame,top_field_first,repeat_pict' -print_format 'compact' 
                                                                               
frame|pict_type=I|interlaced_frame=0|top_field_first=1|repeat_pict=1|
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

### References

- [BT.601: Studio encoding parameters of digital television for standard 4:3 and wide screen 16:9 aspect ratios](https://www.itu.int/rec/R-REC-BT.601-7-201103-I/en)
- [BT.709: Parameter values for the HDTV standards for production and international programme exchange.](https://www.itu.int/rec/R-REC-BT.709)
- [MPEG2Video/H.262 Specification](https://www.itu.int/rec/T-REC-H.262-200002-S/en).  Older version is public
- [DVD Format/Logo Licensing Corporation (FLLC)](https://www.dvdfllc.co.jp/notice.html#october)
- DVD Demystified.  TAILOR, J. (McGraw-Hill)
  - [First edition (1998).](https://archive.org/details/B-001-001-580)
  - [Second edition (2001).](https://archive.org/details/dvddemystified00tayl)
  - [Third Edition (2006).](https://archive.org/details/dvddemystified0000tayl_a1x8)
  - [Bonus Disc for Second & Third Edition.](https://archive.org/details/DVDDemystifiedBonusDisc)
- Digital Video and HD, Algorithms & Interfaces. POYNTON, Charles.  (Morgan Kaufmann)
  - [First Edition (2003)](https://archive.org/details/DigitalVideoForDummies/Digital%20Video%20And%20Hdtv%20Algorithms%20And%20Interfaces/)
  - [Second Edition (2012)](https://archive.org/details/digital-video-and-hd-algorithms-and-interfaces-2nd-ed.-poynton-2012-02-07/)
- Fundamentals of Multimedia.   LI Ze-Nian; DREW Mark S.; LIU Jiangchuan (Pearson / Springer)
  - [First Edition (2004)](https://archive.org/details/fundamentalsofmu0000lize)
  - [Second Edition (2014)](https://archive.org/details/fundamentalsofmu0000lize_2ed6/)
  - [Third Edition (2021)](https://link.springer.com/book/10.1007/978-3-030-62124-7)
- [Mediainfo MPEG2 Pulldown support](https://github.com/MediaArea/MediaInfoLib/blob/4af6558e86ac3e64a248af4d7e985d7135d84b18/Source/MediaInfo/Video/File_Mpegv.cpp#L1353)
