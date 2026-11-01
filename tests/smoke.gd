extends SceneTree

var arena: Node2D
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
	else:
		print("PASS: ",label)

func frames(count: int) -> void:
	for i in count: await physics_frame

func setup_duel() -> void:
	# Exercise the AI's retained scripted swing for common collision rules.
	arena.player.enemy = true
	arena.player.position = Vector2(0,200)
	arena.opponent.position = Vector2(85,200)
	arena.player.facing = 0
	arena.opponent.facing = PI
	arena.opponent.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.camera.set_physics_process(false)
	arena.player.weapon.cancel()
	arena.player.weapon.cooldown = 0
	arena.player.stamina = 100
	arena.opponent.hp = 100
	arena.opponent.posture = 0
	arena.opponent.shield.collision_layer = 0
	await frames(2)

func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	arena.random_map = false
	root.add_child(arena)
	await frames(5)
	check(arena.player.hp == 100,"scene loads with live fighters")
	for rotation in [0.0, PI, PI / 2]:
		var move := Vector2.UP.rotated(rotation)
		check(move.rotated(-rotation).distance_to(Vector2.UP) < 0.001,"camera-relative forward at %.2f" % rotation)
	await setup_duel()
	arena.player.attack(false)
	await frames(180)
	check(arena.opponent.hp < 100,"swept blade damages opponent")
	check(arena.opponent.posture > 0,"impact adds posture strain")
	await setup_duel()
	arena.opponent.guard = true
	arena.opponent.shield.position = Vector2(-30,0)
	arena.opponent.shield.rotation = PI
	arena.opponent.shield.collision_layer = 8
	await frames(2)
	arena.player.attack(true)
	await frames(200)
	check(arena.opponent.stamina < 100,"shield contact consumes stamina")
	check(arena.opponent.hp > 90,"shield reduces HP damage")
	# Deterministic guard endurance, independent of AI choices and regeneration.
	for strong in [false, true]:
		arena.opponent.stamina = 100
		arena.opponent.posture = 0
		arena.opponent.stun = 0
		arena.opponent.impulse_velocity = Vector2.ZERO
		var count := 2 if strong else 3
		for i in count:
			arena.opponent.guard = true
			arena.opponent.absorb_guard(12, Vector2.RIGHT, 1, 0, strong)
			if i < count-1:
				check(arena.opponent.stun == 0,"guard survives preceding hit")
		check(arena.opponent.stamina == 0 and arena.opponent.stun >= 1.6,"stamina depletion breaks guard after %d hits" % count)
		check(not arena.opponent.guard and arena.opponent.shield.collision_layer == 0,"broken shield has no blocking collider")
		check(arena.opponent.recovery >= 1.6,"guard impact delays stamina regeneration")
	await setup_duel()
	arena.opponent.stun = 0
	arena.opponent.impulse_velocity = Vector2.ZERO
	arena.opponent.drive_velocity = Vector2.ZERO
	arena.opponent.receive(30, 0, Vector2.RIGHT)
	var initial_position: Vector2 = arena.opponent.position
	arena.opponent.set_physics_process(true)
	await frames(8)
	check(arena.opponent.position.x > initial_position.x + 3,"impact physically displaces defender across multiple ticks")
	arena.opponent.set_physics_process(false)
	await setup_duel()
	arena.player.position = Vector2(585,200)
	arena.opponent.position = Vector2(-500,-400)
	await frames(2)
	arena.player.attack(false)
	var saw_rebound := false
	for i in 180:
		await frames(1)
		if arena.player.weapon.rebounding and arena.player.weapon.omega < 0: saw_rebound = true
	check(saw_rebound,"wall contact reverses angular momentum")
	check(arena.last_point.x > 610,"weapon contacts outer wall")
	check(not arena.player.weapon.active,"wall stops swing")
	arena.opponent.receive(120,200,Vector2.RIGHT)
	check(arena.opponent.hp == 0 and not arena.opponent.weapon.active,"death cancels combat")
	check(arena.opponent.stun > 0,"posture threshold staggers")
	arena.queue_free()
	await process_frame
	arena = load("res://arena.tscn").instantiate()
	arena.random_map = false
	root.add_child(arena)
	await frames(5)
	check(arena.opponent.hp == 100 and arena.player.hp == 100,"fresh scene resets duel")
	arena.player.set_physics_process(false)
	arena.opponent.set_physics_process(false)
	arena.camera.set_physics_process(false)
	arena.player.position = Vector2(0,200)
	arena.opponent.position = Vector2(70,200)
	arena.opponent.shield.collision_layer = 0
	arena.player.facing = 0
	arena.player.attack(false)
	check(arena.player.weapon.active and not arena.player.weapon.thrust_attack,"short click selects slash")
	await frames(180)
	check(arena.opponent.hp < 100,"scripted player slash hits")
	arena.opponent.hp = 100
	arena.opponent.position = Vector2(105,200)
	arena.player.weapon.angle = 0
	arena.player.weapon.cooldown = 0
	arena.player.stamina = 100
	arena.player.attack(true)
	check(arena.player.weapon.active and arena.player.weapon.thrust_attack,"long hold selects thrust")
	await frames(180)
	check(arena.opponent.hp < 100,"scripted player thrust hits")
	check(arena.player.weapon.extension == 0 and not arena.player.weapon.active,"thrust retracts and recovers")
	arena.player.weapon.cancel()
	arena.player.set_physics_process(true)
	arena.opponent.hp = 100
	arena.opponent.set_physics_process(false)
	arena.camera.set_physics_process(false)
	arena.player.position = Vector2(0,200)
	arena.opponent.position = Vector2(70,200)
	arena.player.facing = 0
	arena.player.start_kick()
	check(arena.player.kick_pending and arena.opponent.hp == 100,"kick windup precedes damage")
	await frames(20)
	check(arena.opponent.hp == 97 and not arena.player.kick_pending,"kick damage occurs once at visible extension")
	await frames(70)
	check(arena.player.kick_time == 0 and arena.opponent.hp == 97,"kick retracts without repeated hits")
	print("SMOKE COMPLETE: ",failures," failures")
	quit(failures)
