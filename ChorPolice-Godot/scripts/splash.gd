## Splash — animated intro (mirrors the iOS SplashView): the logo pops in over the
## live menu backdrop, a subtitle fades up, then a pulsing "TAP TO START" waits.
## Any tap → the main menu (Lobby).
extends Control

var can_tap := false

func _ready() -> void:
	# automation / screenshot hooks skip straight to the menu (Lobby handles them)
	for k in ["CP_SHOT", "CP_HOST", "CP_JOIN", "CP_LSHOT", "CP_OCREATE", "CP_OJOIN"]:
		if OS.has_environment(k):
			_go()
			return

	add_child(MenuBg.new())
	Audio.play_track("menu")

	var vp := get_viewport().get_visible_rect().size

	# centre hero — struts in, then idly jetpack-hops (added before the labels so text stays on top)
	var hy := vp.y * 0.62
	var hero := Player.new()
	hero.is_remote = true
	hero.skin_jacket = Color(0.27, 0.55, 0.97)
	hero.skin_accent = Color(0.5, 0.95, 1.0)
	hero.z_index = 10
	add_child(hero)
	hero.position = Vector2(vp.x / 2.0, hy)
	hero.set_aim(-0.3)
	hero._overlay_visible(false)
	hero.modulate.a = 0.0
	var th := create_tween()
	th.tween_interval(0.7)
	th.tween_property(hero, "modulate:a", 1.0, 0.4)
	th.tween_callback(func() -> void:
		var hop := create_tween().set_loops()
		hop.tween_callback(hero.set_thrust.bind(true))
		hop.tween_property(hero, "position:y", hy - 42.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		hop.tween_callback(hero.set_thrust.bind(false))
		hop.tween_property(hero, "position:y", hy, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		hop.tween_interval(1.0))

	var title := _label("CHOR POLICE", 64, Color.WHITE)
	title.anchor_top = 0.30; title.anchor_bottom = 0.30
	title.pivot_offset = Vector2(vp.x / 2.0, 42)
	title.scale = Vector2(0.5, 0.5)
	title.modulate.a = 0.0

	var sub := _label("Friends • WiFi • Arena Shooter", 18, Color(1, 1, 1, 0.85))
	sub.anchor_top = 0.42; sub.anchor_bottom = 0.42
	sub.modulate.a = 0.0

	var tap := _label("TAP TO START", 26, Color.WHITE)
	tap.anchor_top = 0.78; tap.anchor_bottom = 0.78
	tap.modulate.a = 0.0

	# logo spring-in
	var t1 := create_tween().set_parallel()
	t1.tween_property(title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t1.tween_property(title, "modulate:a", 1.0, 0.4)
	# subtitle
	create_tween().tween_interval(0.45)
	var t2 := create_tween()
	t2.tween_interval(0.45)
	t2.tween_property(sub, "modulate:a", 1.0, 0.5)
	# tap-to-start fade in, then pulse
	var t3 := create_tween()
	t3.tween_interval(1.0)
	t3.tween_property(tap, "modulate:a", 1.0, 0.4)
	t3.tween_callback(func() -> void:
		can_tap = true
		var pulse := create_tween().set_loops()
		pulse.tween_property(tap, "modulate:a", 0.4, 0.8).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(tap, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE))

	if OS.has_environment("CP_SSHOT"):       # screenshot the splash
		await get_tree().create_timer(1.7).timeout
		get_viewport().get_texture().get_image().save_png("/tmp/cp_shot.png")
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if not can_tap:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		can_tap = false
		_go()

func _go() -> void:
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _label(txt: String, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", fsize)
	l.modulate = col
	l.anchor_right = 1.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
