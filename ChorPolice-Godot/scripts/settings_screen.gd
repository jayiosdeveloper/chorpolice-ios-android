## Settings screen — full-screen, two-column: "Your character" on the left, "Game"
## options on the right. Same options as before, spread across the whole screen.
extends Control

var box: VBoxContainer        # the column currently being built into
var box_left: VBoxContainer
var box_right: VBoxContainer

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = _grad([Color(0.08, 0.09, 0.23), Color(0.20, 0.16, 0.34)])
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vp := get_viewport().get_visible_rect().size

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 34)
	title.position = Vector2(34, 22)
	add_child(title)

	var done := Button.new()
	done.text = "Done"
	done.add_theme_font_size_override("font_size", 20)
	done.position = Vector2(vp.x - 154, 22)
	done.size = Vector2(120, 48)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.20, 0.72, 0.36)
	dsb.set_corner_radius_all(24)
	done.add_theme_stylebox_override("normal", dsb)
	done.add_theme_stylebox_override("hover", dsb)
	done.add_theme_stylebox_override("pressed", dsb)
	done.pressed.connect(_close)
	add_child(done)

	# two columns filling the rest of the screen
	var cols := HBoxContainer.new()
	cols.set_anchors_preset(Control.PRESET_FULL_RECT)
	cols.offset_left = 26; cols.offset_right = -26
	cols.offset_top = 84; cols.offset_bottom = -22
	cols.add_theme_constant_override("separation", 18)
	add_child(cols)

	box_left = _column(cols)
	box_right = _column(cols)

	if OS.has_environment("CP_TAB"):
		Settings.skin_mode = int(OS.get_environment("CP_TAB"))
	if OS.has_environment("CP_COLOR"):
		Settings.skin_mode = 0
		Settings.color_index = int(OS.get_environment("CP_COLOR"))
		Settings.resolve_skin()
	_refresh()

	if OS.has_environment("CP_SETSHOT"):
		await get_tree().create_timer(0.7).timeout
		get_viewport().get_texture().get_image().save_png("/tmp/cp_shot.png")
		get_tree().quit()

func _column(parent: Node) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.06)
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(18)
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	sc.add_child(v)
	return v

func _close() -> void:
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _refresh() -> void:
	for c in box_left.get_children():
		c.queue_free()
	for c in box_right.get_children():
		c.queue_free()
	_build_left()
	_build_right()

# MARK: LEFT — your character

func _build_left() -> void:
	box = box_left
	_title("Your character")

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	box.add_child(top)
	top.add_child(_preview(Settings.skin_jacket, Settings.skin_jacket2, Settings.skin_accent,
		Settings.skin_helmet, Settings.skin_pants, Settings.skin_tone, 150, 0.95))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 8)
	top.add_child(info)
	_section_into(info, "Player name")
	var le := LineEdit.new()
	le.text = Settings.player_name
	le.placeholder_text = "Your name"
	le.add_theme_font_size_override("font_size", 18)
	le.text_changed.connect(func(t: String) -> void:
		Settings.player_name = t
		Settings.save_cfg())
	info.add_child(le)

	# full-width tab row (own line) so "Colors / Army / Custom" all fit, no truncation
	_seg(["Colors", "Army", "Custom"], [0, 1, 2], Settings.skin_mode, func(v: int) -> void:
		Settings.skin_mode = v
		Settings.resolve_skin()
		Settings.save_cfg()
		_refresh())

	match Settings.skin_mode:
		1:
			var grid := GridContainer.new()
			grid.columns = 5
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 10)
			box.add_child(grid)
			for i in Settings.ARMY.size():
				var u: Dictionary = Settings.ARMY[i]
				var j: Color = u["jacket"]
				grid.add_child(_tile(j, j, u["accent"], j, Color(j.r * 0.45, j.g * 0.45, j.b * 0.5),
					Color(0.82, 0.62, 0.45), u["name"], Settings.army_index == i, _pick_army.bind(i)))
		2:
			_section("Custom colours")
			_picker("Jacket", "custom_jacket")
			_picker("Helmet", "custom_helmet")
			_picker("Visor & glow", "custom_accent")
			_picker("Pants", "custom_pants")
			_picker("Skin tone", "custom_tone")
		_:
			var row := GridContainer.new()
			row.columns = 5
			row.add_theme_constant_override("h_separation", 8)
			row.add_theme_constant_override("v_separation", 10)
			box.add_child(row)
			for i in Settings.COLORS.size():
				var e: Dictionary = Settings.COLORS[i]
				var a: Color = e["a"]
				var bcol: Color = e["b"]
				row.add_child(_tile(a, bcol, Settings.accent_for(a), a, Color(a.r * 0.45, a.g * 0.45, a.b * 0.5),
					Color(0.86, 0.66, 0.5), "", Settings.skin_mode == 0 and Settings.color_index == i, _pick_color.bind(i)))

# MARK: RIGHT — game options

func _build_right() -> void:
	box = box_right
	_title("Game")
	_switch("Left-handed controls", "Move on the right, aim on the left", "left_handed")
	_switch("Sound effects", "", "sound_on")
	_switch("Music", "", "music_on")
	_section("Fire bullets")
	_seg(["Limited", "Unlimited"], [false, true], Settings.unlimited_ammo, func(v: bool) -> void:
		Settings.unlimited_ammo = v
		Settings.save_cfg()
		_refresh())
	_hint("Uzi / Shotgun / Sniper carry limited ammo (rifle is always ∞)")
	_hint("In multiplayer the host's choice applies to everyone")
	_section("Kills to win (multiplayer)")
	_stepper()

