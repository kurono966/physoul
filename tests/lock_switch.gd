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
	arena.boss_stage = true
	root.add_child(arena)
	await physics_frame
	arena.player.set_physics_process(false)
	arena.camera.set_physics_process(false)
	arena.opponent.set_physics_process(false)
	arena.opponent.weapon.set_physics_process(false)
	arena.player.position = Vector2(0,100)
	arena.player.facing = -PI/2
	arena.camera.rotation = 0
	arena.opponent.position = Vector2(0,-80)
	var center = arena.opponent
	var targets: Array = []
	for pos in [Vector2(100,-80),Vector2(-100,-80),Vector2(40,300),Vector2(20,-80)]:
		var foe = load("res://scripts/fighter.gd").new()
		foe.arena = arena
		foe.enemy = true
		foe.position = pos
		arena.add_child(foe)
		foe.set_physics_process(false)
		foe.weapon.set_physics_process(false)
		targets.append(foe)
	targets[3].make_corpse()
	targets[3].hp = 0
	arena.random_map = true
	arena.camera.locked = true
	Input.action_press("pad_look_right",1)
	arena.camera._physics_process(0)
	check(arena.opponent == targets[0],"right stick selects visible enemy on screen right, excluding dead and rear enemies")
	arena.camera._physics_process(0)
	check(arena.opponent == targets[0],"held stick does not repeat selection")
	Input.action_release("pad_look_right")
	arena.camera._physics_process(0)
	Input.action_press("pad_look_left",1)
	arena.camera._physics_process(0)
	check(arena.opponent == center,"neutral then left returns to nearest enemy on screen left")
	Input.action_release("pad_look_left")
	arena.camera._physics_process(0)
	var wall = StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(-50,10)
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(20,80)
	shape.shape = rect
	wall.add_child(shape)
	arena.add_child(wall)
	await physics_frame
	Input.action_press("pad_look_left",1)
	arena.camera._physics_process(0)
	check(arena.opponent == center,"wall-occluded enemy cannot be selected")
	Input.action_release("pad_look_left")
	arena.camera._physics_process(0)
	wall.queue_free()
	await physics_frame
	for foe in [center]+targets:
		foe.position = arena.player.position+(foe.position-arena.player.position).rotated(PI/2)
	arena.player.facing += PI/2
	arena.camera.rotation = PI/2
	Input.action_press("pad_look_right",1)
	arena.camera._physics_process(0)
	check(arena.opponent == targets[0],"selection follows screen direction after camera rotation")
	Input.action_release("pad_look_right")
	arena.camera._physics_process(0)
	arena.camera.locked = false
	var heading: float = arena.camera.heading
	Input.action_press("pad_look_right",1)
	arena.camera._physics_process(0.1)
	check(arena.camera.heading > heading,"unlocked right stick still rotates view")
	Input.action_release("pad_look_right")
	print("LOCK SWITCH COMPLETE: %d failures" % failures)
	quit(failures)
