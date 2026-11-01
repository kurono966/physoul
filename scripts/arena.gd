extends Node2D

const Fighter = preload("res://scripts/fighter.gd")
const View = preload("res://scripts/view.gd")
const Hud = preload("res://scripts/hud.gd")
const Sound = preload("res://scripts/sound.gd")
const PropVisual = preload("res://scripts/prop_visual.gd")
const Controls = preload("res://scripts/controls.gd")
const MapGenerator = preload("res://scripts/map_generator.gd")
const DungeonGenerator = preload("res://scripts/dungeon_generator.gd")
@export var random_map := true
@export var map_seed := -1
@export var boss_stage := false
var arrival_hp := 100.0
var dungeon: Dictionary = {}
var current_room := -1
var seals := 0
var switching_stage := false

func exploring() -> bool:
	return random_map and not boss_stage

func change_stage(to_boss: bool, new_seed := -1, preserve_hp := false) -> void:
	if switching_stage: return
	switching_stage = true
	var replacement = load("res://arena.tscn").instantiate()
	replacement.map_seed = map_seed if new_seed < 0 else new_seed
	replacement.random_map = random_map if new_seed < 0 else true
	replacement.boss_stage = to_boss
	replacement.arrival_hp = player.hp if preserve_hp else 100.0
	get_tree().root.add_child(replacement)
	get_tree().current_scene = replacement
	queue_free()

func restart_stage() -> void:
	change_stage(boss_stage)

func interact() -> void:
	if player.hp <= 0 or player.attack_movement_locked(): return
	if boss_stage and opponent.hp <= 0:
		regenerate_map()
		return
	if not exploring() or current_room < 0: return
	var room: Dictionary = dungeon.rooms[current_room]
	if player.position.distance_to(room.center) > 100: return
	if room.kind == "gate":
		if seals >= 3: change_stage(true,-1,true)
		else: event_text = "GATE SEALED / DEFEAT 3 GUARDIANS (%d/3)" % seals
	elif room.kind == "shrine" and not room.used:
		room.used = true
		player.hp = minf(100,player.hp+50)
		sound.play("just_guard",55)
		event_text = "SHRINE / HP RESTORED"

func update_exploration() -> void:
	if opponent.hp <= 0 and current_room >= 0:
		var active: Dictionary = dungeon.rooms[current_room]
		if active.kind == "battle" and not active.cleared:
			active.cleared = true
			active.hp = 0.0
			seals += 1
			event_text = "GUARDIAN DEFEATED / SEALS %d/3" % seals
	if player.critical_time > 0: return
	for i in dungeon.rooms.size():
		var room: Dictionary = dungeon.rooms[i]
		if not room.rect.grow(-5).has_point(player.position) or i == current_room: continue
		if current_room >= 0 and dungeon.rooms[current_room].kind == "battle" and not dungeon.rooms[current_room].cleared:
			dungeon.rooms[current_room].hp = opponent.hp
		current_room = i
		room.visited = true
		if room.kind == "battle" and not room.cleared:
			select_enemy(room.enemy)
			opponent.position = room.center+Vector2(0,-60)
			if room.hp >= 0: opponent.hp = room.hp
			event_text = "GUARDIAN / " + opponent.title
		else:
			opponent.hp = 0
			opponent.weapon.cancel()
			opponent.position = Vector2(-100000,-100000)
			opponent.hide()
			opponent.set_physics_process(false)
			event_text = {"start":"EXPLORE / FIND 3 SEALS AND THE BOSS GATE","gate":"BOSS GATE / E OR Y TO ENTER","shrine":"SHRINE / E OR Y TO RESTORE HP"}.get(room.kind,"ROOM CLEARED")
		camera.locked = false
		break
var layout: Dictionary = {}

func regenerate_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	change_stage(false,rng.randi())
var controls: Node
var sound: Node
var player: CharacterBody2D
var opponent: CharacterBody2D
var camera: Camera2D
var debug := false
var time := 0.0
var event_text := "CONTACT & RESOLVE"
var sparks: Array[Dictionary] = []
var last_point := Vector2.ZERO
var last_normal := Vector2.ZERO
var last_impact := 0.0
var freeze := 0.0
var enemy_index := 0
var wave_delay := 0.0

