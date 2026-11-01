extends Node2D

const Fighter = preload("res://scripts/fighter.gd")
const View = preload("res://scripts/view.gd")
const Hud = preload("res://scripts/hud.gd")
const Sound = preload("res://scripts/sound.gd")
const PropVisual = preload("res://scripts/prop_visual.gd")
const Controls = preload("res://scripts/controls.gd")
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
	controls = Controls.new()
	add_child(controls)
	sound = Sound.new()
	add_child(sound)
	for rect in [Rect2(-650,-510,1300,30),Rect2(-650,480,1300,30),Rect2(-650,-480,30,960),Rect2(620,-480,30,960),Rect2(-280,-150,56,100),Rect2(225,65,56,100),Rect2(-310,230,72,72),Rect2(275,-310,72,72)]:
		wall(rect)
	for pos in [Vector2(-140,-120),Vector2(165,-185),Vector2(330,260),Vector2(-400,-310)]:
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
	opponent = Fighter.new()
	opponent.arena = self
	opponent.enemy = true
	opponent.position = Vector2(0,-85)
	opponent.facing = PI/2
	add_child(opponent)
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
	if opponent != null and opponent.hp <= 0 and player.hp > 0:
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
	draw_rect(Rect2(-620,-480,1240,960),Color("151f28"))
	for x in range(-600,600,60):
		for y in range(-480,480,60):
			var tint := 0.015+0.01*sin(x*0.021+y*0.017)
			draw_rect(Rect2(x+1,y+1,58,58),Color(0.4,0.48,0.52,tint))
	# Soft, fixed world-space pools of light keep the center legible.
	for i in range(24,0,-1):
		draw_circle(Vector2(-100,-120),float(i)*20,Color(0.46,0.63,0.69,0.006))
		draw_circle(Vector2(220,190),float(i)*12,Color(0.72,0.54,0.32,0.003))
	for x in range(-600, 620, 60):
		draw_line(Vector2(x,-480),Vector2(x,480),Color(0.16,0.2,0.24,0.3))
	for y in range(-480, 500, 60):
		draw_line(Vector2(-620,y),Vector2(620,y),Color(0.16,0.2,0.24,0.3))
	draw_arc(Vector2.ZERO, 190, 0, TAU, 100, Color(0.32,0.38,0.4,0.4), 2)
	draw_arc(Vector2.ZERO, 198, 0, TAU, 100, Color(0.32,0.38,0.4,0.18), 1,true)
	for i in 16:
		var radial := Vector2.RIGHT.rotated(i*TAU/16)
		draw_line(radial*205,radial*215,Color("52616a"),2,true)
	draw_rect(Rect2(-600,-460,1200,920),Color("475762"),false,2)
	for spark in sparks:
		for i in 7:
			var direction := Vector2.RIGHT.rotated(i * 2.399 + time)
			draw_line(spark.point + direction * 4, spark.point + direction * (8 + (0.22-spark.life)*110), Color(1,0.8,0.4,spark.life/0.22), 2)
	if camera != null and camera.locked and opponent.hp > 0:
		draw_arc(opponent.position, 32, time, time + 5, 32, Color("f0db9f"), 2)
	if debug:
		draw_circle(last_point, 5, Color.RED)
		draw_line(last_point,last_point+last_normal*60,Color.YELLOW,2)
