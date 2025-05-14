package my_math

import "core:log"
import "core:math"
import lin "core:math/linalg"

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
RGB  :: Vec3
RGBA :: Vec4
Mat4 :: matrix[4,4]f32

quatf32 :: lin.Quaternionf32

// function to "shoot" ray from screen position with view and projection (perspective)
ray_from_mouse_pos :: proc (m_pos, w_dim : Vec2, view, proj : Mat4) -> Vec3 {
	ndc := Vec2{(2.0 * m_pos.x) / w_dim.x - 1.0, 1.0 - (2.0 * m_pos.y) / w_dim.y}

	ray_clip : Vec4 = {ndc.x, ndc.y, -1.0, 1.0}

	ray_eye : Vec4 = lin.inverse(proj) * ray_clip
	ray_eye = Vec4{ray_eye.x, ray_eye.y, -1.0, 0.0}

	ray_world := (lin.inverse(view) * ray_eye).xyz
	log.debug(view)
	log.debug(lin.inverse(view))
	ray_world = lin.normalize(ray_world)
	log.debug("ndc: ", ndc, ", ray_clip: ", ray_clip, ", ray_world: ", ray_world)

	return ray_world
}

line_plane_intersection :: proc (ray_origin, ray_direction, plane_origin, plane_normal : Vec3) -> (bool, Vec3) {
	t := -(lin.dot((ray_origin-plane_origin), plane_normal))/lin.dot(ray_direction, plane_normal)
	if (t <= 0) {
		return false, {}
	}
	intersection := ray_origin + (ray_direction * t)
	log.debug("t: ", t, "\nray_origin: ", ray_origin, "\nplane_origin: ", plane_origin, "\nintersection: ", intersection)

	return true, intersection
}
