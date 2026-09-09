## Settings — "locker" layout: a tab rail on the left (Character / Controls / Audio /
## Match), the live 3D character in the middle (updates the instant you pick a colour),
## and the selected tab's options in a panel on the right.
extends Control

enum Tab { CHARACTER, CONTROLS, AUDIO, MATCH }

var tab := Tab.CHARACTER
var bg: MenuBg
var rail: VBoxContainer
var content: VBoxContainer
var name_plate: Label
var role_plate: Label
var _rail_buttons := {}

const TABS := [["CHARACTER", "user", Tab.CHARACTER], ["CONTROLS", "target", Tab.CONTROLS], ["AUDIO", "wifi", Tab.AUDIO], ["MATCH", "globe", Tab.MATCH]]

func _ready() -> void:
	# Pass-through so finger drags reach the 3D hero (in MenuBg, behind this UI).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg = MenuBg.new()
	add_child(bg)
	bg.set_hero(0.36, 0.98, 1.0, 0.98)
	bg.set_drag(true)
	var vp := get_viewport().get_visible_rect().size

	# header — premium "LOCKER" wordmark with an accent bar + a DONE button
	var hx := 40.0
	var hdr := UI.label("LOCKER", 34, UI.TEXT)
	hdr.position = Vector2(hx, 22)
	add_child(hdr)
	var hbar := ColorRect.new()
	hbar.color = UI.ORANGE
	hbar.position = Vector2(hx + 2, 66)
	hbar.size = Vector2(150, 4)
	hbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbar)
	var hsub := UI.label("EQUIP YOUR OPERATOR", 13, UI.CYAN)
	hsub.position = Vector2(hx + 168, 40)
	add_child(hsub)
	var done := Button.new()
	done.text = "DONE"
	done.add_theme_font_size_override("font_size", 19)
	done.position = Vector2(vp.x - 150, 22)
	done.size = Vector2(122, 52)
	UI.style_button(done, "primary", 26.0)
	done.pressed.connect(_close)
	add_child(done)

	# left: tab rail
	rail = VBoxContainer.new()
	rail.position = Vector2(40, 108)
	rail.add_theme_constant_override("separation", 12)
	add_child(rail)
	for t in TABS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 60)
		b.pressed.connect(_set_tab.bind(t[2]))
		rail.add_child(b)
		var stripe := ColorRect.new()
		stripe.color = UI.CYAN
		stripe.position = Vector2(0, 14); stripe.size = Vector2(4, 32)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stripe.name = "stripe"
		b.add_child(stripe)
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 18
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var g := UI.glyph(t[1], UI.CYAN, 13)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(g)
		var l := UI.label(t[0], 16, UI.TEXT)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		_rail_buttons[t[2]] = b

	# centre: rotate hint + a glass name/role plate under the hero's feet
	var rothint := UI.label("↺  DRAG TO ROTATE", 13, Color(1, 1, 1, 0.5), false, HORIZONTAL_ALIGNMENT_CENTER)
	rothint.anchor_left = 0.20; rothint.anchor_right = 0.54
	rothint.anchor_top = 0.855; rothint.anchor_bottom = 0.855
	rothint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rothint)
	var plate := Panel.new()
	plate.anchor_left = 0.20; plate.anchor_right = 0.54
	plate.anchor_top = 0.885; plate.anchor_bottom = 0.885
	plate.offset_left = 40; plate.offset_right = -40
	plate.offset_top = 0; plate.offset_bottom = 66
	var psb := UI.glass(0.10, 16.0, Color(UI.CYAN.r, UI.CYAN.g, UI.CYAN.b, 0.4), 1)
	plate.add_theme_stylebox_override("panel", psb)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	name_plate = UI.label(Settings.resolved_name(), 22, UI.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	name_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_plate.offset_top = 8
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(name_plate)
	role_plate = UI.label("", 13, UI.CYAN, false, HORIZONTAL_ALIGNMENT_CENTER)
	role_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	role_plate.offset_top = 38
	role_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(role_plate)

	# right: content panel
	var pc := PanelContainer.new()
	pc.anchor_left = 0.535; pc.anchor_right = 1.0
	pc.anchor_top = 0.0; pc.anchor_bottom = 1.0
	pc.offset_left = 0; pc.offset_right = -24
	pc.offset_top = 92; pc.offset_bottom = -22
	var sb := UI.glass(0.06, 22.0)
	sb.set_content_margin_all(20)
	pc.add_theme_stylebox_override("panel", sb)
	add_child(pc)
	# ScrollContainer must be the PanelContainer's ONLY child (a 2nd child breaks its
	# layout and the scroll). Vertical touch-drag scroll works over the cards.
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pc.add_child(sc)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# NOTE: do NOT set vertical EXPAND_FILL — it clamps content to the ScrollContainer
	# height and kills scrolling. Content must keep its natural (tall) minimum size.
	content.add_theme_constant_override("separation", 12)
	sc.add_child(content)
	# soft bottom fade — added to the screen (NOT inside the PanelContainer) so it can't
	# interfere with the scroll; it just tapers scrolled-off cards for a finished look.
	var fade := TextureRect.new()
	fade.texture = UI.grad_tex([Color(0.05, 0.06, 0.11, 0.0), Color(0.05, 0.06, 0.11, 0.92)])
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.anchor_left = 0.535; fade.anchor_right = 1.0
	fade.anchor_top = 1.0; fade.anchor_bottom = 1.0
	fade.offset_left = 20; fade.offset_right = -44
	fade.offset_top = -60; fade.offset_bottom = -22
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

	if OS.has_environment("CP_TAB"):
		tab = int(OS.get_environment("CP_TAB")) as Tab
	_set_tab(tab)

	if OS.has_environment("CP_SETSHOT"):
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("CP_SETSHOT"))
		get_tree().quit()