func next_enemy() -> void:
	if exploring() or boss_stage:
		interact()
		return
	select_enemy((enemy_index+1)%4)

func select_enemy(index: int) -> void:
	if player.hp <= 0: return
	enemy_index = clampi(index,0,3)
	if is_instance_valid(opponent):
		remove_child(opponent)
		opponent.queue_free()
	opponent = Fighter.new()
	opponent.arena = self
	opponent.enemy = true
	opponent.enemy_kind = ["warden","brute","spear","boss"][enemy_index]
	opponent.position = Vector2(0,-85)
	opponent.facing = PI/2
	add_child(opponent)
	wave_delay = 0
	if camera != null: camera.locked = false
	event_text = "CHALLENGER / " + opponent.title

func _ready() -> void:
	if map_seed < 0:
		if get_tree().has_meta("physoul_map_seed"): map_seed = int(get_tree().get_meta("physoul_map_seed"))
		else:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			map_seed = rng.randi()
	get_tree().set_meta("physoul_map_seed",map_seed)
	if random_map:
		if exploring():
			dungeon = DungeonGenerator.generate(map_seed)
			layout = {"pillars":[],"crates":dungeon.crates}
		else: layout = MapGenerator.generate(map_seed)
	else:
		layout = {"pillars":[Rect2(-280,-150,56,100),Rect2(225,65,56,100),Rect2(-310,230,72,72),Rect2(275,-310,72,72)],"crates":[Vector2(-140,-120),Vector2(165,-185),Vector2(330,260),Vector2(-400,-310)],"ring_radius":190.0,"light":Vector2(-100,-120),"tile_phase":0.0}
	controls = Controls.new()
	add_child(controls)
	sound = Sound.new()
	add_child(sound)
	var boundaries: Array = dungeon.walls if exploring() else [Rect2(-650,-510,1300,30),Rect2(-650,480,1300,30),Rect2(-650,-480,30,960),Rect2(620,-480,30,960)]
	for rect in boundaries:
		wall(rect)
	for rect in layout.pillars: wall(rect)
	for pos in layout.crates:
		var box := RigidBody2D.new()
		box.position = pos
		box.mass = 4
		box.linear_damp = 4
		box.angular_damp = 5
		box.collision_layer = 4
		box.collision_mask = 7
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(38,38)
		collision.shape = shape
		box.add_child(collision)
		var polygon := PropVisual.new()
		polygon.crate = true
		box.add_child(polygon)
		add_child(box)
	player = Fighter.new()
	player.arena = self
	player.position = Vector2(0,190)
	player.facing = -PI/2
	add_child(player)
	player.hp = arrival_hp
	opponent = Fighter.new()
	opponent.arena = self
	opponent.enemy = true
	if boss_stage: opponent.enemy_kind = "boss"
	opponent.position = Vector2(0,-85)
	opponent.facing = PI/2
	add_child(opponent)
	if exploring():
		opponent.hp = 0
		opponent.position = Vector2(-100000,-100000)
		opponent.hide()
		opponent.set_physics_process(false)
	camera = View.new()
	camera.arena = self
	camera.position = player.position + Vector2(0,-145)
	add_child(camera)
	var hud := Hud.new()
	hud.arena = self
	add_child(hud)

func wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	var polygon := PropVisual.new()
	polygon.size = rect.size
	body.add_child(polygon)
	add_child(body)

func contact(point: Vector2, normal: Vector2, impact: float) -> void:
	last_point = point
	last_normal = normal
	last_impact = impact
	sparks.append({"point":point,"normal":normal,"life":0.22})
	camera.shake = minf(5, impact * 0.08)
	freeze = 0.045
	Engine.time_scale = 0.18

