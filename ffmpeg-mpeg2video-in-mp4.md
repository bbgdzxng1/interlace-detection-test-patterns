#### MPEG2Video/H.262 in MP4 (macOS & FFmpeg compatibility)

I believe that MPEG-2 Video is a valid container format for MPEG-2 Video codec, although the use case is not common.

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
- `-tag:v` vs `-codec_tag` Unsupported?
- MOV vs MP4 vs ISOBMFF boxes and atoms?

Here's the difference...

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