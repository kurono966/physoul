extends Node2D
const Shockwave = preload("res://scripts/shockwave.gd")

@export var mass := 2.8
@export var length := 76.0
@export var max_angular_speed := 13.0
@export var torque := 80000.0
@export var damage_coefficient := 0.032
@export var recoil := 0.27
var fighter: CharacterBody2D
var active := false
var cooldown := 0.0
var omega := 0.0
var angle := 0.0
var elapsed := 0.0
var heavy := false
var hit: Dictionary = {}
var trail: Array[Vector2] = []
var blade: Area2D
var rebounding := false
var swing_sounded := false
var extension := 0.0
var thrust_speed := 0.0
var windup_start := 0.0
var combo_remaining := 0
var combo_index := 0
var swing_direction := 1.0
var thrust_attack := false
var heavy_mode := false
var dash_mode := false
var charged_heavy := false
var player_followup := false
var overhead_pitch := 0.0
var overhead_reach := 76.0
@export var heavy_step_distance := 28.0
@export var charged_step_distance := 42.0
var heavy_step_direction := Vector2.ZERO
var wave_mode := false
var wave_released := false
var wave_heading := 0.0

func wave_step(dt: float) -> void:
	elapsed += dt
	var windup := windup_duration()
	if elapsed <= windup:
		angle = lerp_angle(windup_start,fighter.facing-1.3,smoothstep(0,1,elapsed/windup))
	else:
		if not swing_sounded:
			wave_heading = fighter.facing
			swing_sounded = true
			fighter.arena.sound.play("heavy",75)
		var next := wave_heading-1.3 + clampf((elapsed-windup)/0.28,0,1)*2.6
		omega = 2.6/0.28
		var divisions := maxi(1,ceili(absf(next-angle)*length/2))
		var step := (next-angle)/divisions
		if elapsed <= windup+0.28:
			for i in divisions:
				if sweep(angle,angle+step): return
				angle += step
		if elapsed >= windup+0.14 and not wave_released:
			wave_released = true
			var offsets := [-0.22,0.0,0.22] if fighter.enemy_kind == "boss" and fighter.boss_enraged else [0.0]
			for offset in offsets:
				var wave := Shockwave.new()
				wave.source = fighter
				wave.direction = Vector2.RIGHT.rotated(wave_heading+offset)
				wave.position = fighter.global_position+wave.direction*12
				fighter.arena.add_child(wave)
		if elapsed >= windup+0.28: omega = 0
	trail.append(Vector2.RIGHT.rotated(angle)*length)
	if trail.size() > 14: trail.pop_front()
	if elapsed > windup+0.65: finish_attack()

func attack_velocity() -> Vector2:
	if not active or (not heavy_mode and not dash_mode) or fighter.hp <= 0 or fighter.stun > 0: return Vector2.ZERO
	var time_into_strike := elapsed-windup_duration()
	if dash_mode:
		if time_into_strike <= 0 or time_into_strike >= 0.22: return Vector2.ZERO
		return heavy_step_direction * 72.0 * PI / (2*0.22) * sin(PI*time_into_strike/0.22)
	if time_into_strike <= 0 or time_into_strike >= 0.16: return Vector2.ZERO
	var distance := charged_step_distance if charged_heavy else heavy_step_distance
	return heavy_step_direction * distance * PI / (2*0.16) * sin(PI*time_into_strike/0.16)

func overhead_step(dt: float) -> void:
	elapsed += dt
	angle = fighter.facing
	var previous_reach := overhead_reach
	var windup := windup_duration()
	if elapsed <= windup:
		overhead_pitch = lerpf(0,1.35,smoothstep(0,1,elapsed/windup))
	elif elapsed <= windup+0.18:
		if not swing_sounded:
			heavy_step_direction = fighter.forward()
			fighter.arena.sound.play("heavy",75 if charged_heavy else 55)
			swing_sounded = true
		overhead_pitch = lerpf(1.35,-0.08,clampf((elapsed-windup)/0.18,0,1))
	else:
		overhead_pitch = move_toward(overhead_pitch,0,dt*2)
	overhead_reach = maxf(21,length*cos(overhead_pitch))
	omega = 0
	thrust_speed = 470 if charged_heavy else 360
	if elapsed > windup and elapsed <= windup+0.18 and overhead_pitch < 0.65:
		if sweep(angle,angle,global_position,overhead_reach,previous_reach):
			thrust_speed = 0
			return
	thrust_speed = 0
	if active and elapsed > windup+0.5: finish_attack()

