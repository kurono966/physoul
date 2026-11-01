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
	arena.boss_stage = true
	arena.map_seed = 12345
	root.add_child(arena)
	await physics_frame
	arena.player.set_physics_process(false)
	arena.opponent.set_physics_process(false)
	arena.camera.set_physics_process(false)
	arena.player.position = Vector2(0,100)
	arena.player.facing = 0
	arena.vision.explored.clear()
	arena.vision.current_cells.clear()
	arena.vision.mask.fill(Color(0,0,0,1))
	check(arena.vision.observes(Vector2(100,100)),"forward terrain visible inside fan")
	check(not arena.vision.observes(Vector2(-100,100)),"rear terrain outside view")
	check(not arena.vision.observes(Vector2(10,250)),"side terrain outside fan")
	check(not arena.vision.observes(Vector2(700,100)),"terrain beyond range hidden")
	arena.vision.refresh()
	check(arena.vision.remembers(Vector2(108,108)),"visible terrain added to memory")
	check(not arena.vision.remembers(Vector2(-108,108)),"unseen rear terrain not discovered")
	arena.player.facing = PI
	arena.vision.refresh()
	check(arena.vision.remembers(Vector2(108,108)) and not arena.vision.observes(Vector2(108,108)),"terrain memory survives looking away")
	arena.player.facing = 0
	arena.wall(Rect2(60,50,30,100))
	await physics_frame
	check(not arena.vision.observes(Vector2(150,100)),"wall blocks vision")
	arena.opponent.position = Vector2(150,100)
	arena.vision._process(0.1)
	check(not arena.opponent.visible,"enemy behind wall is hidden")
	arena.camera.locked = true
	arena.camera._physics_process(0.01)
	check(not arena.camera.locked,"unseen enemy cannot remain locked")
	arena.opponent.position = Vector2(45,100)
	arena.player.facing = 0
	arena.vision._process(0.1)
	check(arena.opponent.visible,"visible enemy reappears without respawning")
	arena.opponent.position = Vector2(-100,100)
	arena.vision._process(0.1)
	check(not arena.opponent.visible,"remembered area does not reveal live enemy")
	print("VISION COMPLETE: %d failures" % failures)
	quit(failures)
