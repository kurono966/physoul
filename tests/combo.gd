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
	root.add_child(arena)
	arena.player.set_physics_process(false)
	arena.camera.set_physics_process(false)
	for index in 3:
		arena.select_enemy(index)
		var foe = arena.opponent
		foe.set_physics_process(false)
		foe.position = Vector2(0,200)
		foe.facing = 0
		arena.player.position = Vector2(foe.weapon.engagement_distance()-1,200)
		arena.player.roll = 0.25
		arena.player.shield.collision_layer = 0
		arena.player.hp = 100
		await physics_frame
		foe.weapon.begin_combo()
		check(foe.weapon.windup_duration() >= 0.55,"initial windup preserved %d" % index)
		var seen: Dictionary = {}
		var reverse := false
		var final_cooldown := 0.0
		var fast_strike := false
		if index == 1:
			check(foe.weapon.windup_duration() == 1.0,"hammer initial windup remains 1 second")
		for frame in 600:
			await physics_frame
			if foe.weapon.active:
				if index == 1 and foe.weapon.elapsed > foe.weapon.windup_duration() and foe.weapon.elapsed <= foe.weapon.windup_duration()+0.22 and absf(foe.weapon.omega) >= 8:
					fast_strike = true
				if index == 1 and foe.weapon.combo_index == 1 and not seen.has(1):
					check(foe.weapon.windup_duration() == 0.48,"hammer followup windup preserved")
				seen[foe.weapon.combo_index] = true
				if foe.weapon.combo_index == 1 and foe.weapon.omega < 0: reverse = true
			elif seen.size() > 0:
				final_cooldown = foe.weapon.cooldown
				break
		check(seen.size() == (2 if index == 1 else 3),"expected combo length %d" % index)
		if index == 1: check(fast_strike,"hammer accelerates past 8 rad/s within 0.22 seconds")
		check(final_cooldown >= 0.65,"punishable recovery after combo %d" % index)
		check(foe.stamina < 70,"each followup spends stamina %d" % index)
		if index != 2: check(reverse,"second swing reverses direction %d" % index)
		foe.stamina = 100
		foe.weapon.cooldown = 0
		foe.weapon.begin_combo()
		foe.weapon.bounce(30)
		check(foe.weapon.combo_remaining == 0 and not foe.weapon.active,"rebound interrupts combo %d" % index)
	print("COMBO COMPLETE: %d failures" % failures)
	quit(failures)
