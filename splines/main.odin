#+feature dynamic-literals
package main

import "base:runtime"
import slog "shared:sokol/log"
import sg "shared:sokol/gfx"
import sapp "shared:sokol/app"
import sglue "shared:sokol/glue"

import imgui "shared:odin-imgui"
import imgl "shared:odin-imgui/imgui_impl_opengl3"

import log "core:log"
import math "core:math"
import lin "core:math/linalg"

import shader1 "shaders/shader"
import course_shader "shaders/course_shader"

import m "../lib/math"
import g "../lib/graphics"
import input "../lib/input"

default_context : runtime.Context

state: struct {
    pass_action: sg.Pass_Action,
    pip: sg.Pipeline,
    bind: sg.Bindings,
}

point :: struct {
	pos : m.Vec2,
	color : m.RGB,
}

marker : f32 = 0.0

selected_point : int = 0

vertex :: struct {
	pos :m.Vec3,
	color :	m.RGBA,
	normal : m.Vec3,
}

course : Course

camera := g.DEFAULT_CAMERA

WINDOW_DIMENSIONS :: [2]i32{960, 720}

io : ^imgui.IO

init :: proc "c" () {
	context = default_context

	sg.setup({
		environment = sglue.environment(),
		logger = { func = slog.func },
	})

	imgui_ctx := imgui.CreateContext()
	io = imgui.GetIO()
	io.ConfigFlags += { .NavEnableKeyboard, .DockingEnable }
	io.DisplaySize = { f32(sapp.width()), f32(sapp.height()) }
	imgl.Init("#version 430")

	log.debug(sapp.width())
	log.debug(sapp.height())

	log.debug(f32(WINDOW_DIMENSIONS.x)/sapp.dpi_scale())


	vertices := [?]f32 {
		// positions         colors
		-0.5,  0.5, 0.0,     1.0, 1.0, 1.0, 1.0,
		 0.5,  0.5, 0.0,     1.0, 1.0, 1.0, 1.0,
		 0.5, -0.5, 0.0,     1.0, 1.0, 1.0, 1.0,
		-0.5, -0.5, 0.0,     1.0, 1.0, 1.0, 1.0,
	}
	state.bind.vertex_buffers[0] = sg.make_buffer({
		data = { ptr = &vertices, size = size_of(vertices) },
		usage = {
			vertex_buffer 	= true,
			immutable	= true,
		}
	})

	indices := [?]u16 { 0, 1, 2,  0, 2, 3 }
	state.bind.index_buffer = sg.make_buffer({
		data = { ptr = &indices, size = size_of(indices) },
		usage = {
			index_buffer 	= true,
			immutable	= true,
		}
	})

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

	state.pass_action = {
		colors = {
		    0 = { load_action = .CLEAR, clear_value = { 0, 0, 0, 1 }},
		},
	}

	setup_course(&course)	
	course_append_point(&course, {0,0,0})
	
	camera.position = {0.0, 0.0, 180.0}
}


event :: proc "c" (e : ^sapp.Event) {
	context = default_context

	input.handle_input_event(e)
}

handle_input :: proc (dt : f32) {
	// Change point
	if input.key_pressed(.N) {
		selected_point = (selected_point + 1) % int(course.point_count)
	}
	if input.key_pressed(.C) {
		camera_state = (camera_state + 1) % 2
	}

	if input.key_pressed(.E) {
		course.lines_per_section += 1	
	}
	if input.key_pressed(.Q) {
		course.lines_per_section -= 1	
	}
	// Move selected point
	move_speed : f32 = 60.0
	if input.key_down(.W) {
		course.point_positions[selected_point].y -= move_speed * dt
	}
	if input.key_down(.S) {
		course.point_positions[selected_point].y += move_speed * dt
	}
	if input.key_down(.A) {
		course.point_positions[selected_point].x -= move_speed * dt
	}
	if input.key_down(.D) {
		course.point_positions[selected_point].x += move_speed * dt
	}
	if input.key_down(.J) {
		course.point_positions[selected_point].z -= move_speed * dt
	}
	if input.key_down(.K) {
		course.point_positions[selected_point].z += move_speed * dt
	}
	rotate_speed : f32 = 0.2

	if input.key_down(.LEFT) {
		g.rotate_camera_yaw(&camera, rotate_speed * dt)
	}
	if input.key_down(.RIGHT) {
		g.rotate_camera_yaw(&camera, -rotate_speed * dt)
	}

	if input.key_down(.UP) {
		g.rotate_camera_pitch(&camera, -rotate_speed * dt)
	}
	if input.key_down(.DOWN) {
		g.rotate_camera_pitch(&camera, rotate_speed * dt)
	}



	// move marker
	if input.key_down(.Z) {
		marker -= 1.0 * dt
	}
	if input.key_down(.X) {
		marker += 1.0 * dt
	}
	if marker <= 0.0 {
		marker += f32(len(course.point_positions))
	}
	if marker >= f32(course.point_count) {
		marker -= f32(course.point_count)
	}

	// Add new point in spline
	if input.mouse_pressed(.LEFT){
		m_pos := input.get_mouse_pos()
		w_dim := m.Vec2{f32(WINDOW_DIMENSIONS.x), f32(WINDOW_DIMENSIONS.y)}

		view := g.get_camera_view(camera) 
		proj := g.get_camera_projection(camera)

		ray_world := m.ray_from_mouse_pos(m_pos, w_dim, view, proj) 
		log.debug(ray_world)

		_, intersect := m.line_plane_intersection(camera.position, ray_world, {0.0,0.0,0.0}, lin.normalize(m.Vec3{0.0,0.0,1.0}))

		if course.point_count < 3 {
			course_append_point(&course, intersect)
		}
		else {
			inject_index : u16 = 0
			distance2 : f32 = math.F32_MAX
			for i in 0..<course.point_count {
				p0 := m.Vec2{intersect.x, intersect.y}
				p1 := course.point_positions[i]
				p2 := course.point_positions[(i+1)%course.point_count]

				d1 := p1.xy - p0	 
				p0p1 := lin.length2(d1)

				d2 := p2.xy - p0
				p0p2 := lin.length2(d2)

				cur_distance2 := p0p1 + p0p2
				if cur_distance2 < distance2 {
					distance2 = cur_distance2

					inject_index = (i+1)%course.point_count
				}
			}
			course_inject_point(&course, intersect, inject_index)
		}


	}

	if input.mouse_down(.LEFT){
		imgui.IO_AddMouseButtonEvent(io, i32(sapp.Mousebutton.LEFT), true)
	} else {
		imgui.IO_AddMouseButtonEvent(io, i32(sapp.Mousebutton.LEFT), false)
	}
}

