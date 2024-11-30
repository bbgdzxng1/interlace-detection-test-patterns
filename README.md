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

#### TODO

- [x] Overlay the names of the test cases into each video.  WARNING: progressive test case has the wrong overlay.  Needs separate function.
- [ ] Investigate audio frame_size
- [ ] Only analyse if dependency is installed
- [ ] Use `jq` for parsing and summarizing the json (WIP)
- [ ] -flags:v '+bitexact' # so as to avoid unnecessry git changes
- [ ] -flags:a '+bitexact' # so as to avoid unnecessry git changes
- [ ] Add gnuplot graphs to plot csv/tsv to svg

## Notes

### FFmpeg bwdif & yadif
- These extreme-case interlace test patterns expose one of the weaknesses of the bwdif deinterlacer.  For general use, bwdif remains superior to yadif, but the particular characteristics of the content exposes bwdif's weakness.
  - bwdif is a selective, block-based deinterlacer.  It decides on a block-level whether to either line-double (bob) or weave.  The algorithm struggles with very rapid changes between fields.  bwdif will leave artifacts with these test patterns.
  - yadif is a more unselective, field-based deinterlacer and can handle very rapid changes between fields.

### MPEG2Video/H.262 in MP4 (macOS & FFmpeg compatibility)

FFmpeg can't write mpeg2video & ac3 to an MP4, in a way that Apple Quicktime / Apple avmediainfo likes...

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

But FFmpeg can write mpeg2video & ac3 to an MOV, which is compatible...

```
$ ffmpeg -f lavfi -i "testsrc2=size=ntsc:rate=ntsc[out]" -c:v mpeg2video -t 30 ./test.mov -y

$ avmediainfo ./test.mov
>  Movie analyzed with 0 error.
```

And GPAC/MP4Box can remux that MOV to an MP4. This is a true remux, not a rename.
```
$ MP4Box -add ./test.mov -new ./test.mp4

$ avmediainfo ./test.mov
>  Movie analyzed with 0 error.
```

Will need further investigation:
- `-tag:v`
- `-codec_tag`
- MOV vs MP4 vs ISOBMFF boxes and atoms.
