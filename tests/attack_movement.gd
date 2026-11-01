extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	arena.random_map = false
	root.add_child(arena)
	await physics_frame
	arena.opponent.set_physics_process(false)
	arena.camera.set_physics_process(false)
	var player = arena.player
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	player.charge = 0.15
	player.drive_velocity = Vector2(100,0)
	var origin: Vector2 = player.position
	for i in 8: await physics_frame
	check(player.position.distance_to(origin) < 0.01 and player.drive_velocity == Vector2.ZERO,"charge stops input and existing movement immediately")
	check(player.weapon.extension < 0,"weapon preparation still moves sword")
	player.charge = 0
	player.attack(true)
	player.weapon.elapsed = player.weapon.windup_duration()
	var extended := false
	for i in 100:
		await physics_frame
		if player.weapon.extension > 10: extended = true
	check(player.position.distance_to(origin) < 0.01,"attack and recovery stop WASD movement")
	check(extended,"attack-authored thrust motion still plays")
	player.weapon.cooldown = 0.4
	player.push_impulse(Vector2.RIGHT,100)
	for i in 8: await physics_frame
	check(player.position.x > origin.x+2,"external impact still pushes during attack lock")
	player.impulse_velocity = Vector2.ZERO
	player.weapon.cooldown = 0
	for i in 8: await physics_frame
	check(player.drive_velocity.length() > 0,"input movement resumes after recovery")
	key.pressed = false
	Input.parse_input_event(key)
	print("MOVEMENT COMPLETE: %d failures" % failures)
	quit(failures)
