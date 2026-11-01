extends SceneTree
var failures := 0
func check(ok: bool,label: String) -> void:
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
	arena.camera.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.opponent.set_physics_process(false)
	arena.opponent.weapon.set_physics_process(false)
	var target = arena.opponent
	var fx = arena.damage_effects
	fx.set_process(false)
	target.receive(5,0,Vector2.RIGHT)
	check(fx.particles.is_empty(),"zero damage does not create damage particles")
	target.roll = 0.25
	target.receive(5,20,Vector2.RIGHT)
	check(fx.particles.is_empty(),"invulnerable dodge does not create damage particles")
	target.roll = 0
	target.receive(5,20,Vector2.RIGHT,Vector2(40,100))
	check(fx.particles.size() == 12 and fx.flashes[0].point == Vector2(40,100),"actual HP damage creates burst at exact contact point")
	var start: Vector2 = fx.particles[0].point
	fx._process(0.05)
	check(fx.particles[0].point.distance_to(start) > 1,"particles physically spread from impact")
	fx._process(1)
	check(fx.particles.is_empty() and fx.flashes.is_empty(),"particles and flashes expire")
	target.hp = 10
	target.receive(5,20,Vector2.RIGHT)
	check(fx.particles.size() == 28,"lethal damage produces a larger burst")
	for i in 50: fx.burst(target,Vector2.ZERO,Vector2.RIGHT,20,false)
	check(fx.particles.size() <= 384 and fx.flashes.size() <= 24,"simultaneous effects have bounded particle budget")
	fx._process(1)
	arena.random_map = true
	arena.player.position = Vector2(0,100)
	arena.player.facing = 0
	target.hp = 100
	target.position = Vector2(-100,100)
	target.receive(0,10,Vector2.RIGHT,Vector2(-80,100))
	check(fx.particles.is_empty(),"unseen enemy damage does not reveal its position")
	target.position = Vector2(100,100)
	target.receive(0,10,Vector2.RIGHT,Vector2(80,100))
	check(fx.particles.size() == 12,"visible enemy damage still produces burst")
	check(not fx.observable(Vector2(-100,100),false),"particles outside current cone stay hidden")
	print("DAMAGE EFFECTS COMPLETE: %d failures" % failures)
	quit(failures)
