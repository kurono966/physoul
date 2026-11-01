extends SceneTree
var failures := 0
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)
func trigger(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	Input.parse_input_event(event)
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	arena.random_map = false
	root.add_child(arena)
	await frames(20)
	arena.opponent.set_physics_process(false)
	arena.player.position = Vector2(0,200)
	arena.opponent.position = Vector2(400,200)
	trigger(0.8)
	await frames(6)
	check(arena.player.heavy_charge > 0 and arena.player.attack_movement_locked(),"RT starts heavy preparation and stops movement")
	trigger(0)
	await frames(2)
	check(arena.player.weapon.active and arena.player.weapon.heavy_mode and not arena.player.weapon.thrust_attack and not arena.player.weapon.player_followup,"RT tap releases overhead without followup")
	await frames(200)
	arena.player.stamina = 100
	trigger(1)
	await frames(85)
	check(arena.player.weapon.active and arena.player.weapon.charged_heavy and arena.player.weapon.player_followup,"RT hold automatically releases charged attack")
	var followup := false
	for i in 200:
		await frames(1)
		if arena.player.weapon.active and arena.player.weapon.heavy_mode and arena.player.weapon.swing_direction < 0:
			followup = true
	check(followup,"charged attack chains into overhead followup")
	check(not arena.player.weapon.active and arena.player.heavy_charge == 0,"holding RT does not repeat charged combo")
	trigger(0)
	await frames(2)
	check(not arena.player.weapon.active,"release after charged combo does not attack again")
	arena.player.weapon.cooldown = 0
	arena.player.stamina = 100
	arena.player.start_heavy(true)
	arena.player.weapon.bounce(50)
	check(not arena.player.weapon.player_followup,"weapon rebound cancels charged followup")
	arena.camera.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.player.weapon.cancel()
	arena.player.weapon.cooldown = 0
	arena.player.stamina = 100
	arena.player.facing = 0
	arena.opponent.position = Vector2(80,200)
	arena.opponent.shield.collision_layer = 0
	arena.player.start_heavy(false)
	await frames(160)
	check(arena.opponent.hp < 100,"RT overhead physically hits frontal target")
	arena.player.weapon.cancel()
	arena.player.weapon.cooldown = 0
	arena.player.stamina = 100
	arena.opponent.hp = 100
	arena.opponent.position = Vector2(0,265)
	arena.player.start_heavy(false)
	await frames(160)
	check(arena.opponent.hp == 100,"overhead does not hit targets beside the player")
	print("HEAVY COMPLETE: %d failures" % failures)
	quit(failures)
