extends CanvasLayer
## The mask stores explored terrain (R) and current sight (G); actors never use memory.
@export var sight_distance := 650.0
@export var sight_angle := 110.0
const CELL := 24.0
const RESOLUTION := 256
const ORIGIN := Vector2(-1200,-1200)
var arena: Node2D
var explored: Dictionary = {}
var current_cells: Array[Vector2i] = []
var mask: Image
var texture: ImageTexture
var material: ShaderMaterial
var actor_material: ShaderMaterial
var timer := 0.0

func _ready() -> void:
	layer = 1
	mask = Image.create(RESOLUTION,RESOLUTION,false,Image.FORMAT_RGBA8)
	mask.fill(Color(0,0,0,1))
	texture = ImageTexture.create_from_image(mask)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D sight_mask : filter_linear, repeat_disable;
uniform vec2 view_origin;
uniform vec2 world_dx;
uniform vec2 world_dy;
uniform vec2 map_origin;
uniform float map_size;
void fragment() {
 vec2 world = view_origin + SCREEN_UV.x * world_dx + SCREEN_UV.y * world_dy;
 vec2 uv = (world-map_origin)/map_size;
 vec2 memory = texture(sight_mask,uv).rg;
 if (uv.x<0.0 || uv.y<0.0 || uv.x>1.0 || uv.y>1.0) memory=vec2(0.0);
 float known = smoothstep(0.1,0.9,memory.r);
 float visible = smoothstep(0.1,0.9,memory.g);
 COLOR=vec4(0.018,0.027,0.036,mix(mix(1.0,0.76,known),0.0,visible));
}"""
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("sight_mask",texture)
	material.set_shader_parameter("map_origin",ORIGIN)
	material.set_shader_parameter("map_size",CELL*RESOLUTION)
	var actor_shader := Shader.new()
	actor_shader.code = shader.code.substr(0,shader.code.find("void fragment()"))+"""void fragment() {
 vec2 world = view_origin + SCREEN_UV.x * world_dx + SCREEN_UV.y * world_dy;
 vec2 uv = (world-map_origin)/map_size;
 float sight = texture(sight_mask,uv).g;
 if (uv.x<0.0 || uv.y<0.0 || uv.x>1.0 || uv.y>1.0) sight=0.0;
 COLOR.a *= smoothstep(0.1,0.9,sight);
}"""
	actor_material = ShaderMaterial.new()
	actor_material.shader = actor_shader
	actor_material.set_shader_parameter("sight_mask",texture)
	actor_material.set_shader_parameter("map_origin",ORIGIN)
	actor_material.set_shader_parameter("map_size",CELL*RESOLUTION)
	var cover := ColorRect.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.material = material
	add_child(cover)
	visible = arena.random_map

func observes(point: Vector2) -> bool:
	if not arena.random_map: return true
	var delta: Vector2 = point-arena.player.global_position
	if delta.length() > sight_distance: return false
	if delta.length() > 1 and arena.player.forward().dot(delta.normalized()) < cos(deg_to_rad(sight_angle*0.5)): return false
	var query := PhysicsRayQueryParameters2D.create(arena.player.global_position,point,1)
	var hit := arena.get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or arena.player.global_position.distance_to(hit.position) >= delta.length()-8

func observes_body(body: Node2D, radius := 16.0) -> bool:
	for offset in [Vector2.ZERO,Vector2.LEFT*radius,Vector2.RIGHT*radius,Vector2.UP*radius,Vector2.DOWN*radius]:
		if observes(body.global_position+offset): return true
	return false

func remembers(point: Vector2) -> bool:
	return explored.has(Vector2i(floori(point.x/CELL),floori(point.y/CELL)))

func refresh() -> void:
	for cell in current_cells: mask.set_pixelv(cell,Color(1,0,0,1))
	current_cells.clear()
	var center: Vector2 = arena.player.global_position
	var base := Vector2i(floori(center.x/CELL),floori(center.y/CELL))
	var radius := ceili(sight_distance/CELL)
	for x in range(-radius,radius+1):
		for y in range(-radius,radius+1):
			var cell := base+Vector2i(x,y)
			var point := (Vector2(cell)+Vector2.ONE*0.5)*CELL
			# A small light at the feet keeps the player's silhouette readable.
			var feet := point.distance_to(center) < 38
			if not feet and not observes(point): continue
			var pixel := cell-Vector2i(ORIGIN/CELL)
			if pixel.x < 0 or pixel.y < 0 or pixel.x >= RESOLUTION or pixel.y >= RESOLUTION: continue
			explored[cell] = true
			current_cells.append(pixel)
			mask.set_pixelv(pixel,Color(1,1,0,1))
	texture.update(mask)

func _process(dt: float) -> void:
	if not arena.random_map: return
	timer -= dt
	if timer <= 0:
		refresh()
		timer = 0.08
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var size := get_viewport().get_visible_rect().size
	for target_material in [material,actor_material]:
		target_material.set_shader_parameter("view_origin",inverse*Vector2.ZERO)
		target_material.set_shader_parameter("world_dx",inverse.basis_xform(Vector2(size.x,0)))
		target_material.set_shader_parameter("world_dy",inverse.basis_xform(Vector2(0,size.y)))
	for child in arena.get_children():
		if child is CharacterBody2D and child.enemy:
			child.visible = observes_body(child,32 if child.enemy_kind == "boss" else 16)
			child.material = actor_material
			child.weapon.use_parent_material = true
		elif child is RigidBody2D:
			child.visible = observes_body(child,20)
			child.material = actor_material
			for visual in child.get_children():
				if visual is CanvasItem: visual.use_parent_material = true
		elif child.get_script() == preload("res://scripts/shockwave.gd"):
			child.visible = observes(child.global_position)
			child.material = actor_material
