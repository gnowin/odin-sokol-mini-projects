//----------------j-------------------------------------------------------------
//  quad/main.odin
//
//  Simple 2D rendering with vertex- and index-buffer.
//------------------------------------------------------------------------------
#+feature dynamic-literals
package main

import "base:runtime"
import slog "shared:sokol/log"
import sg "shared:sokol/gfx"
import sapp "shared:sokol/app"
import sglue "shared:sokol/glue"

import log "core:log"
import math "core:math"
import lin "core:math/linalg"

import shader1 "shaders/shader"
import course_shader "shaders/course_shader"
import m "../lib/math"
import input "../lib/input"

default_context : runtime.Context

state: struct {
    pass_action: sg.Pass_Action,
    pip: sg.Pipeline,
    bind: sg.Bindings,
}

line_state : struct {
	pip: sg.Pipeline,
	bind: sg.Bindings,
	index_count : u16,
}

point :: struct {
	pos : m.vec2,
	color : m.rgb,
}
marker : f32 = 0.0
points := [dynamic]m.vec3 {
	{40, 40, 0.0}
}
selected_point : int = 0

vertex :: struct {
	pos :m.vec3,
	color :	m.rgba,
	normal : m.vec3,
}

MAX_POINTS :: 32
MAX_POINTS_PER_LINE :: 32
MAX_VERTICES :: 2 * MAX_POINTS * MAX_POINTS_PER_LINE
MAX_INDICES :: 6 * MAX_POINTS * MAX_POINTS_PER_LINE

setup_thick_lines_spline :: proc () {
	line_state.bind.vertex_buffers[0] = sg.make_buffer({
		size = MAX_VERTICES * size_of(vertex),
		usage = .STREAM,
	})	
	line_state.bind.index_buffer = sg.make_buffer({
		size = MAX_INDICES * size_of(u16),
		type = .INDEXBUFFER,
		usage = .STREAM,
	})
	line_state.pip = sg.make_pipeline({
		shader = sg.make_shader(course_shader.course_shader_desc(sg.query_backend())),
		index_type = .UINT16,
		layout = {
		    attrs = {
			course_shader.ATTR_course_position = { format = .FLOAT3 },
			course_shader.ATTR_course_color0 = { format = .FLOAT4 },
			course_shader.ATTR_course_normal0 = { format = .FLOAT3 },
		    },
		},
		depth = {
			write_enabled = true,
			compare = .LESS_EQUAL,
		},

	})
}

update_thick_lines_spline :: proc () {
	lps : u8 = 32
	if len(points) > 2 {
		vertices, indices := get_spline_quad_data(points[:], lines_per_section = lps, line_width = 2.0)	
		points_count := len(points)
		vertex_count := points_count * int(lps) * 2
		index_count := points_count * int(lps) * 6

		sg.update_buffer(line_state.bind.vertex_buffers[0], {
			ptr = &vertices,
			size = uint(vertex_count) * size_of(vertex)
		})

		sg.update_buffer(line_state.bind.index_buffer, {
			ptr = &indices,
			size = uint(index_count) * size_of(u16)
		})

		line_state.index_count = u16(index_count)	
	}
}


init :: proc "c" () {
	context = default_context

	sg.setup({
		environment = sglue.environment(),
		logger = { func = slog.func },
	})

	// a vertex buffer
	vertices := [?]f32 {
		// positions         colors
		-0.5,  0.5, 0.0,     1.0, 1.0, 1.0, 1.0,
		 0.5,  0.5, 0.0,     1.0, 1.0, 1.0, 1.0,
		 0.5, -0.5, 0.0,     1.0, 1.0, 1.0, 1.0,
		-0.5, -0.5, 0.0,     1.0, 1.0, 1.0, 1.0,
	}
	state.bind.vertex_buffers[0] = sg.make_buffer({
		data = { ptr = &vertices, size = size_of(vertices) },
	})

	// an index buffer
	indices := [?]u16 { 0, 1, 2,  0, 2, 3 }
	state.bind.index_buffer = sg.make_buffer({
		type = .INDEXBUFFER,
		data = { ptr = &indices, size = size_of(indices) },
	})

	// a shader1 and pipeline object
	state.pip = sg.make_pipeline({
		shader = sg.make_shader(shader1.quad_shader_desc(sg.query_backend())),
		index_type = .UINT16,
		layout = {
		    attrs = {
			shader1.ATTR_quad_position = { format = .FLOAT3 },
			shader1.ATTR_quad_color0 = { format = .FLOAT4 },
		    },
		},
		
	})

	// default pass action
	state.pass_action = {
	colors = {
	    0 = { load_action = .CLEAR, clear_value = { 0, 0, 0, 1 }},
	},
	}
	setup_thick_lines_spline()
}


