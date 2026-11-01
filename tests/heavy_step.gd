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
	await frames(3)
	arena.camera.set_physics_process(false)
	arena.opponent.set_physics_process(false)
	arena.opponent.position = Vector2(-500,-400)
	var player = arena.player
	player.position = Vector2(0,200)
	player.facing = 0
	player.start_heavy(false)
	await frames(25)
	check(player.position.length() > 0 and absf(player.position.x) < 0.01,"no step during heavy windup")
	await frames(35)
	var normal_distance: float = player.position.x
	check(normal_distance > 24 and normal_distance < 32,"normal overhead steps about 28px forward")
	await frames(35)
	check(absf(player.position.x-normal_distance) < 0.01,"step ends without recovery drift")
	player.weapon.cancel()
	player.weapon.cooldown = 0
	player.stamina = 100
	player.position = Vector2(0,200)
	player.start_heavy(true)
	player.weapon.player_followup = false
	await frames(30)
	check(player.position.x > 38 and player.position.x < 46,"charged overhead steps about 42px forward")
	player.weapon.cancel()
	player.weapon.cooldown = 0
	player.stamina = 100
	player.position = Vector2(595,200)
	player.start_heavy(false)
	await frames(90)
	check(player.position.x <= 601.1,"step cannot penetrate outer wall")
	player.weapon.cancel()
	player.weapon.cooldown = 0
	player.stamina = 100
	player.position = Vector2(0,200)
	player.attack(false)
	await frames(90)
	check(absf(player.position.x) < 0.01,"ordinary slash does not gain heavy step")
	print("HEAVY STEP COMPLETE: %d failures" % failures)
	quit(failures)
