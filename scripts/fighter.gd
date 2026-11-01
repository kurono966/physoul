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
var awareness_enabled := false
var home_position := Vector2.ZERO
var alerted := false
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
	if critical_time > 0 or stun > 0 or roll > 0 or weapon.active or weapon.cooldown > 0 or not spend(40 if charged else 28): return
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
	if enemy or heavy_charge > 0 or hp <= 0 or stun > 0 or roll > 0 or kick_time > 0.3 or weapon.active or weapon.cooldown > 0 or critical_time > 0 or stamina < 20:
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
	return critical_time > 0 or charge > 0 or heavy_charge > 0 or weapon.active or weapon.cooldown > 0 or kick_time > 0.3

func start_kick() -> void:
	if heavy_charge > 0 or critical_time > 0 or kick_time > 0 or weapon.active or roll > 0 or not spend(22): return
	kick_time = 0.7
	kick_pending = true
	kick_facing = facing
	guard = false
	arena.sound.play("swing", 25)

func resolve_kick() -> void:
	var target = arena.player if enemy else arena.opponent
	var direction := Vector2.RIGHT.rotated(kick_facing)
	if global_position.distance_to(target.global_position) < 85 and direction.dot(global_position.direction_to(target.global_position)) > 0.65:
		target.receive(65, 3, direction)
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
	circle.radius = 36 if enemy_kind == "boss" else 19
	shape.shape = circle
	add_child(shape)
	weapon = Weapon.new()
	weapon.fighter = self
	if enemy:
		match enemy_kind:
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
	if critical_time <= 0 and roll <= 0 and kick_time <= 0.3 and not weapon.active and weapon.cooldown <= 0 and spend(30 if heavy else 18):
		guard = false
		weapon.begin(heavy)

func receive(impact: float, damage: float, direction: Vector2) -> void:
	if hp <= 0 or (roll > 0.13 and roll < 0.38):
		return
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
			guard = (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_action_pressed("pad_guard")) and critical_time <= 0 and stamina > 0 and not weapon.active and roll <= 0 and kick_time <= 0.3
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
		stamina = minf(100, stamina + dt * (13 if guard else 26))
	posture = maxf(0, posture - dt * (8 if guard else 15))
	var speed := move_speed
	if sprinting: speed *= 1.7
	if guard: speed *= 0.48
	if hp <= 0 or stun > 0: speed = 0
	if attack_movement_locked():
		drive_velocity = Vector2.ZERO
	else:
		drive_velocity = drive_velocity.move_toward(movement * speed, dt * 1100)
		if roll > 0: drive_velocity = roll_direction * 360
	velocity = drive_velocity + impulse_velocity + weapon.attack_velocity()
	move_and_slide()
	# Preserve collision response; input acceleration cannot erase an impact.
	for i in get_slide_collision_count():
		impulse_velocity = impulse_velocity.slide(get_slide_collision(i).get_normal())
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
	var color := Color("d17a65") if enemy else Color("72c8bd")
	if enemy and enemy_kind == "brute": color = Color("caa363")
	if enemy and enemy_kind == "spear": color = Color("aca1de")
	if enemy_kind == "boss":
		color = Color("db7758") if boss_enraged else Color("b4a28a")
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*1.9)
	if hp <= 0: color = Color("414751")
	for radius in [29,25,21]:
		draw_circle(Vector2(6,10),radius,Color(0.015,0.02,0.03,0.13))
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
	if stun > 0:
		draw_arc(Vector2.ZERO, 28, ai_clock * 5, ai_clock * 5 + 4, 24, Color("ffd477"), 3)
		if riposte_available and hp > 0:
			var diamond := PackedVector2Array([Vector2(0,-10),Vector2(10,0),Vector2(0,10),Vector2(-10,0),Vector2(0,-10)])
			draw_polyline(diamond,Color("ffd477"),2,true)
	if roll > 0:
		draw_arc(Vector2.ZERO, 25, 0, TAU, 32, Color("a1e8ee"), 2)
	if arena.debug:
		draw_arc(Vector2.ZERO, 48, facing - 0.8, facing + 0.8, 20, Color(0.5,0.8,1,0.5), 1)
