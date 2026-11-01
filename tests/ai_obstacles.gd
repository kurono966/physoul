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
	arena.camera.set_physics_process(false)
	for child in arena.get_children():
		if child is StaticBody2D or child is RigidBody2D: child.queue_free()
	var foe = arena.opponent
	for actor in [arena.player,foe]:
		actor.set_physics_process(false)
		actor.weapon.set_physics_process(false)
		actor.shield.collision_layer = 0
	foe.position = Vector2.ZERO
	foe.facing = 0
	arena.player.position = Vector2(80,0)
	await physics_frame
	for sequence in 4:
		foe.stamina = 100
		foe.weapon.cooldown = 0
		foe.weapon.enemy_attack_sequence = sequence
		arena.player.hp = 100
		arena.player.posture = 0
		arena.player.stun = 0
		foe.weapon.begin_combo()
		foe.weapon.combo_remaining = 0
		var expected: String = ["slash","backhand","thrust","overhead"][sequence]
		check(foe.weapon.active and foe.weapon.enemy_motion == expected,"open space selects distinct motion: "+expected)
		for i in 10: foe.weapon._physics_process(1.0/120)
		check(arena.player.hp == 100 and foe.weapon.attack_phase() == "WINDUP","motion has non-damaging preparation: "+expected)
		for i in 240: foe.weapon._physics_process(1.0/120)
		check(arena.player.hp < 100 and not foe.weapon.active,"motion hits target and recovers: "+expected)
	arena.wall(Rect2(-60,30,180,18))
	await physics_frame
	foe.weapon.cooldown = 0
	foe.stamina = 100
	foe.weapon.enemy_attack_sequence = 0
	check(not foe.weapon.motion_clear("slash") and not foe.weapon.motion_clear("backhand"),"nearby side wall obstructs both broad swings")
	foe.weapon.begin_combo()
	check(foe.weapon.active and foe.weapon.enemy_motion in ["thrust","overhead"],"enemy chooses narrow attack when wall blocks broad swings")
	foe.weapon.cancel()
	arena.wall(Rect2(40,-20,18,40))
	await physics_frame
	foe.weapon.begin(false)
	foe.weapon.combo_remaining = 2
	foe.weapon.elapsed = foe.weapon.windup_duration()-0.001
	foe.weapon._physics_process(1.0/120)
	check(not foe.weapon.active and foe.weapon.combo_remaining == 0 and foe.obstacle_reposition > 0,"obstruction detected at end of windup cancels attack before striking wall")
	foe.weapon.begin(false)
	foe.weapon.combo_remaining = 2
	foe.weapon.omega = 10
	check(foe.weapon.sweep(0,0),"unexpected wall contact physically blocks weapon")
	check(not foe.weapon.active and foe.weapon.combo_remaining == 0 and foe.obstacle_reposition > 0,"wall bounce cancels combo and requests reposition")
	foe.weapon.cooldown = 0
	foe.awareness_enabled = true
	foe.alerted = true
	var escape: Vector2 = foe.think(1.0/120)
	check(escape.length() > 0 and escape.x < 0 and not foe.weapon.active,"enemy moves away from obstruction instead of attacking again")
	var start: Vector2 = foe.position
	foe.set_physics_process(true)
	foe.weapon.set_physics_process(true)
	for i in 70: await physics_frame
	check(foe.position.distance_to(start) > 25 and not foe.weapon.active,"reposition produces real movement without repeating blocked attack")
	print("AI OBSTACLES COMPLETE: %d failures" % failures)
	quit(failures)