func engagement_distance() -> float:
	# Target radius is 19px; keep 10px of overlap rather than aiming at its edge.
	return length + (30.0 if fighter.enemy_kind == "spear" else 9.0)

func target_in_reach() -> bool:
	return target_in_reach_at(engagement_distance())

func target_in_reach_at(reach: float) -> bool:
	var target = fighter.arena.player
	if target.hp <= 0 or fighter.global_position.distance_to(target.global_position) > reach:
		return false
	var query := PhysicsRayQueryParameters2D.create(fighter.global_position,target.global_position,1|4)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func begin_combo() -> void:
	if not target_in_reach(): return
	fighter.attack(fighter.enemy_kind in ["brute","boss"])
	if active:
		combo_index = 0
		combo_remaining = 1 if fighter.enemy_kind == "brute" else 2
		if fighter.enemy_kind == "boss":
			combo_remaining = 2 if fighter.boss_enraged else 1
			fighter.boss_attack_count += 1
		swing_direction = 1

func finish_attack() -> void:
	if not fighter.enemy and player_followup:
		cancel()
		if fighter.hp > 0 and fighter.stun <= 0 and fighter.spend(18):
			begin(false)
			heavy_mode = true
			heavy = true
			swing_direction = -1
		return
	var remaining := combo_remaining
	var index := combo_index
	cancel()
	if remaining > 0 and fighter.hp > 0 and fighter.stun <= 0 and target_in_reach() and fighter.spend(24 if fighter.enemy_kind == "brute" else 14):
		combo_remaining = remaining-1
		combo_index = index+1
		swing_direction = -1 if combo_index%2 == 1 else 1
		begin(fighter.enemy_kind in ["brute","boss"] or combo_index == 2)
	else:
		combo_index = 0
		cooldown = 1.15 if fighter.enemy_kind == "brute" else 0.7
		if fighter.enemy_kind == "boss": cooldown = 0.85 if fighter.boss_enraged else 1.2

func windup_duration() -> float:
	if fighter.enemy_kind == "boss":
		if wave_mode: return 1.05 if fighter.boss_enraged else 1.25
		if combo_index > 0: return 0.38 if fighter.boss_enraged else 0.5
		return 0.95 if fighter.boss_enraged else 1.15
	if wave_mode: return 0.95
	if dash_mode: return 0.18
	if heavy_mode: return 0.28
	if not fighter.enemy: return 0.16 if thrust_attack else 0.12
	if combo_index > 0:
		return 0.48 if fighter.enemy_kind == "brute" else (0.32 if fighter.enemy_kind == "spear" else 0.28)
	if fighter.enemy_kind == "spear": return 0.85
	if fighter.enemy_kind == "brute": return 1.0
	return 0.75 if heavy else 0.55

func attack_phase() -> String:
	if not active: return "RECOVERY" if cooldown > 0 else "READY"
	if elapsed < windup_duration(): return "WINDUP"
	if (thrust_attack or fighter.enemy_kind == "spear") and elapsed >= windup_duration()+0.27: return "RECOVERY"
	if heavy_mode and elapsed >= windup_duration()+0.18: return "RECOVERY"
	if wave_mode and elapsed >= windup_duration()+0.28: return "RECOVERY"
	return "STRIKE"

var inertia: float:
	get: return mass * length * length / 3.0

