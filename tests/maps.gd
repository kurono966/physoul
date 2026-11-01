extends SceneTree
const Generator = preload("res://scripts/map_generator.gd")
var failures := 0
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var all_valid := true
	var signatures: Dictionary = {}
	var min_pillars := 99
	var min_crates := 99
	for seed_value in 50:
		var map := Generator.generate(seed_value)
		var repeat := Generator.generate(seed_value)
		if map != repeat: all_valid = false
		var obstacles: Array[Rect2] = []
		for rect in map.pillars: obstacles.append(rect)
		for pos in map.crates: obstacles.append(Rect2(pos-Vector2(19,19),Vector2(38,38)))
		if not Generator.connected(obstacles): all_valid = false
		for i in obstacles.size():
			if obstacles[i].grow(55).intersects(Generator.SAFE_ZONE): all_valid = false
			for j in range(i+1,obstacles.size()):
				if obstacles[i].grow(40).intersects(obstacles[j].grow(40)): all_valid = false
		min_pillars = mini(min_pillars,map.pillars.size())
		min_crates = mini(min_crates,map.crates.size())
		signatures[str(map.pillars)+str(map.crates)] = true
	check(all_valid,"50 seeds: deterministic, connected, separated, spawn area clear")
	check(signatures.size() == 50,"different seeds produce different physical layouts")
	check(min_pillars >= 4 and min_crates >= 3,"every sampled map has pillars and movable crates (%d / %d minimum)" % [min_pillars,min_crates])
	var arena = load("res://arena.tscn").instantiate()
	arena.map_seed = 12345
	arena.boss_stage = true
	root.add_child(arena)
	current_scene = arena
	await physics_frame
	check(arena.layout == Generator.generate(12345),"scene instantiates selected seed")
	var old_layout: Dictionary = arena.layout.duplicate(true)
	check(get_tree_seed() == 12345,"retry seed is stored")
	arena.restart_stage()
	await process_frame
	check(current_scene.map_seed == 12345 and current_scene.layout == old_layout,"restart preserves identical map")
	current_scene.regenerate_map()
	await process_frame
	check(current_scene.map_seed != 12345 and current_scene.player.hp == 100,"regenerate changes seed and resets duel")
	print("MAP COMPLETE: %d failures" % failures)
	quit(failures)
func get_tree_seed() -> int:
	return int(get_meta("physoul_map_seed"))
