extends Node2D

var arena: Node2D
var particles: Array[Dictionary] = []
var flashes: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 30
	rng.randomize()

func burst(actor: CharacterBody2D, point: Vector2, direction: Vector2, damage: float, lethal: bool) -> void:
	if arena.random_map and actor != arena.player and not arena.vision.observes(point): return
	var power := clampf(damage/42.0,0.2,1.8)
	var count := 28 if lethal else (22 if damage >= 50 else 12)
	var color := Color("f2aa82") if actor.enemy else Color("9de6ef")
	var heading := direction.angle() if direction.length() > 0.1 else rng.randf()*TAU
	for i in count:
		if particles.size() >= 384: particles.pop_front()
		var angle := heading+rng.randf_range(-1.8,1.8)
		if i%3 == 0: angle = rng.randf()*TAU
		particles.append({"point":point,"velocity":Vector2.RIGHT.rotated(angle)*rng.randf_range(65,220)*(0.7+power*0.3),"age":0.0,"life":rng.randf_range(0.2,0.48),"size":rng.randf_range(1.5,3.5)*(1.2 if lethal else 1.0),"angle":angle,"color":Color("fff4d6") if i%4 == 0 else color,"self":actor == arena.player})
	flashes.append({"point":point,"center":actor.global_position,"angle":heading,"age":0.0,"power":power,"color":color,"self":actor == arena.player})
	if flashes.size() > 24: flashes.pop_front()
	queue_redraw()

func observable(point: Vector2, self_hit: bool) -> bool:
	return not arena.random_map or arena.vision.observes(point) or (self_hit and point.distance_to(arena.player.global_position) < 38)

func _process(dt: float) -> void:
	for particle in particles:
		particle.age += dt
		particle.point += particle.velocity*dt
		particle.velocity *= exp(-5*dt)
		particle.angle += dt*7
	particles = particles.filter(func(p): return p.age < p.life)
	for flash in flashes: flash.age += dt
	flashes = flashes.filter(func(f): return f.age < 0.22)
	queue_redraw()

func _draw() -> void:
	for flash in flashes:
		if not observable(flash.point,flash.self): continue
		var fade: float = 1-flash.age/0.22
		draw_arc(flash.point,4+flash.age*100,0,TAU,24,Color(flash.color,fade*0.55),1.5,true)
		if flash.age < 0.08:
			var length: float = (8+flash.power*5)*(1-flash.age/0.08)
			for offset in [-0.6,0.6]:
				var axis: Vector2 = Vector2.RIGHT.rotated(flash.angle+offset)
				draw_line(flash.point-axis*length,flash.point+axis*length,Color("fff6dc"),2.5,true)
			if observable(flash.center,flash.self): draw_arc(flash.center,22,0,TAU,32,Color(1,0.91,0.73,fade*0.7),2,true)
	for particle in particles:
		if not observable(particle.point,particle.self): continue
		var fade: float = pow(1-particle.age/particle.life,1.5)
		var axis: Vector2 = Vector2.RIGHT.rotated(particle.angle)*particle.size
		draw_line(particle.point-axis,particle.point+axis,Color(particle.color,fade),particle.size*0.8,true)
