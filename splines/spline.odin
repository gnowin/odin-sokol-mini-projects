package main

import math "core:math"
import log "core:log"
import lin "core:math/linalg"

import m "../lib/math"

_get_points :: proc (t : f32, point_count : u16, looped : bool) -> (p0 : i16, p1 : i16, p2 : i16, p3 : i16) {
	if !looped {
		p1 = i16(t) + 1
		p2 = p1 + 1
		p3 = p2 + 1
		p0 = p1 - 1
		}
	else {
		length := point_count
		p1 = i16(t)
		p2 = (p1 + 1) % i16(point_count)
		p3 = (p2 + 1) % i16(point_count)
		p0 = p1 >= 1 ? p1 - 1 : i16(length) - 1
	}
	return
}

get_spline_point :: proc (t : f32, points : []m.Vec3, point_count : u16, looped : bool = true) -> m.Vec3 {
	p0, p1, p2, p3 := _get_points(t, point_count, looped) 
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

get_spline_gradient :: proc (t : f32, points : []m.Vec3, point_count : u16, looped : bool = true) -> m.Vec3 {
	p0, p1, p2, p3 := _get_points(t, point_count, looped)	
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