func _close() -> void:
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _set_tab(t: Tab) -> void:
	tab = t
	for k in _rail_buttons:
		var b: Button = _rail_buttons[k]
		UI.style_button(b, "blue" if k == t else "dark", 16.0)
		var s := b.get_node_or_null("stripe")
		if s:
			s.visible = k == t
	_refresh()

func _refresh() -> void:
	for c in content.get_children():
		c.queue_free()
	match tab:
		Tab.CHARACTER: _build_character()
		Tab.CONTROLS: _build_controls()
		Tab.AUDIO: _build_audio()
		_: _build_match()
	_sync_hero()

func _sync_hero() -> void:
	if bg:
		bg.set_hero_colors(Settings.skin_jacket, Settings.skin_accent)
	if name_plate:
		name_plate.text = Settings.resolved_name()
	if role_plate:
		var ch := _selected_char()
		role_plate.text = "%s  ·  %s" % [str(ch.get("tag", "Operator")).to_upper(), str(ch.get("tier", ""))]
		role_plate.modulate = ch.get("col", UI.CYAN)

func _selected_char() -> Dictionary:
	for c in Settings.CHARACTERS:
		if str(c.get("id", "")) == Settings.char_id:
			return c
	return Settings.CHARACTERS[0]

func _save_and_sync() -> void:
	Settings.resolve_skin()
	Settings.save_cfg()
	_sync_hero()

# MARK: character tab

func _build_character() -> void:
	_title("Characters", "Your name, and the operator you take into battle")
	# name field (compact, labelled)
	content.add_child(UI.heading("Player name"))
	var le := LineEdit.new()
	le.text = Settings.player_name
	le.placeholder_text = "Your name"
	le.max_length = 14
	le.add_theme_font_size_override("font_size", 20)
	le.custom_minimum_size = Vector2(0, 48)
	le.text_changed.connect(func(t: String) -> void:
		Settings.player_name = t
		Settings.save_cfg()
		_sync_hero())
	content.add_child(le)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	content.add_child(head)
	head.add_child(UI.heading("Choose operator"))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var owned_n := 0
	for c in Settings.CHARACTERS:
		if bool(c.get("owned", false)):
			owned_n += 1
	var cnt := UI.label("%d / %d" % [owned_n, Settings.CHARACTERS.size()], 13, UI.MUTED)
	cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cnt)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for ch in Settings.CHARACTERS:
		grid.add_child(_char_card(ch))
	var pad := Control.new()          # breathing room so the last row clears the bottom fade
	pad.custom_minimum_size = Vector2(0, 30)
	content.add_child(pad)

