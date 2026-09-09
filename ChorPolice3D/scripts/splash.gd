## Splash — the intro: the hero fades up on the glowing disc, the shield logo springs in
## with the wordmark, a tagline slides up, and a pulsing "TAP TO START" pill waits.
## Any tap → the main menu (Lobby).
extends Control

var can_tap := false
var bg: MenuBg

func _ready() -> void:
	for k in ["CP_SHOT", "CP_HOST", "CP_JOIN", "CP_LSHOT", "CP_OCREATE", "CP_OJOIN"]:
		if OS.has_environment(k):
			_go()
			return

	bg = MenuBg.new()
	add_child(bg)
	bg.set_hero(0.5, 0.92, 0.0, 0.9)
	Audio.play_track("menu")

	var vp := get_viewport().get_visible_rect().size

	# logo (stacked) — centred, top third
	var logo := Logo.new()
	logo.mode = "stacked"
	logo.show_tagline = false
	add_child(logo)
	logo.scale = Vector2(0.52, 0.52)
	logo.pivot_offset = Vector2(220, 0)
	logo.position = Vector2(vp.x / 2.0 - 220, vp.y * 0.03)
	logo.modulate.a = 0.0

	var tag := UI.label("FRIENDS  •  WIFI  •  ONLINE  •  ARENA SHOOTER", 15, UI.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	tag.anchor_right = 1.0
	tag.anchor_top = 0.33; tag.anchor_bottom = 0.33
	tag.modulate.a = 0.0
	add_child(tag)

	# tap pill
	var pill := PanelContainer.new()
	var sb := UI.solid(Color(1, 1, 1, 0.08), 28.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.33, 0.9, 1.0, 0.7)
	sb.content_margin_left = 34; sb.content_margin_right = 34
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	pill.add_theme_stylebox_override("panel", sb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(UI.label("TAP TO START", 22, UI.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(pill)
	await get_tree().process_frame
	pill.position = Vector2(vp.x / 2.0 - pill.size.x / 2.0, vp.y * 0.905)
	pill.modulate.a = 0.0

	var ver := UI.label("v3.0  •  3D", 12, Color(1, 1, 1, 0.35))
	ver.position = Vector2(vp.x - 90, vp.y - 30)
	add_child(ver)

	# hero fades up first
	var th := create_tween()
	th.tween_method(func(a: float) -> void: bg.set_hero(0.5, 0.92, a, 0.9), 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	# logo springs in
	logo.scale = Vector2(0.25, 0.25)
	var t1 := create_tween().set_parallel()
	t1.tween_property(logo, "scale", Vector2(0.52, 0.52), 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t1.tween_property(logo, "modulate:a", 1.0, 0.35)
	var t2 := create_tween()
	t2.tween_interval(0.55)
	t2.tween_property(tag, "modulate:a", 1.0, 0.5)
	var t3 := create_tween()
	t3.tween_interval(1.1)
	t3.tween_property(pill, "modulate:a", 1.0, 0.4)
	t3.tween_callback(func() -> void:
		can_tap = true
		var pulse := create_tween().set_loops()
		pulse.tween_property(pill, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(pill, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE))

	if OS.has_environment("CP_SSHOT"):
		await get_tree().create_timer(2.2).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("CP_SSHOT"))
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if not can_tap:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		can_tap = false
		_go()

func _go() -> void:
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
