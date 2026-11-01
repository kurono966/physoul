extends SceneTree
var failures := 0
func check(ok: bool,label: String) -> void:
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
	arena.player.set_physics_process(false)
	arena.camera.set_physics_process(false)
	for index in 4:
		arena.select_enemy(index)
		var enemy = arena.opponent
		enemy.set_physics_process(false)
		enemy.position = Vector2(75,200)
		arena.player.position = Vector2(0,200)
		await physics_frame
		var live_contact = arena.player.move_and_collide(Vector2(140,0))
		check(live_contact != null,"living enemy %d still blocks movement" % index)
		arena.player.position = Vector2(0,200)
		enemy.receive(0,1000,Vector2.RIGHT)
		await physics_frame
		var dead_contact = arena.player.move_and_collide(Vector2(140,0))
		check(dead_contact == null and arena.player.position.x > 139,"corpse %d cannot block movement" % index)
		check(enemy.collision_layer == 0 and enemy.collision_mask == 0 and enemy.shield.collision_layer == 0 and enemy.weapon.blade.collision_layer == 0,"corpse %d body shield and weapon all disabled" % index)
		enemy.set_physics_process(true)
		var resting: Vector2 = enemy.position
		for i in 10: await physics_frame
		check(enemy.position == resting,"corpse %d remains at rest" % index)
	print("CORPSES COMPLETE: %d failures" % failures)
	quit(failures)