func _ready() -> void:
	blade = Area2D.new()
	blade.collision_layer = 16
	blade.collision_mask = 0
	blade.set_meta("weapon", self)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length - 20, 7)
	shape.position.x = (length + 20) / 2
	shape.shape = rect
	blade.add_child(shape)
	add_child(blade)
	angle = fighter.facing + 0.55

func begin(strong: bool) -> void:
	dash_mode = false
	wave_mode = false
	wave_released = false
	heavy_step_direction = Vector2.ZERO
	overhead_pitch = 0
	overhead_reach = length
	heavy_mode = false
	charged_heavy = false
	player_followup = false
	if not fighter.enemy: swing_direction = 1
	thrust_attack = not fighter.enemy and strong
	if not thrust_attack:
		extension = 0
		position = Vector2.ZERO
	heavy = strong
	swing_sounded = false
	rebounding = false
	active = true
	elapsed = 0
	omega = 0
	windup_start = angle
	hit.clear()
	trail.clear()

func cancel() -> void:
	player_followup = false
	combo_remaining = 0
	combo_index = 0
	thrust_speed = 0
	active = false
	rebounding = false
	omega = 0
	cooldown = 0.9 if fighter.enemy else 0.55

func bounce(impact: float) -> void:
	player_followup = false
	combo_remaining = 0
	combo_index = 0
	thrust_speed = 0
	active = false
	rebounding = true
	omega = -signf(omega) * clampf(absf(omega) * (0.35 + recoil), 2, 8)
	cooldown = 0.55 + impact * 0.003

func _physics_process(dt: float) -> void:
	cooldown = maxf(0, cooldown - dt)
	if fighter.heavy_charge > 0 and not active:
		angle = fighter.facing
		overhead_pitch = lerpf(0,1.35,smoothstep(0,1,clampf(fighter.heavy_charge/0.65,0,1)))
		overhead_reach = maxf(21,length*cos(overhead_pitch))
		extension = 0
		position = Vector2.ZERO
		blade.rotation = angle
		blade.collision_layer = 0
		queue_redraw()
		return
	if fighter.critical_time > 0:
		angle = fighter.facing
		var age: float = 0.9-fighter.critical_time
		extension = lerpf(-20,28,clampf((age-0.23)/0.12,0,1)) if age < 0.45 else move_toward(extension,0,dt*90)
		position = fighter.forward()*extension
		blade.rotation = angle
		blade.collision_layer = 0
		queue_redraw()
		return
	if not fighter.enemy and fighter.charge > 0 and not active:
		var progress := clampf(fighter.charge/0.32,0,1)
		angle = rotate_toward(angle,fighter.facing,dt*8)
		extension = lerpf(0,-22,smoothstep(0,1,progress))
		position = fighter.forward()*extension
		omega = 0
		thrust_speed = 0
		blade.rotation = angle
		blade.collision_layer = 0
		queue_redraw()
		return
	if active:
		if wave_mode:
			wave_step(dt)
			blade.rotation = angle
			blade.collision_layer = 16 if active and attack_phase() == "STRIKE" else 0
			queue_redraw()
			return
		if heavy_mode:
			overhead_step(dt)
			blade.rotation = angle
			blade.scale.x = overhead_reach/length
			blade.collision_layer = 16 if active and attack_phase() == "STRIKE" and overhead_pitch < 0.65 else 0
			queue_redraw()
			return
		blade.scale = Vector2.ONE
		if thrust_attack or fighter.enemy_kind == "spear":
			spear_step(dt)
			blade.rotation = angle
			blade.collision_layer = 16 if active and attack_phase() == "STRIKE" else 0
			queue_redraw()
			return
		elapsed += dt
		var windup := windup_duration()
		if elapsed <= windup:
			var progress := smoothstep(0,1,elapsed/windup)
			angle = lerpf(windup_start,fighter.facing-1.65*swing_direction,progress)
		if elapsed > windup:
			if not swing_sounded:
				fighter.arena.sound.play("heavy" if heavy else "swing", 65 if heavy else 40)
				swing_sounded = true
			omega = swing_direction * minf(max_angular_speed * (1.15 if heavy else 1), absf(omega) + torque / inertia * dt * (2.2 if heavy_mode else (1.4 if heavy else 1)))
			var step := omega * dt
			var subdivisions := maxi(1, ceili(absf(step) * length / 2.0))
			for i in subdivisions:
				var next := angle + step / subdivisions
				if sweep(angle, next): break
				angle = next
			trail.append(Vector2.RIGHT.rotated(angle) * length)
			if trail.size() > 14: trail.pop_front()
		if active and (elapsed > windup + 0.55 or (elapsed > windup and (angle-fighter.facing)*swing_direction > 2.0)):
			finish_attack()
	else:
		blade.scale = Vector2.ONE
		if extension != 0:
			extension = move_toward(extension,0,dt*150)
			position = fighter.forward()*extension
		if rebounding:
			angle += omega * dt
			omega *= exp(-9 * dt)
			if absf(omega) < 0.3: rebounding = false
		else:
			# Spring-damper return preserves momentum rather than snapping to rest.
			omega += (angle_difference(angle, fighter.facing + 0.55) * 65 - omega * 16) * dt
			angle += omega * dt
		if not trail.is_empty(): trail.pop_front()
	blade.rotation = angle
	blade.collision_layer = 16 if active and attack_phase() == "STRIKE" else 0
	queue_redraw()

