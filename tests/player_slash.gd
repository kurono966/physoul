extends SceneTree
var failures := 0
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func tap(arena: Node) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	event.pressed = true
	arena.camera._unhandled_input(event)
	event.pressed = false
	arena.camera._unhandled_input(event)
func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	arena.random_map = false
	root.add_child(arena)
	await physics_frame
	arena.camera.set_physics_process(false)
	for child in arena.get_children():
		if child is StaticBody2D or child is RigidBody2D: child.queue_free()
	for actor in [arena.player,arena.opponent]:
		actor.set_physics_process(false)
		actor.weapon.set_physics_process(false)
		actor.shield.collision_layer = 0
	var player = arena.player
	var target = arena.opponent
	player.position = Vector2.ZERO
	for setting in [Vector2(0,0),Vector2(PI/2,0),Vector2(-3.12,0),Vector2(3.12,0),Vector2(0,-0.4),Vector2(0,0.4)]:
		player.facing = setting.x
		player.weapon.angle = setting.x+0.55+TAU*2
		player.weapon.cooldown = 0
		player.stamina = 100
		player.charge = 0
		target.hp = 100
		target.posture = 0
		target.stun = 0
		target.position = Vector2.RIGHT.rotated(setting.x+setting.y)*80
		await physics_frame
		tap(arena)
		check(player.weapon.active and player.weapon.is_player_slash(),"RB tap begins horizontal slash: "+str(setting))
		for i in 12: player.weapon._physics_process(1.0/120)
		check(target.hp == 100,"preparation cannot hit: "+str(setting))
		for i in 30: player.weapon._physics_process(1.0/120)
		check(target.hp < 100,"front arc hits within 0.35 seconds: "+str(setting))
		var hp_after: float = target.hp
		for i in 120: player.weapon._physics_process(1.0/120)
		check(target.hp == hp_after and not player.weapon.active,"slash hits once and recovers: "+str(setting))
	player.facing = 0
	player.weapon.cooldown = 0
	player.stamina = 100
	target.position = Vector2(125,0)
	target.hp = 100
	await physics_frame
	tap(arena)
	for i in 160: player.weapon._physics_process(1.0/120)
	check(target.hp == 100,"slash cannot hit beyond blade reach")
	player.weapon.cooldown = 0
	player.stamina = 100
	target.position = Vector2(80,0)
	arena.wall(Rect2(35,-60,14,120))
	await physics_frame
	tap(arena)
	for i in 160: player.weapon._physics_process(1.0/120)
	check(target.hp == 100,"physical wall blocks slash before target")
	print("PLAYER SLASH COMPLETE: %d failures" % failures)
	quit(failures)
