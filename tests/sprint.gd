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
func lb(down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_LEFT_SHOULDER
	event.pressed = down
	Input.parse_input_event(event)
func rb(down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_RIGHT_SHOULDER
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
	await frames(240)
	arena.player.position = Vector2(-200,200)
	arena.player.facing = 0
	arena.player.stamina = 100
	stick(1)
	l3(true)
	await frames(2)
	l3(false)
	var stamina_before: float = arena.player.stamina
	rb(true)
	await frames(2)
	check(arena.player.weapon.active and arena.player.weapon.dash_mode and not arena.player.guard,"RB during sprint starts running slash immediately")
	check(not arena.player.sprinting and stamina_before-arena.player.stamina >= 28,"dash attack spends stamina and ends sprint")
	stick(0)
	var start: Vector2 = arena.player.position
	await frames(3)
	check(arena.player.position.x > start.x and arena.player.drive_velocity == Vector2.ZERO,"dash attack begins forward motion during windup without ordinary input drive")
	await frames(50)
	check(arena.player.position.x-start.x > 100 and arena.player.position.x-start.x < 114,"running slash advances about 110px across preparation and strike")
	await frames(70)
	check(not arena.player.weapon.active and arena.player.charge == 0,"held RB does not add a thrust or repeat dash attack")
	rb(false)
	await frames(4)
	check(not arena.player.weapon.active and arena.player.charge == 0,"releasing RB does not add a normal slash")
	lb(true)
	await frames(4)
	check(arena.player.guard and not arena.player.weapon.active,"LB after release guards when not sprinting")
	lb(false)
	await frames(100)
	stick(1)
	l3(true)
	await frames(4)
	l3(false)
	check(arena.player.sprinting,"sprint can restart for guard check")
	lb(true)
	await frames(4)
	check(arena.player.guard and not arena.player.weapon.active and not arena.player.sprinting,"LB during sprint guards instead of attacking")
	lb(false)
	stick(0)
	print("SPRINT COMPLETE: %d failures" % failures)
	quit(failures)
