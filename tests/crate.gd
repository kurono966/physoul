extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	arena.random_map = false
	root.add_child(arena)
	arena.player.set_physics_process(false)
	arena.opponent.set_physics_process(false)
	var box: RigidBody2D
	for child in arena.get_children():
		if child is RigidBody2D:
			box = child
			break
	var start := box.position
	for i in 240: await physics_frame
	if box.position.distance_to(start) > 0.1:
		push_error("Untouched crate drifted")
		quit(1)
		return
	print("PASS: untouched crate remains stationary for 2 seconds")
	box.apply_central_impulse(Vector2(160,0))
	for i in 12: await physics_frame
	if box.position.x <= start.x + 1:
		push_error("Impulse did not move crate")
		quit(1)
		return
	print("PASS: applied impulse moves crate")
	for i in 240: await physics_frame
	if box.linear_velocity.length() > 0.5:
		push_error("Crate did not slow down")
		quit(1)
		return
	print("PASS: crate slows to rest without directional acceleration")
	quit()
