## IconGen — renders the "Chor Police" badge into a 512x512 SubViewport (independent
## of window stretch) and writes the launcher icon PNGs. Run windowed:
##   Godot --path PROJ res://scenes/IconGen.tscn
extends Control

class Emblem:
	extends Control

	func _draw() -> void:
		var c := Vector2(256, 256)
		draw_rect(Rect2(0, 0, 512, 512), Color(0.10, 0.10, 0.20))
		draw_circle(c, 215, Color(0.18, 0.14, 0.30, 0.55))
		draw_arc(c, 168, 0, TAU, 80, Color(0.96, 0.78, 0.30), 18, true)
		draw_arc(c, 151, 0, TAU, 80, Color(0.72, 0.52, 0.16), 4, true)
		draw_circle(c, 150, Color(0.09, 0.10, 0.18))
		_rrect_rot(c, 232, 30, deg_to_rad(30), Color(0.22, 0.23, 0.27))
		_rrect_rot(c, 232, 30, deg_to_rad(-30), Color(0.22, 0.23, 0.27))
		_rrect_rot(c + Vector2(96, 55), 38, 14, deg_to_rad(30), Color(0.88, 0.45, 0.2))
		_rrect_rot(c + Vector2(-96, 55), 38, 14, deg_to_rad(-30), Color(0.88, 0.45, 0.2))
		draw_colored_polygon(_star(c, 96, 42, 5), Color(0.98, 0.82, 0.32))
		draw_colored_polygon(_star(c, 70, 30, 5), Color(0.86, 0.66, 0.20))
		draw_circle(c, 26, Color(0.10, 0.12, 0.20))

	func _star(c: Vector2, ro: float, ri: float, n: int) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in n * 2:
			var ang := -PI / 2.0 + float(i) * PI / float(n)
			var r := ro if i % 2 == 0 else ri
			pts.append(c + Vector2(cos(ang), sin(ang)) * r)
		return pts

	func _rrect_rot(c: Vector2, w: float, h: float, ang: float, col: Color) -> void:
		var hw := w / 2.0
		var hh := h / 2.0
		var local := [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]
		var out := PackedVector2Array()
		for p in local:
			out.append(c + p.rotated(ang))
		draw_colored_polygon(out, col)

func _ready() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(512, 512)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var em := Emblem.new()
	em.size = Vector2(512, 512)
	sv.add_child(em)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var dir := ProjectSettings.globalize_path("res://")
	var src := sv.get_texture().get_image()
	src.save_png(dir + "icon.png")
	var a := sv.get_texture().get_image(); a.resize(192, 192, Image.INTERPOLATE_LANCZOS); a.save_png(dir + "icon_192.png")
	var b := sv.get_texture().get_image(); b.resize(432, 432, Image.INTERPOLATE_LANCZOS); b.save_png(dir + "icon_432.png")
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(Color(0.10, 0.10, 0.20))
	bg.save_png(dir + "icon_bg_432.png")
	print("[icon] written to ", dir)
	get_tree().quit()
