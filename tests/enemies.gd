extends SceneTree

var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	else: print("PASS: ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_MIDDLE
	click.pressed = true
	arena.camera._unhandled_input(click)
	check(arena.camera.locked,"middle click locks")
	click.pressed = false
	arena.camera._unhandled_input(click)
	check(arena.camera.locked,"middle release does not toggle")
	click.pressed = true
	arena.camera._unhandled_input(click)
	check(not arena.camera.locked,"middle click unlocks")
	for index in 3:
		arena.select_enemy(index)
		check(arena.opponent.hp == arena.opponent.max_hp,"enemy %d starts at full HP" % index)
		check(arena.opponent.has_shield == (index == 0),"enemy %d equipment differs" % index)
		arena.player.set_physics_process(false)
		arena.opponent.set_physics_process(false)
		arena.camera.set_physics_process(false)
		arena.opponent.position = Vector2(0,200)
		arena.opponent.facing = 0
		arena.player.position = Vector2(125 if index == 2 else 80,200)
		arena.player.hp = 100
		arena.player.shield.collision_layer = 0
		arena.player.roll = 0
		await physics_frame
		arena.opponent.attack(index == 1)
		for frame in 30: await physics_frame
		check(arena.player.hp == 100,"enemy %d windup cannot damage" % index)
		check(arena.opponent.weapon.attack_phase() == "WINDUP" and arena.opponent.weapon.blade.collision_layer == 0,"enemy %d telegraphs before activating blade" % index)
		var saved_elapsed: float = arena.opponent.weapon.elapsed
		arena.opponent.weapon.elapsed = arena.opponent.weapon.windup_duration()-0.1
		var saved_facing: float = arena.opponent.facing
		var saved_position: Vector2 = arena.player.position
		arena.player.position += Vector2(0,100)
		var movement: Vector2 = arena.opponent.think(0.1)
		check(arena.opponent.facing == saved_facing and movement == Vector2.ZERO,"enemy %d commits aim before strike" % index)
		arena.player.position = saved_position
		arena.opponent.weapon.elapsed = saved_elapsed
		for frame in 260: await physics_frame
		check(arena.player.hp < 100,"enemy %d weapon connects" % index)
		check(not arena.opponent.weapon.active,"enemy %d attack recovers" % index)
		arena.player.hp = 100
		arena.opponent.hp = 0
		arena.wave_delay = 2.6
		arena._process(0.01)
		check(arena.enemy_index == (index+1)%4,"defeat advances to next enemy")
	print("ENEMIES COMPLETE: %d failures" % failures)
	quit(failures)
