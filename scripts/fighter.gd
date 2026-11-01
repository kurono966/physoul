extends CharacterBody2D

const Weapon = preload("res://scripts/weapon.gd")
var arena: Node2D
var enemy := false
var enemy_kind := "warden"
var title := "WARDEN"
var max_hp := 100.0
var move_speed := 165.0
var has_shield := true
var boss_enraged := false
var boss_attack_count := 0
var sprint_requested := false
var sprinting := false
@export var max_flasks := 3
var flasks := 3
var healing_time := 0.0
var healing_pending := false
var healing_flash := 0.0
var wall_impact_cooldown := 0.0
var hop_time := 0.0
var hop_pause := 0.0
var hop_count := 0
var hop_side := 1.0
var hop_direction := Vector2.ZERO

func think_reptile(dt: float, toward: Vector2, distance: float) -> Vector2:
	guard = false
	if distance > 170:
		ai_state = "SKITTER / APPROACH"
		return toward*0.7
	if hop_time > 0:
		hop_time = maxf(0,hop_time-dt)
		ai_state = "SIDE HOP"
		if hop_time <= 0: hop_pause = 0.18
		return hop_direction
	if hop_pause > 0:
		hop_pause = maxf(0,hop_pause-dt)
		ai_state = "SETTLE"
		return Vector2.ZERO
	if hop_count >= 2 and stamina >= 22 and weapon.cooldown <= 0 and forward().dot(toward) > 0.85:
		weapon.begin_combo()
		if weapon.active:
			hop_count = 0
			return Vector2.ZERO
	hop_side *= -1
	hop_direction = (toward.orthogonal()*hop_side+toward*clampf((distance-120)/100,-0.4,0.3)).normalized()
	for attempt in 2:
		var clear := true
		for offset in [-18,0,18]:
			var origin: Vector2 = global_position+hop_direction.orthogonal()*offset
			if not weapon.path_segment_clear(origin,origin+hop_direction*90): clear = false
		if clear: break
		hop_direction = -hop_direction
		if attempt == 1: hop_direction = obstacle_movement(toward)
	hop_time = 0.28
	hop_count += 1
	ai_state = "SIDE HOP"
	return hop_direction

func start_heal() -> void:
	if enemy or hp <= 0 or hp >= max_hp or flasks <= 0 or stun > 0 or roll > 0 or guard or attack_movement_locked(): return
	flasks -= 1
	healing_time = 0.75
	healing_pending = true
	charge = 0
	sprinting = false
	sprint_requested = false
	drive_velocity = Vector2.ZERO
	arena.event_text = "DRINKING / HEALING FLASK"

func update_healing(dt: float) -> void:
	healing_flash = maxf(0,healing_flash-dt)
	if healing_time <= 0: return
	if hp <= 0 or stun > 0:
		healing_time = 0
		healing_pending = false
		return
	healing_time = maxf(0,healing_time-dt)
	if healing_pending and healing_time <= 0.35:
		healing_pending = false
		hp = minf(max_hp,hp+45)
		healing_flash = 0.5
		arena.sound.play("heal",45)
		arena.event_text = "FLASK / HP RESTORED"

func start_dash_attack() -> void:
	if not sprinting or hp <= 0 or stun > 0 or attack_movement_locked() or roll > 0 or not spend(28): return
	guard = false
	sprinting = false
	sprint_requested = false
	charge = 0
	weapon.begin(false)
	weapon.dash_mode = true
	weapon.heavy_step_direction = forward()
var awareness_enabled := false
var home_position := Vector2.ZERO
var alerted := false
var obstacle_reposition := 0.0
var obstacle_escape := Vector2.ZERO
var obstacle_side := 1.0

func avoid_blocked_attack(normal: Vector2) -> void:
	if not enemy: return
	obstacle_reposition = 0.9
	obstacle_escape = normal
	obstacle_side *= -1

func obstacle_movement(toward: Vector2) -> Vector2:
	var intended := (obstacle_escape*0.9+toward.orthogonal()*obstacle_side-toward*0.25).normalized()
	for direction in [intended,obstacle_escape,toward.orthogonal()*obstacle_side,-toward.orthogonal()*obstacle_side,-toward]:
		if direction.length() < 0.1: continue
		var clear := true
		for offset in [-18,0,18]:
			var origin: Vector2 = global_position+direction.orthogonal()*offset
			var query := PhysicsRayQueryParameters2D.create(origin,origin+direction*65,1|4)
			if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): clear = false
		if clear: return direction.normalized()*0.8
	return Vector2.ZERO