event :: proc "c" (e : ^sapp.Event) {
	context = default_context

	input.handle_input_event(e)
}

handle_input :: proc (dt : f32) {
	// Change point
	if input.key_pressed(.N) {
		selected_point = (selected_point + 1) % len(points)
	}
	if input.key_pressed(.C) {
		camera = (camera + 1) % 2
	}
	// Move selected point
	move_speed : f32 = 60.0
	if input.key_down(.W) {
		points[selected_point].y -= move_speed * dt
	}
	if input.key_down(.S) {
		points[selected_point].y += move_speed * dt
	}
	if input.key_down(.A) {
		points[selected_point].x -= move_speed * dt
	}
	if input.key_down(.D) {
		points[selected_point].x += move_speed * dt
	}
	if input.key_down(.J) {
		points[selected_point].z -= move_speed * dt
	}
	if input.key_down(.K) {
		points[selected_point].z += move_speed * dt
	}

	if input.key_down(.Z) {
		marker -= 1.0 * dt
	}
	if input.key_down(.X) {
		marker += 1.0 * dt
	}
	if marker <= 0.0 {
		marker += f32(len(points))
	}
	if marker >= f32(len(points)) {
		marker -= f32(len(points))
	}

	if input.mouse_pressed(.LEFT){
		log.debug("HELLO!")
		actual_pos := input.get_mouse_pos() * m.vec2{160.0/2560, 80.0/1280}
		points_len := len(points)

		if points_len < 3 {
			append(&points, m.vec3{actual_pos.x, actual_pos.y, 0.0})	
		}

		inject_index := 0
		distance_sqr2 : f32 = math.F32_MAX

		for i in 0..<points_len {
			p0 := actual_pos
			p1 := points[i]
			p2 := points[(i+1)%points_len]

			d1 := p1.xy - p0	 
			p0p1 := d1.x * d1.x + d1.y * d1.y 

			d2 := p2.xy - p0
			p0p2 := d2.x * d2.x + d1.y * d1.y

			cur_distance_sqr2 := p0p1 + p0p2
			if cur_distance_sqr2 < distance_sqr2 {
				distance_sqr2 = cur_distance_sqr2

				inject_index = (i+1)%points_len
			}
		}
		log.debug(inject_index)
		inject_at(&points, inject_index, m.vec3{actual_pos.x, actual_pos.y, 0.0})	
	}
}

time : f32

