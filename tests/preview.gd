extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	arena.random_map = false
	if "--explore" in OS.get_cmdline_user_args():
		arena.random_map = true
		arena.map_seed = 12345
	if "--map" in OS.get_cmdline_user_args():
		arena.random_map = true
		arena.boss_stage = true
		arena.map_seed = 73491
	root.add_child(arena)
	for i in 20: await process_frame
	if "--encounter" in OS.get_cmdline_user_args() and arena.exploring():
		var selected: Dictionary = {}
		for room: Dictionary in arena.dungeon.rooms:
			if room.escorts.is_empty(): continue
			if selected.is_empty() or room.tiles.size() > selected.tiles.size(): selected = room
		if not selected.is_empty():
			arena.player.position = selected.center+Vector2(0,150)
			arena.player.facing = -1.95
			arena.camera.rotation = arena.player.facing+PI/2
			arena.camera.position = arena.player.position+Vector2.UP.rotated(arena.camera.rotation)*145
			arena.camera.set_physics_process(false)
			arena.player.set_physics_process(false)
			arena.update_exploration()
			arena.vision.refresh()
			await process_frame
	if "--ell" in OS.get_cmdline_user_args():
		for room: Dictionary in arena.dungeon.rooms:
			if room.shape == "ell":
				arena.player.position = room.center+Vector2(0,100)
				arena.camera.position = arena.player.position+Vector2(0,-145)
				arena.update_exploration()
				break
		await process_frame
	if "--boss" in OS.get_cmdline_user_args():
		arena.select_enemy(3)
		arena.opponent.position = Vector2(0,-20)
		await process_frame
	if "--hammer" in OS.get_cmdline_user_args():
		arena.select_enemy(1)
		await process_frame
	if "--spear" in OS.get_cmdline_user_args():
		arena.select_enemy(2)
		await process_frame
	if "--wolf" in OS.get_cmdline_user_args():
		arena.select_enemy(4)
		arena.opponent.position = Vector2(0,30)
		await process_frame
	if "--reptile" in OS.get_cmdline_user_args():
		arena.select_enemy(5)
		arena.opponent.position = Vector2(0,30)
		await process_frame
	if "--lock" in OS.get_cmdline_user_args():
		arena.camera.locked = true
		await process_frame
	if "--debug" in OS.get_cmdline_user_args(): arena.debug = true
	if "--slash" in OS.get_cmdline_user_args():
		arena.player.set_physics_process(false)
		arena.player.weapon.set_physics_process(false)
		arena.camera.set_physics_process(false)
		arena.player.attack(false)
		for i in 31: arena.player.weapon._physics_process(1.0/120)
		arena.player.queue_redraw()
	for motion in ["backhand","thrust","overhead"]:
		if ("--enemy-"+motion) in OS.get_cmdline_user_args():
			arena.opponent.set_physics_process(false)
			arena.opponent.weapon.set_physics_process(false)
			arena.opponent.weapon.begin(false)
			arena.opponent.weapon.apply_enemy_motion(motion)
			arena.opponent.weapon.elapsed = arena.opponent.weapon.windup_duration()*0.8
			arena.opponent.weapon._physics_process(0.001)
			arena.opponent.queue_redraw()
			arena.camera.set_physics_process(false)
	if "--dash" in OS.get_cmdline_user_args():
		arena.player.sprinting = true
		arena.player.start_dash_attack()
		arena.player.weapon.dash_step(0.23)
		arena.player.set_physics_process(false)
		arena.player.weapon.set_physics_process(false)
		arena.camera.set_physics_process(false)
		arena.player.queue_redraw()
		arena.player.weapon.queue_redraw()
	if "--wave" in OS.get_cmdline_user_args():
		arena.controls.help_visible = false
		arena.player.start_wave()
		arena.player.weapon.elapsed = 0.65
		var wave = load("res://scripts/shockwave.gd").new()
		wave.source = arena.player
		wave.direction = arena.player.forward()
		wave.position = arena.player.position+wave.direction*150
		arena.add_child(wave)
		await process_frame
	if "--overhead" in OS.get_cmdline_user_args():
		arena.player.heavy_charge = 0.58
		arena.camera.set_physics_process(false)
		arena.player.set_physics_process(false)
		await process_frame
	if "--kick" in OS.get_cmdline_user_args():
		arena.player.start_kick()
		arena.player.kick_time = 0.56
		arena.player.set_physics_process(false)
		arena.player.queue_redraw()
		await process_frame
	if "--damage" in OS.get_cmdline_user_args():
		arena.player.set_physics_process(false)
		arena.opponent.set_physics_process(false)
		arena.camera.set_physics_process(false)
		arena.opponent.position = arena.player.position+arena.player.forward()*70
		arena.opponent.receive(25,25,arena.player.forward(),arena.opponent.position-arena.player.forward()*16)
		arena.damage_effects._process(0.045)
		arena.damage_effects.set_process(false)
		arena.damage_effects.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview.png")
	arena.queue_free()
	await process_frame
	quit()
