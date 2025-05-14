package graphics

import m "../math"
import lin "core:math/linalg"
import "core:log"

Projection_Type :: enum {PERSPECTIVE, ORTHOGRAPHIC}

Perspective_Params :: struct {
	fov	: f32,
	aspect	: f32,
}

Orthographic_Params :: struct {
	left	: f32,
	right	: f32,
	bottom	: f32,
	top	: f32,
}

Camera :: struct {
	position		: m.Vec3,
	forward			: m.Vec3,
	up			: m.Vec3,
	projection_type		: Projection_Type,
	near			: f32,
	far			: f32,
	perspective_params 	: Perspective_Params,
	orthographic_params	: Orthographic_Params,
}

DEFAULT_PERSPECTIVE_PARAMS :: Perspective_Params {
	fov 	= 120.0,
	aspect 	= 4.0/3.0 // because I like 4:3 :)
}

// TODO: not tested, come back to this
DEFAULT_ORTHOGRAPHIC_PARAMS :: Orthographic_Params {
	left 	= -0.5,
	right	=  0.5,
	bottom  =  0.5,
	top 	= -0.5,
}

DEFAULT_CAMERA :: Camera {
	position 		= {0.0, 0.0,  0.0},
	forward 		= {0.0, 0.0, -1.0},
	up			= {0.0, 1.0,  0.0},
	projection_type 	= .PERSPECTIVE,
	perspective_params 	= DEFAULT_PERSPECTIVE_PARAMS,
	orthographic_params 	= DEFAULT_ORTHOGRAPHIC_PARAMS,
	near			= 0.001,
	far			= 1000.0,
}

//DEFAULT_ORTHOGRAPHIC_CAMERA :: Camera {
//	position 	= {0.0, 0.0,  0.0},
//	forward 	= {0.0, 0.0, -1.0},
//	up		= {0.0, 1.0,  0.0},
//	projection_type = .ORTHOGRAPHIC,
//	near		= 0.001,
//	far		= 1000.0,
//}

get_camera_view :: proc (camera : Camera) -> m.Mat4 {
	eye 	:= camera.position
	centre  := camera.position + camera.forward
	up	:= camera.up

	return lin.matrix4_look_at_f32(eye, centre, up)
}

get_camera_projection :: proc (camera : Camera) -> m.Mat4 {
	if camera.projection_type == .PERSPECTIVE {
		params 	:= camera.perspective_params
		fov 	:= params.fov
		aspect 	:= params.aspect
		return lin.matrix4_perspective(fov, aspect, camera.near, camera.far)
	}
	{
		params	:= camera.orthographic_params
		left 	:= params.left
		right	:= params.right
		bottom	:= params.bottom
		top	:= params.top
		return lin.matrix_ortho3d(left, right, bottom, top, camera.near, camera.far)
	}
}

rotate_camera_yaw :: proc (camera : ^Camera, angle : f32, radians : bool = true) {
	yaw_axis := camera.up

	q := lin.quaternion_angle_axis_f32(angle, yaw_axis)
	rotation := lin.to_matrix3(q)

	camera.forward = rotation * camera.forward
}

rotate_camera_pitch :: proc (camera : ^Camera, angle : f32, radians : bool = true) {
	pitch_axis := lin.cross(camera.up, camera.forward)

	q := lin.quaternion_angle_axis_f32(angle, pitch_axis)
	rotation := lin.to_matrix3(q)

	camera.forward = rotation * camera.forward
	camera.up = rotation * camera.up

}
