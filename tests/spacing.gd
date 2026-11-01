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
	var foe = arena.opponent
	var player = arena.player
	foe.set_physics_process(false)
	player.set_physics_process(false)
	arena.camera.set_physics_process(false)
	foe.position = Vector2(0,200)
	foe.facing = 0
	player.position = Vector2(110,200)
	var move: Vector2 = foe.think(0.01)
	check(not foe.weapon.active and move.x > 0 and foe.ai_state == "APPROACH","swordsman approaches instead of attacking at 110px")
	player.position.x = 82
	foe.think(0.01)
	check(foe.weapon.active and foe.weapon.combo_remaining == 2,"swordsman starts combo inside actual sword reach")
	player.position.x = 150
	foe.weapon.finish_attack()
	check(not foe.weapon.active and foe.weapon.combo_remaining == 0,"target leaving range stops followup")
	foe.weapon.cooldown = 0
	move = foe.think(0.01)
	check(move.x > 0 and not foe.weapon.active,"swordsman approaches again after target escapes")
	foe.set_physics_process(true)
	var began := false
	for i in 400:
		await physics_frame
		if foe.weapon.active:
			began = true
			check(foe.global_position.distance_to(player.global_position) <= foe.weapon.engagement_distance()+1,"live AI closes distance before restarting")
			break
	check(began,"live AI eventually attacks after closing distance")
	foe.set_physics_process(false)
	foe.weapon.cancel()
	foe.weapon.cooldown = 0
	foe.position = Vector2(0,200)
	player.position = Vector2(82,200)
	arena.wall(Rect2(35,175,10,50))
	await physics_frame
	check(not foe.weapon.target_in_reach(),"wall blocks attack decision even at close range")
	print("SPACING COMPLETE: %d failures" % failures)
	quit(failures)