var facing := 0.0
var hp := 100.0
var stamina := 100.0
var posture := 0.0
var guard := false
var stun := 0.0
var roll := 0.0
var roll_direction := Vector2.ZERO
var recovery := 0.0
var charge := 0.0
var heavy_charge := 0.0

func start_wave() -> void:
	if attack_movement_locked() or critical_time > 0 or roll > 0 or guard or not spend(38): return
	weapon.begin(false)
	weapon.wave_mode = true
	weapon.heavy = true

func start_heavy(charged: bool) -> void:
	heavy_charge = 0
	if healing_time > 0 or critical_time > 0 or stun > 0 or roll > 0 or weapon.active or weapon.cooldown > 0 or not spend(40 if charged else 28): return
	guard = false
	weapon.begin(false)
	weapon.heavy_mode = true
	weapon.heavy = true
	weapon.charged_heavy = charged
	weapon.player_followup = charged
	if charged: weapon.elapsed = weapon.windup_duration()
var ai_clock := 0.0
var ai_state := "APPROACH"
var weapon: Node2D
var shield: StaticBody2D
var kick_time := 0.0
var impulse_velocity := Vector2.ZERO
var drive_velocity := Vector2.ZERO
var shield_deflection := 0.0
var kick_pending := false
var kick_facing := 0.0
var riposte_available := false
var critical_time := 0.0
var critical_hit := false
var critical_target: CharacterBody2D
@export var just_guard_duration := 0.18
var just_guard_window := 0.0
var just_guard_cooldown := 0.0
var just_guard_flash := 0.0
var guard_button_was_down := false

func update_guard_timing(pressed: bool, dt: float) -> void:
	just_guard_window = maxf(0,just_guard_window-dt)
	just_guard_cooldown = maxf(0,just_guard_cooldown-dt)
	just_guard_flash = maxf(0,just_guard_flash-dt)
	if pressed and not guard_button_was_down and guard and not enemy and just_guard_cooldown <= 0:
		just_guard_window = just_guard_duration
		just_guard_cooldown = 0.45
	if not guard: just_guard_window = 0
	guard_button_was_down = pressed

func can_critical() -> bool:
	if enemy or healing_time > 0 or heavy_charge > 0 or hp <= 0 or stun > 0 or roll > 0 or kick_time > 0.3 or weapon.active or weapon.cooldown > 0 or critical_time > 0 or stamina < 20:
		return false
	var target = arena.opponent
	if target.hp <= 0 or target.stun <= 0 or not target.riposte_available or global_position.distance_to(target.global_position) > 65:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position,target.global_position,1|4)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func start_critical() -> bool:
	if not can_critical(): return false
	spend(20)
	charge = 0
	guard = false
	critical_target = arena.opponent
	critical_target.riposte_available = false
	critical_target.stun = maxf(critical_target.stun,1.1)
	critical_target.impulse_velocity = Vector2.ZERO
	impulse_velocity = Vector2.ZERO
	drive_velocity = Vector2.ZERO
	facing = global_position.direction_to(critical_target.global_position).angle()
	critical_time = 0.9
	critical_hit = false
	arena.event_text = "CRITICAL STRIKE"
	return true

func update_critical(dt: float) -> void:
	if critical_time <= 0: return
	if hp <= 0 or stun > 0 or not is_instance_valid(critical_target) or critical_target.hp <= 0:
		critical_time = 0
		return
	critical_time = maxf(0,critical_time-dt)
	if critical_time <= 0.55 and not critical_hit:
		critical_hit = true
		if global_position.distance_to(critical_target.global_position) <= 80:
			critical_target.receive(0,100,forward())
			arena.sound.play("heavy",75)
			arena.contact(critical_target.global_position,-forward(),75)
	if critical_time <= 0: weapon.cooldown = 0.35

func attack_movement_locked() -> bool:
	return healing_time > 0 or critical_time > 0 or charge > 0 or heavy_charge > 0 or weapon.active or (weapon.cooldown > 0 and enemy_kind not in ["wolf","reptile"]) or kick_time > 0.3

func start_kick() -> void:
	if healing_time > 0 or heavy_charge > 0 or critical_time > 0 or kick_time > 0 or weapon.active or roll > 0 or not spend(22): return
	kick_time = 0.7
	kick_pending = true
	kick_facing = facing
	guard = false
	arena.sound.play("swing", 25)

