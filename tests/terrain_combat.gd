extends SceneTree
var failures := 0
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	arena.random_map = false
	root.add_child(arena)
	await frames(2)
	arena.camera.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.opponent.set_physics_process(false)
	arena.opponent.weapon.set_physics_process(false)
	var crate = load("res://scripts/crate.gd").new()
	crate.arena = arena
	crate.position = Vector2(50,0)
	crate.mass = 4
	crate.linear_damp = 4
	crate.collision_layer = 4
	crate.collision_mask = 7
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(38,38)
	collision.shape = shape
	crate.add_child(collision)
	for child in arena.get_children():
		if child is StaticBody2D: child.queue_free()
		if child is RigidBody2D: child.queue_free()
	arena.add_child(crate)
	arena.player.position = Vector2.ZERO
	arena.player.facing = 0
	arena.player.kick_facing = 0
	arena.opponent.position = Vector2(115,0)
	arena.opponent.shield.collision_layer = 0
	await frames(2)
	arena.player.resolve_kick()
	await frames(2)
	check(crate.linear_velocity.x > 200,"kick launches nearest crate forward")
	await frames(35)
	check(arena.opponent.hp < 100 and arena.opponent.posture > 25,"moving crate damages enemy and loads posture")
	var hp_after: float = arena.opponent.hp
	await frames(70)
	check(arena.opponent.hp == hp_after,"resting crate does not repeatedly damage touching enemy")
	crate.queue_free()
	await frames(2)
	arena.opponent.position = Vector2(55,0)
	arena.opponent.impulse_velocity = Vector2.ZERO
	arena.opponent.posture = 0
	arena.opponent.stun = 0
	arena.opponent.hp = 100
	arena.wall(Rect2(90,-60,20,120))
	await frames(2)
	arena.player.resolve_kick()
	arena.opponent.weapon.cooldown = 10
	arena.opponent.set_physics_process(true)
	await frames(25)
	check(arena.opponent.hp <= 92 and arena.opponent.stun > 0 and arena.opponent.riposte_available,"kicking enemy into wall creates stagger and critical opening")
	arena.opponent.set_physics_process(false)
	arena.select_enemy(4)
	var wolf = arena.opponent
	wolf.position = Vector2(0,200)
	wolf.facing = 0
	arena.player.position = Vector2(160,200)
	arena.wall(Rect2(70,210,25,80))
	await frames(2)
	wolf.weapon.begin_combo()
	check(wolf.weapon.active,"wolf commits when narrow bite line clears pillar corner")
	await frames(95)
	check(wolf.hp < 65 and wolf.stun > 0 and not wolf.weapon.active,"pounce clipping pillar corner crashes and interrupts wolf")
	print("TERRAIN COMBAT COMPLETE: %d failures" % failures)
	quit(failures)
