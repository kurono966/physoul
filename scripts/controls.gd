extends Node
## Standard Godot gamepad layout (Xbox / PlayStation equivalent positions).
var using_pad := false
var help_visible := true
const BUTTONS := {"pad_attack": JOY_BUTTON_RIGHT_SHOULDER, "pad_guard": JOY_BUTTON_LEFT_SHOULDER, "pad_roll": JOY_BUTTON_A, "pad_kick": JOY_BUTTON_X, "pad_lock": JOY_BUTTON_RIGHT_STICK, "pad_restart": JOY_BUTTON_START, "pad_next": JOY_BUTTON_DPAD_RIGHT}
const AXES := {"pad_left": [JOY_AXIS_LEFT_X,-1.0],"pad_right": [JOY_AXIS_LEFT_X,1.0],"pad_up": [JOY_AXIS_LEFT_Y,-1.0],"pad_down": [JOY_AXIS_LEFT_Y,1.0],"pad_look_left": [JOY_AXIS_RIGHT_X,-1.0],"pad_look_right": [JOY_AXIS_RIGHT_X,1.0]}

func _ready() -> void:
	if not InputMap.has_action("pad_wave"):
		InputMap.add_action("pad_wave",0.15)
		var trigger := InputEventJoypadMotion.new()
		trigger.device = -1
		trigger.axis = JOY_AXIS_TRIGGER_LEFT
		trigger.axis_value = 1
		InputMap.action_add_event("pad_wave",trigger)
	if not InputMap.has_action("pad_heavy"):
		InputMap.add_action("pad_heavy",0.15)
		var trigger := InputEventJoypadMotion.new()
		trigger.device = -1
		trigger.axis = JOY_AXIS_TRIGGER_RIGHT
		trigger.axis_value = 1
		InputMap.action_add_event("pad_heavy",trigger)
	for action in BUTTONS:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = BUTTONS[action]
		InputMap.action_add_event(action,event)
	for action in AXES:
		if InputMap.has_action(action): continue
		InputMap.add_action(action,0.22)
		var mapping: Array = AXES[action]
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = mapping[0]
		event.axis_value = mapping[1]
		InputMap.action_add_event(action,event)
	Input.joy_connection_changed.connect(connection_changed)

func connection_changed(_device: int, connected: bool) -> void:
	if not connected:
		get_parent().player.charge = 0
		get_parent().player.heavy_charge = 0
		using_pad = false

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.25):
		using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 2):
		using_pad = false

func movement() -> Vector2:
	return Input.get_vector("pad_left","pad_right","pad_up","pad_down",0.22)

func look() -> float:
	return Input.get_axis("pad_look_left","pad_look_right")