func resolve_kick() -> void:
	var direction := Vector2.RIGHT.rotated(kick_facing)
	var query := PhysicsRayQueryParameters2D.create(global_position+direction*20,global_position+direction*85,1|2|4)
	query.exclude = [get_rid(),shield.get_rid()]
	query.hit_from_inside = true
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty(): return
	var target: Object = result.collider
	if target is RigidBody2D and target.has_method("launch"):
		target.launch(direction)
		arena.sound.play("kick",65)
		arena.contact(result.position,direction,55)
	elif target is CharacterBody2D and target.hp > 0:
		target.receive(65,3,direction,result.position)
		arena.sound.play("kick", 65)
		arena.contact(target.global_position, direction, 65)

func push_impulse(direction: Vector2, strength: float) -> void:
	if enemy_kind == "boss": strength *= 0.35
	impulse_velocity = (impulse_velocity + direction * strength).limit_length(330)

func break_guard() -> void:
	if stun <= 0: arena.sound.play("break", 75)
	posture = 0
	stun = 1.6
	riposte_available = enemy
	recovery = 1.8
	guard = false
	shield.collision_layer = 0
	weapon.cancel()
	arena.event_text = "WARDEN GUARD BROKEN" if enemy else "YOUR GUARD BROKEN"

func absorb_guard(impact: float, direction: Vector2, incidence: float, edge: float, heavy: bool, attacker: CharacterBody2D = null) -> bool:
	if guard and just_guard_window > 0 and hp > 0 and stun <= 0 and stamina >= 4:
		just_guard_window = 0
		just_guard_flash = 0.3
		stamina -= 4
		posture = maxf(0,posture-8)
		recovery = 0.3
		shield_deflection = 0.12
		if is_instance_valid(attacker):
			attacker.receive(60,0,-direction)
		arena.event_text = "JUST GUARD"
		arena.sound.play("just_guard",75)
		return true
	# Full stamina withstands about three light contacts or two heavy contacts.
	var cost := (53.0 if heavy else 36.0) * lerpf(0.85, 1.15, incidence) * (1 - edge * 0.12)
	stamina = maxf(0, stamina - cost)
	receive(impact * (1 - edge * 0.35), impact * 0.025, direction)
	recovery = 1.6
	shield_deflection = clampf(direction.dot(forward().orthogonal()) * impact * 0.009, -0.5, 0.5)
	if stamina <= 0 and hp > 0:
		break_guard()
	return false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 7
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 36 if enemy_kind == "boss" else (16 if enemy_kind == "wolf" else 19)
	shape.shape = circle
	add_child(shape)
	weapon = Weapon.new()
	weapon.fighter = self
	if enemy:
		match enemy_kind:
			"reptile":
				title = "JADE SKITTER"
				max_hp = 80
				move_speed = 330
				has_shield = false
				weapon.mass = 2.0
				weapon.length = 50
				weapon.damage_coefficient = 0.024
			"wolf":
				title = "ASH FANG"
				max_hp = 65
				move_speed = 240
				has_shield = false
				weapon.mass = 2.2
				weapon.length = 45
				weapon.damage_coefficient = 0.025
			"boss":
				title = "THE HOLLOW REGENT"
				max_hp = 650
				move_speed = 110
				has_shield = false
				weapon.mass = 9
				weapon.length = 150
				weapon.torque = 1500000
				weapon.max_angular_speed = 14
				weapon.damage_coefficient = 0.04
			"brute":
				title = "IRON MAUL"
				max_hp = 160
				move_speed = 115
				has_shield = false
				weapon.mass = 6.5
				weapon.length = 95
				weapon.torque = 600000
				weapon.max_angular_speed = 18
				weapon.damage_coefficient = 0.045
			"spear":
				title = "NEEDLE"
				max_hp = 75
				move_speed = 195
				has_shield = false
				weapon.mass = 1.8
				weapon.length = 115
				weapon.max_angular_speed = 16
				weapon.damage_coefficient = 0.055
		hp = max_hp
	add_child(weapon)
	shield = StaticBody2D.new()
	shield.collision_layer = 8
	shield.collision_mask = 0
	shield.set_meta("fighter", self)
	var shield_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 46)
	shield_shape.shape = rect
	shield.add_child(shield_shape)
	add_child(shield)

func forward() -> Vector2:
	return Vector2.RIGHT.rotated(facing)

func spend(amount: float) -> bool:
	if stamina < amount or hp <= 0 or stun > 0:
		return false
	stamina -= amount
	recovery = 0.85
	return true

func attack(heavy: bool) -> void:
	if healing_time <= 0 and critical_time <= 0 and roll <= 0 and kick_time <= 0.3 and not weapon.active and weapon.cooldown <= 0 and spend(30 if heavy else 18):
		guard = false
		weapon.begin(heavy)

