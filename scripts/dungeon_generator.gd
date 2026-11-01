extends RefCounted
const TILE := 60
const STEP := Vector2i(15,13)
const ROOM_SIZE := Vector2(720,600)

static func room_tiles(shape: String, half_width: int, half_height: int) -> Dictionary:
	var tiles: Dictionary = {}
	for x in range(-half_width,half_width):
		for y in range(-half_height,half_height):
			var ax := absf(x+0.5)
			var ay := absf(y+0.5)
			if shape == "cross" and ax >= 2 and ay >= 2: continue
			if shape == "ell" and x >= 2 and y <= -2: continue
			if shape == "octagon" and ax >= half_width-2 and ay >= half_height-2: continue
			tiles[Vector2i(x,y)] = true
	return tiles

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
	# One extra connection creates a useful return route rather than only dead ends.
	var loops: Array = []
	for cell in cells:
		for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
			var next: Vector2i = cell+direction
			if cells.has(next) and not links.has([cell,next]) and not links.has([next,cell]): loops.append([cell,next])
	if not loops.is_empty(): links.append(loops[rng.randi_range(0,loops.size()-1)])
	distances = {Vector2i.ZERO:0}
	var pending: Array[Vector2i] = [Vector2i.ZERO]
	var cursor := 0
	while cursor < pending.size():
		var cell := pending[cursor]
		cursor += 1
		for edge in links:
			var next: Vector2i = edge[1] if edge[0] == cell else edge[0]
			if cell not in edge or distances.has(next): continue
			distances[next] = int(distances[cell])+1
			pending.append(next)
	var gate := cells[1]
	for cell in cells:
		if int(distances[cell]) > int(distances[gate]): gate = cell
	var rooms: Array[Dictionary] = []
	var floors: Dictionary = {}
	var crates: Array[Vector2] = []
	var shapes := ["hall","tower","cross","ell","octagon","chamber"]
	for i in range(shapes.size()-1,0,-1):
		var swap := rng.randi_range(0,i)
		var saved: String = shapes[i]
		shapes[i] = shapes[swap]
		shapes[swap] = saved
	var battle_index := 0
	for i in cells.size():
		var cell := cells[i]
		var center := Vector2(cell*STEP)*TILE
		var kind := "start" if i == 0 else ("gate" if cell == gate else "battle")
		if i == 1 and cell != gate: kind = "shrine"
		var shape: String = "octagon" if i == 0 else shapes[(i-1)%shapes.size()]
		var half_width := 6
		var half_height := 5
		if shape == "hall": half_height = 3
		if shape == "tower": half_width = 3
		if shape == "chamber":
			half_width = rng.randi_range(4,6)
			half_height = rng.randi_range(3,5)
		var local_tiles := room_tiles(shape,half_width,half_height)
		if shape == "ell":
			var mirror_x := rng.randf() < 0.5
			var mirror_y := rng.randf() < 0.5
			var mirrored: Dictionary = {}
			for tile: Vector2i in local_tiles:
				mirrored[Vector2i(-tile.x-1 if mirror_x else tile.x,-tile.y-1 if mirror_y else tile.y)] = true
			local_tiles = mirrored
		var tiles: Dictionary = {}
		for tile: Vector2i in local_tiles:
			var global_tile := cell*STEP+tile
			tiles[global_tile] = true
			floors[global_tile] = true
		var size := Vector2(half_width,half_height)*2*TILE
		var escorts: Array = []
		if kind == "battle" and battle_index in [1,2,4]: escorts.append({"kind":"warden" if battle_index == 2 else ("reptile" if battle_index == 4 else "wolf"),"position":center+Vector2(-120,90)})
		rooms.append({"cell":cell,"center":center,"rect":Rect2(center-size/2,size),"tiles":tiles,"shape":shape,"kind":kind,"enemy":[0,3,2,1][battle_index%4],"escorts":escorts,"hp":-1.0,"cleared":kind != "battle","visited":false,"used":false})
		if kind == "battle":
			battle_index += 1
			# Small pillar islands only where a full ring of walkable floor remains.
			var pillar_candidates: Array[Vector2i] = []
			for tile: Vector2i in local_tiles:
				var offset := (Vector2(tile)+Vector2.ONE*0.5)*TILE
				if absf(offset.x) < 150 or absf(offset.y) < 150: continue
				var clear := true
				for x in range(-1,2):
					for y in range(-1,2):
						if not local_tiles.has(tile+Vector2i(x,y)): clear = false
				if clear: pillar_candidates.append(tile)
			var chosen: Array[Vector2i] = []
			for pick in 2:
				if pillar_candidates.is_empty(): break
				var tile: Vector2i = pillar_candidates.pop_at(rng.randi_range(0,pillar_candidates.size()-1))
				var separated := true
				for other in chosen:
					if Vector2(tile-other).length() < 3: separated = false
				if not separated: continue
				chosen.append(tile)
				local_tiles.erase(tile)
				tiles.erase(cell*STEP+tile)
				floors.erase(cell*STEP+tile)
			var candidates: Array[Vector2] = []
			for tile: Vector2i in local_tiles:
				var offset := (Vector2(tile)+Vector2.ONE*0.5)*TILE
				if offset.length() < 190 or absf(offset.x) < 80 or absf(offset.y) < 80: continue
				var clear := true
				for x in range(-1,2):
					for y in range(-1,2):
						if not local_tiles.has(tile+Vector2i(x,y)): clear = false
				if clear: candidates.append(center+offset)
			var last := Vector2.INF
			for pick in 2:
				if candidates.is_empty(): break
				var pos := candidates.pop_at(rng.randi_range(0,candidates.size()-1)) as Vector2
				if pos.distance_to(last) < 120: continue
				crates.append(pos)
				last = pos
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
