extends RefCounted
## Seeded arena layouts. Connectivity is checked with clearance for the boss.
const SAFE_ZONE := Rect2(-170,-250,340,540)
const WALK_BOUNDS := Rect2(-580,-440,1160,880)
const CLEARANCE := 42.0

static func connected(obstacles: Array[Rect2]) -> bool:
	var free: Dictionary = {}
	for x in 20:
		for y in 16:
			var point := Vector2(-570+x*60,-450+y*60)
			if not WALK_BOUNDS.has_point(point): continue
			var blocked := false
			for obstacle in obstacles:
				if obstacle.grow(CLEARANCE).has_point(point):
					blocked = true
					break
			if not blocked: free[Vector2i(x,y)] = true
	if free.is_empty(): return false
	var pending: Array[Vector2i] = [free.keys()[0]]
	var visited: Dictionary = {pending[0]: true}
	var cursor := 0
	while cursor < pending.size():
		var cell := pending[cursor]
		cursor += 1
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+direction
			if free.has(next) and not visited.has(next):
				visited[next] = true
				pending.append(next)
	return visited.size() == free.size()

static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pillars: Array[Rect2] = []
	var crates: Array[Vector2] = []
	var occupied: Array[Rect2] = []
	var target_pillars := rng.randi_range(7,11)
	var target_crates := rng.randi_range(5,8)
	for i in 240:
		if pillars.size() >= target_pillars and crates.size() >= target_crates: break
		var is_pillar := pillars.size() < target_pillars and (crates.size() >= target_crates or rng.randf() < 0.6)
		var dimensions := Vector2(38,38)
		if is_pillar:
			dimensions = [Vector2(58,58),Vector2(58,100),Vector2(100,58),Vector2(78,78)][rng.randi_range(0,3)]
		var center := Vector2(rng.randi_range(-8,8)*60,rng.randi_range(-6,6)*60)
		var rect := Rect2(center-dimensions/2,dimensions)
		if rect.grow(55).intersects(SAFE_ZONE): continue
		if not Rect2(-580,-440,1160,880).encloses(rect.grow(35)): continue
		var overlaps := false
		for other in occupied:
			if rect.grow(45).intersects(other.grow(45)):
				overlaps = true
				break
		if overlaps: continue
		occupied.append(rect)
		if not connected(occupied):
			occupied.pop_back()
			continue
		if is_pillar: pillars.append(rect)
		else: crates.append(center)
	return {"pillars":pillars,"crates":crates,"ring_radius":rng.randf_range(170,210),"light":Vector2(rng.randf_range(-190,190),rng.randf_range(-190,40)),"tile_phase":rng.randf_range(0,TAU)}
