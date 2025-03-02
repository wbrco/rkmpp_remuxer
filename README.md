# rkmpp_remuxer
## Remuxer script using [ffmpeg-rockchip](https://github.com/nyanmisaka/ffmpeg-rockchip) from @nyanmisaka

I wrote this script as a test for my Orange Pi 5 Max and it's ability to use the hardware acceleration
of the [RockChip RK3588](http://www.rock-chips.com/a/en/products/RK35_Series/2022/0926/1660.html)

My DVR is fairly small (by today's standards) and is nearly full. Most of my videos are 1080p mp4,
but not all of them. So I figured "what the heck" ..

Well, as I got into doing it, I found that I really wanted to make things work pretty slick, and ended up
spending a lot more time than I expected on developing this, but that's how I am. 

**Some notes on the script:**
- The video files are just a mount on the Orange Pi.
- There is some sort of problem with the mpeg4_rkmpp decoder. it constantly errored. I removed it and use the software decoder instead.
- The script detects the actual size of the media, and if larger than 720p, it resizes it down, maintaining aspect ratio. Otherwise, it maintains the original size and aspect ratio.
- If the audio stream is not aac, it is remuxed to aac, even if the stream is compatible with .mp4.
- The hevc_rkmpp encoder doesn't support CRF, or an encoder preset (high, medium, low etc.) so I used CQP. I will admit that I don't fully understand CQP, particularly in this case. My reading lead me to believe that CQP was fixed, but hevc_rkmpp has the init/max/min settings. I included some links I found very useful in the code comments.
- With the above settings, I get a 50% to 70% reduction of the size of the file with good quality video.
- Transcoding framerate for converting a 1080p h264 video to 720p hevc is ~ 120 FPS. Faster than my Nvidia M2200 in my Lenovo P51!

**Where to tweak**
- I have ffprobe/ffmpeg output when there is an error. However, this doesn't mean that detection/transcoding failed. FFmpeg can recover/fix certain types of errors. If you are getting a lot of error output, but the transcoding continures, try setting -v from 'error' to 'fatal'.
- Regarding the errors setting above. I'm also unable to determine if an 'error' in ffmpeg relates to a non 0 exit code in bash. It *seems* not to, but I can't be 100% sure.
- Try changing the qp_init, qp_max, and qp_min. The ranges are from 0 (none) to 51 (max). See the links in the code for help on these settings. After I ran this, I wish I'd set the qp_max setting higher, which would have given me better reduction in file size. YMMV.
- I have the encoder use the -strict parameter with a value of -2. First the -2 is depreciated, you should use 'experimental'. Second, I don't know if this is necessary.
- I don't do any tweaking of the aac audio. This can be another source of file reduction. See the [FFmpeg AAC](https://trac.ffmpeg.org/wiki/Encode/AAC) encoder page for more info.

**Known issues:**  
- Some .avi/mpeg4 files actually transcode larger. But only **some**. Cause is unknown at this time. I'm not going to dig into it, as I have very few avi/mpeg4 files.

I putting this out with the hopes of others trying to understand the intricacies ffmpeg-rockchip can see a real world implementation.

Enjoy!

B.A.

P.S. Please don't ask questions about building/installing ffmpeg-rockchip. They are way outside the scope of this repo.