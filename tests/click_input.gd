extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	arena.player.set_physics_process(false)
	arena.opponent.set_physics_process(false)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	arena.camera._unhandled_input(click)
	assert(arena.player.charge > 0 and not arena.player.weapon.active)
	click.pressed = false
	arena.camera._unhandled_input(click)
	assert(arena.player.weapon.active and not arena.player.weapon.thrust_attack)
	print("PASS: short click releases slash")
	arena.player.weapon.cancel()
	arena.player.weapon.cooldown = 0
	click.pressed = true
	arena.camera._unhandled_input(click)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100,0)
	var heading: float = arena.camera.heading
	arena.camera._unhandled_input(motion)
	assert(arena.camera.heading > heading and not arena.player.weapon.active)
	print("PASS: mouse turns camera during hold without swinging sword")
	for i in 20: await physics_frame
	assert(not arena.player.weapon.active and arena.player.weapon.extension < 0)
	assert(arena.player.weapon.blade.collision_layer == 0)
	print("PASS: holding visibly draws sword back without hitbox")
	for i in 22: await physics_frame
	assert(arena.player.weapon.active and arena.player.weapon.thrust_attack and arena.player.charge == 0)
	assert(arena.player.weapon.elapsed >= arena.player.weapon.windup_duration())
	print("PASS: thrust starts automatically before release without second windup")
	for i in 180: await physics_frame
	assert(not arena.player.weapon.active)
	print("PASS: continuing to hold does not repeat thrust")
	click.pressed = false
	arena.camera._unhandled_input(click)
	assert(not arena.player.weapon.active and arena.player.charge == 0)
	print("PASS: release after automatic thrust does not start another attack")
	quit()