func _process(dt: float) -> void:
	if exploring() and player.hp > 0:
		update_exploration()
	elif boss_stage and opponent.hp <= 0 and player.hp > 0:
		event_text = "REGENT DEFEATED / E OR Y FOR NEW EXPEDITION"
	elif opponent != null and opponent.hp <= 0 and player.hp > 0:
		wave_delay += dt
		if wave_delay >= 2.5: next_enemy()
	if freeze > 0:
		freeze -= dt / Engine.time_scale
		if freeze <= 0: Engine.time_scale = 1
	time += dt
	for spark in sparks: spark.life -= dt
	sparks = sparks.filter(func(s): return s.life > 0)
	queue_redraw()

func _exit_tree() -> void:
	Engine.time_scale = 1

func _draw() -> void:
	if exploring():
		draw_dungeon()
	else:
		draw_rect(Rect2(-620,-480,1240,960),Color("151f28"))
		for x in range(-600,600,60):
			for y in range(-480,480,60):
				var tint := 0.015+0.01*sin(x*0.021+y*0.017+float(layout.get("tile_phase",0)))
				draw_rect(Rect2(x+1,y+1,58,58),Color(0.4,0.48,0.52,tint))
		# Soft, fixed world-space pools of light keep the center legible.
		for i in range(24,0,-1):
			draw_circle(layout.get("light",Vector2(-100,-120)),float(i)*20,Color(0.46,0.63,0.69,0.006))
			draw_circle(Vector2(220,190),float(i)*12,Color(0.72,0.54,0.32,0.003))
		for x in range(-600, 620, 60):
			draw_line(Vector2(x,-480),Vector2(x,480),Color(0.16,0.2,0.24,0.3))
		for y in range(-480, 500, 60):
			draw_line(Vector2(-620,y),Vector2(620,y),Color(0.16,0.2,0.24,0.3))
		var ring: float = layout.get("ring_radius",190.0)
		draw_arc(Vector2.ZERO, ring, 0, TAU, 100, Color(0.32,0.38,0.4,0.4), 2)
		draw_arc(Vector2.ZERO, ring+8, 0, TAU, 100, Color(0.32,0.38,0.4,0.18), 1,true)
		for i in 16:
			var radial := Vector2.RIGHT.rotated(i*TAU/16)
			draw_line(radial*(ring+15),radial*(ring+25),Color("52616a"),2,true)
		draw_rect(Rect2(-600,-460,1200,920),Color("475762"),false,2)
	for spark in sparks:
		for i in 7:
			var direction := Vector2.RIGHT.rotated(i * 2.399 + time)
			draw_line(spark.point + direction * 4, spark.point + direction * (8 + (0.22-spark.life)*110), Color(1,0.8,0.4,spark.life/0.22), 2)
	if debug:
		draw_circle(last_point, 5, Color.RED)
		draw_line(last_point,last_point+last_normal*60,Color.YELLOW,2)

func draw_dungeon() -> void:
	for tile: Vector2i in dungeon.floors:
		var origin := Vector2(tile)*DungeonGenerator.TILE
		draw_rect(Rect2(origin,Vector2.ONE*60),Color("1b2932"))
		draw_rect(Rect2(origin+Vector2.ONE,Vector2.ONE*58),Color("202f39").darkened(0.06 if (tile.x+tile.y)%2 == 0 else 0))
	for room: Dictionary in dungeon.rooms:
		var rect: Rect2 = room.rect
		draw_rect(rect.grow(-12),Color("3d515a"),false,2)
		draw_rect(rect.grow(-20),Color(0.3,0.45,0.5,0.16),false,1)
		if room.kind in ["gate","shrine"]:
			var color := Color("e1b777") if room.kind == "gate" else Color("81cfbc")
			if room.used: color = color.darkened(0.65)
			var center: Vector2 = room.center
			if room.kind == "gate":
				for i in 3:
					draw_circle(center+Vector2((i-1)*20,55),4,Color("e1b777") if seals > i else Color("3c484f"))
			for radius in [45,33]: draw_arc(center,radius,0,TAU,40,Color(color,0.3),2,true)
			draw_colored_polygon(PackedVector2Array([center+Vector2(0,-20),center+Vector2(14,0),center+Vector2(0,20),center+Vector2(-14,0)]),color)
		elif room.kind == "battle" and room.cleared:
			draw_arc(room.center,35,0,TAU,32,Color("739a8b"),2,true)