time : f32
camera_state : int

frame :: proc "c" () {
	context = default_context

	dt := f32(sapp.frame_duration())
	time += dt
	marker += 0.1 * dt

	m_pos := input.get_mouse_pos() * sapp.dpi_scale()
	imgui.IO_AddMousePosEvent(io, m_pos.x, m_pos.y)
	handle_input(dt)

	update_course_model(&course)

	vs_params : shader1.Vs_Params
	
	imgl.NewFrame()
	imgui.NewFrame()

	sg.begin_pass({ action = state.pass_action, swapchain = sglue.swapchain() })

	sg.apply_pipeline(state.pip)
	sg.apply_bindings(state.bind)
	vs_params = shader1.Vs_Params {
		mvp = compute_mvp({0.0, 0.0, -0.1}, scale = m.Vec3{130.0, 100.0, 0.0}),
		p_color = m.Vec3{43, 34, 59}/255.0,
	}

	sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params) })
	sg.draw(0, 6, 1)

	sg.apply_pipeline(course.pip)
	sg.apply_bindings(course.bind)
	vs_params = shader1.Vs_Params {
		mvp = compute_mvp({0.0, 0.0, 0.0}, scale = 1.0),
		p_color = m.Vec3{0.0, 1.0, 0.0}
	}
	sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)})
	sg.draw(0, course.index_count, 1)


	sg.apply_pipeline(state.pip)
	sg.apply_bindings(state.bind)
	spline_point_amount : f32 = 1.0


	for i in 0..<course.point_count {
		vs_params := shader1.Vs_Params {
			mvp = compute_mvp(course.point_positions[i], scale = 1.0),
			p_color = m.Vec3{1.0,1.0,1.0},
		}

		if i == u16(selected_point) {
			vs_params.p_color = m.Vec3{1.0, 0.0, 0.0}
		}
		sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)})
		sg.draw(0, 6, 1)
	}
	if camera_state == 0 {

		p1 := get_spline_point(marker, course.point_positions[:], course.point_count, true)
		g1 := get_spline_gradient(marker, course.point_positions[:], course.point_count, true)
		p2, p3 := get_spline_wings(p1, g1, 3.0)

		vs_params = shader1.Vs_Params {
			mvp = compute_mvp(m.Vec3(p1)),
			p_color = {0.0, 0.0, 1.0}
		}		
		vs_params.mvp = compute_mvp( p1 )
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
		
		vs_params.mvp = compute_mvp( p1 + lin.normalize(g1) * 5.0)
		vs_params.p_color = { 0.0, 0.0, 1.0 }
		sg.apply_uniforms(shader1.UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)})
		sg.draw(0, 6, 1)

	}

	imgui.Begin("test")
	{
		imgui.Text("Hello!", 123)
		if imgui.Button("Save"){
			log.debug("woaaa")
		}
		if imgui.IsWindowHovered() {
			log.debug("hovering")
		}
	}	
	imgui.End()

	imgui.Render()
	imgl.RenderDrawData(imgui.GetDrawData())
	
	sg.end_pass()
	
	sg.commit()
}
compute_ortho_mvp :: proc (pos : m.Vec3, scale : f32 = 3.0) -> m.Mat4 {
	proj := lin.matrix_ortho3d_f32(0, 160, 80, 0, -1000, 1000)
	model := lin.matrix4_translate_f32({pos.x, pos.y, 0}) * lin.matrix4_scale_f32(scale)
	return proj * model
}

compute_mvp :: proc (pos : m.Vec3, scale : m.Vec3 = 3.0) -> m.Mat4 {
	//proj := lin.matrix4_perspective_f32(fovy = 120.0, aspect = 4.0/3.0, near = 0.01, far = 1000.0)
	proj := g.get_camera_projection(camera)
	view : m.Mat4
	if camera_state == 0 {
		view = g.get_camera_view(camera)
 
	}
	else{
		p1 := get_spline_point(marker, course.point_positions[:], course.point_count, true)
		g1 := get_spline_gradient(marker, course.point_positions[:], course.point_count, true)
		left := right_angle_vector(g1)
		up := lin.normalize(lin.cross(g1, left))
		above_ground := up * 2.5
		view = lin.matrix4_look_at_f32(eye = p1 + above_ground, centre = p1+g1 + above_ground, up = up, flip_z_axis = true)	
	}

	model := lin.matrix4_translate_f32({pos.x, pos.y, pos.z}) * lin.matrix4_scale_f32(scale)
	return proj * view * model
}


cleanup :: proc "c" () {
	context = default_context

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
		width = WINDOW_DIMENSIONS.x,
		height = WINDOW_DIMENSIONS.y,
		fullscreen = false,
		window_title = "Splines",
		icon = { sokol_default = true },
		logger = { func = slog.func },
	})
}
