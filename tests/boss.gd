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
	root.add_child(arena)
	await frames(3)
	arena.select_enemy(3)
	var boss = arena.opponent
	boss.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.camera.set_physics_process(false)
	boss.position = Vector2(0,200)
	boss.facing = 0
	arena.player.position = Vector2(130,200)
	arena.player.shield.collision_layer = 0
	check(boss.hp == 650 and boss.weapon.length == 150,"boss has unique health and reach")
	check(boss.get_child(0).shape.radius == 36,"large body has matching physical collider")
	boss.weapon.begin_combo()
	check(boss.weapon.combo_remaining == 1 and boss.weapon.windup_duration() == 1.15,"phase one has telegraphed two-hit combo")
	await frames(240)
	check(arena.player.hp < 100,"boss weapon actually hits player")
	boss.weapon.cancel()
	boss.receive(0,330,Vector2.ZERO)
	check(boss.boss_enraged and boss.move_speed == 145,"half health triggers second phase")
	boss.stun = 0
	boss.weapon.cooldown = 0
	boss.stamina = 100
	arena.player.hp = 100
	boss.weapon.begin_combo()
	check(boss.weapon.combo_remaining == 2 and boss.weapon.windup_duration() == 0.95,"phase two has faster three-hit combo")
	boss.weapon.cancel()
	boss.weapon.cooldown = 0
	arena.player.position = Vector2(320,200)
	boss.boss_attack_count = 0
	boss.stamina = 100
	boss.think(0.01)
	check(boss.weapon.wave_mode and boss.weapon.active,"boss selects ranged wave at distance")
	var fan := false
	for i in 200:
		await frames(1)
		var count := 0
		for child in arena.get_children():
			if child.get_script() == load("res://scripts/shockwave.gd"): count += 1
		if count == 3: fan = true
	check(fan,"second phase launches three-wave fan")
	boss.receive(110,0,Vector2.ZERO)
	check(boss.riposte_available and boss.stun > 0,"boss posture break offers critical opening")
	boss.receive(0,1000,Vector2.ZERO)
	check(boss.hp == 0 and not boss.weapon.active,"boss death cancels attack")
	print("BOSS COMPLETE: %d failures" % failures)
	quit(failures)
