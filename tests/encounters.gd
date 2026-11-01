extends SceneTree
const Generator = preload("res://scripts/dungeon_generator.gd")
var failures := 0
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var valid := true
	var pillars := false
	for seed_value in 30:
		var layout := Generator.generate(seed_value)
		if layout.links.size() < layout.rooms.size(): valid = false
		var count := 0
		for room: Dictionary in layout.rooms:
			if room.kind != "battle":
				if not room.escorts.is_empty(): valid = false
				continue
			count += 1+room.escorts.size()
			for entry: Dictionary in room.escorts:
				var tile := Vector2i(floori(entry.position.x/60),floori(entry.position.y/60))
				if not room.tiles.has(tile) or not layout.floors.has(tile): valid = false
			for tile: Vector2i in room.tiles:
				for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					if not layout.floors.has(tile+direction) and room.rect.has_point(Vector2(tile+direction)*60+Vector2(30,30)): pillars = true
		if count != 8: valid = false
	check(valid,"30 seeds have a loop, safe escort spawns, eight enemies and peaceful rest rooms")
	check(pillars,"combat spaces contain interior obstacles")
	var arena = load("res://arena.tscn").instantiate()
	arena.map_seed = 12345
	root.add_child(arena)
	await physics_frame
	arena.player.set_physics_process(false)
	arena.camera.set_physics_process(false)
	for member in arena.guardians.values()+arena.escorts:
		member.set_physics_process(false)
		member.weapon.set_physics_process(false)
	check(arena.escorts.size() == 3,"three additional enemies are preplaced before approaching rooms")
	var index := -1
	for key in arena.room_guards:
		if arena.room_guards[key].size() > 1:
			index = key
			break
	var members: Array = arena.room_guards[index]
	members[0].hp = 0
	arena.update_exploration()
	check(arena.seals == 0 and not arena.dungeon.rooms[index].cleared,"defeating leader alone does not clear paired encounter")
	members[1].hp = 0
	arena.update_exploration()
	arena.update_exploration()
	check(arena.seals == 1 and arena.dungeon.rooms[index].cleared,"defeating entire encounter awards one seal only")
	arena.encounter_attack_delay = 0.4
	arena.player.position = members[1].position
	check(not arena.can_start_enemy_attack(members[1]),"nearby enemies cannot begin attacks at identical timing")
	print("ENCOUNTERS COMPLETE: %d failures" % failures)
	quit(failures)
