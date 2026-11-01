extends SceneTree
var failures := 0
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)
func frames(n: int) -> void:
	for i in n: await physics_frame
func stick(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	Input.parse_input_event(event)
func l3(down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_LEFT_STICK
	event.pressed = down
	Input.parse_input_event(event)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	arena.random_map = false
	root.add_child(arena)
	await frames(20)
	arena.opponent.set_physics_process(false)
	arena.camera.set_physics_process(false)
	arena.player.position = Vector2(0,200)
	stick(1)
	await frames(24)
	var walk_speed: float = arena.player.drive_velocity.length()
	l3(true)
	await frames(2)
	l3(false)
	await frames(24)
	check(arena.player.sprinting and arena.player.drive_velocity.length() > walk_speed*1.6,"L3 enables faster camera-relative movement")
	check(arena.player.stamina < 98,"sprinting consumes stamina")
	stick(0)
	await frames(2)
	check(not arena.player.sprinting and not arena.player.sprint_requested,"releasing movement stops sprint")
	stick(1)
	await frames(2)
	l3(true)
	await frames(2)
	l3(false)
	arena.player.stamina = 0.01
	await frames(3)
	check(not arena.player.sprinting and not arena.player.sprint_requested,"exhaustion stops sprint without repeated restarting")
	arena.player.stamina = 100
	l3(true)
	await frames(2)
	l3(false)
	arena.player.attack(false)
	await frames(2)
	check(not arena.player.sprinting and arena.player.drive_velocity == Vector2.ZERO,"attack preparation cancels sprint and input movement")
	stick(0)
	print("SPRINT COMPLETE: %d failures" % failures)
	quit(failures)
