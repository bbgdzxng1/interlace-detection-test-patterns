# Test patterns for deinterlace and inverse-telecine

These test patterns are useful for:
- Testing FFmpeg's idet (interlace detect) filter
- Testing dgpulldown's soft telecine tool
- Testing media analyzers & inspecting headers (FFprobe, mediainfo, wader/fq, https://media-analyzer.pro/app etc)
- Evaluating deinterlacers (bwdif, yadif, nnedi) and inverse telecine (pullup, fieldmatch) processes
- Aid in the development of an automated interlace/inverse telecine detection method using FFmpeg's idet filter.
  - https://github.com/mpv-player/mpv/blob/master/TOOLS/idet.sh
  - https://github.com/utahjohnnymontana/DVD-Rip-Prep
  - https://www.mistralsolutions.com/newsletter/Jul13/Field_Dominance_Algorithm.pdf


#### Notes
- The test patterns include a frame-countup of {0..29} or {0..23} front-and-center stage.  The large font ensures that there are sufficient varying pixels for FFmpeg's idet to produce an accurate result.
- The interlace test patterns include Top & Bottom Field visual indicators.  These indicators are not fully deinterlaced by bwdif, but remain weaved.  yadif deinterlaces the visual indicators as expected.
- The telecine test patterns include ABCD cadence pattern visual indicators.
- These extreme-case interlace test patterns expose one of the weaknesses of the bwdif deinterlacer.  For general use, bwdif is considered superior to yadif, but the particular characteristics of the content knowingly expose bwdif's weakness.
  - bwdif is a selective, block-based deinterlacer.  It decides on a block-level whether to either line-double (bob) or weave.  The algorithm struggles with very rapid changes between fields.  bwdif will leave artifacts with these test patterns; bwdif leaves the visual indicators weaved. 
  - yadif is a field-based deinterlacer and leaves fewer artifacts when there are such significant changes between fields.
- The source is generated at yuv422p10le.  The drawtext and tinterlace filters produce better output when operating with a yuv422p (8 or 10bit) source.  After interlacing or telecining, files are finally converted to a yuv420p "consumer" format.  
- The script contains almost no error checking of success.  This is intentional to improve readability.
- The accuracy of FFmpeg's idet filter can be improved by using 'extractplanes=planes='y',idet' to focus on the Y plane, since yuv420p may not have sufficient vertical resolution in the chroma planes to produce an accurate result
- In theory, output files could be concatenated to produce a hybrid/mixed stream. "-seq_disp_ext:v 'always'" is specified to aid concatenation by always(?) writing a Sequence Display Extension, 
- Files are first generated as MPEG2-TS and remuxed to MKV.  MPEG-TS is a more "broadcast" format, but MKV is included to mimic the output produced from a MakeMKV DVD rip.

### DGPulldown
- This script uses DGPulldown 1.0.11 by Donald A. Graft _et al_ to generate the soft-telecine test pattern.
- https://www.rationalqm.us/dgpulldown/dgpulldown.html
- DGPulldown was released under the GNU General Public License v2 (GPLv2).
- Caveat: The dgpulldown 1.0.11-L (Linux/macOS) port has some build quirks on compilation on macOS.
- dgpulldown generates a 3:2 pulldown pattern producing the same result as FFmpeg's 'pulldown=pattern=32' hard telecine.  dgpulldown does not offer an option to specify alternate [ 23 | 32 | 2332 ] pulldown patterns.


#### TODO

- [ ] Add an interlaced tff "untagged" test case, to simulate interlaced content that has been encoded as progressive.
- [ ] Improve the script to only analyse if optional dependencies are installed
- [ ] Use `jq` for parsing and summarizing the json
- [ ] Add gnuplot graphs to plot csv/tsv to svg.
- [ ] Investigate FFmpeg audio frame_size warning when reading from raw ac3 (frame rate estimated from bitrate)
- [ ] Add a Github release(s) of output media.
- [ ] mediainfo has separate fields for "FrameRate_Original" and "FrameRate" - although I have not yet got DGPulldown to trigger this behavior.  Needs further digging.
- [x] ~Overlay the names of the test cases into each video.~
- [x] ~Add a distinct function for progressive.~
- [x] ~Add `-flags:v '+bitexact'` # to avoid unnecessry git changes in media files between architectures~ 

#### Out of Scope / Limitations

- Interlaced 625 / 576i is currently out of scope, but could be added by copying the NTSC templates and using 470b/g colors.
- Complicated pulldown patterns such as euro-pulldown / 2:2 pulldown are out of scope, but pull requests are welcome.
- Progressive segmented-Frame (PsF) & Quasi-interlace are out of scope.
- Field-picture based encoding is out of scope.

## Notes

The current script uses FFmpeg's mpeg2video encoder and dgpulldown, since FFmpeg does not support 3:2 pulldown.

There have been various attempts to add 3:2 pulldown to FFmpeg, but none have reached stable.
- Abandoned attempt to port mplayer's mp=softpulldown filter as an FFmpeg filter.  https://lists.ffmpeg.org/pipermail/ffmpeg-devel/2015-January/thread.html#167982
- Attempt to add a bitstream filter, with `-bsf:v mpeg2_metadata=ivtc=true`.  This was never merged.  https://ffmpeg.org/pipermail/ffmpeg-devel/2020-December/thread.html#274084.  It does not seem like the patch sets the RFF in the Picture Coding Extension, so appears it is not fully functional.
- Original FFmpeg soft-telecine trac ticket.  https://fftrac-bg.ffmpeg.org/ticket/2602

[Here](./mpeg2-encoders.md) are some notes on some alternate, cross platform command-line MPEG-2 encoders.
- MJPEGTool's mpeg2enc supports native 3:2 pulldown.

### qscale iterative search with ab-av1

[ab-av1's](https://github.com/alexheretic/ab-av1) `crf-search` has been updated to support `qscale` for FFmpeg's mpeg2video.  This could be useful for DVD production.

The `crf-search` tool performs an interative search to identify the pseudo-crf (qscale) necessary to achieve an VMAF score of 95.  The mpeg2video qscale is passed to the command as if it were "crf" (ie `--min-crf` is equivilent to `--min-qscale`).

```shell
$ ab-av1 crf-search --cache false \
  -i "${infile}" \
  --min-crf 1 --max-crf 28 \
  --encoder 'mpeg2video' --pix-format 'yuv420p' \
  --enc 'profile:v=main' --enc 'level:v=main' \
  --enc 'g:v=18' --enc 'bf:v=2' \
  --enc 'non_linear_quant:v=true' --enc 'qmax:v=28' \
  --enc 'maxrate:v=8000000' --enc 'bufsize:v=1835006'
``` 

### References

- [BT.601: Studio encoding parameters of digital television for standard 4:3 and wide screen 16:9 aspect ratios](https://www.itu.int/rec/R-REC-BT.601-7-201103-I/en)
- [BT.709: Parameter values for the HDTV standards for production and international programme exchange.](https://www.itu.int/rec/R-REC-BT.709)
- [MPEG2Video/H.262 Specification](https://www.itu.int/rec/T-REC-H.262-200002-S/en).  Older version is now public.
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
- Digital Video: An introduction to MPEG-2.  HASKELL, Barry G; PURI, Atul; NETRAVALI, Arun N. (Kluwer)
  - [First Edition (1997)](https://archive.org/details/digitalvideointr0000hask)
  - [Second Edition (2002)](https://link.springer.com/book/10.1007/b115887)]
- [Mediainfo MPEG2 Pulldown support](https://github.com/MediaArea/MediaInfoLib/blob/4af6558e86ac3e64a248af4d7e985d7135d84b18/Source/MediaInfo/Video/File_Mpegv.cpp#L1353)


### Other Notes

#### TFF vs BFF

- Although the ` { picture_structure, top_field_first, repeat_first_field }` can be modified per picture and is specified in the MPEG-2 Picture Coding Extension, the general consensus (citation needed) seems to be:
  - High Definition BT.709 is always top field first
  - Standard definition DV & mini-DV (PAL or NTSC) is usually bottom field first
  - Standard definition D1 PAL is usually top field first
  - Standard Definition D1 NTSC is usually (but not always) bottom field first
  - Standard Definition ATSC 1.0 captures (via HDHomerun) seem to be TFF.
  - What about DVB-T?
  - What about PAL & NTSC DVDs?  The standard allows both, but does it stand that the convention is that PAL DVDs are TFF and NTSC DVDs are BFF?
 
https://www.provideocoalition.com/field_order/
https://www.dvmp.co.uk/digital-video.htm


#### Progressive segmented-Frame (PsF) & Quasi-interlace

Poynton in "Digital Video and HDTV Algorithms and Interfaces" states *"24PsF Image format is typically 1920×1080" and "A scheme called Progressive segmented-Frame has been adopted to adapt HDTV equipment to handle images at 24 frames per second. The scheme, denoted 24PsF, samples in progressive fashion: Both fields represent the same instant in time, and vertical filtering to reduce twitter is both unnecessary and undesirable. However, lines are rearranged to interlaced order for studio distribution and recording."*

*"The Progressive segmented-Frame (PsF) technique is known in consumer SDTV systems as quasi-interlace."

Quasi-Interlace is a *"Term in consumer electronics denoting progressive segmented frame"* and *"Quasi-interlace in consumer SDTV is comparable to Progressive segmented-Frame (PsF) in HDTV, though at 25 or 29.97 frames per second instead of 24"*