## A finished locker card: a tier-tinted portrait with a bold monogram, a top ribbon
## (tier left / status right), and a dark scrim footer with name + role. Locked cards
## dim and show a lock. Tapping an owned card equips it.
func _char_card(ch: Dictionary) -> Control:
	var owned := bool(ch.get("owned", false))
	var selected := owned and Settings.char_id == str(ch.get("id", ""))
	var col: Color = ch.get("col", UI.CYAN)
	var nm := str(ch.get("name", "?"))
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 150)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_contents = true
	btn.disabled = not owned
	var border: Color = col if selected else Color(1, 1, 1, 0.10)
	var sb := UI.glass(0.05, 16.0, border, 3 if selected else 1); sb.set_content_margin_all(0)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", UI.glass(0.10, 16.0, col if owned else border, 3))
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.add_theme_stylebox_override("disabled", sb)
	if owned:
		btn.pressed.connect(func() -> void:
			Settings.char_id = str(ch.get("id", "bravo"))
			Settings.save_cfg()
			if bg:
				bg.set_hero_char(Settings.char_id)
			_refresh())

	# full-card tier-tinted portrait (diagonal-ish tint via vertical gradient)
	var port := TextureRect.new()
	port.texture = UI.grad_tex([Color(col.r * 0.9, col.g * 0.9, col.b * 0.9, 0.6), Color(col.r * 0.16, col.g * 0.16, col.b * 0.22, 0.95)])
	port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	port.stretch_mode = TextureRect.STRETCH_SCALE
	port.set_anchors_preset(Control.PRESET_FULL_RECT)
	port.offset_left = 3; port.offset_top = 3; port.offset_right = -3; port.offset_bottom = -3
	port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(port)
	# real rendered character portrait if we have one, else a bold monogram watermark
	var pth := "res://assets/real/chars/portraits/%s.png" % str(ch.get("id", ""))
	if ResourceLoader.exists(pth):
		var pic := TextureRect.new()
		pic.texture = load(pth)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.offset_left = 4; pic.offset_top = 2; pic.offset_right = -4; pic.offset_bottom = -26
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not owned:
			pic.modulate = Color(0.5, 0.5, 0.55)
		btn.add_child(pic)
	else:
		var mono := UI.label(nm.substr(0, 1).to_upper(), 84, Color(1, 1, 1, 0.16))
		mono.set_anchors_preset(Control.PRESET_CENTER)
		mono.offset_left = -34; mono.offset_top = -70; mono.offset_right = 34
		mono.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(mono)
	# dark scrim at the bottom for readable text
	var scrim := TextureRect.new()
	scrim.texture = UI.grad_tex([Color(0, 0, 0, 0.0), Color(0.02, 0.03, 0.06, 0.82)])
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	scrim.offset_left = 3; scrim.offset_right = -3; scrim.offset_top = -70; scrim.offset_bottom = -3
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(scrim)
	# top ribbon: tier (left)
	var ribbon := UI.pill(str(ch.get("tier", "")), col, 11)
	ribbon.position = Vector2(12, 12)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(ribbon)
	# footer: name + role
	var name_l := UI.label(nm, 21, UI.TEXT if owned else Color(1, 1, 1, 0.65))
	name_l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	name_l.offset_left = 14; name_l.offset_top = -46; name_l.offset_right = 200
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_l)
	var role_l := UI.label(str(ch.get("tag", "")), 13, Color(col.r, col.g, col.b, 0.95) if owned else UI.MUTED)
	role_l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	role_l.offset_left = 14; role_l.offset_top = -24; role_l.offset_right = 200
	role_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(role_l)

	if selected:
		var badge := UI.pill("✓ EQUIPPED", UI.GREEN, 11)
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -118; badge.offset_top = 12; badge.offset_right = -12
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(badge)
	elif not owned:
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.03, 0.06, 0.5)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.offset_left = 3; dim.offset_top = 3; dim.offset_right = -3; dim.offset_bottom = -3
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(dim)
		var lk := UI.label("🔒", 26, Color(1, 1, 1, 0.9), false, HORIZONTAL_ALIGNMENT_CENTER)
		lk.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		lk.offset_left = -46; lk.offset_top = 8; lk.offset_right = -10
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lk)
	return btn

func _swatch(a: Color, b: Color, selected: bool, idx: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 62)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2 if selected else 1)
	sb.border_color = UI.CYAN if selected else Color(1, 1, 1, 0.08)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.pressed.connect(func() -> void:
		Settings.skin_mode = 0
		Settings.color_index = idx
		_save_and_sync()
		_refresh())
	var tr := TextureRect.new()
	tr.texture = UI.grad_tex([a, b])
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 10; tr.offset_right = -10; tr.offset_top = 10; tr.offset_bottom = -10
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(tr)
	if selected:
		var chk := UI.label("✓", 22, Color.WHITE, false, HORIZONTAL_ALIGNMENT_CENTER)
		chk.set_anchors_preset(Control.PRESET_FULL_RECT)
		chk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.add_child(chk)
	return btn