func receive(impact: float, damage: float, direction: Vector2, contact_point := Vector2.INF) -> void:
	if hp <= 0 or (roll > 0.13 and roll < 0.38):
		return
	if damage > 0:
		var point := contact_point if contact_point != Vector2.INF else global_position-direction.normalized()*16
		arena.damage_effects.burst(self,point,direction,minf(hp,damage),hp <= damage)
	if damage > 0:
		healing_time = 0
		healing_pending = false
	hp = maxf(0, hp - damage)
	if enemy_kind == "boss" and hp > 0 and hp <= max_hp*0.5 and not boss_enraged:
		boss_enraged = true
		move_speed = 145
		weapon.cancel()
		stun = maxf(stun,0.7)
		riposte_available = false
		arena.event_text = "THE REGENT / UNBOUND"
	posture += impact * (1.2 if velocity.length() > 130 else 1.0)
	push_impulse(direction, minf(impact * 4.5, 250))
	recovery = 0.8
	if posture >= 100:
		break_guard()
	if hp <= 0:
		arena.sound.play("death", 70)
		make_corpse()
		arena.event_text = "VICTORY — R: restart" if enemy else "YOU DIED — R: restart"

func make_corpse() -> void:
	healing_time = 0
	healing_pending = false
	collision_layer = 0
	collision_mask = 0
	shield.collision_layer = 0
	weapon.cancel()
	weapon.blade.collision_layer = 0
	guard = false
	riposte_available = false
	charge = 0
	heavy_charge = 0
	critical_time = 0
	kick_time = 0
	kick_pending = false
	roll = 0
	drive_velocity = Vector2.ZERO
	impulse_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	sprint_requested = false
	sprinting = false

func _physics_process(dt: float) -> void:
	if hp <= 0:
		make_corpse()
		queue_redraw()
		return
	stun = maxf(0, stun - dt)
	if stun <= 0: riposte_available = false
	update_critical(dt)
	update_healing(dt)
	wall_impact_cooldown = maxf(0,wall_impact_cooldown-dt)
	recovery = maxf(0, recovery - dt)
	roll = maxf(0, roll - dt)
	kick_time = maxf(0, kick_time - dt)
	if kick_pending:
		if hp <= 0 or stun > 0:
			kick_pending = false
			kick_time = 0
		elif kick_time <= 0.56:
			kick_pending = false
			resolve_kick()
	shield_deflection = move_toward(shield_deflection, 0, dt * 2.5)
	ai_clock += dt
	var movement := Vector2.ZERO
	guard = false
	if hp > 0 and stun <= 0:
		if enemy:
			movement = think(dt)
		else:
			var axis := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
			movement = (axis.normalized()+arena.controls.movement()).limit_length(1).rotated(arena.camera.rotation)
			if Input.is_action_just_pressed("pad_sprint"): sprint_requested = not sprint_requested
			guard = (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_action_pressed("pad_guard")) and healing_time <= 0 and critical_time <= 0 and stamina > 0 and not weapon.active and roll <= 0 and kick_time <= 0.3
			if (Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_action_just_pressed("pad_roll")) and not attack_movement_locked() and roll <= 0 and recovery <= 0.3 and spend(25):
				roll = 0.46
				arena.sound.play("roll", 35)
				roll_direction = movement if movement.length() > 0 else forward()
			if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_action_just_pressed("pad_kick"): start_kick()
	update_guard_timing((Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_action_pressed("pad_guard")) if not enemy else guard,dt)
	if movement.length() < 0.15 or guard or attack_movement_locked() or roll > 0 or stun > 0:
		sprint_requested = false
	sprinting = not enemy and sprint_requested and stamina > 0
	if sprinting:
		stamina = maxf(0,stamina-18*dt)
		recovery = 0.65
		if stamina <= 0:
			sprinting = false
			sprint_requested = false
	if recovery <= 0 and not weapon.active and roll <= 0:
		stamina = minf(100, stamina + dt * (19.5 if guard else 39.0))
	posture = maxf(0, posture - dt * (8 if guard else 15))
	var speed := move_speed
	if sprinting: speed *= 2.55
	if guard: speed *= 0.48
	if hp <= 0 or stun > 0: speed = 0
	if attack_movement_locked():
		drive_velocity = Vector2.ZERO
	else:
		drive_velocity = drive_velocity.move_toward(movement * speed, dt * 1100)
		if roll > 0: drive_velocity = roll_direction * 360
	velocity = drive_velocity + impulse_velocity + weapon.attack_velocity()
	var incoming_velocity := velocity
	var wall_crash_normal := Vector2.ZERO
	var wall_crash_speed := 0.0
	move_and_slide()
	# Preserve collision response; input acceleration cannot erase an impact.
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider()
		var normal := collision.get_normal()
		if body is StaticBody2D and body.collision_layer & 1:
			var speed_into_wall := -impulse_velocity.dot(normal)
			if enemy_kind in ["wolf","reptile"] and weapon.active and weapon.attack_phase() == "STRIKE": speed_into_wall = maxf(speed_into_wall,-incoming_velocity.dot(normal))
			if speed_into_wall > wall_crash_speed:
				wall_crash_speed = speed_into_wall
				wall_crash_normal = normal
		impulse_velocity = impulse_velocity.slide(normal)
	if wall_crash_speed > 140 and wall_impact_cooldown <= 0 and hp > 0:
		wall_impact_cooldown = 0.8
		receive(100 if enemy_kind in ["wolf","reptile"] else 50,5,wall_crash_normal)
		weapon.cancel()
		stun = maxf(stun,0.65)
		arena.sound.play("stone",70)
		arena.contact(global_position-wall_crash_normal*18,wall_crash_normal,65)
		arena.event_text = "WALL IMPACT"
	impulse_velocity *= exp(-6 * dt)
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_collider() is RigidBody2D:
			collision.get_collider().apply_central_impulse(-collision.get_normal() * 8)
	shield.position = forward() * (30 - absf(shield_deflection) * 12)
	shield.rotation = facing + shield_deflection
	shield.collision_layer = 8 if guard and hp > 0 else 0
	queue_redraw()