# MARK: skin widgets

func _pick_color(i: int) -> void:
	Settings.skin_mode = 0
	Settings.color_index = i
	Settings.resolve_skin()
	Settings.save_cfg()
	_refresh()

func _pick_army(i: int) -> void:
	Settings.skin_mode = 1
	Settings.army_index = i
	Settings.resolve_skin()
	Settings.save_cfg()
	_refresh()

func _picker(label: String, prop: String) -> void:
	var p := ColorPickerButton.new()
	p.color = Settings.get(prop)
	p.text = label
	p.custom_minimum_size = Vector2(0, 40)
	p.edit_alpha = false
	p.color_changed.connect(func(col: Color) -> void:
		Settings.set(prop, col)
		Settings.skin_mode = 2
		Settings.resolve_skin()
		Settings.save_cfg())
	box.add_child(p)

func _preview(j: Color, j2: Color, a: Color, h: Color, p: Color, tn: Color, height: float, scl: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(120, height)
	var bgp := StyleBoxFlat.new()
	bgp.bg_color = Color(1, 1, 1, 0.08)
	bgp.set_corner_radius_all(16)
	var pan := Panel.new()
	pan.set_anchors_preset(Control.PRESET_FULL_RECT)
	pan.add_theme_stylebox_override("panel", bgp)
	pan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(pan)
	var op := Player.new()
	op.is_remote = true
	op.skin_jacket = j; op.skin_jacket2 = j2; op.skin_accent = a; op.skin_helmet = h; op.skin_pants = p; op.skin_tone = tn
	op.z_index = 10
	op.scale = Vector2(scl, scl)
	op.position = Vector2(60, height - 16.0)
	c.add_child(op)
	var setup := func() -> void:
		op.set_aim(-0.2)
		op._overlay_visible(false)
	if op.is_node_ready():
		setup.call()
	else:
		op.ready.connect(setup)
	return c

func _tile(j: Color, j2: Color, a: Color, h: Color, p: Color, tn: Color, label: String, selected: bool, cb: Callable) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 88)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.20 if selected else 0.05)
	sb.set_corner_radius_all(12)
	if selected:
		sb.set_border_width_all(2)
		sb.border_color = Color.WHITE
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.pressed.connect(cb)
	var op := Player.new()
	op.is_remote = true
	op.skin_jacket = j; op.skin_jacket2 = j2; op.skin_accent = a; op.skin_helmet = h; op.skin_pants = p; op.skin_tone = tn
	op.z_index = 10
	op.scale = Vector2(0.4, 0.4)
	op.position = Vector2(36, 74)
	btn.add_child(op)
	var setup := func() -> void:
		op.set_aim(0.0)
		op._overlay_visible(false)
	if op.is_node_ready():
		setup.call()
	else:
		op.ready.connect(setup)
	v.add_child(btn)
	if label != "":
		var l := Label.new()
		l.text = label
		l.add_theme_font_size_override("font_size", 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate = Color(1, 1, 1, 1.0 if selected else 0.65)
		v.add_child(l)
	return v

# MARK: option widgets

func _switch(label: String, subtitle: String, prop: String) -> void:
	var h := HBoxContainer.new()
	box.add_child(h)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var lab := Label.new()
	lab.text = label
	lab.add_theme_font_size_override("font_size", 20)
	col.add_child(lab)
	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.add_theme_font_size_override("font_size", 13)
		sub.modulate = Color(1, 1, 1, 0.6)
		col.add_child(sub)
	var cb := CheckButton.new()
	cb.button_pressed = bool(Settings.get(prop))
	cb.toggled.connect(func(v: bool) -> void:
		Settings.set(prop, v)
		if prop == "sound_on":
			Audio.set_sound(v)
		elif prop == "music_on":
			Audio.set_music(v)
		Settings.save_cfg())
	h.add_child(cb)

func _seg(options: Array, values: Array, cur, on_pick: Callable) -> HBoxContainer:
	return _seg_into(box, options, values, cur, on_pick)

func _seg_into(parent: Node, options: Array, values: Array, cur, on_pick: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	parent.add_child(h)
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.custom_minimum_size = Vector2(0, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if cur == values[i]:
			b.modulate = Color(0.55, 0.9, 1.0)
		b.pressed.connect(on_pick.bind(values[i]))
		h.add_child(b)
	return h

func _stepper() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	box.add_child(h)
	var l := Label.new()
	l.text = "%d kills" % Settings.kills_to_win
	l.add_theme_font_size_override("font_size", 20)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(56, 44)
	minus.add_theme_font_size_override("font_size", 24)
	minus.pressed.connect(func() -> void:
		Settings.kills_to_win = maxi(3, Settings.kills_to_win - 1)
		Settings.save_cfg()
		_refresh())
	h.add_child(minus)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(56, 44)
	plus.add_theme_font_size_override("font_size", 24)
	plus.pressed.connect(func() -> void:
		Settings.kills_to_win = mini(30, Settings.kills_to_win + 1)
		Settings.save_cfg()
		_refresh())
	h.add_child(plus)

func _title(txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 22)
	box.add_child(l)

func _section(txt: String) -> void:
	_section_into(box, txt)

func _section_into(parent: Node, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = Color(1, 1, 1, 0.7)
	parent.add_child(l)

func _hint(txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(1, 1, 1, 0.5)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)

func _grad(colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 1)
	t.width = 256
	t.height = 256
	return t
