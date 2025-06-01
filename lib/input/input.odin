// Handle input through sokol events
package input

import "base:runtime"
import sapp "shared:sokol/app"

key_states: #sparse[sapp.Keycode][2]bool
mouse_button_states: #sparse[sapp.Mousebutton][2]bool
mouse_pos: [2]f32

key_down :: proc (k : sapp.Keycode) -> bool {
	return key_states[k][0]
}
key_pressed :: proc (k : sapp.Keycode) -> bool {
	just_pressed := key_states[k][0] && !key_states[k][1]	
	key_states[k][1] = key_states[k][0]
	return just_pressed
}
mouse_down :: proc (mb : sapp.Mousebutton) -> bool{
	return mouse_button_states[mb][0]
}

mouse_pressed :: proc (mb : sapp.Mousebutton) -> bool{
	just_pressed := mouse_button_states[mb][0] && !mouse_button_states[mb][1]	
	mouse_button_states[mb][1] = mouse_button_states[mb][0]
	return just_pressed
}
get_mouse_pos :: proc () -> [2]f32 {
	return mouse_pos
}
// Put in sokol event callback and pass the event
handle_input_event :: proc (e : ^sapp.Event) {
	key_state := &key_states[e.key_code]
	mouse_button_state := &mouse_button_states[e.mouse_button]
	#partial switch e.type {
		case .KEY_DOWN:	
			key_state[0] = true
		case .KEY_UP:
			key_state[0] = false
		case .MOUSE_DOWN:
			mouse_button_state[0] = true
		case .MOUSE_UP:
			mouse_button_state[0] = false
		case .MOUSE_MOVE:
			mouse_pos = {e.mouse_x, e.mouse_y} / sapp.dpi_scale()
	}
}

