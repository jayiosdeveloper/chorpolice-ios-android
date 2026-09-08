## IconGen — renders the Logo emblem onto a rounded navy gradient tile in a 512x512
## SubViewport and writes the launcher icon PNGs (icon.png, icon_192, icon_432 + the
## adaptive background). Run windowed:  Godot --path PROJ res://scenes/IconGen.tscn
extends Control

func _ready() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(512, 512)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)

	var tile := TextureRect.new()
	tile.texture = UI.grad_tex([Color(0.10, 0.13, 0.26), Color(0.04, 0.05, 0.11)])
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_SCALE
	tile.size = Vector2(512, 512)
	sv.add_child(tile)
	# corner glows
	for g in [[Vector2(60, 470), Color(1.0, 0.44, 0.16, 0.45)], [Vector2(460, 50), Color(0.2, 0.62, 1.0, 0.45)]]:
		var gt := GradientTexture2D.new()
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 1.0])
		gr.colors = PackedColorArray([g[1], Color(g[1].r, g[1].g, g[1].b, 0.0)])
		gt.gradient = gr
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		var tr := TextureRect.new()
		tr.texture = gt
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = Vector2(520, 520)
		tr.position = g[0] - Vector2(260, 260)
		sv.add_child(tr)
	var logo := Logo.new()
	logo.mode = "emblem"
	sv.add_child(logo)
	logo.scale = Vector2(2.1, 2.1)
	logo.position = Vector2(256 - 100 * 2.1, 256 - 100 * 2.1 + 6)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var dir := ProjectSettings.globalize_path("res://")
	sv.get_texture().get_image().save_png(dir + "icon.png")
	var a := sv.get_texture().get_image(); a.resize(192, 192, Image.INTERPOLATE_LANCZOS); a.save_png(dir + "icon_192.png")
	# adaptive foreground: emblem only on transparent, background: the tile
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(Color(0.06, 0.08, 0.16))
	bg.save_png(dir + "icon_bg_432.png")
	var b := sv.get_texture().get_image(); b.resize(432, 432, Image.INTERPOLATE_LANCZOS); b.save_png(dir + "icon_432.png")
	print("[icon] written to ", dir)
	get_tree().quit()
