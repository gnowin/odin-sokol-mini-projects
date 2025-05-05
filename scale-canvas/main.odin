package main

import "base:runtime"
import slog "shared:sokol/log"
import sg "shared:sokol/gfx"
import sapp "shared:sokol/app"
import sglue "shared:sokol/glue"
import m "../lib/math"
import lin "core:math/linalg"

dimensions :: struct {
	width  : i32,
	height : i32,
}

OFFSCREEN_DIM : dimensions : {80, 60}
DEFAULT_DIM   : dimensions : {1200, 900}

state: struct {
	offscreen: struct {
		pass_action: sg.Pass_Action,
		attachments: sg.Attachments,
		pip: sg.Pipeline,
		bind: sg.Bindings,
	},
	default: struct {
		pass_action: sg.Pass_Action,
		pip: sg.Pipeline,
		bind: sg.Bindings,
	},
	rx, ry:    f32,
}

setup_plane :: proc (color_img : sg.Image) {
	plane_vertices := [?]f32 {
		0.0, 0.0, 0.0,   1.0, 0.0, 0.0, 1.0,	0.0,0.0,
		1.0, 0.0, 0.0,   1.0, 0.0, 0.0, 1.0,	1.0,0.0,
		1.0,  1.0, 0.0,   1.0, 0.0, 0.0, 1.0,	1.0,1.0,
		0.0,  1.0, 0.0,   1.0, 0.0, 0.0, 1.0,	0.0,1.0,
	}	
	plane_indices := [?]u16 {
		0, 1, 2, 0, 2, 3,
	}
	smp := sg.make_sampler({
		min_filter = .NEAREST,
		mag_filter = .NEAREST,
		wrap_u = .REPEAT,
		wrap_v = .REPEAT,
	})
	vb : [8]sg.Buffer
	vb[0] = sg.make_buffer({
			data = { ptr = &plane_vertices, size = size_of(plane_vertices) },
		})
	state.default.bind = {
		vertex_buffers = vb,
		index_buffer = sg.make_buffer({
			type = .INDEXBUFFER,
			data = { ptr = &plane_indices, size = size_of(plane_indices) },
		}),
		images = { IMG_tex = color_img },
		samplers = { SMP_smp = smp },
	}
	state.default.pip = sg.make_pipeline({
		shader = sg.make_shader(default_shader_desc(sg.query_backend())),
		layout = {
			buffers = {
				0 = { stride = 36 },
			},
			attrs = {
				ATTR_default_position= { format = .FLOAT3 },
				ATTR_default_color0= { format = .FLOAT4 },
				ATTR_default_texcoord0 = { format = .FLOAT2 },
			},
		},
		index_type = .UINT16,
		cull_mode = .BACK,
		depth = {
			write_enabled = true,
			compare = .LESS_EQUAL,
		},
	})
}
setup_cube :: proc (color_img : sg.Image, depth_img : sg.Image) {
	state.offscreen.attachments = sg.make_attachments({
		colors = {
			0 = { image = color_img},
		},
		depth_stencil = {
			image = depth_img,
		}
	})
	// cube vertex buffer
	cube_vertices := [?]f32 {
		-1.0, -1.0, -1.0,   1.0, 0.0, 0.0, 1.0,
		1.0, -1.0, -1.0,   1.0, 0.0, 0.0, 1.0,
		1.0,  1.0, -1.0,   1.0, 0.0, 0.0, 1.0,
		-1.0,  1.0, -1.0,   1.0, 0.0, 0.0, 1.0,

		-1.0, -1.0,  1.0,   0.0, 1.0, 0.0, 1.0,
		1.0, -1.0,  1.0,   0.0, 1.0, 0.0, 1.0,
		1.0,  1.0,  1.0,   0.0, 1.0, 0.0, 1.0,
		-1.0,  1.0,  1.0,   0.0, 1.0, 0.0, 1.0,

		-1.0, -1.0, -1.0,   0.0, 0.0, 1.0, 1.0,
		-1.0,  1.0, -1.0,   0.0, 0.0, 1.0, 1.0,
		-1.0,  1.0,  1.0,   0.0, 0.0, 1.0, 1.0,
		-1.0, -1.0,  1.0,   0.0, 0.0, 1.0, 1.0,

		1.0, -1.0, -1.0,    1.0, 0.5, 0.0, 1.0,
		1.0,  1.0, -1.0,    1.0, 0.5, 0.0, 1.0,
		1.0,  1.0,  1.0,    1.0, 0.5, 0.0, 1.0,
		1.0, -1.0,  1.0,    1.0, 0.5, 0.0, 1.0,

		-1.0, -1.0, -1.0,   0.0, 0.5, 1.0, 1.0,
		-1.0, -1.0,  1.0,   0.0, 0.5, 1.0, 1.0,
		1.0, -1.0,  1.0,   0.0, 0.5, 1.0, 1.0,
		1.0, -1.0, -1.0,   0.0, 0.5, 1.0, 1.0,

		-1.0,  1.0, -1.0,   1.0, 0.0, 0.5, 1.0,
		-1.0,  1.0,  1.0,   1.0, 0.0, 0.5, 1.0,
		1.0,  1.0,  1.0,   1.0, 0.0, 0.5, 1.0,
		1.0,  1.0, -1.0,   1.0, 0.0, 0.5, 1.0,
	}
	cube_indices := [?]u16 {
		0, 1, 2,  0, 2, 3,
		6, 5, 4,  7, 6, 4,
		8, 9, 10,  8, 10, 11,
		14, 13, 12,  15, 14, 12,
		16, 17, 18,  16, 18, 19,
		22, 21, 20,  23, 22, 20,
	}
	vb : [8]sg.Buffer
	vb[0] =  sg.make_buffer({
			data = { ptr = &cube_vertices, size = size_of(cube_vertices) },
		})
 	state.offscreen.bind = {
		vertex_buffers = vb, 
		index_buffer = sg.make_buffer({
			type = .INDEXBUFFER,
			data = { ptr = &cube_indices, size = size_of(cube_indices) },
		}),
	}
	state.offscreen.pip = sg.make_pipeline({
		shader = sg.make_shader(offscreen_shader_desc(sg.query_backend())),
		layout = {
			buffers = {
				0 = { stride = 28 },
			},
			attrs = {
				ATTR_offscreen_position= { format = .FLOAT3 },
				ATTR_offscreen_color0= { format = .FLOAT4 },
			},
		},
		index_type = .UINT16,
		cull_mode = .BACK,
		sample_count = 1,
		depth = {
			pixel_format = .DEPTH,
			write_enabled = true,
			compare = .LESS_EQUAL,
		},
		colors = {
			0 = { pixel_format = .RGBA8 },
		}
	})

}

