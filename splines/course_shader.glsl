@header package course_shader
@header import sg "shared:sokol/gfx"
@header import m "../../../lib/math"

@ctype mat4 m.Mat4
@ctype vec3 m.Vec3

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

	vec3 light_pos = vec3(30.0,0.0,100.0);
	vec3 camera_pos = vec3(0.0,0.0,180.0);
	vec4 light_color = vec4(0.5,0.0,0.3,1.0);


	vec3 light_dir = normalize(light_pos - vec3(mvp * position));
	float diff = max(dot(vec3(normal0), light_dir), 0.0);
	vec4 diffuse = diff * light_color;
	vec4 ambient = 0.5 * light_color;
	vec4 result = (ambient+diffuse) * color0;

	color = result;

	normal = normal0;
}
@end

@fs fs
in vec4 color;
in vec4 normal;
out vec4 frag_color;

void main() {
	frag_color = color;
    //frag_color = mix(color, normal, 0.5);
}
@end

@program course vs fs