func spear_step(dt: float) -> void:
	elapsed += dt
	var old_origin := global_position
	var old_angle := angle
	angle = rotate_toward(angle,fighter.facing,dt*4)
	var windup := windup_duration()
	if elapsed < windup:
		extension = lerpf(0,-22,smoothstep(0,1,elapsed/(windup*0.76)))
		thrust_speed = 0
	elif elapsed < windup+0.27:
		if not swing_sounded:
			fighter.arena.sound.play("swing",50)
			swing_sounded = true
		thrust_speed = 240
		extension = minf(43,extension+thrust_speed*dt)
	else:
		thrust_speed = 0
		extension = move_toward(extension,0,dt*85)
	position = fighter.forward()*extension
	if thrust_speed > 0:
		if sweep(old_angle,angle,old_origin):
			position = old_origin-fighter.global_position
			extension = position.dot(fighter.forward())
	if active and elapsed > windup+0.58:
		finish_attack()
		position = Vector2.ZERO
		extension = 0
		thrust_speed = 0

func sweep(old: float, next: float, previous_origin := Vector2.INF, reach := -1.0, previous_reach := -1.0) -> bool:
	var space := get_world_2d().direct_space_state
	if reach < 0: reach = length
	if previous_reach < 0: previous_reach = reach
	if previous_origin == Vector2.INF: previous_origin = global_position
	# Radial rays cover the entire blade; tip/intermediate sweeps cover its motion.
	for sample in range(6):
		var radius := lerpf(21, reach, sample / 5.0)
		var old_radius := lerpf(21,previous_reach,sample/5.0)
		var start := previous_origin + Vector2.RIGHT.rotated(old) * old_radius
		var end := global_position + Vector2.RIGHT.rotated(next) * radius
		if sample == 0:
			start = global_position + Vector2.RIGHT.rotated(next) * 21
			end = global_position + Vector2.RIGHT.rotated(next) * reach
		var query := PhysicsRayQueryParameters2D.create(start, end, 1 | 2 | 4 | 8 | 16)
		query.exclude = [fighter.get_rid(), fighter.shield.get_rid(), blade.get_rid()]
		query.collide_with_areas = true
		var result := space.intersect_ray(query)
		if result.is_empty(): continue
		var collider: Object = result.collider
		var contact_id := collider.get_instance_id()
		if collider.has_meta("fighter"): contact_id = collider.get_meta("fighter").get_instance_id()
		if hit.has(collider.get_instance_id()): continue
		hit[collider.get_instance_id()] = true
		var contact_velocity: Vector2 = Vector2.RIGHT.rotated(next).orthogonal()*omega*length + fighter.forward()*maxf(0,thrust_speed)
		var tangent: Vector2 = contact_velocity.normalized()
		var contact_radius: float = clampf(global_position.distance_to(result.position), 20, length)
		var target_velocity := Vector2.ZERO
		if collider is CharacterBody2D: target_velocity = collider.velocity
		elif collider is RigidBody2D: target_velocity = collider.linear_velocity
		elif collider.has_meta("fighter"): target_velocity = collider.get_meta("fighter").velocity
		var relative_speed := maxf(0, (Vector2.RIGHT.rotated(next).orthogonal()*omega*contact_radius + fighter.forward()*maxf(0,thrust_speed) + fighter.velocity - target_velocity).dot(tangent))
		var impact := clampf(mass * relative_speed * 0.025 * (1.4 if heavy else 1), 4, 75)
		if heavy_mode: impact = minf(100,impact*(1.6 if charged_heavy else 1.2))
		var blocked := false
		var sound_kind := "stone"
		if collider.has_meta("fighter"):
			sound_kind = "metal"
			var defender = collider.get_meta("fighter")
			hit[defender.get_instance_id()] = true
			var incidence := absf(tangent.dot(defender.forward()))
			var edge := clampf(absf((result.position - defender.shield.global_position).dot(defender.forward().orthogonal())) / 23, 0, 1)
			if defender.absorb_guard(impact, tangent, incidence, edge, heavy, fighter):
				fighter.arena.contact(result.position,result.normal,65)
				angle = old
				bounce(65)
				return true
			omega *= lerpf(0.65, 0.12, incidence * (1 - edge * 0.6))
			fighter.posture += impact * 0.16
			fighter.push_impulse(-tangent, impact * 1.7)
			blocked = incidence > 0.65 and edge < 0.75
		elif collider.has_meta("weapon"):
			sound_kind = "metal"
			var other = collider.get_meta("weapon")
			var ratio: float = mass / maxf(0.1, other.mass)
			other.omega *= clampf(0.3 / ratio, 0.1, 0.8)
			other.fighter.posture += impact * 0.3
			other.fighter.push_impulse(tangent, impact * 2)
			other.bounce(impact / ratio)
			omega *= clampf(ratio * 0.3, 0.1, 0.8)
			fighter.posture += impact * 0.22
			fighter.push_impulse(-tangent, impact * 2)
			blocked = true
		elif collider is CharacterBody2D:
			sound_kind = "flesh"
			collider.receive(impact * 0.65, clampf(relative_speed * mass * damage_coefficient, 6, 42) * ((1.9 if charged_heavy else 1.5) if heavy_mode else (1.35 if heavy else 1)), tangent)
			omega *= 0.72
			fighter.push_impulse(-tangent, impact * 0.65)
		elif collider is RigidBody2D:
			sound_kind = "wood"
			collider.apply_impulse(tangent * impact * 12, result.position - collider.global_position)
			omega *= 0.6
		else:
			blocked = true
			fighter.posture += impact * 0.22
			fighter.push_impulse(-tangent, impact * 2.2)
		fighter.arena.sound.play(sound_kind, impact)
		fighter.arena.contact(result.position, result.normal, impact)
		if blocked:
			angle = old
			bounce(impact)
			return true
	return false

