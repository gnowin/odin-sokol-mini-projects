package main

import log "core:log"
import lin "core:math/linalg"

import sg "shared:sokol/gfx"

import course_shader "shaders/course_shader"

import m "../lib/math"

MAX_POINTS :: 32
MAX_POINTS_PER_LINE :: 32
MAX_VERTICES :: 2 * MAX_POINTS * MAX_POINTS_PER_LINE
MAX_INDICES :: 6 * MAX_POINTS * MAX_POINTS_PER_LINE

Course :: struct {
	point_positions		: [MAX_POINTS]m.Vec3,
	point_widths		: [MAX_POINTS]f32,
	point_count		: u16,
	lines_per_section 	: u8,
	pip 			: sg.Pipeline, 
	bind 			: sg.Bindings,
	index_count		: u16,
}

setup_course :: proc (c : ^Course) {
	c.point_count = 0
	c.lines_per_section = 3
	c.bind.vertex_buffers[0] = sg.make_buffer({
		size = MAX_VERTICES * size_of(vertex),
		usage = {
			vertex_buffer 	= true,
			immutable	= false,
			dynamic_update 	= true,
		},
	})	
	c.bind.index_buffer = sg.make_buffer({
		size = MAX_INDICES * size_of(u16),
		usage = {
			index_buffer	= true,
			immutable	= false,
			dynamic_update 	= true,
		},

	})
	c.pip = sg.make_pipeline({
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

_create_model_data :: proc (c : ^Course) -> ([MAX_VERTICES]vertex, [MAX_INDICES]u16) {
	context = default_context
	lps := c.lines_per_section	
	line_count := c.point_count * u16(lps)
	vertex_count := line_count * 2
	line_vertices : [MAX_VERTICES]vertex
	line_indices : [MAX_INDICES]u16

	line_width : f32 = 1.0
	
	i := 0
	for t : f32 = 0.0 ; t < f32(c.point_count) ; t+= 1.0/f32(lps) {
		p := get_spline_point(t, c.point_positions[:], c.point_count, true)
		g := lin.normalize(get_spline_gradient(t, c.point_positions[:], c.point_count, true))	
		w1, w2 := get_spline_wings(p, g, line_width)
		
		left := right_angle_vector(g) 

		normal := lin.normalize(lin.cross(left, g))

		vi := i * 2
		ii := (i * 6)


		line_vertices[vi] 	= vertex{{w2.x, w2.y, w2.z}, {1.0, 1.0, 1.0, 1.0}, normal}
		line_vertices[vi+1] 	= vertex{{w1.x, w1.y, w1.z}, {1.0, 1.0, 1.0, 1.0}, normal}
		
		line_indices[ii] = 	u16(ii/3)	
		line_indices[ii+1] = 	u16(ii/3 + 1) % (vertex_count)
		line_indices[ii+2] = 	u16(ii/3 + 3) % (vertex_count)
		line_indices[ii+3] = 	u16(ii/3 + 3) % (vertex_count)
		line_indices[ii+4] = 	u16(ii/3 + 2) % (vertex_count)
		line_indices[ii+5] = 	u16(ii/3)
		i += 1	
	}
	
	return line_vertices, line_indices
}

update_course_model :: proc (c : ^Course) {
	if c.point_count > 2 {
		vertices, indices := _create_model_data(c)		
		lps := course.lines_per_section 		
		vertex_count := int(c.point_count) * int(lps) * 2
		c.index_count = u16(c.point_count) * u16(lps) * 6

		sg.update_buffer(c.bind.vertex_buffers[0], {
			ptr = &vertices,
			size = uint(vertex_count) * size_of(vertex)
		})

		sg.update_buffer(c.bind.index_buffer, {
			ptr = &indices,
			size = uint(c.index_count) * size_of(u16)
		})
	}
}

course_append_point :: proc (c : ^Course, pos : m.Vec3) {	
	log.debug("hello!")
	if(c.point_count < MAX_POINTS){
		c.point_positions[c.point_count] = pos
		c.point_widths[c.point_count] = 1.0
		c.point_count += 1
	}
}

course_inject_point :: proc (c : ^Course, pos : m.Vec3, index : u16) {
	if (c.point_count >= MAX_POINTS){
		return
	}
	for i := c.point_count; i > index; i -= 1 {
		c.point_positions[i] = c.point_positions[i-1]
		c.point_widths[i] = c.point_widths[i-1]
	}
	c.point_positions[index] = pos 
	c.point_widths[index] = 1.0

	c.point_count += 1
}
