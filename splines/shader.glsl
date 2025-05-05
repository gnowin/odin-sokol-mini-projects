@header package shader1
@header import sg "shared:sokol/gfx"
@header import m "../../../lib/math"

@ctype mat4 m.mat4
@ctype vec3 m.vec3

@vs vs
layout(binding=0) uniform vs_params {
    mat4 mvp;
    vec3 p_color;
};

in vec4 position;
in vec4 color0;
out vec4 color;

void main() {
    gl_Position = mvp * position;
    color = vec4(p_color, 1.0) * color0;
}
@end

@fs fs
in vec4 color;
out vec4 frag_color;

void main() {
    frag_color = color;
}
@end

@program quad vs fs

