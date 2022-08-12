# HLS-Streaming-Server

* Streaming video via obs
```
rtmp://ip-address:1935/live
```

* Streaming video via ffmpeg
```
ffmpeg -i movie.mp4 -vcodec copy -loop -1 -c:a aac -b:a160k -ar 44100 -strict -2 -f flv rtmp:/ip-addresss:1935/live
```

* Receiving video hls and Mpeg-Dash streams
```
http://ip-address:8080/hls/index.m3u8
http://ip-address:8080/dash/index.mpd
```
