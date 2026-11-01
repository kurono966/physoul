extends SceneTree
var arena: Node2D
var failures := 0
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)
func button(index: int, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)
func axis(index: int,value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	arena.random_map = false
	root.add_child(arena)
	await frames(2)
	arena.opponent.set_physics_process(false)
	axis(JOY_AXIS_LEFT_X,0.1)
	await frames(2)
	check(arena.controls.movement() == Vector2.ZERO,"stick deadzone prevents drift")
	axis(JOY_AXIS_LEFT_X,0.6)
	await frames(8)
	check(arena.player.drive_velocity.length() > 10 and arena.controls.movement().length() < 1,"analog stick moves at partial speed")
	axis(JOY_AXIS_LEFT_X,0)
	var heading: float = arena.camera.heading
	axis(JOY_AXIS_RIGHT_X,0.8)
	await frames(8)
	check(arena.camera.heading > heading,"right stick turns view")
	axis(JOY_AXIS_RIGHT_X,0)
	button(JOY_BUTTON_RIGHT_STICK,true)
	await frames(2)
	check(arena.camera.locked,"R3 locks target")
	button(JOY_BUTTON_RIGHT_STICK,false)
	button(JOY_BUTTON_RIGHT_SHOULDER,true)
	await frames(3)
	button(JOY_BUTTON_RIGHT_SHOULDER,false)
	await frames(2)
	check(arena.player.weapon.active and not arena.player.weapon.thrust_attack,"RB tap slashes")
	arena.player.weapon.cancel()
	arena.player.weapon.cooldown = 0
	button(JOY_BUTTON_RIGHT_SHOULDER,true)
	await frames(45)
	check(arena.player.weapon.active and arena.player.weapon.thrust_attack,"RB hold automatically thrusts")
	button(JOY_BUTTON_RIGHT_SHOULDER,false)
	arena.player.weapon.cancel()
	arena.player.weapon.cooldown = 0
	button(JOY_BUTTON_LEFT_SHOULDER,true)
	await frames(2)
	check(arena.player.guard and arena.player.just_guard_window > 0,"LB opens guard and just guard window")
	await frames(30)
	check(arena.player.guard and arena.player.just_guard_window == 0,"holding LB does not repeat just guard")
	button(JOY_BUTTON_LEFT_SHOULDER,false)
	await frames(2)
	check(not arena.player.guard,"releasing LB drops guard")
	arena.player.recovery = 0
	arena.player.stamina = 100
	button(JOY_BUTTON_A,true)
	await frames(2)
	check(arena.player.roll > 0,"A triggers roll")
	button(JOY_BUTTON_A,false)
	arena.player.roll = 0
	button(JOY_BUTTON_X,true)
	await frames(2)
	check(arena.player.kick_time > 0,"X triggers kick")
	button(JOY_BUTTON_X,false)
	arena.player.kick_time = 0
	arena.player.kick_pending = false
	button(JOY_BUTTON_RIGHT_SHOULDER,true)
	await frames(2)
	arena.controls.connection_changed(0,false)
	check(arena.player.charge == 0,"disconnect cancels pending charge")
	button(JOY_BUTTON_RIGHT_SHOULDER,false)
	arena.opponent.position = arena.player.position+Vector2(55,0)
	arena.opponent.break_guard()
	arena.player.weapon.cooldown = 0
	button(JOY_BUTTON_RIGHT_SHOULDER,true)
	await frames(2)
	check(arena.player.critical_time > 0,"RB triggers adjacent critical")
	button(JOY_BUTTON_RIGHT_SHOULDER,false)
	print("CONTROLLER COMPLETE: %d failures" % failures)
	quit(failures)
