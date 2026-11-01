extends Node2D
var source: CharacterBody2D
var direction := Vector2.RIGHT
var speed := 520.0
var life := 0.8

func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0 or not is_instance_valid(source):
		queue_free()
		return
	var motion := direction*speed*dt
	var closest: Dictionary = {}
	var distance := INF
	for offset in [-10,0,10]:
		var start: Vector2 = global_position+direction.orthogonal()*offset
		var query := PhysicsRayQueryParameters2D.create(start,start+motion,1|2|4|8)
		query.exclude = [source.get_rid(),source.shield.get_rid()]
		var result := get_world_2d().direct_space_state.intersect_ray(query)
		if not result.is_empty() and start.distance_to(result.position) < distance:
			closest = result
			distance = start.distance_to(result.position)
	if not closest.is_empty():
		var target: Object = closest.collider
		var perfect := false
		if target.has_meta("fighter"):
			perfect = target.get_meta("fighter").absorb_guard(42,direction,1,0,true,source)
		elif target is CharacterBody2D:
			target.receive(42,35,direction,closest.position)
		elif target is RigidBody2D:
			target.apply_impulse(direction*350,closest.position-target.global_position)
		if not perfect: source.arena.sound.play("metal" if target.has_meta("fighter") else "stone",55)
		source.arena.contact(closest.position,closest.normal,42)
		queue_free()
		return
	position += motion
	queue_redraw()

func _draw() -> void:
	var angle := direction.angle()
	var opacity := minf(1,life*5)
	draw_arc(-direction*10,24,angle-0.85,angle+0.85,20,Color(0.35,0.7,1,opacity*0.15),18,true)
	draw_arc(-direction*10,24,angle-0.85,angle+0.85,20,Color(0.55,0.85,1,opacity*0.7),6,true)
	draw_arc(-direction*10,24,angle-0.85,angle+0.85,20,Color(0.9,0.98,1,opacity),2,true)