func think(dt: float) -> Vector2:
	var target = arena.player
	if target.hp <= 0:
		ai_state = "WAIT"
		return Vector2.ZERO
	var delta: Vector2 = target.global_position - global_position
	if weapon.active:
		ai_state = weapon.attack_phase()+" / %d" % (weapon.combo_index+1)
		# Commit aim before the strike: a late sidestep can evade the attack.
		if weapon.elapsed < weapon.windup_duration()-0.25:
			facing = rotate_toward(facing,delta.angle(),dt*1.5)
		guard = false
		return Vector2.ZERO
	if obstacle_reposition > 0:
		facing = rotate_toward(facing,delta.angle(),dt*3.3)
		guard = false
		ai_state = "REPOSITION / CLEAR WEAPON"
		if not attack_movement_locked(): obstacle_reposition = maxf(0,obstacle_reposition-dt)
		return obstacle_movement(delta.normalized())
	if awareness_enabled:
		var sight := PhysicsRayQueryParameters2D.create(global_position,target.global_position,1)
		var visible := get_world_2d().direct_space_state.intersect_ray(sight).is_empty()
		if delta.length() > 850: alerted = false
		if not alerted and delta.length() <= 520 and visible: alerted = true
		if not alerted or not visible:
			guard = false
			ai_state = "IDLE" if not alerted else "RETURN"
			return global_position.direction_to(home_position)*0.5 if global_position.distance_to(home_position) > 12 else Vector2.ZERO
	facing = rotate_toward(facing, delta.angle(), dt * (1.1 if weapon.active else 3.3))
	var distance := delta.length()
	var toward := delta.normalized()
	if enemy_kind == "reptile": return think_reptile(dt,toward,distance)
	if enemy_kind == "wolf":
		guard = false
		if stamina < 22 or posture > 65:
			ai_state = "PROWL / RECOVER"
			return (-toward+toward.orthogonal()*sin(ai_clock*2))*0.8
		if distance > 160:
			ai_state = "CHASE"
			return (toward+toward.orthogonal()*sin(ai_clock*2.5)*0.25).normalized()
		if distance < 65:
			ai_state = "DISENGAGE"
			return (-toward+toward.orthogonal()*0.5).normalized()
		if weapon.cooldown <= 0 and forward().dot(toward) > 0.9:
			weapon.begin_combo()
		if weapon.active: return Vector2.ZERO
		ai_state = "PROWL / FLANK"
		return toward.orthogonal()*(1 if sin(ai_clock*0.8) >= 0 else -1)*0.9
	if enemy_kind == "boss" and distance > 180 and distance < 360 and boss_attack_count%2 == 0 and weapon.cooldown <= 0 and stamina >= 38 and forward().dot(toward) > 0.75 and weapon.target_in_reach_at(360):
		spend(38)
		weapon.begin(false)
		weapon.wave_mode = true
		weapon.heavy = true
		boss_attack_count += 1
		ai_state = "WAVE WINDUP"
		return Vector2.ZERO
	guard = has_shield and not weapon.active and stamina > 15 and (target.weapon.active or sin(ai_clock * 1.8) > 0.15)
	if stamina < 25 or posture > 70:
		ai_state = "RECOVER"
		return -toward * 0.7
	var preferred: float = weapon.engagement_distance()
	if distance > preferred:
		ai_state = "APPROACH"
		return toward
	if distance < (100 if enemy_kind == "spear" else 64):
		ai_state = "RETREAT"
		return -toward
	if not weapon.active and weapon.cooldown <= 0 and weapon.target_in_reach() and forward().dot(toward) > 0.65:
		weapon.begin_combo()
	ai_state = "WINDUP" if weapon.active else "CIRCLE / GUARD"
	return toward.orthogonal() * sin(ai_clock * 0.7) * 0.55

