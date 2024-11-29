# Test patterns for deinterlace and inverse-telecine

These test patterns are useful for evaluating:
- FFmpeg's idet (interlace detect) filter
- dgpulldown's soft telecine tool
- Media analyzers (FFprobe, mediainfo, wader/fq, https://media-analyzer.pro/app etc)
- General deinterlacers and the pullup processes


#### Notes

- The test patterns include a frame-countup of {0-29} or {0..23} front-and-center stage.  The large font ensures that there are sufficient changing pixels for FFmpeg's idet to produce an accurate result.
- The two interlace test patterns include Top & Bottom Field indicators
- The two telecine test patterns include ABCD cadence pattern indicators
- The source is generated at yuv422p, then interlaced or telecined and finally converted to yuv420p.  The drawtext and tinterlace filters prefer running in yuv422p.
- The soft telecine test pattern requires dgpulldown 1.0.11 for generation of soft telecine.  dgpulldown 1.0.11-L (Linux/macOS) has some build quirks on compilation on macOS.  dgpulldown appears to generate a 3:2 pulldown pattern when soft telecine is applied (* citation needed) since 'repeatfields,idet' produces the same result as FFmpeg's 'pulldown=pattern=32' hard telecine.  dgpulldown does not offer the option to select between [ 23 | 32 | 2332 ] pulldown patterns.  Caveat: Pulldown patterns may also depend on the version of dgpulldown.
- The script contains almost no error checking of success.  That is intentional to make the script readable & accessible.
- The accuracy of FFmpeg's idet filter can be improved by using 'extractplanes=planes='y',idet' to focus on the y plane, since yuv420p may not have sufficient vertical resolution in the chroma planes to produce an accurate result
- In theory, output files can be concatted to produce a hybrid/mixed stream. "-seq_disp_ext:v 'always'" is specified to always(?) write a Sequence Display Extension.
- Files are generated as MPEG2-TS and remuxed to MKV.  MPEG-TS is a more broadcasty format, but MKV is included to mimic the output produced from MakeMKV DVD rip.
- These extreme interlace test patterns expose one of the weaknesses of the bwdif deinterlacer.  For general use, bwdif remains superior to yadif, but the particular characteristics of the content exposes bwdif's weakness.
  - bwdif is a selective, block-based deinterlacer.  It decides on a block-level whether to either line-double (bob) or weave.  The algorithm struggles with very rapid changes between fields.  bwdif will leave artifacts with these test patterns.
  - yadif is a more unselective, field-based deinterlacer and can handle very rapid changes between fields.


<!-- 
### Github-specific Previews

https://github.com/user-attachments/assets/b1639c0f-52d5-4c2f-8880-3d5981cca0ac

https://github.com/user-attachments/assets/4d69cb10-89ea-4521-b62b-c511f17745b0

https://github.com/user-attachments/assets/c4664e3c-3519-44d7-8603-5f3169e81434

https://github.com/user-attachments/assets/d08a4902-63b0-4cb4-8846-0901e50e4740 -->
