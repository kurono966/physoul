extends SceneTree
var failures := 0
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	arena.random_map = false
	root.add_child(arena)
	await frames(2)
	arena.camera.set_physics_process(false)
	arena.player.set_physics_process(false)
	for child in arena.get_children():
		if child is StaticBody2D or child is RigidBody2D: child.queue_free()
	arena.select_enemy(5)
	var reptile = arena.opponent
	reptile.position = Vector2.ZERO
	reptile.facing = 0
	arena.player.position = Vector2(120,0)
	arena.player.shield.collision_layer = 0
	reptile.weapon.cooldown = 10
	var left := false
	var right := false
	var paused := false
	var excursion := 0.0
	for i in 160:
		await frames(1)
		if reptile.drive_velocity.y < -50: left = true
		if reptile.drive_velocity.y > 50: right = true
		if reptile.hop_pause > 0: paused = true
		excursion = maxf(excursion,absf(reptile.position.y))
	check(left and right and excursion > 25 and paused,"reptile physically hops both sideways with visible pauses")
	reptile.receive(10,10,Vector2.ZERO)
	check(reptile.hp == 70,"side hopping does not grant invulnerability")
	reptile.set_physics_process(false)
	reptile.position = Vector2.ZERO
	reptile.facing = 0
	reptile.hop_time = 0
	reptile.hop_pause = 0
	reptile.hop_count = 0
	reptile.hop_side = 1
	arena.wall(Rect2(-100,-80,300,20))
	var wall = arena.get_child(arena.get_child_count()-1)
	await frames(2)
	var escape: Vector2 = reptile.think(1.0/120)
	check(escape.y > 0,"blocked sideways hop reverses away from wall")
	wall.queue_free()
	await frames(2)
	reptile.impulse_velocity = Vector2.ZERO
	reptile.drive_velocity = Vector2.ZERO
	reptile.weapon.cooldown = 0
	reptile.hop_time = 0
	reptile.hop_pause = 0
	reptile.hop_count = 2
	arena.player.position = Vector2(100,0)
	await frames(1)
	reptile.think(1.0/120)
	check(reptile.weapon.active and reptile.weapon.windup_duration() >= 0.6,"after two hops reptile settles into telegraphed bite")
	reptile.set_physics_process(true)
	await frames(55)
	check(arena.player.hp == 100 and reptile.position.length() < 1,"bite preparation does not move or damage")
	await frames(60)
	check(arena.player.hp < 100 and reptile.position.x > 25,"bite lunges forward and hits")
	reptile.make_corpse()
	check(reptile.collision_layer == 0 and reptile.collision_mask == 0,"reptile corpse is nonblocking")
	arena.queue_free()
	await frames(2)
	var expedition = load("res://arena.tscn").instantiate()
	expedition.map_seed = 12345
	root.add_child(expedition)
	await frames(2)
	var present := false
	for enemy in expedition.escorts:
		if enemy.enemy_kind == "reptile": present = true
	check(present,"reptile is preplaced in exploration encounter")
	print("REPTILE COMPLETE: %d failures" % failures)
	quit(failures)
