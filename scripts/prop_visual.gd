extends Node2D

var size := Vector2(38,38)
var crate := false

func _draw() -> void:
	var rect := Rect2(-size/2,size)
	var cast := Vector2(12,18).rotated(-global_rotation)
	for spread in [6.0,3.0,0.0]:
		draw_rect(Rect2(rect.position+cast-Vector2.ONE*spread,size+Vector2.ONE*spread*2),Color(0.015,0.02,0.03,0.07))
	draw_rect(rect.grow(3),Color(0.02,0.03,0.04,0.45))
	var base := Color("685d4b") if crate else Color("303e49")
	var edge := Color("b6a17b") if crate else Color("627784")
	draw_rect(rect,base)
	var inset := 4.0 if crate else 6.0
	var face := rect.grow(-inset)
	# Broad bevels make the top plane readable without texture noise.
	draw_colored_polygon(PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),Vector2(face.end.x,face.position.y),face.position]),base.lightened(0.28))
	draw_colored_polygon(PackedVector2Array([rect.position,face.position,Vector2(face.position.x,face.end.y),Vector2(rect.position.x,rect.end.y)]),base.lightened(0.12))
	draw_colored_polygon(PackedVector2Array([rect.end,Vector2(rect.position.x,rect.end.y),Vector2(face.position.x,face.end.y),face.end]),base.darkened(0.34))
	draw_colored_polygon(PackedVector2Array([rect.end,face.end,Vector2(face.end.x,face.position.y),Vector2(rect.end.x,rect.position.y)]),base.darkened(0.24))
	draw_rect(face,base.lightened(0.05))
	draw_rect(rect,edge.darkened(0.2),false,1)
	draw_line(rect.position+Vector2(3,3),Vector2(size.x/2-3,-size.y/2+3),edge,2,true)
	if crate:
		draw_line(-size/2+Vector2(5,5),size/2-Vector2(5,5),edge.darkened(0.2),3,true)
		draw_line(Vector2(-size.x/2+5,size.y/2-5),Vector2(size.x/2-5,-size.y/2+5),edge.darkened(0.2),3,true)
		for x in [-1,1]:
			for y in [-1,1]: draw_circle(Vector2(x,y)*(size/2-Vector2(5,5)),1.7,Color("dfcca5"))
	else:
		draw_rect(face.grow(-3),Color("51616a"),false,1)
