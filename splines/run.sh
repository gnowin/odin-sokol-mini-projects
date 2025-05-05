#!/bin/bash
NAME="splines"

rm ./$NAME/shaders -r
for s in ./$NAME/*.glsl; do
	[ -f "$s" ] || break	
	file=${s##./$NAME/}
	shader_name=${file%.*}
	file_name=$shader_name.odin
	dir=./$NAME/shaders

	mkdir -p $dir
	mkdir -p $dir/$shader_name

	sokol-shdc --input $s --output $dir/$shader_name/$file_name --format sokol_odin --slang glsl430
done

if [ $? -eq 0 ]; then
	mkdir -p ./build
	odin run ./$NAME -out=./build/$NAME
fi
