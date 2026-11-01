extends CanvasLayer

var arena: Node2D
var display: Control

func _ready() -> void:
	layer = 2
	display = Control.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.draw.connect(paint)
	add_child(display)

func _process(_dt: float) -> void:
	display.queue_redraw()

func text_at(point: Vector2, text: String, size := 18, color := Color("d6dedf")) -> void:
	display.draw_string(ThemeDB.fallback_font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func bar(point: Vector2, label: String, value: float, color: Color, width := 250.0) -> void:
	text_at(point,label,13)
	display.draw_rect(Rect2(point+Vector2(0,9),Vector2(width,8)),Color("25313c"))
	display.draw_rect(Rect2(point+Vector2(0,9),Vector2(width*clampf(value/100,0,1),8)),color)

func compact_bar(point: Vector2, label: String, value: float, color: Color) -> void:
	text_at(point+Vector2(0,7),label,11)
	var origin := point+Vector2(56,0)
	display.draw_rect(Rect2(origin,Vector2(166,6)),Color("25313c"))
	display.draw_rect(Rect2(origin,Vector2(166*clampf(value/100,0,1),6)),color)

func paint() -> void:
	var size := display.get_viewport_rect().size
	if arena.camera.locked and arena.opponent.hp > 0:
		draw_target_marker()
	var panel := Color(0.025,0.04,0.055,0.76)
	display.draw_style_box(panel_style(panel),Rect2(16,16,250,110))
	text_at(Vector2(30,39),"PHYSOUL",16,Color("e5d4ae"))
	compact_bar(Vector2(30,54),"HP",arena.player.hp,Color("c87168"))
	compact_bar(Vector2(30,76),"STAMINA",arena.player.stamina,Color("72c8ab"))
	compact_bar(Vector2(30,98),"POSTURE",arena.player.posture,Color("e2ba72"))
	if (arena.opponent.hp > 0 and arena.can_observe(arena.opponent)) or (not arena.exploring() and arena.opponent.hp <= 0):
		display.draw_style_box(panel_style(panel),Rect2(size.x-266,16,250,110))
		var right := size.x-252
		text_at(Vector2(right,39),arena.opponent.title,14 if arena.opponent.enemy_kind == "boss" else 16,Color("e5d4ae"))
		compact_bar(Vector2(right,54),"HP",arena.opponent.hp/arena.opponent.max_hp*100,Color("c87168"))
		compact_bar(Vector2(right,76),"POSTURE",arena.opponent.posture,Color("e2ba72"))
		text_at(Vector2(right,109),"LOCK ON" if arena.camera.locked else "TAB / R3 / MMB: LOCK",11,Color("91a7af"))
		if arena.opponent.enemy_kind == "boss":
			text_at(Vector2(right,145),"BOSS / UNBOUND" if arena.opponent.boss_enraged else "BOSS / PHASE I",12,Color("e7ae7d"))
	if arena.controls.help_visible:
		display.draw_rect(Rect2(0,size.y-80,size.x,80),Color(0.025,0.04,0.055,0.9))
		if arena.controls.using_pad:
			text_at(Vector2(30,size.y-50),"LS Move  RS Turn  RB/R1 Slash · Hold: Thrust  RT/R2 Overhead  LT/L2 Wave  LB/L1 Guard",15)
			text_at(Vector2(30,size.y-23),"L3 Sprint  A Roll  X Kick  Y Interact  R3 Lock  D-pad Up New Map  Start Retry  Back Help",16)
		else:
			text_at(Vector2(30,size.y-50),"WASD Move   Mouse Turn   LMB Click: Slash / Hold: Prepare + Auto Thrust   RMB Guard",16)
			text_at(Vector2(30,size.y-23),"SHIFT Roll  SPACE Kick  E Interact / Gate  TAB Lock  M New Map  R Retry  ESC Cursor  H Help",16)
	text_at(Vector2(30,151),arena.event_text,14,Color("e5d4ae"))
	if arena.player.sprinting: text_at(Vector2(195,39),"SPRINT",11,Color("91dcc6"))
	text_at(Vector2(30,172),"MAP %d  /  %s" % [arena.map_seed,"D-PAD UP: NEW" if arena.controls.using_pad else "M: NEW  ·  R: RETRY"],11,Color("91a7af"))
	if arena.exploring():
		text_at(Vector2(30,194),"SEALS %d/3  /  EXPLORE → BOSS GATE" % arena.seals,12,Color("e5d4ae"))
		if not arena.debug: draw_minimap()
		if arena.current_room >= 0:
			var room: Dictionary = arena.dungeon.rooms[arena.current_room]
			if arena.player.position.distance_to(room.center) <= 100 and arena.vision.observes(room.center):
				var action := "Y" if arena.controls.using_pad else "E"
				if room.kind == "gate":
					text_at(Vector2(size.x/2-150,size.y-210),action+" / ENTER BOSS ARENA" if arena.seals >= 3 else "BOSS GATE / NEED 3 SEALS",18,Color("e5d4ae"))
				elif room.kind == "shrine" and not room.used:
					text_at(Vector2(size.x/2-120,size.y-210),action+" / RESTORE HP",18,Color("91dcc6"))
	if OS.has_feature("web") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not arena.controls.using_pad:
		text_at(Vector2(size.x/2-160,size.y/2-60),"CLICK TO CAPTURE MOUSE / ESC TO RELEASE",15,Color("e5d4ae"))
	if arena.player.just_guard_flash > 0:
		text_at(Vector2(size.x/2-85,size.y-170),"JUST GUARD",23,Color("b7ffff"))
	if arena.player.can_critical():
		text_at(Vector2(size.x/2-140,size.y-140),("RB / R1" if arena.controls.using_pad else "LMB")+" / CRITICAL STRIKE",20,Color("ffd477"))
	if arena.player.charge > 0:
		text_at(Vector2(size.x/2-100,size.y-110),"PREPARING THRUST",18,Color("e2ba72"))
	if arena.player.heavy_charge > 0:
		text_at(Vector2(size.x/2-170,size.y-110),"HEAVY / HOLD FOR CHARGED FOLLOWUP",18,Color("ffb768"))
	if arena.debug:
		display.draw_rect(Rect2(22,210,455,190),Color(0.02,0.03,0.04,0.92))
		var lines := ["F3 / LIVE PHYSICS", "AI: %s" % arena.opponent.ai_state, "Weapon ω: %.2f rad/s | inertia: %.0f" % [arena.player.weapon.omega,arena.player.weapon.inertia], "Mass %.1f | length %.0f | torque %.0f" % [arena.player.weapon.mass,arena.player.weapon.length,arena.player.weapon.torque], "Last impact: %.1f | red: contact / yellow: normal" % arena.last_impact, "Posture player %.1f / enemy %.1f" % [arena.player.posture,arena.opponent.posture]]
		for i in lines.size(): text_at(Vector2(34,238+i*27),lines[i],15)

func panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	return style

func draw_minimap() -> void:
	var origin := Vector2(45,242)
	display.draw_style_box(panel_style(Color(0.025,0.04,0.055,0.78)),Rect2(16,212,170,165))
	var scale := Vector2(50.0/15,50.0/13)
	for tile: Vector2i in arena.dungeon.floors:
		if not arena.vision.remembers((Vector2(tile)+Vector2.ONE*0.5)*60): continue
		display.draw_rect(Rect2(origin+Vector2(tile)*scale,scale),Color("576f79"))
	for room: Dictionary in arena.dungeon.rooms:
		var color := Color("648477") if room.cleared else Color("b67560")
		if room.kind == "gate": color = Color("d9ba7d")
		for tile: Vector2i in room.tiles:
			if not arena.vision.remembers((Vector2(tile)+Vector2.ONE*0.5)*60): continue
			display.draw_rect(Rect2(origin+Vector2(tile)*scale,scale),color)
	var position: Vector2 = origin+arena.player.position/60*scale
	display.draw_circle(position,3,Color("bce8e0"))
	display.draw_line(position,position+arena.player.forward()*8,Color("bce8e0"),1.5,true)

func draw_target_marker() -> void:
	# Screen-space overlay stays above the boss and does not rotate with the floor.
	var center: Vector2 = display.get_viewport().get_canvas_transform()*arena.opponent.global_position
	var extent := 66.0 if arena.opponent.enemy_kind == "boss" else 32.0
	var ink := Color("f6dfa4")
	for x in [-1,1]:
		for y in [-1,1]:
			var corner := center+Vector2(x,y)*extent
			var points := PackedVector2Array([corner-Vector2(x*14,0),corner,corner-Vector2(0,y*14)])
			display.draw_polyline(points,Color(0.025,0.04,0.055,0.9),7,true)
			display.draw_polyline(points,ink,2.5,true)
	var above := center+Vector2(0,-extent-12)
	var diamond := PackedVector2Array([above+Vector2(0,-6),above+Vector2(6,0),above+Vector2(0,6),above+Vector2(-6,0),above+Vector2(0,-6)])
	display.draw_polyline(diamond,Color("14202a"),6,true)
	display.draw_polyline(diamond,ink,2,true)
	display.draw_circle(center,4,Color("14202a"))
	display.draw_circle(center,1.7,ink)
