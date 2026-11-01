extends RigidBody2D

var arena: Node2D
var previous_velocity := Vector2.ZERO
var contact_cooldowns: Dictionary = {}

func _ready() -> void:
	gravity_scale = 0
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

func launch(direction: Vector2, strength := 1400.0) -> void:
	var impulse := direction.normalized()*strength
	previous_velocity = linear_velocity+impulse/mass
	sleeping = false
	apply_central_impulse(impulse)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	for i in state.get_contact_count():
		var actor := state.get_contact_collider_object(i)
		if not is_instance_valid(actor) or not actor.has_method("receive") or actor.hp <= 0: continue
		var normal: Vector2 = state.transform.basis_xform(state.get_contact_local_normal(i)).normalized()
		var speed := maxf(-(previous_velocity-actor.velocity).dot(normal),-(state.linear_velocity-actor.velocity).dot(normal))
		if speed < 100: continue
		var id := actor.get_instance_id()
		if Time.get_ticks_msec() < contact_cooldowns.get(id,0): continue
		contact_cooldowns[id] = Time.get_ticks_msec()+600
		strike_actor.call_deferred(actor,speed,-normal)
	previous_velocity = state.linear_velocity

func strike_actor(actor: Node2D, speed: float, direction: Vector2) -> void:
	if not is_instance_valid(actor) or actor.hp <= 0: return
	actor.receive(clampf(speed*0.4,25,110),clampf(speed*0.035,4,18),direction)
	if speed >= 150 and actor.hp > 0:
		actor.weapon.cancel()
		actor.stun = maxf(actor.stun,0.35)
	arena.sound.play("wood",65)
	arena.contact(actor.global_position,direction,55)
	arena.event_text = "CRATE IMPACT"
