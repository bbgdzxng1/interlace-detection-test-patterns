## Create a 480i, interlaced DVD-Video with FFmpeg and dvdauthor.

Simple DVD-Video framework.

### Exampke dvdauthor control file

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<dvdauthor>
  <vmgm/>
  <titleset>
    <titles>
      <pgc>
        <vob file="./source_video.vob" chapters="00:00:00.000,00:00:30.000"/>
      </pgc>
    </titles>
  </titleset>
</dvdauthor>
```

### Color accuracy & macOS DVD Player & FFmpeg smptebars

Do not trust the colors.  Assume that the this is not a color-correct workflow.
- By default, FFmpeg's smptebars filter tags frames as bt470bg/unknown/unkown, which is not the correct colorspace for SD smptebars (which should be either SMPTE170M or RGB).  I'm not sure whether it is the tagging that is incorrect or the filter itself.
- Colors appear to be washed-out in macOS DVD Player, but look fine in MPV/VLC.  Furthermore, the colors appear to be correct when a TS is played in macOS QuickTime Player.
- I tried various combinations of colorspace filter, colorspace options, and pix_fmt options but there is still variance between players.  Therefore, I'm deliberately not specifying any colorspace flags'n'tags and assuming that the colorspace is incorrect.
- it may be preferable to use smptehdbars, bt.709 and convert to smpte170m.

