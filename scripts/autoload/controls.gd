extends Node
## Registers every gameplay input action for keyboard AND controller at startup,
## so the game works without touching Project Settings > Input Map.
## Actions added in the editor's Input Map are kept; we only add missing ones.
## Also tracks whether the player last used a gamepad so prompts can show the right button.

signal device_changed(using_gamepad: bool)

const DEADZONE := 0.3

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE, KEY_Z],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E],
	"attack": [KEY_J, KEY_X],
	"heavy": [KEY_K],
	"special": [KEY_L],
	"dodge": [KEY_C],
	"inventory": [KEY_TAB, KEY_I],
	"pause": [KEY_ESCAPE, KEY_P],
}

const PAD_BUTTONS := {
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_up": [JOY_BUTTON_DPAD_UP],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"jump": [JOY_BUTTON_A],
	"sprint": [JOY_BUTTON_B],
	"interact": [JOY_BUTTON_Y],
	"attack": [JOY_BUTTON_X],
	"heavy": [JOY_BUTTON_Y],
	"special": [JOY_BUTTON_RIGHT_SHOULDER],
	"dodge": [JOY_BUTTON_LEFT_SHOULDER],
	"inventory": [JOY_BUTTON_BACK],
	"pause": [JOY_BUTTON_START],
}

## action -> [[axis, direction], ...]
const PAD_AXES := {
	"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	"move_up": [[JOY_AXIS_LEFT_Y, -1.0]],
	"move_down": [[JOY_AXIS_LEFT_Y, 1.0]],
	"dodge": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"sprint": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
}

const KEY_LABELS := {
	"move_left": "A/←", "move_right": "D/→", "move_up": "W/↑", "move_down": "S/↓",
	"jump": "Space", "sprint": "Shift", "interact": "E", "attack": "J", "heavy": "K",
	"special": "L", "dodge": "C", "inventory": "Tab", "pause": "Esc",
}
const PAD_LABELS := {
	"move_left": "L-Stick", "move_right": "L-Stick", "move_up": "L-Stick ↑", "move_down": "L-Stick ↓",
	"jump": "A", "sprint": "B / RT", "interact": "Y", "attack": "X", "heavy": "Y",
	"special": "RB", "dodge": "LB / LT", "inventory": "Back", "pause": "Start",
}

var using_gamepad := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for button in PAD_BUTTONS.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = button
			InputMap.action_add_event(action, jb)
		for axis_def in PAD_AXES.get(action, []):
			var jm := InputEventJoypadMotion.new()
			jm.axis = axis_def[0]
			jm.axis_value = axis_def[1]
			InputMap.action_add_event(action, jm)
	# Let E / gamepad A confirm in menus and dialogue too.
	for key in [KEY_E, KEY_SPACE]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event("ui_accept", ev)


func _input(event: InputEvent) -> void:
	var pad := using_gamepad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	if pad != using_gamepad:
		using_gamepad = pad
		device_changed.emit(pad)


## Button label for the device the player is currently using, e.g. "[E]" or "(Y)".
func label(action: String) -> String:
	if using_gamepad:
		return "(" + PAD_LABELS.get(action, action) + ")"
	return "[" + KEY_LABELS.get(action, action) + "]"


## Replaces {action} tokens with the current device's button label, e.g. "Press {jump}".
func format(text: String) -> String:
	for action in KEY_LABELS:
		text = text.replace("{" + action + "}", label(action))
	return text


func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
