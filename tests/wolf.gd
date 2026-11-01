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
	arena.select_enemy(4)
	var wolf = arena.opponent
	wolf.position = Vector2.ZERO
	wolf.facing = 0
	arena.player.position = Vector2(160,0)
	arena.player.shield.collision_layer = 0
	await frames(1)
	check(wolf.enemy_kind == "wolf" and wolf.hp == 65 and wolf.move_speed > 220 and not wolf.has_shield,"wolf has fast, fragile, unshielded equipment profile")
	wolf.weapon.begin_combo()
	check(wolf.weapon.active and wolf.weapon.combo_remaining == 0,"wolf begins one committed pounce")
	await frames(48)
	check(wolf.position.length() < 1 and arena.player.hp == 100 and wolf.weapon.attack_phase() == "WINDUP","crouch telegraph stops movement and does not damage")
	await frames(50)
	check(wolf.position.x > 70 and arena.player.hp < 100,"pounce advances physically and bite hits player")
	wolf.set_physics_process(false)
	var hp_after: float = arena.player.hp
	await frames(100)
	check(arena.player.hp == hp_after and not wolf.weapon.active,"one pounce hits only once and recovers")
	wolf.position = Vector2.ZERO
	wolf.facing = 0
	wolf.stamina = 100
	wolf.weapon.cooldown = 0
	wolf.impulse_velocity = Vector2.ZERO
	arena.player.hp = 100
	arena.player.position = Vector2(160,0)
	await frames(1)
	wolf.weapon.begin_combo()
	wolf.set_physics_process(true)
	await frames(50)
	arena.player.position = Vector2(160,140)
	await frames(70)
	check(arena.player.hp == 100,"late sidestep evades committed pounce")
	wolf.set_physics_process(false)
	wolf.weapon.cancel()
	wolf.weapon.cooldown = 0
	wolf.position = Vector2.ZERO
	wolf.facing = 0
	wolf.stamina = 100
	wolf.posture = 0
	wolf.impulse_velocity = Vector2.ZERO
	wolf.drive_velocity = Vector2.ZERO
	arena.player.position = Vector2(100,0)
	arena.player.facing = PI
	arena.player.guard = true
	arena.player.just_guard_window = 1
	arena.player.shield.position = Vector2(-30,0)
	arena.player.shield.rotation = PI
	arena.player.shield.collision_layer = 8
	await frames(1)
	wolf.weapon.begin_combo()
	wolf.set_physics_process(true)
	await frames(95)
	check(arena.player.hp == 100 and arena.player.just_guard_window == 0 and not wolf.weapon.active,"just guard blocks bite and interrupts pounce")
	wolf.set_physics_process(false)
	wolf.weapon.cancel()
	wolf.position = Vector2.ZERO
	wolf.facing = 0
	arena.wall(Rect2(70,-40,20,80))
	await frames(1)
	check(not wolf.weapon.motion_clear("bite"),"wall in pounce path prevents committed bite")
	wolf.make_corpse()
	check(wolf.collision_layer == 0 and wolf.collision_mask == 0,"wolf corpse does not block movement")
	arena.queue_free()
	await frames(2)
	var expedition = load("res://arena.tscn").instantiate()
	expedition.map_seed = 12345
	root.add_child(expedition)
	await frames(2)
	var count := 0
	for guardian in expedition.guardians.values():
		if guardian.enemy_kind == "wolf": count += 1
	check(count > 0,"wolf is preplaced in exploration map before room entry")
	print("WOLF COMPLETE: %d failures" % failures)
	quit(failures)