func _draw() -> void:
	if enemy_kind == "reptile":
		draw_reptile()
		return
	if enemy_kind == "wolf":
		draw_wolf()
		return
	var color := Color("d17a65") if enemy else Color("72c8bd")
	if enemy and enemy_kind == "brute": color = Color("caa363")
	if enemy and enemy_kind == "spear": color = Color("aca1de")
	if enemy_kind == "boss":
		color = Color("db7758") if boss_enraged else Color("b4a28a")
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*1.9)
	if hp <= 0: color = Color("414751")
	for radius in [29,25,21]:
		draw_circle(Vector2(6,10),radius,Color(0.015,0.02,0.03,0.13))
	var lean: float = weapon.dash_lean() if not enemy else 0
	if lean > 0:
		for offset in [-12,12]:
			draw_line(-forward()*38+forward().orthogonal()*offset,-forward()*22+forward().orthogonal()*offset,Color(0.6,0.85,0.8,lean*0.35),2,true)
		draw_set_transform(forward()*lean*14)
	draw_circle(Vector2.ZERO,21,Color("111b23"))
	draw_circle(Vector2.ZERO, 19, color.darkened(0.45))
	draw_arc(Vector2.ZERO,19,-2.9,-0.4,24,color.lightened(0.12),2,true)
	draw_arc(Vector2.ZERO,19,0.2,2.8,24,color.darkened(0.28),2,true)
	var f := forward()
	var side := f.orthogonal()
	# Geometric shoulders, armored torso and visor maintain a true overhead view.
	draw_line(-side * 20, side * 20, color.darkened(0.3), 13, true)
	draw_line(-side * 20 + f * 2, -side * 14 + f * 2, color, 3, true)
	draw_line(side * 14 + f * 2, side * 20 + f * 2, color, 3, true)
	if enemy and enemy_kind == "brute":
		draw_line(-side*25-f*4,side*25-f*4,color,7,true)
	if enemy_kind == "boss":
		for sign_value in [-1,1]:
			var s: Vector2 = side*sign_value
			draw_colored_polygon(PackedVector2Array([s*16+f*9,s*30+f*5,s*27-f*12,s*15-f*15]),color.darkened(0.3))
			draw_line(s*18+f*8,s*29+f*5,color.lightened(0.3),2,true)
			draw_line(f*16+s*6,f*26+s*10,Color("e9d4a4"),3,true)
	if enemy and enemy_kind == "spear":
		draw_colored_polygon(PackedVector2Array([-f*27,-f*12+side*13,-f*12-side*13]),color.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([f*15, f*5+side*12,-f*14+side*9,-f*14-side*9,f*5-side*12]),color.darkened(0.16))
	var light := Vector2(-0.6,-0.8)
	var left_lit := clampf(side.dot(light)*0.5+0.5,0,1)
	draw_colored_polygon(PackedVector2Array([f*15,f*5+side*12,-f*14+side*9,-f*12]),color.darkened(0.45).lerp(color.lightened(0.12),left_lit))
	draw_colored_polygon(PackedVector2Array([f*15,-f*12,-f*14-side*9,f*5-side*12]),color.darkened(0.45).lerp(color.lightened(0.12),1-left_lit))
	draw_line(f*10,-f*10,color.lightened(0.2),1.5,true)
	draw_circle(f*7+Vector2(2,3),10,Color(0,0,0,0.25))
	draw_circle(f * 7, 9, Color("26333e"))
	draw_arc(f*7,8,-2.9,-0.4,16,color.lightened(0.28),2,true)
	draw_line(f*7-side*6,f*7+side*6,Color("4d6570"),2,true)
	draw_line(f * 13 - side * 6, f * 13 + side * 6, Color("f3e1b8"), 3, true)
	if not enemy and weapon.active and weapon.is_player_slash():
		draw_line(side*14,Vector2.RIGHT.rotated(weapon.angle)*22,color.lightened(0.1),7,true)
	if lean > 0:
		draw_line(side*14-f*2,Vector2.RIGHT.rotated(weapon.angle)*22, color.lightened(0.1),7,true)
		draw_set_transform(Vector2.ZERO)
	draw_line(-f * 10-side*8,-f*21-side*8,color.darkened(0.2),7,true)
	if kick_time <= 0.3:
		draw_line(-f*10+side*8,-f*21+side*8,color.darkened(0.2),7,true)
	elif hp > 0:
		var age := 0.7 - kick_time
		var extension := clampf(age / 0.14, 0, 1) if age < 0.14 else clampf(1-(age-0.14)/0.26,0,1)
		var k := Vector2.RIGHT.rotated(kick_facing)
		var hip := k.orthogonal()*8-k*8
		var boot := hip + k * lerpf(4, 72, extension)
		draw_line(hip, boot, Color("26333e"), 11, true)
		draw_line(hip, boot, color, 5, true)
		draw_line(boot-k*7,boot+k*4,Color("f3e1b8"),12,true)
		if extension > 0.45:
			draw_arc(Vector2.ZERO, boot.length()+5, kick_facing-0.28,kick_facing+0.28,16,Color(0.95,0.83,0.57,extension*0.75),3,true)
			for offset in [-13,13]:
				draw_line(k*24+k.orthogonal()*offset,k*(40+extension*18)+k.orthogonal()*offset,Color(0.95,0.83,0.57,extension*0.4),2,true)
	if guard:
		var shield_side := Vector2.UP.rotated(shield.rotation)
		var shield_color := Color("b7ffff") if just_guard_window > 0 or just_guard_flash > 0 else Color("e7d6a2").lerp(Color("e66a51"), 1-stamina/100)
		draw_line(shield.position+Vector2(4,6)+shield_side*23,shield.position+Vector2(4,6)-shield_side*23,Color(0,0,0,0.28),11,true)
		draw_line(shield.position+shield_side*25,shield.position-shield_side*25,Color("18252e"),12,true)
		draw_line(shield.position + shield_side * 23, shield.position - shield_side * 23, shield_color, 7)
		draw_line(shield.position-forward()*2+shield_side*21,shield.position-forward()*2-shield_side*21,shield_color.lightened(0.25),2,true)
	if just_guard_flash > 0:
		draw_arc(Vector2.ZERO,32+(0.3-just_guard_flash)*90,facing-1.2,facing+1.2,32,Color(0.7,1,1,just_guard_flash/0.3),3,true)
	if healing_time > 0:
		var hand := f*13+side*13
		draw_line(side*15,hand,color.lightened(0.1),6,true)
		draw_circle(hand,5,Color("91dcc6"))
		draw_line(hand-f*5,hand-f*8,Color("e5d4ae"),4,true)
	if healing_flash > 0:
		draw_arc(Vector2.ZERO,25+(0.5-healing_flash)*35,0,TAU,40,Color(0.5,1,0.8,healing_flash),2,true)
	if stun > 0:
		draw_arc(Vector2.ZERO, 28, ai_clock * 5, ai_clock * 5 + 4, 24, Color("ffd477"), 3)
		if riposte_available and hp > 0:
			var diamond := PackedVector2Array([Vector2(0,-10),Vector2(10,0),Vector2(0,10),Vector2(-10,0),Vector2(0,-10)])
			draw_polyline(diamond,Color("ffd477"),2,true)
	if roll > 0:
		draw_arc(Vector2.ZERO, 25, 0, TAU, 32, Color("a1e8ee"), 2)
	if arena.debug:
		draw_arc(Vector2.ZERO, 48, facing - 0.8, facing + 0.8, 20, Color(0.5,0.8,1,0.5), 1)

