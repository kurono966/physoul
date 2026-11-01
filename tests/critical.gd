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
	arena.select_enemy(1)
	arena.camera.set_physics_process(false)
	var player = arena.player
	var target = arena.opponent
	player.position = Vector2(0,200)
	target.position = Vector2(55,200)
	target.break_guard()
	await physics_frame
	check(player.can_critical(),"adjacent staggered enemy offers critical")
	player.position = Vector2(-100,200)
	check(not player.can_critical(),"distant stagger cannot be executed")
	player.position = Vector2(0,200)
	check(player.start_critical(),"critical consumes opening")
	check(not target.riposte_available and player.stamina <= 80,"opening and stamina consumed once")
	check(not player.start_critical(),"critical cannot restart while executing")
	var origin: Vector2 = player.position
	for i in 20: await physics_frame
	check(target.hp == 160,"windup does not damage early")
	for i in 35: await physics_frame
	check(target.hp == 60,"critical deals 100 damage once")
	check(player.position.distance_to(origin) < 0.1,"critical locks attacker movement")
	for i in 100: await physics_frame
	check(target.hp == 60 and player.critical_time == 0,"critical recovers without repeated damage")
	target.weapon.cancel()
	target.set_physics_process(false)
	player.weapon.cooldown = 0
	player.stamina = 100
	target.hp = 50
	target.break_guard()
	target.position = player.position+Vector2(55,0)
	await physics_frame
	check(player.start_critical(),"fresh stagger offers another critical")
	for i in 70: await physics_frame
	check(target.hp == 0,"critical kills low HP enemy")
	print("CRITICAL COMPLETE: %d failures" % failures)
	quit(failures)
