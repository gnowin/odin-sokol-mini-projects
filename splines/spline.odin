package main

import math "core:math"
import log "core:log"
import lin "core:math/linalg"

import m "../lib/math"

get_spline_point :: proc (t : f32, points : []m.Vec3, looped : bool = true) -> m.Vec3 {
	p0, p1, p2, p3 : i16
	if !looped {
		p1 = i16(t) + 1
		p2 = p1 + 1
		p3 = p2 + 1
		p0 = p1 - 1
		}
	else {
		length := i16(len(points))
		p1 = i16(t)
		p2 = (p1 + 1) % length
		p3 = (p2 + 1) % length
		p0 = p1 >= 1 ? p1 - 1 : i16(length) - 1
	}
	t := t - f32(i16(t))
	tt := t * t
	ttt := tt * t

	q0, q1, q2, q3, tx, ty, tz : f32
	q0 = -ttt + 2.0*tt - t
	q1 = 3.0*ttt - 5.0*tt + 2.0
	q2 = -3.0*ttt + 4.0*tt + t
	q3 = ttt - tt

	pos : m.Vec3
	
	for i in 0..<3 {
		// i = 0, 1, 2 which corresponds to x, y, z
		// maybe  change to some kind of Vector matrix multiplication later
		pos[i] = 0.5 * (points[p0][i] * q0 + points[p1][i] * q1 + points[p2][i] * q2 + points[p3][i] * q3) 
	}
	return pos
}

get_spline_gradient :: proc (t : f32, points : []m.Vec3, looped : bool = true) -> m.Vec3 {
	p0, p1, p2, p3 : i16
	if !looped {
		p1 = i16(t) + 1
		p2 = p1 + 1
		p3 = p2 + 1
		p0 = p1 - 1
		}
	else {
		length := i16(len(points))
		p1 = i16(t)
		p2 = (p1 + 1) % length
		p3 = (p2 + 1) % length
		p0 = p1 >= 1 ? p1 - 1 : i16(length) - 1
	}
	t := t - f32(i16(t))
	tt := t * t
	ttt := tt * t

	q0, q1, q2, q3, tx, ty : f32
	q0 = -3.0*tt + 4.0*t - 1.0
	q1 = 9.0*tt-10.0*t 
	q2 = -9.0*tt + 8.0*t + 1.0
	q3 = 3.0*tt - 2.0*t 

	pos : m.Vec3
	
	for i in 0..<3 {
		// i = 0, 1, 2 which corresponds to x, y, z
		// maybe  change to some kind of Vector matrix multiplication later
		pos[i] = 0.5 * (points[p0][i] * q0 + points[p1][i] * q1 + points[p2][i] * q2 + points[p3][i] * q3) 
	}
	
	return pos
}

// Calculate a Vector that is +90 degrees of input Vector 
right_angle_vector :: proc (v : m.Vec3) -> m.Vec3  {
	a  := math.atan2(-v.y, v.x)
//	g := gradient
//	w1 := point + spread * lin.normalize(m.Vec3{-g.y, g.x, g.z})
//	w2 := point + spread * lin.normalize(m.Vec3{g.y, -g.x, g.z})
	
	return m.Vec3{math.sin(a), math.cos(a), 0.0}
}

get_spline_wings :: proc (point, gradient : m.Vec3, spread : f32) -> (m.Vec3, m.Vec3){
	right_vector := right_angle_vector(gradient)
	w1 := point + -(right_vector * spread)
	w2 := point +  (right_vector * spread)

	return w1, w2
}

create_spline_quad_data :: proc (points : []m.Vec3, lines_per_section : u8, line_width : f32) -> ([MAX_VERTICES]vertex, [MAX_INDICES]u16) {
	context = default_context
	lps := lines_per_section
	point_count := u16(len(points))
	line_count := point_count * u16(lps)
	vertex_count := line_count * 2
	line_vertices : [MAX_VERTICES]vertex
	line_indices : [MAX_INDICES]u16
	
	i := 0
	for t : f32 = 0.0 ; t < f32(point_count) ; t+= 1.0/f32(lps) {
		p := get_spline_point(t, points[:], true)
		g := lin.normalize(get_spline_gradient(t, points[:], true))	
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
