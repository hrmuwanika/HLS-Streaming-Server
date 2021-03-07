# HLS-Streaming-Server

* Streaming video via obs
```
rtmp://ip-address:1935/stream
```

* Streaming video via ffmpeg
```
ffmpeg -i movie.mp4 -vcodec copy -loop -1 -c:a aac -b:a160k -ar 44100 -strict -2 -f flv rtmp:/ip-addresss:1935/stream
```

* Receiving video hls streams
```
http://ip-address:8080/stream/hls/stream_name/index.m3u8
```

* Receiving video dash streams
```
http://ip-address:8080/stream/dash/stream_name/index.mpd
```