func draw_wolf() -> void:
	var color := Color("9faeb6") if hp > 0 else Color("414751")
	var f := forward()
	var side := f.orthogonal()
	var preparing: bool = weapon.active and weapon.attack_phase() == "WINDUP"
	var lunging: bool = weapon.active and weapon.attack_phase() == "STRIKE"
	var crouch := 0.8 if preparing else 1.0
	var gait := sin(ai_clock*23)*6 if velocity.length() > 25 and hp > 0 else 0.0
	draw_circle(Vector2(4,8),22,Color(0.01,0.02,0.03,0.3))
	for sign_value in [-1,1]:
		var s: Vector2 = side*sign_value
		draw_line(-f*12+s*9,-f*(21+gait*sign_value)+s*16,color.darkened(0.3),6,true)
		draw_line(f*11+s*9,f*(17-gait*sign_value)+s*17,color.darkened(0.15),5,true)
	var tail := PackedVector2Array([-f*14-side*5,-f*36+side*(sin(ai_clock*4)*6),-f*28+side*8,-f*14+side*6])
	draw_colored_polygon(tail,color.darkened(0.35))
	var body := PackedVector2Array([-f*22*crouch,-f*14*crouch-side*10,f*12*crouch-side*14,f*21*crouch,f*12*crouch+side*14,-f*14*crouch+side*10])
	draw_colored_polygon(body,color.darkened(0.27))
	draw_colored_polygon(PackedVector2Array([-f*19,-f*9-side*7,f*14-side*10,f*17,f*3]),color)
	draw_line(-f*16,f*14,color.lightened(0.2),2,true)
	var head := f*(21 if not lunging else 27)*crouch
	draw_colored_polygon(PackedVector2Array([head+f*15,head+f*4-side*8,head-f*8-side*11,head-f*10+side*11,head+f*4+side*8]),color.lightened(0.1))
	for sign_value in [-1,1]:
		var s: Vector2 = side*sign_value
		draw_colored_polygon(PackedVector2Array([head-f*5+s*5,head-f*15+s*14,head+f*3+s*10]),color.darkened(0.3))
		draw_line(head+f*4+s*4,head+f*6+s*7,Color("ffca85") if hp > 0 else Color("414751"),2,true)
	draw_circle(head+f*14,3,Color("1b2832"))
	if preparing or lunging:
		draw_line(head+f*8-side*5,head+f*13,Color("19252e"),3,true)
		draw_line(head+f*8+side*5,head+f*13,Color("19252e"),3,true)
	if stun > 0:
		draw_arc(Vector2.ZERO,30,ai_clock*5,ai_clock*5+4,24,Color("ffd477"),3,true)
		if riposte_available: draw_circle(-f*5,4,Color("ffd477"))

