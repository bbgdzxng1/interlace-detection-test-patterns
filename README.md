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

### Future - PsF & Quasi-interlace

Poynton in Digital Video and HDTV Algorithms and Interfaces claims *"24PsF Image format is typically 1920×1080" and "A scheme called progressive segmented-frame has been adopted to adapt HDTV equipment to handle images at 24 frames per second. The scheme, denoted 24PsF, samples in progressive fashion: Both fields represent the same instant in time, and vertical filtering to reduce twitter is both unnecessary and undesirable. However, lines are rearranged to interlaced order for studio distribution and recording."*

*"The progressive segmented-frame (PsF) technique is known in consumer SDTV systems as quasi-interlace."

Quasi-Interlace is a *"Term in consumer electronics denoting progressive segmented frame"* and *"Quasi-interlace in consumer SDTV is comparable to progressive segmented-frame (PsF) in HDTV, though at 25 or 29.97 frames per second instead of 24"*


### References

- Older version of H.262 Specification, but publicly available without payment.  https://www.itu.int/rec/T-REC-H.262-200002-S/en
- DVD Format/Logo Licensing Corporation (FLLC) https://www.dvdfllc.co.jp/notice.html#october
- DVD Demystified, Third Edition(2006).  Tailor, J. McGraw-Hill Publishing.
  - First edition		 1998, McGraw-Hill. https://archive.org/details/B-001-001-580
  - Second edition	2001, McGraw-Hill. https://archive.org/details/dvddemystified00tayl
  - Third Edition		2006, McGraw-Hill. https://archive.org/details/dvddemystified0000tayl_a1x8
  - Bonus Disc for Second & Third Edition.  https://archive.org/details/DVDDemystifiedBonusDisc
- Poynton
  - Digital Video and HD, Algorithms & Interfaces, Second Edition.  https://archive.org/details/digital-video-and-hd-algorithms-and-interfaces-2nd-ed.-poynton-2012-02-07/mode/2up
  - Digital Video and HDTV, Algorithms & Interfaces, First Edition.  https://archive.org/details/DigitalVideoForDummies/Digital%20Video%20And%20Hdtv%20Algorithms%20And%20Interfaces/mode/2up
  
- Mediainfo MPEG2 Pulldown support https://github.com/MediaArea/MediaInfoLib/blob/4af6558e86ac3e64a248af4d7e985d7135d84b18/Source/MediaInfo/Video/File_Mpegv.cpp#L1353