func _army_chip(nm: String, jacket: Color, accent: Color, selected: bool, idx: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 54)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(btn, "blue" if selected else "ghost", 14.0)
	btn.pressed.connect(func() -> void:
		Settings.skin_mode = 1
		Settings.army_index = idx
		_save_and_sync()
		_refresh())
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(h)
	var flag := Control.new()
	flag.custom_minimum_size = Vector2(34, 54)
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c1 := Shapes.circ(15, jacket); c1.position = Vector2(17, 27); flag.add_child(c1)
	var c2 := Shapes.circ(6, accent); c2.position = Vector2(17, 27); flag.add_child(c2)
	h.add_child(flag)
	var l := UI.label(nm, 17, Color(0.02, 0.06, 0.14) if selected else UI.TEXT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return btn

func _picker(label: String, prop: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	content.add_child(h)
	var l := UI.label(label, 17, UI.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var p := ColorPickerButton.new()
	p.color = Settings.get(prop)
	p.custom_minimum_size = Vector2(120, 42)
	p.edit_alpha = false
	p.color_changed.connect(func(col: Color) -> void:
		Settings.set(prop, col)
		Settings.skin_mode = 2
		_save_and_sync())
	h.add_child(p)

# MARK: controls tab

func _build_controls() -> void:
	_title("Controls", "How the touch screen plays")
	content.add_child(_layout_diagram())
	var cust := Button.new()
	cust.text = "CUSTOMIZE BUTTONS  ›"
	cust.custom_minimum_size = Vector2(0, 50)
	cust.add_theme_font_size_override("font_size", 17)
	UI.style_button(cust, "primary", 14.0)
	cust.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/HudEditor.tscn"))
	content.add_child(cust)
	_hint("Drag FIRE / JUMP / RELOAD / GRENADE anywhere on the screen and pick their size")
	_switch("Left-handed", "Move on the right, look on the left", "left_handed")
	_switch("Auto-fire", "Shoots by itself when an enemy is in your crosshair", "auto_fire")
	content.add_child(UI.heading("Aim sensitivity"))
	_seg(["Low", "Normal", "High"], [0, 1, 2], Settings.aim_sens, func(v: int) -> void:
		Settings.aim_sens = v
		Settings.save_cfg()
		_refresh())
	_switch("Gyro aim", "Tilt the phone to fine-aim (like PUBG / Free Fire)", "gyro_aim")
	content.add_child(UI.heading("Gyro strength"))
	_seg(["Low", "Medium", "High"], [0.6, 1.0, 1.6], Settings.gyro_sens, func(v: float) -> void:
		Settings.gyro_sens = v
		Settings.save_cfg()
		_refresh())
	_hint("Right side: drag to look • FIRE buttons on both sides • JUMP: hold in the air = jetpack • R: reload")

## A small picture of the in-game HUD so the options make sense.
func _layout_diagram() -> Control:
	var c := PanelContainer.new()
	var sb := UI.glass(0.04, 14.0)
	sb.set_content_margin_all(10)
	c.add_theme_stylebox_override("panel", sb)
	var d := _Diagram.new()
	d.custom_minimum_size = Vector2(0, 150)
	d.left_handed = Settings.left_handed
	c.add_child(d)
	return c

class _Diagram:
	extends Control
	var left_handed := false
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.25))
		var f := ThemeDB.fallback_font
		var mx := w * (0.8 if left_handed else 0.2)
		var lx := w * (0.2 if left_handed else 0.8)
		# move stick
		draw_arc(Vector2(mx, h * 0.62), 26, 0, TAU, 32, Color(1, 1, 1, 0.5), 2, true)
		draw_circle(Vector2(mx, h * 0.62), 11, Color(1, 1, 1, 0.5))
		draw_string(f, Vector2(mx - 22, h * 0.62 + 46), "MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.MUTED)
		# look area
		var lr := Rect2(lx - w * 0.16, h * 0.15, w * 0.32, h * 0.45)
		draw_rect(lr, Color(0.33, 0.9, 1.0, 0.08))
		draw_rect(lr, Color(0.33, 0.9, 1.0, 0.5), false, 1.5)
		draw_string(f, Vector2(lr.position.x + 6, lr.position.y + 16), "DRAG = LOOK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.CYAN)
		# fire buttons
		var fx := w * (0.06 if left_handed else 0.94)
		draw_circle(Vector2(fx, h * 0.8), 15, Color(0.95, 0.35, 0.25, 0.7))
		draw_string(f, Vector2(fx - 12, h * 0.8 + 4), "FIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		var fx2 := w * (0.94 if left_handed else 0.06)
		draw_circle(Vector2(fx2, h * 0.45), 10, Color(0.95, 0.35, 0.25, 0.6))
		draw_circle(Vector2(fx, h * 0.45), 11, Color(1, 1, 1, 0.25))
		draw_string(f, Vector2(fx - 13, h * 0.45 + 4), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
		# crosshair
		draw_circle(Vector2(w / 2.0, h / 2.0), 2.5, Color.WHITE)

# MARK: audio tab

func _build_audio() -> void:
	_title("Audio", "Sound effects and music")
	_switch("Sound effects", "Guns, footsteps, reloads, explosions", "sound_on")
	_switch("Music", "Menu and battle tracks", "music_on")
	_hint("You can also toggle these from the pause menu during a match")

# MARK: match tab

func _build_match() -> void:
	_title("Match", "Defaults for practice and the rooms you host")
	content.add_child(UI.heading("Bot difficulty (practice)"))
	_seg(["Easy", "Normal", "Hard", "Insane"], [0, 1, 2, 3], Settings.bot_level, func(v: int) -> void:
		Settings.bot_level = v
		Settings.save_cfg()
		_refresh())
	content.add_child(UI.heading("Fire bullets"))
	_seg(["Limited", "Unlimited"], [false, true], Settings.unlimited_ammo, func(v: bool) -> void:
		Settings.unlimited_ammo = v
		Settings.save_cfg()
		_refresh())
	_hint("Limited: guns carry a magazine + reserve, the rifle is always ∞  •  the host's choice applies to everyone")
	content.add_child(UI.heading("Kills to win (multiplayer)"))
	_stepper()

# MARK: widgets

func _title(txt: String, sub: String) -> void:
	content.add_child(UI.label(txt, 24, UI.TEXT, true))
	content.add_child(UI.bar(64, 4))
	content.add_child(UI.label(sub, 13, UI.MUTED))

func _switch(label: String, subtitle: String, prop: String) -> void:
	var row := PanelContainer.new()
	var rsb := UI.glass(0.04, 12.0, Color(1, 1, 1, 0.06))
	rsb.content_margin_left = 14; rsb.content_margin_right = 10
	rsb.content_margin_top = 8; rsb.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", rsb)
	content.add_child(row)
	var h := HBoxContainer.new()
	row.add_child(h)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 1)
	h.add_child(col)
	col.add_child(UI.label(label, 18, UI.TEXT))
	if subtitle != "":
		col.add_child(UI.label(subtitle, 12, UI.MUTED))
	var cb := CheckButton.new()
	cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cb.button_pressed = bool(Settings.get(prop))
	cb.toggled.connect(func(v: bool) -> void:
		Settings.set(prop, v)
		if prop == "sound_on":
			Audio.set_sound(v)
		elif prop == "music_on":
			Audio.set_music(v)
		Settings.save_cfg()
		if prop == "left_handed":
			_refresh())
	h.add_child(cb)

func _seg(options: Array, values: Array, cur, on_pick: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	content.add_child(h)
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		UI.style_button(b, "blue" if cur == values[i] else "ghost", 12.0)
		b.pressed.connect(on_pick.bind(values[i]))
		h.add_child(b)

func _stepper() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	content.add_child(h)
	var l := UI.label("%d kills" % Settings.kills_to_win, 20, UI.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	for step in [-1, 1]:
		var b := Button.new()
		b.text = "−" if step < 0 else "+"
		b.custom_minimum_size = Vector2(56, 44)
		b.add_theme_font_size_override("font_size", 24)
		UI.style_button(b, "ghost", 12.0)
		b.pressed.connect(func() -> void:
			Settings.kills_to_win = clampi(Settings.kills_to_win + step, 3, 30)
			Settings.save_cfg()
			_refresh())
		h.add_child(b)

func _hint(txt: String) -> void:
	var l := UI.label(txt, 12, UI.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(l)
