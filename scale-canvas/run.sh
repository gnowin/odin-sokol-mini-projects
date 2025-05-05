#!/bin/bash
NAME="scale-canvas"
sokol-shdc --input ./$NAME/shader.glsl --output ./$NAME/shader.odin --format sokol_odin --slang glsl430
mkdir -p ./build
odin run ./$NAME -out=./build/$NAME