func _draw() -> void:
	var direction := Vector2.RIGHT.rotated(angle)
	if wave_mode and active:
		var progress := clampf(elapsed/windup_duration(),0,1)
		if fighter.arena.debug:
			draw_arc(Vector2.ZERO,30,-PI/2,-PI/2+TAU*maxf(0.01,progress),36,Color("9ad9ff"),3,true)
		draw_line(direction*22,direction*length,Color(0.5,0.8,1,0.25+progress*0.5),10,true)
	if not fighter.enemy and (fighter.heavy_charge > 0 or (heavy_mode and active)):
		draw_overhead(direction)
		return
	if fighter.heavy_charge > 0:
		var progress := clampf(fighter.heavy_charge/0.65,0,1)
		if fighter.arena.debug:
			draw_arc(Vector2.ZERO,32,-PI/2,-PI/2+TAU*maxf(0.01,progress),40,Color("ffb768"),3,true)
		draw_circle(direction*length,3+progress*5,Color(1,0.68,0.3,0.5+progress*0.5))
	if not fighter.enemy and fighter.charge > 0:
		var progress := clampf(fighter.charge/0.32,0,1)
		if fighter.arena.debug:
			draw_arc(-position,29,-PI/2,-PI/2+TAU*maxf(0.01,progress),32,Color("e2ba72"),2,true)
	if fighter.enemy and active and attack_phase() == "WINDUP":
		var progress := clampf(elapsed/windup_duration(),0,1)
		var warning := Color(1,0.72,0.32,0.3+progress*0.6)
		if fighter.arena.debug:
			draw_arc(-position,30,-PI/2,-PI/2+TAU*maxf(0.01,progress),40,warning,3,true)
		draw_circle(direction*length,4+progress*3,warning)
		if fighter.enemy_kind == "spear":
			draw_line(direction*length,direction*(length+55),Color(1,0.72,0.32,0.22+progress*0.2),2,true)
	for i in range(1, trail.size()):
		draw_line(trail[i-1], trail[i], Color(0.8,0.85,0.7,float(i)/trail.size()*0.45), 3)
	if fighter.enemy and fighter.enemy_kind in ["brute","spear"]:
		draw_polearm()
		if fighter.arena.debug: draw_line(direction*20,direction*length,Color.RED,1.5,true)
		return
	draw_line(direction*16+Vector2(4,7),direction*length+Vector2(4,7),Color(0.015,0.02,0.03,0.3),7,true)
	draw_line(direction*16,direction*length,Color("18252e"),8,true)
	draw_line(direction * 16, direction * 30, Color("bfa171"), 6)
	draw_line(direction * 30, direction * length, Color("e4e9e5") if not heavy else Color("ffcc83"), 5)
	draw_line(direction*32-direction.orthogonal()*1.3,direction*(length-2)-direction.orthogonal()*1.3,Color("ffffff"),1.3,true)
	draw_line(direction*32+direction.orthogonal()*2,direction*length+direction.orthogonal()*2,Color("718b99"),1.3,true)
	if fighter.enemy_kind == "boss":
		var edge := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([direction*(length+5),direction*(length-35)+edge*15,direction*(length-42)-edge*11]),Color("e4c5a0") if not fighter.boss_enraged else Color("f69b74"))
		draw_line(direction*35,direction*(length-27),Color("a58f77"),9,true)
	draw_line(direction * 28 + direction.orthogonal()*9, direction*28-direction.orthogonal()*9, Color("8a9da8"), 4)
	if fighter.arena.debug:
		draw_line(direction * 20, direction * length, Color(1,0.2,0.3,0.8), 9)

