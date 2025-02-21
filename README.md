# Test patterns for deinterlace and inverse-telecine

The script and test patterns in this repository are useful for:
- Testing FFmpeg's `idet` (interlace detect) filter
- Evaluating deinterlacers (bwdif, yadif, nnedi) and inverse telecine (pullup, fieldmatch) workflows
- Testing dgpulldown's soft-telecine tool
- Testing media analyzers & inspecting headers (FFprobe, mediainfo, wader/fq, https://media-analyzer.pro/app etc)
- Aid in the development of an automated interlace/inverse telecine detection method using FFmpeg's idet filter
  - https://github.com/utahjohnnymontana/DVD-Rip-Prep
  - https://github.com/mpv-player/mpv/blob/master/TOOLS/idet.sh
  - https://www.mistralsolutions.com/newsletter/Jul13/Field_Dominance_Algorithm.pdf

The test patterns include a field-countup of {0..59} or {0..23} front-and-center stage.  The large font ensures that there are sufficient varying pixels for FFmpeg's `idet` to produce an accurate result.

One feature that is rarely included in other test patterns are the interlace and telecine indicators.
- The interlace test patterns include Top & Bottom Field visual indicators.  The frames are constructued in such as way so that that when (cleanly) deinterlaced from fields-to-frames that they will separate into Top Field (TF) and Bottom Field (BF).
- The telecine test patterns include ABCD cadence pattern visual indicators.

#### Web previews...

The GIFs embedded in this README are web-previews.  The GIFs are not useful for testing.  Use the MKV or TS media in the repository, or modify the script to customize the output.

Example Test Pattern | Deinterlaced / Inverse Telecined
---|---
Interlaced - Note the TF/BF indicator in the top left. ![bt601-525_480_interlaced_bff](https://github.com/user-attachments/assets/5f686173-6d03-40da-8837-c3be3dba5b3a) | FFmpeg's `yadif` in field mode correctly separates the frame into top field & bottom field ![bt601-525_480_interlaced_bff_yadif](https://github.com/user-attachments/assets/420e80ef-03aa-4caf-bda9-22a4566ca8d4)
Hard Telecined - Note the ABCD telecine pattern indicator in the top right.  Hard telecined content will show 'extra' frames constructed of repeated fields. ![bt601-525_480_telecined_hard](https://github.com/user-attachments/assets/3ee2cc06-95a1-4b32-83dd-e0f8827e1ae1) | FFmpeg's `fieldmatch,decimate=cycle=5` or `pullup` filters should correctly restore 23.98fps and correctly cycle through the ABCD indicators. ![bt601-525_480_telecined_hard_ivtc](https://github.com/user-attachments/assets/208a33ce-a3c5-42b1-9311-fd3c31eb12fa)


#### Notes
- These extreme-case test patterns knowingly produces content that will expose some of the weaknesses of the `bwdif` deinterlacer.  For general use, bwdif is still considered superior to yadif, but the particular characteristics of these test patterns will challenge bwdif.  bwdif is a selective, block-based deinterlacer.  It decides on a per-block level whether to either line-double (bob) or leave the block as weaved.  The bwdif algorithm struggles with very rapid changes between fields.
  - bwdif will leave artifacts with these test patterns
  - bwdif leaves the visual indicators weaved. 
- The video frames are generated at yuv422p10le.  The drawtext and tinterlace filters produce better output when fed with a 444 or 422 source.  After interlacing or telecining, files are finally encoded in an 8-bit yuv420p "consumer" format.
- Files are first generated as MPEG2-TS and subsequently remuxed to MKV.  MPEG-TS is a more "broadcast" format, but MKV is included to mimic the output produced from a MakeMKV DVD rip.
- The script contains almost no error checking of success.  This is intentional to improve readability.
- When dealing with yuv420 chroma-subsampled content, the accuracy of FFmpeg's idet filter can be improved by using `extractplanes=planes='y',idet` to focus on the Y plane, since yuv420p does not have sufficient vertical resolution in the chroma planes for idet to produce an accurate result.
- In theory, the output files could be concatenated to produce a hybrid/mixed stream. "-seq_disp_ext:v 'always'" writes the Sequence Display Extension to aid concatenation. 

### DGPulldown soft telecine
- This script uses FFmpeg's mpeg2video codec and DGPulldown 1.0.11 by Donald A. Graft _et al_ to generate the soft-telecine test pattern.
- https://www.rationalqm.us/dgpulldown/dgpulldown.html
- DGPulldown was released under the GNU General Public License v2 (GPLv2).
- Caveat: The dgpulldown 1.0.11-L (Linux/macOS) port has some build quirks on compilation on macOS.
- dgpulldown generates a 3:2 pulldown pattern producing the same result as FFmpeg's 'pulldown=pattern=32' hard telecine.  dgpulldown does not offer an option to specify alternate [ 23 | 32 | 2332 ] pulldown patterns.

MJPEGTool's mpeg2enc encoder supports native 3:2 pulldown, without the need for DGPulldown.

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

- Although the ` { picture_structure, top_field_first, repeat_first_field }` in the MPEG-2 Picture Coding Extension can be defined on a per-picture basis, the general consensus (citation needed) seems to be:
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


#### TODO

- [ ] Add an interlaced tff "untagged" test case, to simulate interlaced content that has been encoded as progressive.
- [ ] Improve the script to only perform the analyse operation if the optional dependencies are installed
- [ ] Use `jq` for parsing and summarizing the json
- [ ] Add gnuplot graphs to plot csv/tsv to svg.
- [ ] Investigate FFmpeg audio frame_size warning when reading from raw ac3 (frame rate estimated from bitrate)
- [ ] Add a Github release(s) of output media.
- [ ] mediainfo has separate fields for "FrameRate_Original" and "FrameRate" - although I have not yet got DGPulldown to trigger this behavior.  Needs further digging.
- [x] ~Overlay the names of the test cases into each video.~
- [x] ~Add a distinct function for progressive.~
- [x] ~Add `-flags:v '+bitexact'` # to avoid unnecessry git changes in media files between architectures~ 
