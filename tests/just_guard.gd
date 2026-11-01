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
	await physics_frame
	var player = arena.player
	var foe = arena.opponent
	player.set_physics_process(false)
	foe.set_physics_process(false)
	arena.camera.set_physics_process(false)
	player.guard = true
	player.update_guard_timing(true,0.008)
	check(player.just_guard_window > 0,"guard press opens timing window")
	var hp: float = player.hp
	var stamina: float = player.stamina
	check(player.absorb_guard(40,Vector2.RIGHT,1,0,false,foe),"timely shield contact succeeds")
	check(player.hp == hp and player.stamina == stamina-4 and player.posture == 0,"just guard prevents damage and reduces stamina cost")
	check(foe.posture >= 60,"just guard adds attacker posture strain")
	check(not player.absorb_guard(40,Vector2.RIGHT,1,0,false,foe),"same window cannot block a second hit perfectly")
	player.update_guard_timing(true,0.6)
	check(player.just_guard_window == 0,"holding guard does not reopen window")
	player.guard = false
	player.update_guard_timing(false,0.01)
	player.guard = true
	player.update_guard_timing(true,0.01)
	check(player.just_guard_window > 0,"release and new press rearms after cooldown")
	player.update_guard_timing(true,0.2)
	check(not player.absorb_guard(10,Vector2.RIGHT,1,0,false,foe),"late hit uses normal guard")
	player.stamina = 100
	player.stun = 0
	player.guard = true
	player.just_guard_window = 0.18
	player.position = Vector2(80,200)
	player.facing = PI
	player.shield.position = Vector2(-30,0)
	player.shield.rotation = PI
	player.shield.collision_layer = 8
	foe.position = Vector2(0,200)
	foe.facing = 0
	foe.weapon.begin_combo()
	foe.weapon.set_physics_process(false)
	foe.weapon.angle = 0
	foe.weapon.thrust_speed = 240
	foe.posture = 55
	await physics_frame
	var blocked: bool = foe.weapon.sweep(0,0)
	check(blocked and foe.weapon.rebounding and foe.weapon.combo_remaining == 0,"real shield contact deflects weapon and interrupts combo")
	check(foe.stun > 0 and foe.riposte_available,"posture threshold creates critical opening")
	print("JUST GUARD COMPLETE: %d failures" % failures)
	quit(failures)
