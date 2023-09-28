#!/usr/bin/env bash

for video_file in $(ls *.{webm,mp4}); do
    ffmpeg -i "${video_file}" -s 480x270 -q:v 2 -frames:v 1 -y "../../img/gallery/${video_file%.*}_thumb.jpg";
done
