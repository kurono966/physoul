extends SceneTree
var failures := 0
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)
func frames(n: int) -> void:
	for i in n: await physics_frame
func waves(arena: Node) -> int:
	var count := 0
	for child in arena.get_children():
		if child.get_script() == load("res://scripts/shockwave.gd"): count += 1
	return count
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	arena.random_map = false
	root.add_child(arena)
	await frames(20)
	arena.opponent.set_physics_process(false)
	arena.opponent.position = Vector2(250,200)
	arena.opponent.shield.collision_layer = 0
	arena.player.position = Vector2(0,200)
	arena.player.facing = 0
	arena.camera.heading = 0
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_BACK
	back.pressed = true
	Input.parse_input_event(back)
	await frames(2)
	check(not arena.controls.help_visible,"Back hides help")
	back.pressed = false
	Input.parse_input_event(back)
	await frames(2)
	back.pressed = true
	Input.parse_input_event(back)
	await frames(2)
	check(arena.controls.help_visible,"Back restores help")
	var lt := InputEventJoypadMotion.new()
	lt.axis = JOY_AXIS_TRIGGER_LEFT
	lt.axis_value = 1
	Input.parse_input_event(lt)
	await frames(50)
	check(arena.player.weapon.wave_mode and arena.player.weapon.active and waves(arena) == 0,"LT starts long windup without early wave")
	check(arena.player.position.distance_to(Vector2(0,200)) < 0.01,"wave preparation stops movement")
	await frames(180)
	check(arena.opponent.hp == 65,"wave hits distant enemy once for 35 damage")
	check(not arena.player.weapon.active,"holding LT does not repeat attack")
	arena.player.weapon.cancel()
	arena.player.weapon.cooldown = 0
	arena.player.stamina = 100
	arena.opponent.hp = 100
	arena.wall(Rect2(140,175,15,50))
	lt.axis_value = 0
	Input.parse_input_event(lt)
	await frames(2)
	lt.axis_value = 1
	Input.parse_input_event(lt)
	await frames(250)
	check(arena.opponent.hp == 100,"wall stops shockwave")
	check(waves(arena) == 0,"wave cleans up after wall impact")
	print("WAVE COMPLETE: %d failures" % failures)
	quit(failures)