frame :: proc "c" () {
	context = default_context

	dt := f32(sapp.frame_duration())
	time += dt
	marker += 0.1 * dt
	handle_input(dt)

	update_thick_lines_spline()

	vs_params : shader1.Vs_Params

	sg.begin_pass({ action = state.pass_action, swapchain = sglue.swapchain() })

	sg.apply_pipeline(line_state.pip)
	sg.apply_bindings(line_state.bind)
	vs_params = shader1.Vs_Params {
		mvp = compute_mvp({0.0, 0.0, 0.0}, scale = 1.0),
		p_color = {0.0, 1.0, 0.0}
	}
	sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)})
	sg.draw(0, line_state.index_count, 1)


	sg.apply_pipeline(state.pip)
	sg.apply_bindings(state.bind)
	spline_point_amount : f32 = 1.0


	for t : f32 = 0.0 ; t < f32(len(points)) ; t+= 1.0/spline_point_amount {
		pos := get_spline_point(t, points[:], true)
		
		vs_params := shader1.Vs_Params {
			mvp = compute_mvp(pos),
			p_color = {0.5, 0.5, 0.5}
		}		
		sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)})
		sg.draw(0, 6, 1)
	}
	for i in 0..<len(points) {
		vs_params := shader1.Vs_Params {
			mvp = compute_mvp(points[i]),
			p_color = {1.0,1.0,1.0},
		}

		if i == int(selected_point) {
			vs_params.p_color = {1.0, 0.0, 0.0}
		}
		sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)})
		sg.draw(0, 6, 1)
	}
	if camera == 0 {

		p1 := get_spline_point(marker, points[:], true)
		g1 := get_spline_gradient(marker, points[:], true)
		p2, p3 := get_spline_wings(p1, g1, 3.0)
		forward := p1+g1
		left := m.vec3{p2.x, p2.y, p2.z}
		p4 := p1 + lin.normalize(lin.cross(left, p1+g1))

		r  := math.atan2(-g1.y, g1.x)

		vs_params = shader1.Vs_Params {
			mvp = compute_mvp(m.vec3(p1)),
			p_color = {0.0, 0.0, 1.0}
		}		
		sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)})
		sg.draw(0, 6, 1)

		vs_params.mvp = compute_mvp(p2)

		vs_params.p_color = { 1.0, 0.0, 1.0 }
		sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)})
		sg.draw(0, 6, 1)

		vs_params.mvp = compute_mvp(p3)
		vs_params.p_color = { 0.0, 1.0, 1.0 }
		sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)})
		sg.draw(0, 6, 1)
		
		vs_params.mvp = compute_mvp( p1 + lin.normalize(g1) * 10.0)
		vs_params.p_color = { 0.0, 0.0, 1.0 }
		sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)})
		sg.draw(0, 6, 1)

		vs_params.mvp = compute_mvp( p1 )
		sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)})
		sg.draw(0, 6, 1)

		vs_params.mvp = compute_mvp( p4 )
		vs_params.p_color = {1.0,1.0,0.0}
		sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)})
		sg.draw(0, 6, 1)


		vs_params.mvp = compute_mvp( forward )
		vs_params.p_color = {1.0,0.0,0.0}
		sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)})
		sg.draw(0, 6, 1)
	
	}
	
	sg.end_pass()
	sg.commit()
}

camera : int

compute_ortho_mvp :: proc (pos : m.vec3, scale : f32 = 3.0) -> m.mat4 {
	proj := lin.matrix_ortho3d_f32(0, 160, 80, 0, -1000, 1000)
	model := lin.matrix4_translate_f32({pos.x, pos.y, 0}) * lin.matrix4_scale_f32(scale)
	return proj * model
}

compute_mvp :: proc (pos : m.vec3, scale : f32 = 3.0) -> m.mat4 {
	proj := lin.matrix4_perspective_f32(fovy = 120.0, aspect = 4.0/3.0, near = 0.01, far = 1000.0)
	view : m.mat4
	if camera == 0 {
		view = lin.matrix4_look_at_f32(eye = {(math.sin(time) - 0.5) * 100, 0.0, 150.0}, centre = {0.0, 0.0, 0.0}, up = {0.0, 1.0, 0.0}, flip_z_axis = true)
	}
	else{
		p1 := get_spline_point(marker, points[:], true)
		g1 := get_spline_gradient(marker, points[:], true)
		w1, _ := get_spline_wings(p1, g1, 1.0)
		up := lin.normalize(lin.cross(p1+g1, w1))
		above_ground := up * 2.5
		view = lin.matrix4_look_at_f32(eye = p1 + above_ground, centre = p1+g1 + above_ground, up = up, flip_z_axis = true)	
	}

	model := lin.matrix4_translate_f32({pos.x, pos.y, pos.z}) * lin.matrix4_scale_f32(scale)
	return proj * view * model
}


cleanup :: proc "c" () {
	context = default_context

	delete(points)

	sg.shutdown()
}

main :: proc () {
	context.logger = log.create_console_logger()	
	default_context = context

    sapp.run({
        init_cb = init,
        frame_cb = frame,
	event_cb = event,
        cleanup_cb = cleanup,
        width = 2560,
        height = 1920,
        window_title = "quad",
        icon = { sokol_default = true },
        logger = { func = slog.func },
    })
}
