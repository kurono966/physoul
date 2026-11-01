extends SceneTree
const Generator = preload("res://scripts/dungeon_generator.gd")
var failures := 0
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var valid := true
	var shapes: Dictionary = {}
	for seed_value in 30:
		var layout := Generator.generate(seed_value)
		if layout != Generator.generate(seed_value) or layout.rooms.size() != 8: valid = false
		var visited: Dictionary = {Vector2i.ZERO:true}
		var pending: Array[Vector2i] = [Vector2i.ZERO]
		var cursor := 0
		while cursor < pending.size():
			var point := pending[cursor]
			cursor += 1
			for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i = point+direction
				if layout.floors.has(next) and not visited.has(next):
					visited[next] = true
					pending.append(next)
		if visited.size() != layout.floors.size(): valid = false
		for room: Dictionary in layout.rooms:
			shapes[room.shape] = true
			var spawn_tile := Vector2i(room.cell*Generator.STEP)+Vector2i(0,-1)
			if not room.tiles.has(spawn_tile): valid = false
			if room.kind == "battle":
				for crate: Vector2 in layout.crates:
					var tile := Vector2i(floori(crate.x/60),floori(crate.y/60))
					if not layout.floors.has(tile): valid = false
	check(valid,"30 seeds generate reproducible connected eight-room dungeons")
	check(shapes.size() == 6,"six room silhouettes appear with safe spawn tiles")
	var arena = load("res://arena.tscn").instantiate()
	arena.map_seed = 12345
	root.add_child(arena)
	current_scene = arena
	await frames(3)
	arena.player.set_physics_process(false)
	arena.camera.set_physics_process(false)
	check(arena.exploring() and arena.current_room == 0 and arena.opponent.hp == 0,"expedition starts in a safe room")
	var destination: Vector2 = Vector2(arena.dungeon.links[0][1]*Generator.STEP)*Generator.TILE
	arena.player.position = Vector2.ZERO
	await frames(2)
	for i in 130:
		var delta: Vector2 = destination-arena.player.position
		if delta.length() < 5: break
		arena.player.move_and_collide(delta.limit_length(10))
		if arena.opponent.hp > 0: arena.opponent.set_physics_process(false)
		await physics_frame
	check(arena.player.position.distance_to(destination) < 5,"physical player can traverse room doorway and corridor")
	arena.player.position = Vector2.ZERO
	arena.update_exploration()
	var battle := -1
	for i in arena.dungeon.rooms.size():
		if arena.dungeon.rooms[i].kind == "battle":
			battle = i
			break
	arena.player.position = arena.dungeon.rooms[battle].center
	arena.update_exploration()
	arena.opponent.set_physics_process(false)
	check(arena.opponent.hp > 0 and arena.opponent.enemy_kind != "boss","battle room spawns a local guardian")
	arena.opponent.hp = 40
	arena.player.position = Vector2.ZERO
	arena.update_exploration()
	arena.player.position = arena.dungeon.rooms[battle].center
	arena.update_exploration()
	check(arena.opponent.hp == 40,"guardian HP survives leaving and returning")
	arena.opponent.hp = 0
	arena.update_exploration()
	arena.update_exploration()
	check(arena.seals == 1 and arena.dungeon.rooms[battle].cleared,"defeat awards one seal only")
	for room: Dictionary in arena.dungeon.rooms:
		if room.kind == "shrine":
			arena.player.position = room.center
			arena.player.hp = 40
			arena.update_exploration()
			arena.interact()
			arena.interact()
			check(arena.player.hp == 90 and room.used,"shrine heals once per expedition")
	var gate := -1
	for i in arena.dungeon.rooms.size():
		if arena.dungeon.rooms[i].kind == "gate": gate = i
	arena.player.position = arena.dungeon.rooms[gate].center
	arena.update_exploration()
	arena.interact()
	check(not arena.switching_stage,"boss gate stays sealed before three victories")
	arena.seals = 3
	arena.player.hp = 63
	arena.interact()
	await process_frame
	var boss_arena = current_scene
	check(boss_arena.boss_stage and not boss_arena.exploring() and boss_arena.opponent.enemy_kind == "boss","boss gate enters separate open arena")
	check(boss_arena.player.hp == 63 and boss_arena.dungeon.is_empty(),"boss transition preserves HP and uses arena layout")
	boss_arena.restart_stage()
	await process_frame
	check(current_scene.boss_stage and current_scene.player.hp == 100,"boss retry stays in boss stage")
	print("DUNGEON COMPLETE: %d failures" % failures)
	quit(failures)
