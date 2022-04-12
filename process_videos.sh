#!/usr/bin/env bash

# use MSYS MINGW64 to run this

for video_file in $(ls assets/video/gallery/*.{webm,mp4}); do
    video_filename=$(basename -- "${video_file}")
    ffmpeg -i "${video_file}" -s 480x270 -q:v 2 -frames:v 1 -y "assets/img/gallery/${video_filename%.*}_thumb.jpg";
done