func draw_reptile() -> void:
	var f := forward()
	var side := f.orthogonal()
	var color := Color("80aa78") if hp > 0 else Color("424c47")
	draw_circle(Vector2(5,9),25,Color(0.01,0.02,0.03,0.3))
	var lift := sin(PI*clampf(hop_time/0.28,0,1))*6 if hp > 0 and stun <= 0 else 0.0
	draw_set_transform(Vector2.UP.rotated(arena.camera.rotation)*lift)
	var tail: Vector2 = -f*44+side*sin(ai_clock*9)*12
	draw_colored_polygon(PackedVector2Array([-f*10-side*9,-f*26-side*7,tail,-f*27+side*8,-f*10+side*9]),color.darkened(0.35))
	for sign_value in [-1,1]:
		var s: Vector2 = side*sign_value
		for hip in [-10,11]:
			var knee: Vector2 = f*hip+s*22
			var toe: Vector2 = f*(hip-9)+s*30
			draw_line(f*hip+s*8,knee,color.darkened(0.15),6,true)
			draw_line(knee,toe,color,4,true)
			draw_line(toe-f*3,toe+f*3,Color("d8d9ae"),2,true)
	draw_colored_polygon(PackedVector2Array([-f*22,-f*12-side*14,f*14-side*15,f*24,f*14+side*15,-f*12+side*14]),color.darkened(0.2))
	for point in [-12,-2,8]:
		var center: Vector2 = f*point
		draw_colored_polygon(PackedVector2Array([center+f*6,center+side*5,center-f*6,center-side*5]),color.lightened(0.16))
	var head := f*(23 if not weapon.active else 28)
	draw_colored_polygon(PackedVector2Array([head+f*15-side*5,head-side*13,head-f*8,head+side*13,head+f*15+side*5]),color.lightened(0.1))
	draw_line(head+f*10-side*6,head+f*10+side*6,Color("263c32"),2,true)
	for sign_value in [-1,1]:
		draw_circle(head+side*9*sign_value,3,Color("ecd27e") if hp > 0 else color)
		draw_line(head+side*9*sign_value-f*2,head+side*9*sign_value+f*2,Color("1a2926"),1.5,true)
	draw_set_transform(Vector2.ZERO)
	if stun > 0:
		draw_arc(Vector2.ZERO,33,ai_clock*5,ai_clock*5+4,24,Color("ffd477"),3,true)
		if riposte_available: draw_circle(Vector2.ZERO,4,Color("ffd477"))
