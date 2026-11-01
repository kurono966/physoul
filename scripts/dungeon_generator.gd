extends RefCounted
const TILE := 60
const STEP := Vector2i(15,13)
const ROOM_SIZE := Vector2(720,600)

static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var links: Array = []
	var distances := {Vector2i.ZERO:0}
	while cells.size() < 8:
		var options: Array = []
		for cell in cells:
			for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i = cell+direction
				if next.x < 0 or next.y < 0 or next.x > 2 or next.y > 2 or cells.has(next): continue
				options.append([cell,next])
		var edge: Array = options[rng.randi_range(0,options.size()-1)]
		cells.append(edge[1])
		links.append(edge)
		distances[edge[1]] = int(distances[edge[0]])+1
	var gate := cells[1]
	for cell in cells:
		if int(distances[cell]) > int(distances[gate]): gate = cell
	var rooms: Array[Dictionary] = []
	var floors: Dictionary = {}
	var crates: Array[Vector2] = []
	for i in cells.size():
		var cell := cells[i]
		var center := Vector2(cell*STEP)*TILE
		var kind := "start" if i == 0 else ("gate" if cell == gate else "battle")
		if i == 1 and cell != gate: kind = "shrine"
		rooms.append({"cell":cell,"center":center,"rect":Rect2(center-ROOM_SIZE/2,ROOM_SIZE),"kind":kind,"enemy":i%3,"hp":-1.0,"cleared":kind != "battle","visited":false,"used":false})
		for x in range(-6,6):
			for y in range(-5,5): floors[cell*STEP+Vector2i(x,y)] = true
		if kind == "battle":
			crates.append(center+Vector2(-220,180))
			crates.append(center+Vector2(220,-180))
	for edge in links:
		var start: Vector2i = edge[0]*STEP
		var finish: Vector2i = edge[1]*STEP
		var direction := Vector2i(signi(finish.x-start.x),signi(finish.y-start.y))
		var point := start
		while true:
			for offset in range(-1,2): floors[point+Vector2i(-direction.y,direction.x)*offset] = true
			if point == finish: break
			point += direction
	var boundary: Dictionary = {}
	for tile: Vector2i in floors:
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if not floors.has(tile+direction): boundary[tile+direction] = true
	var walls: Array[Rect2] = []
	while not boundary.is_empty():
		var cell: Vector2i = boundary.keys()[0]
		var left := cell.x
		var right := cell.x
		while boundary.has(Vector2i(left-1,cell.y)): left -= 1
		while boundary.has(Vector2i(right+1,cell.y)): right += 1
		for x in range(left,right+1): boundary.erase(Vector2i(x,cell.y))
		walls.append(Rect2(Vector2(left,cell.y)*TILE,Vector2((right-left+1)*TILE,TILE)))
	return {"rooms":rooms,"links":links,"floors":floors,"walls":walls,"crates":crates,"gate":gate}
