extends CanvasLayer

var arena: Node2D
var display: Control

func _ready() -> void:
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
	var panel := Color(0.025,0.04,0.055,0.76)
	display.draw_style_box(panel_style(panel),Rect2(16,16,250,110))
	display.draw_style_box(panel_style(panel),Rect2(size.x-266,16,250,110))
	text_at(Vector2(30,39),"PHYSOUL",16,Color("e5d4ae"))
	compact_bar(Vector2(30,54),"HP",arena.player.hp,Color("c87168"))
	compact_bar(Vector2(30,76),"STAMINA",arena.player.stamina,Color("72c8ab"))
	compact_bar(Vector2(30,98),"POSTURE",arena.player.posture,Color("e2ba72"))
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
			text_at(Vector2(30,size.y-23),"A / Cross Roll   X / Square Kick   R3 Lock   D-pad Right Next Enemy   Start Restart  Back Help",16)
		else:
			text_at(Vector2(30,size.y-50),"WASD Move   Mouse Turn   LMB Click: Slash / Hold: Prepare + Auto Thrust   RMB Guard",16)
		text_at(Vector2(30,size.y-23),"SHIFT Roll   SPACE Kick   TAB / MMB Lock   1–4 Enemy   N Next   ESC Cursor   F3 Debug   R Restart  H Help",16)
	text_at(Vector2(30,151),arena.event_text,14,Color("e5d4ae"))
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
