#!/bin/bash

wget -O test.mp4 https://raw.githubusercontent.com/mediaelement/mediaelement-files/master/big_buck_bunny.mp4
ffmpeg -re -i "big_buck_bunny.mp4" -c:v copy -c:a aac -ar 44100 -ac 1 -f flv rtmp://localhost:1935/live/stream
