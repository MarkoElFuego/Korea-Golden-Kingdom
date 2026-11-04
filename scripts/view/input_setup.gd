extends RefCounted
## Keyboard shortcuts, registered in code so they live in one readable place.

const ACTIONS := {
	"camera_left": [KEY_A, KEY_LEFT],
	"camera_right": [KEY_D, KEY_RIGHT],
	"camera_forward": [KEY_W, KEY_UP],
	"camera_back": [KEY_S, KEY_DOWN],
	"camera_rotate_left": [KEY_Q],
	"camera_rotate_right": [KEY_E],
	"game_pause": [KEY_SPACE],
	"game_speed_1": [KEY_1, KEY_KP_1],
	"game_speed_2": [KEY_2, KEY_KP_2],
	"game_speed_3": [KEY_3, KEY_KP_3],
	"tool_road": [KEY_G], # gil
	"tool_demolish": [KEY_X, KEY_DELETE],
	"tool_rotate": [KEY_R],
	"tool_cancel": [KEY_ESCAPE],
	"overlay_water": [KEY_F1],
	"overlay_food": [KEY_F2],
	"overlay_seonangdang": [KEY_F3],
	"overlay_jang": [KEY_F5],
	"overlay_jars": [KEY_F6],
	"goods_window": [KEY_F4],
}

## Shortcuts pressed together with Ctrl.
const CTRL_ACTIONS := {
	"game_save": [KEY_S],
	"game_load": [KEY_L],
}


static func ensure_actions() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action: String in CTRL_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in CTRL_ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			event.ctrl_pressed = true
			InputMap.action_add_event(action, event)
