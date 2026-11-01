extends SceneTree
var failures := 0
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)
func frames(n: int) -> void:
	for i in n: await physics_frame
func button(index: int, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	arena.map_seed = 12345
	root.add_child(arena)
	await frames(4)
	arena.camera.set_physics_process(false)
	for foe in arena.guardians.values():
		foe.set_physics_process(false)
		foe.weapon.set_physics_process(false)
	var player = arena.player
	player.position = Vector2.ZERO
	player.hp = 40
	button(JOY_BUTTON_DPAD_DOWN,true)
	await frames(4)
	check(player.flasks == 3 and player.healing_time == 0,"D-pad down no longer uses flask")
	button(JOY_BUTTON_DPAD_DOWN,false)
	button(JOY_BUTTON_X,true)
	await frames(4)
	check(player.flasks == 2 and player.healing_time > 0 and player.hp == 40 and player.kick_time == 0,"X consumes one flask and begins drinking without kicking")
	button(JOY_BUTTON_RIGHT_SHOULDER,true)
	await frames(2)
	button(JOY_BUTTON_RIGHT_SHOULDER,false)
	await frames(2)
	check(not player.weapon.active and player.charge == 0 and player.drive_velocity == Vector2.ZERO,"drinking locks attack and input movement")
	await frames(50)
	check(player.hp == 85 and player.flasks == 2,"drink restores 45 HP after preparation")
	await frames(50)
	check(player.flasks == 2 and player.healing_time == 0,"holding X does not consume more flasks")
	button(JOY_BUTTON_X,false)
	await frames(4)
	player.hp = 100
	var key := InputEventKey.new()
	key.keycode = KEY_DOWN
	key.pressed = true
	arena.camera._unhandled_input(key)
	check(player.flasks == 2,"full HP does not waste a flask")
	player.hp = 90
	arena.camera._unhandled_input(key)
	await frames(100)
	check(player.hp == 100 and player.flasks == 1,"keyboard down uses flask and HP is capped")
	player.hp = 40
	player.start_heal()
	player.receive(1,5,Vector2.ZERO)
	await frames(100)
	check(player.hp == 35 and player.flasks == 0 and not player.healing_pending,"taking damage interrupts drink without refund or delayed heal")
	player.start_heal()
	check(player.flasks == 0 and player.healing_time == 0,"empty flask cannot be used")
	player.set_physics_process(false)
	player.position = Vector2(150,0)
	arena.update_exploration()
	arena.interact()
	check(player.flasks == 0,"rest point cannot refill from outside interaction range")
	player.position = Vector2.ZERO
	arena.update_exploration()
	arena.interact()
	check(player.flasks == 3 and player.hp == 100,"starting rest point fully restores flasks and HP")
	for i in arena.dungeon.rooms.size():
		var room: Dictionary = arena.dungeon.rooms[i]
		if room.kind != "shrine": continue
		player.position = room.center
		player.flasks = 0
		player.hp = 40
		arena.update_exploration()
		arena.interact()
		check(player.flasks == 3 and player.hp == 90,"shrine restores flasks and retains one-time HP blessing")
		player.flasks = 0
		arena.interact()
		check(player.flasks == 3 and player.hp == 90,"used shrine can refill flasks again")
	player.flasks = 1
	player.hp = 70
	arena.change_stage(true,-1,true)
	await process_frame
	var boss_arena = current_scene
	check(boss_arena.player.flasks == 1 and boss_arena.player.hp == 70,"entering boss stage preserves remaining flasks")
	boss_arena.restart_stage()
	await process_frame
	check(current_scene.player.flasks == 3 and current_scene.player.hp == 100,"retry restores full flask capacity")
	print("HEALING COMPLETE: %d failures" % failures)
	quit(failures)