func draw_polearm() -> void:
	draw_set_transform(Vector2.ZERO,angle)
	var shadow := Vector2(4,7).rotated(-angle)
	var socket := length-25
	draw_line(Vector2(16,0)+shadow,Vector2(length-5,0)+shadow,Color(0.01,0.02,0.03,0.32),9,true)
	draw_line(Vector2(16,0),Vector2(socket+8,0),Color("15212a"),9,true)
	draw_line(Vector2(16,0),Vector2(socket+8,0),Color("76664f"),5,true)
	draw_line(Vector2(18,-1.4),Vector2(socket+6,-1.4),Color("b0a084"),1.4,true)
	for x in range(19,37,5):
		draw_line(Vector2(x,-3),Vector2(x+2,3),Color("3b4143"),2,true)
	# A metal collar visibly sockets the head onto the continuous wooden shaft.
	draw_line(Vector2(socket-5,0),Vector2(socket+9,0),Color("25343e"),9,true)
	draw_line(Vector2(socket-4,-1),Vector2(socket+8,-1),Color("9ba9a9"),5,true)
	if fighter.enemy_kind == "brute":
		var head := PackedVector2Array([Vector2(length-22,-17),Vector2(length-5,-17),Vector2(length,-12),Vector2(length,12),Vector2(length-5,17),Vector2(length-22,17),Vector2(length-27,12),Vector2(length-27,-12)])
		var cast := PackedVector2Array()
		for point in head: cast.append(point+shadow)
		draw_colored_polygon(cast,Color(0.01,0.02,0.03,0.3))
		draw_colored_polygon(head,Color("6d7b81"))
		draw_colored_polygon(PackedVector2Array([head[0],head[1],Vector2(length-7,-11),Vector2(length-20,-11)]),Color("abb8b6"))
		draw_colored_polygon(PackedVector2Array([head[3],head[4],head[5],Vector2(length-20,10),Vector2(length-5,10)]),Color("3f515d"))
		draw_rect(Rect2(length-21,-11,15,22),Color("81908f"))
		draw_line(Vector2(length-12,-15),Vector2(length-12,15),Color("b6a17d"),4,true)
		draw_circle(Vector2(length-12,0),2.5,Color("26343d"))
		var outline := head.duplicate()
		outline.append(head[0])
		draw_polyline(outline,Color("1c2a33"),2,true)
	else:
		var leaf := PackedVector2Array([Vector2(length,0),Vector2(length-19,-7),Vector2(length-27,-3),Vector2(length-27,3),Vector2(length-19,7)])
		var cast := PackedVector2Array()
		for point in leaf: cast.append(point+shadow)
		draw_colored_polygon(cast,Color(0.01,0.02,0.03,0.3))
		draw_colored_polygon(leaf,Color("8399a3"))
		draw_colored_polygon(PackedVector2Array([leaf[0],leaf[1],leaf[2],Vector2(length-25,0)]),Color("d2dfdc"))
		draw_colored_polygon(PackedVector2Array([leaf[0],Vector2(length-25,0),leaf[3],leaf[4]]),Color("687b8e"))
		var outline := leaf.duplicate()
		outline.append(leaf[0])
		draw_polyline(outline,Color("1c2a33"),1.5,true)
		draw_line(Vector2(length-25,0),Vector2(length-2,0),Color("b7caca"),1,true)
	draw_set_transform(Vector2.ZERO)

