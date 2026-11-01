extends Camera2D

var arena: Node2D
var heading := -PI / 2
var locked := false
var shake := 0.0
@export var mouse_sensitivity := 0.0012
@export var stick_turn_speed := 2.1
var trigger_was_down := false
var left_trigger_was_down := false

func _ready() -> void:
	ignore_rotation = false
	position_smoothing_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("web") else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if OS.has_feature("web") and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if not locked:
			heading += event.relative.x * mouse_sensitivity
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				arena.player.charge = 0
				arena.player.heavy_charge = 0
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_TAB: locked = not locked
			KEY_F3: arena.debug = not arena.debug
			KEY_H: arena.controls.help_visible = not arena.controls.help_visible
			KEY_R: get_tree().reload_current_scene()
			KEY_N: arena.next_enemy()
			KEY_M: arena.call_deferred("regenerate_map")
			KEY_1: arena.select_enemy(0)
			KEY_2: arena.select_enemy(1)
			KEY_3: arena.select_enemy(2)
			KEY_4: arena.select_enemy(3)
	var pad_attack := event is InputEventJoypadButton and event.is_action("pad_attack")
	if pad_attack or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		if event.pressed:
			var player = arena.player
			if player.start_critical(): return
			if player.heavy_charge <= 0 and player.critical_time <= 0 and player.hp > 0 and player.stun <= 0 and player.roll <= 0 and player.kick_time <= 0.3 and not player.guard and not player.weapon.active and player.weapon.cooldown <= 0:
				player.charge = 0.001
		else:
			if arena.player.charge > 0:
				arena.player.attack(false)
			arena.player.charge = 0
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		locked = not locked
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_BACK: arena.controls.help_visible = not arena.controls.help_visible
		if event.button_index == JOY_BUTTON_DPAD_UP: arena.call_deferred("regenerate_map")
		if event.is_action("pad_lock"): locked = not locked
		if event.is_action("pad_restart"): get_tree().reload_current_scene()
		if event.is_action("pad_next"): arena.next_enemy()

func _physics_process(dt: float) -> void:
	var player = arena.player
	var left_trigger_down := Input.get_action_strength("pad_wave") > (0.15 if left_trigger_was_down else 0.4)
	if left_trigger_down and not left_trigger_was_down: player.start_wave()
	left_trigger_was_down = left_trigger_down
	var trigger_down := Input.get_action_strength("pad_heavy") > (0.15 if trigger_was_down else 0.4)
	if trigger_down and not trigger_was_down and not player.attack_movement_locked() and player.hp > 0 and player.stun <= 0 and player.roll <= 0 and not player.guard:
		player.heavy_charge = 0.001
	if player.heavy_charge > 0:
		if player.hp <= 0 or player.stun > 0 or player.guard or player.roll > 0:
			player.heavy_charge = 0
		elif not trigger_down:
			player.start_heavy(false)
		else:
			player.heavy_charge += dt
			if player.heavy_charge >= 0.65: player.start_heavy(true)
	trigger_was_down = trigger_down
	if not locked:
		heading += arena.controls.look()*stick_turn_speed*dt
	if player.charge > 0:
		if player.hp <= 0 or player.stun > 0 or player.roll > 0 or player.guard or player.kick_time > 0.3:
			player.charge = 0
		else:
			player.charge += dt
			if player.charge >= 0.32:
				player.attack(true)
				if player.weapon.active and player.weapon.thrust_attack:
					# The held animation already performed the windup.
					player.weapon.elapsed = player.weapon.windup_duration()
				player.charge = 0
	if arena.opponent.hp <= 0: locked = false
	if locked:
		heading = (arena.opponent.global_position - player.global_position).angle()
	if player.hp > 0 and player.stun <= 0 and player.critical_time <= 0:
		player.facing = rotate_toward(player.facing, heading, dt * (1.5 if player.weapon.active else 12))
	rotation = lerp_angle(rotation, player.facing + PI / 2, 1 - exp(-10 * dt))
	# Camera center lies ahead: player is 145 px below screen center.
	var center: Vector2 = player.global_position + Vector2.UP.rotated(rotation) * 145
	global_position = global_position.lerp(center, 1 - exp(-14 * dt))
	shake = maxf(0, shake - dt * 30)
	offset = Vector2(sin(arena.time * 130), cos(arena.time * 110)) * shake
