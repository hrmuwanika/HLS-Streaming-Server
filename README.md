# HLS-Streaming-Server

Streaming video via obs
rtmp://host-server:1935/stream

Streaming video via ffmpeg
ffmpeg -i movie.mp4 -vcodec copy -loop -1 -c:a aac -b:a160k -ar 44100 -strict -2 -f flv rtmp://host-server:1935/stream

Receiving video hls streams
http://host-server:8080/stream/hls/mystreamkey.m3u8

Receiving video dash streams
http://host-server:8080/stream/dash/mystreamkey.mpd
