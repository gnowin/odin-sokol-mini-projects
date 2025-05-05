@header package main
@header import sg "shared:sokol/gfx"
@header import m "../lib/math"

@ctype mat4 m.mat4

@block uniforms
layout(binding=0) uniform vs_params {
    mat4 mvp;
};
@end

// Offscreen shader (without image)
@vs vs_offscreen
@include_block uniforms

in vec4 position;
in vec4 color0;

out vec4 color;

void main() {
    gl_Position = mvp * position;
    color = color0;
}
@end

@fs fs_offscreen
in vec4 color;
out vec4 frag_color;

void main() {
    frag_color = color;
}
@end

@program offscreen vs_offscreen fs_offscreen

// Default shader (with texture)
@vs vs_default
@include_block uniforms

in vec4 position;
in vec4 color0;
in vec2 texcoord0;

out vec2 uv;
out vec4 color;

void main() {
    gl_Position = mvp * position;
    uv = vec2(texcoord0.x + (1.0 / 800.0), texcoord0.y + (1.0 / 600.0));
    uv = texcoord0;
    color = color0;
}
@end

@fs fs_default
layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler smp;

in vec2 uv;
in vec4 color;
out vec4 frag_color;

void main() {
	frag_color = texture(sampler2D(tex,smp),uv);
    //frag_color = color;;//texture(sampler2D(tex, smp), uv);
}
@end

@program default vs_default fs_default