init :: proc "c" () {
	context = runtime.default_context()
	sg.setup({
		environment = sglue.environment(),
		logger = { func = slog.func },
	})	
	img_desc := sg.Image_Desc {
		render_target = true,
		width = OFFSCREEN_DIM.width,
		height = OFFSCREEN_DIM.height,
		pixel_format = .RGBA8,
		sample_count = 1,
	}
	color_img := sg.make_image(img_desc)
	img_desc.pixel_format = .DEPTH
	depth_img := sg.make_image(img_desc)
	setup_cube(color_img, depth_img)
	setup_plane(color_img)
}

frame :: proc "c" () {
	context = runtime.default_context()
	t := f32(sapp.frame_duration())
	state.rx += 1.0 * t
	state.ry += 2.0 * t

	// vertex shader uniform with model-view-projection matrix	
	pass_action := sg.Pass_Action {
		colors = {
			0 = { load_action = .CLEAR, clear_value = { 0.25, 0.5, 0.75, 1.0 } },
		},
	}
	vs_params := Vs_Params {
		mvp = compute_mvp(rx = state.rx, ry = state.ry)
	}
	sg.begin_pass({ action = pass_action, attachments = state.offscreen.attachments })
	sg.apply_pipeline(state.offscreen.pip)
	sg.apply_bindings(state.offscreen.bind)
	sg.apply_uniforms(UB_vs_params, { ptr = &vs_params, size = size_of(vs_params) })
	sg.draw(0, 36, 1)
	sg.end_pass()
	vs_params = Vs_Params {
		mvp = compute_ortho_mvp(),
	}
	pass_action = sg.Pass_Action {
		colors = {
			0 = { load_action = .CLEAR, clear_value = { 0.25, 0.5, 0.75, 1.0 } },
		},
	}
	sg.begin_pass({ action = pass_action, swapchain = sglue.swapchain() })
	sg.apply_pipeline(state.default.pip)
	sg.apply_bindings(state.default.bind)
	sg.apply_uniforms(UB_vs_params, { ptr = &vs_params, size = size_of(vs_params)} )
	sg.draw(0, 6, 1)
	sg.end_pass()
	sg.commit()
}

compute_mvp :: proc (rx, ry: f32) -> m.mat4 {
	proj := lin.matrix4_perspective_f32(fovy = 95.0, aspect = 4.0/3.0, near = 0.01, far = 10.0)
	view := lin.matrix4_look_at_f32(eye = {0.0, 0.0, 6.0}, centre = {0.0, 0.0, 0.0}, up = {0.0, 1.0, 0.0}, flip_z_axis = true)
	rxm := lin.matrix4_rotate_f32(rx, {1.0, 0.0, 0.0})
	rym := lin.matrix4_rotate_f32(ry, {0.0, 1.0, 0.0})
	model := rxm * rym
	return proj * view * model
}
compute_ortho_mvp :: proc () -> m.mat4 {
	proj := lin.matrix_ortho3d_f32(0, 1, 1, 0, -1000, 1000)
	return proj
}

cleanup :: proc "c" () {
	context = runtime.default_context()
		sg.shutdown()
	}

	main :: proc () {
	sapp.run({
		init_cb = init,
		frame_cb = frame,
		cleanup_cb = cleanup,
		width = DEFAULT_DIM.width,
		height = DEFAULT_DIM.height,
		sample_count = 4,
		window_title = "cube",
		icon = { sokol_default = true },
		logger = { func = slog.func },
	})
}
