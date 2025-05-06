@header package course_shader
@header import sg "shared:sokol/gfx"
@header import m "../../../lib/math"

@ctype mat4 m.mat4
@ctype vec3 m.vec3

@vs vs
layout(binding=0) uniform vs_params {
    mat4 mvp;
};

in vec4 position;
in vec4 color0;
in vec4 normal0;
out vec4 color;
out vec4 normal;

void main() {
    gl_Position = mvp * position;
    color = color0;
    normal = normal0;
}
@end

@fs fs
in vec4 color;
in vec4 normal;
out vec4 frag_color;

void main() {
    frag_color = mix(color, normal, 0.5);
}
@end

@program course vs fs
