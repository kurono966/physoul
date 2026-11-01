extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	for i in 20: await process_frame
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
	if "--lock" in OS.get_cmdline_user_args():
		arena.camera.locked = true
		await process_frame
	if "--debug" in OS.get_cmdline_user_args(): arena.debug = true
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
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview.png")
	arena.queue_free()
	await process_frame
	quit()