func draw_overhead(direction: Vector2) -> void:
	var height := maxf(0,sin(overhead_pitch))
	var screen_up := Vector2.UP.rotated(fighter.arena.camera.rotation)
	var hand := direction*16 + screen_up*height*9
	var tip := direction*overhead_reach+screen_up*height*25
	var shadow_tip := direction*overhead_reach-screen_up*7
	draw_line(direction*16-screen_up*7,shadow_tip,Color(0,0,0,0.28-height*0.12),7+height*5,true)
	draw_circle(shadow_tip,4+height*6,Color(0,0,0,0.15))
	draw_line(hand,tip,Color("283844"),10+height*4,true)
	draw_line(hand,hand.lerp(tip,0.23),Color("bfa171"),7+height*2,true)
	draw_line(hand.lerp(tip,0.23),tip,Color("ffcd8b").lerp(Color("fff3d5"),height),5+height*3,true)
	var side := direction.orthogonal()
	var cross := hand.lerp(tip,0.23)
	draw_line(cross-side*(9+height*3),cross+side*(9+height*3),Color("d0b58b"),4,true)
	if active and attack_phase() == "STRIKE":
		draw_line(hand+screen_up*24,tip,Color(1,0.86,0.65,0.45),10,true)
	if fighter.heavy_charge > 0:
		var progress := clampf(fighter.heavy_charge/0.65,0,1)
		if fighter.arena.debug:
			draw_arc(Vector2.ZERO,32,-PI/2,-PI/2+TAU*maxf(0.01,progress),40,Color("ffb768"),3,true)
	if fighter.arena.debug:
		draw_line(direction*21,direction*overhead_reach,Color.RED,2,true)
