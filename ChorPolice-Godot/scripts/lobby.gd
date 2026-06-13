## Lobby / main menu — iOS-style two-column main screen (branding + your character on
## the left, icon cards on the right, settings gear) plus Host/Join sub-screens.
extends Control

enum Screen { MAIN, HOST, JOIN, WAIT }

var screen := Screen.MAIN
var sel_map := 0
var sel_mode := 0
var sel_minutes := 5
var sel_target := 10        # kills (DM/TDM) or flags (CTF) to win — host-set, applies to all

var root: Control
var panel: VBoxContainer
var status: Label

func _ready() -> void:
	randomize()
	if Settings.player_name.strip_edges() == "" and not OS.has_environment("CP_NAME"):
		Settings.player_name = _random_name()
		Settings.save_cfg()
	Net.local_name = OS.get_environment("CP_NAME") if OS.has_environment("CP_NAME") else Settings.player_name
	Net.color_index = Settings.color_index
	Net.jacket = Settings.skin_jacket
	if OS.has_environment("CP_MAP"):
		sel_map = int(OS.get_environment("CP_MAP"))
	if OS.has_environment("CP_MODE"):
		sel_mode = int(OS.get_environment("CP_MODE"))
	sel_target = 3 if sel_mode == 2 else Settings.kills_to_win

	Net.peers_changed.connect(_rebuild)
	Net.hosts_changed.connect(_on_hosts_changed)
	Net.connected.connect(_on_connected)
	Net.disconnected.connect(_on_disconnected)
	Net.match_started.connect(_on_started)

	_build_chrome()
	_rebuild()

	if OS.has_environment("CP_LSHOT"):
		await get_tree().create_timer(0.7).timeout
		get_viewport().get_texture().get_image().save_png("/tmp/cp_shot.png")
		get_tree().quit()
		return
	if OS.has_environment("CP_SHOT"):
		_practice()
	elif OS.has_environment("CP_HOST"):
		_host()
		await get_tree().create_timer(7.0).timeout
		if Net.is_host:
			_start()
	elif OS.has_environment("CP_JOIN"):
		_join_ip(OS.get_environment("CP_JOIN"))

func _build_chrome() -> void:
	add_child(MenuBg.new())
	Audio.play_track("menu")

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var vp := get_viewport().get_visible_rect().size
	var gear := Button.new()
	gear.text = "⚙"
	gear.add_theme_font_size_override("font_size", 28)
	gear.position = Vector2(vp.x - 78, 24)
	gear.size = Vector2(54, 54)
	gear.pressed.connect(_open_settings)
	add_child(gear)

	status = Label.new()
	status.anchor_top = 1.0; status.anchor_right = 1.0; status.anchor_bottom = 1.0
	status.offset_top = -40
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.modulate = Color(1, 1, 1, 0.7)
	add_child(status)

# MARK: screens

func _rebuild() -> void:
	if not root:
		return
	for c in root.get_children():
		c.queue_free()
	if screen == Screen.MAIN:
		_main()
	else:
		_centered()

func _main() -> void:
	var vp := get_viewport().get_visible_rect().size

	# LEFT — branding + your character
	var left := VBoxContainer.new()
	left.position = Vector2(56, vp.y * 0.2)
	left.add_theme_constant_override("separation", 2)
	root.add_child(left)
	_big(left, "CHOR")
	_big(left, "POLICE")
	var ul := ColorRect.new()
	ul.color = Color(0.30, 0.80, 0.40)
	ul.custom_minimum_size = Vector2(150, 7)
	left.add_child(ul)
	var sub := Label.new()
	sub.text = "Friends • WiFi & Bluetooth • Arena Shooter"
	sub.add_theme_font_size_override("font_size", 16)
	sub.modulate = Color(1, 1, 1, 0.8)
	left.add_child(sub)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 12)
	crow.custom_minimum_size = Vector2(0, 110)
	left.add_child(crow)
	crow.add_child(_op_control(0.62))
	var chip := Button.new()
	chip.custom_minimum_size = Vector2(230, 74)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0, 0, 0, 0.3)
	csb.set_corner_radius_all(20)
	csb.content_margin_left = 16; csb.content_margin_right = 16
	chip.add_theme_stylebox_override("normal", csb)
	chip.add_theme_stylebox_override("hover", csb)
	chip.add_theme_stylebox_override("pressed", csb)
	chip.pressed.connect(_open_settings)
	crow.add_child(chip)
	var cv := VBoxContainer.new()
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	cv.offset_left = 16
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(cv)
	var nm := Label.new()
	nm.text = Settings.resolved_name()
	nm.add_theme_font_size_override("font_size", 18)
	cv.add_child(nm)
	var ed := Label.new()
	ed.text = "Edit character  ✎"
	ed.add_theme_font_size_override("font_size", 12)
	ed.modulate = Color(1, 1, 1, 0.6)
	cv.add_child(ed)

	# RIGHT — menu cards
	var right := VBoxContainer.new()
	right.position = Vector2(vp.x - 460, vp.y * 0.16)
	right.add_theme_constant_override("separation", 14)
	root.add_child(right)
	_menu_card(right, "Practice", "Warm up vs bots", Color(0.20, 0.72, 0.36), _practice)
	_menu_card(right, "Host Game", "Start a nearby match", Color(0.18, 0.52, 0.92), _host)
	_menu_card(right, "Join Game", "Join friends nearby", Color(0.93, 0.57, 0.16), _join)

func _centered() -> void:
	# HOST shows match setup; JOIN and WAIT show the same iOS-style "JOINING GAME"
	# avatar screen (auto-connects to the first host found — no manual host ID).
	_lobby_two_col(screen == Screen.HOST)

func _lobby_two_col(host_mode: bool) -> void:
	var vp := get_viewport().get_visible_rect().size
	# LEFT — title + player avatar field
	var left := VBoxContainer.new()
	left.position = Vector2(48, vp.y * 0.09)
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	var t := Label.new()
	t.text = "HOSTING GAME" if host_mode else "JOINING GAME"
	t.add_theme_font_size_override("font_size", 30)
	left.add_child(t)
	var sub := Label.new()
	sub.text = "Friends on the same WiFi / hotspot connect automatically"
	sub.add_theme_font_size_override("font_size", 14)
	sub.modulate = Color(1, 1, 1, 0.6)
	left.add_child(sub)
	_avatar_field(left, Vector2(vp.x * 0.46, vp.y * 0.52))
	var stat := Label.new()
	stat.text = "%d players ready" % Net.players.size() if Net.players.size() > 1 else "Searching for players nearby…"
	stat.add_theme_font_size_override("font_size", 14)
	stat.modulate = Color(1, 1, 1, 0.6)
	left.add_child(stat)
	# RIGHT — match setup (host) or waiting (client)
	var right := VBoxContainer.new()
	right.position = Vector2(vp.x * 0.57, vp.y * 0.18)
	right.add_theme_constant_override("separation", 12)
	root.add_child(right)
	panel = right
	if host_mode:
		_btn("Mode:  %s" % _mode_name(sel_mode), _cycle_mode)
		_btn("Map:  %s" % Maps.get_map(sel_map)["name"], _cycle_map)
		_btn(("Flags to win:  %d" if sel_mode == 2 else "Kills to win:  %d") % sel_target, _cycle_target)
		_btn("Time:  %d min" % sel_minutes, _cycle_time)
		_btn("START MATCH", _start)
	else:
		_label("Waiting for the host to start…" if Net.players.has(Net.my_id()) else "Searching for a host nearby…", 18)
	_btn("Back", _back)

func _on_hosts_changed() -> void:
	# Auto-connect to the first host we discover — no manual host ID (iOS-style).
	if screen == Screen.JOIN and not Net.active and not Net.hosts.is_empty():
		_join_ip(Net.hosts.keys()[0])
	else:
		_rebuild()

func _avatar_field(parent: Node, fsize: Vector2) -> void:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = fsize
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(16)
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 18)
	flow.add_theme_constant_override("v_separation", 16)
	pc.add_child(flow)
	# Always show YOUR avatar (from Settings) even before connecting, like iOS.
	if not Net.players.has(Net.my_id()):
		flow.add_child(_self_bubble())
	for id in Net.players:
		flow.add_child(_bubble(id))

func _bubble(id: int) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var disc := Control.new()
	disc.custom_minimum_size = Vector2(76, 78)
	var jak := Net.jacket_of(id)
	var ring := Shapes.circ(36, Color(jak.r, jak.g, jak.b, 0.22))
	ring.position = Vector2(38, 38)
	disc.add_child(ring)
	var op := Player.new()
	op.is_remote = true
	op.skin_jacket = jak
	op.skin_accent = jak.lightened(0.45)
	op.z_index = 10
	op.scale = Vector2(0.42, 0.42)
	op.position = Vector2(38, 66)
	disc.add_child(op)
	var setup := func() -> void:
		op.set_aim(0.0)
		op._overlay_visible(false)
	if op.is_node_ready():
		setup.call()
	else:
		op.ready.connect(setup)
	v.add_child(disc)
	var l := Label.new()
	l.text = Net.name_of(id) + (" (You)" if id == Net.my_id() else "")
	l.add_theme_font_size_override("font_size", 13)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v

func _self_bubble() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var disc := Control.new()
	disc.custom_minimum_size = Vector2(76, 78)
	var jak: Color = Settings.skin_jacket
	var ring := Shapes.circ(36, Color(jak.r, jak.g, jak.b, 0.22))
	ring.position = Vector2(38, 38)
	disc.add_child(ring)
	var op := Player.new()
	op.is_remote = true
	op.skin_jacket = Settings.skin_jacket
	op.skin_accent = Settings.skin_accent
	op.skin_helmet = Settings.skin_helmet
	op.skin_pants = Settings.skin_pants
	op.skin_tone = Settings.skin_tone
	op.z_index = 10
	op.scale = Vector2(0.42, 0.42)
	op.position = Vector2(38, 66)
	disc.add_child(op)
	var setup := func() -> void:
		op.set_aim(0.0)
		op._overlay_visible(false)
	if op.is_node_ready():
		setup.call()
	else:
		op.ready.connect(setup)
	v.add_child(disc)
	var l := Label.new()
	l.text = Settings.resolved_name() + " (You)"
	l.add_theme_font_size_override("font_size", 13)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v

# MARK: actions

func _open_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _practice() -> void:
	Net.leave()
	MatchCfg.is_multiplayer = false
	MatchCfg.map_index = sel_map
	MatchCfg.mode = 0
	MatchCfg.bot_level = Settings.bot_level
	MatchCfg.unlimited_ammo = Settings.unlimited_ammo
	MatchCfg.local_team = -1
	_goto_game()

func _host() -> void:
	if Net.host():
		Net.match_cfg = {"map": sel_map}
		screen = Screen.HOST
		_set_status("Hosting — others on the same WiFi can Join")
	else:
		_set_status("Could not host (port busy?)")
	_rebuild()

func _join() -> void:
	Net.start_browse()
	screen = Screen.JOIN
	_set_status("")
	_rebuild()

func _join_ip(ip: String) -> void:
	Net.stop_browse()
	if Net.join(ip):
		_set_status("Connecting to %s…" % ip)
	else:
		_set_status("Could not connect to %s" % ip)
	_rebuild()

func _start() -> void:
	var cfg := {
		"map": sel_map, "mode": sel_mode,
		"target": sel_target,
		"minutes": sel_minutes, "unlimited": Settings.unlimited_ammo,
		"assign": _team_assign(),
	}
	Net.start_match(cfg)

func _mode_name(m: int) -> String:
	return ["Deathmatch", "Team Deathmatch", "Capture the Flag"][m]

func _team_assign() -> Dictionary:
	var a := {}
	if sel_mode >= 1:
		var i := 0
		for id in Net.players:
			a[str(id)] = i % 2
			i += 1
	return a

func _back() -> void:
	Net.leave()
	Net.stop_browse()
	screen = Screen.MAIN
	_set_status("")
	_rebuild()

func _cycle_map() -> void:
	sel_map = (sel_map + 1) % Maps.count()
	Net.match_cfg = {"map": sel_map}
	_rebuild()

func _cycle_mode() -> void:
	sel_mode = (sel_mode + 1) % 3
	sel_target = 3 if sel_mode == 2 else Settings.kills_to_win   # sensible default per mode
	_rebuild()

func _cycle_target() -> void:
	if sel_mode == 2:
		sel_target = (sel_target % 10) + 1          # 1..10 flags
	else:
		sel_target += 5
		if sel_target > 30:
			sel_target = 5                          # 5..30 kills
	_rebuild()

func _cycle_time() -> void:
	sel_minutes = (sel_minutes % 10) + 1
	_rebuild()

func _on_connected() -> void:
	screen = Screen.WAIT
	_set_status("Connected")
	_rebuild()

func _on_disconnected() -> void:
	screen = Screen.MAIN
	_set_status("Disconnected")
	_rebuild()

func _on_started(cfg: Dictionary) -> void:
	MatchCfg.is_multiplayer = true
	MatchCfg.apply_start(cfg)
	if int(cfg.get("mode", 0)) >= 1:
		MatchCfg.local_team = int(cfg.get("assign", {}).get(str(Net.my_id()), 0))
	else:
		MatchCfg.local_team = -1
	_goto_game()

func _goto_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

# MARK: widgets

func _big(parent: Node, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 66)
	parent.add_child(l)

func _op_control(scl: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(90, 110)
	var op := Player.new()
	op.is_remote = true
	op.skin_jacket = Settings.skin_jacket
	op.skin_accent = Settings.skin_accent
	op.skin_helmet = Settings.skin_helmet
	op.skin_pants = Settings.skin_pants
	op.skin_tone = Settings.skin_tone
	op.z_index = 10
	op.scale = Vector2(scl, scl)
	op.position = Vector2(45, 100)
	c.add_child(op)
	var setup := func() -> void:
		op.set_aim(-0.2)
		op._overlay_visible(false)
	if op.is_node_ready():
		setup.call()
	else:
		op.ready.connect(setup)
	return c

func _menu_card(parent: Node, title: String, subtitle: String, accent: Color, cb: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(430, 96)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.10)
	sb.set_border_width_all(2)
	sb.border_color = accent
	sb.set_corner_radius_all(16)
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate()
	hov.bg_color = Color(1, 1, 1, 0.18)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.pressed.connect(cb)
	parent.add_child(b)

	# everything laid out by an HBox so icon / text / chevron stay vertically centred
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 20.0
	hb.offset_right = -18.0
	hb.add_theme_constant_override("separation", 16)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(50, 50)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c1 := Shapes.circ(24, accent)
	c1.position = Vector2(25, 25)
	icon.add_child(c1)
	var c2 := Shapes.circ(8, Color.WHITE)
	c2.position = Vector2(25, 25)
	icon.add_child(c2)
	hb.add_child(icon)

	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_theme_constant_override("separation", 2)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 24)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(tl)
	var st := Label.new()
	st.text = subtitle
	st.add_theme_font_size_override("font_size", 14)
	st.modulate = Color(1, 1, 1, 0.65)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(st)

	var ch := Label.new()
	ch.text = "›"
	ch.add_theme_font_size_override("font_size", 30)
	ch.modulate = Color(1, 1, 1, 0.5)
	ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(ch)

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 50)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	panel.add_child(b)
	return b

func _label(text: String, fsize := 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(l)
	return l

func _set_status(s: String) -> void:
	if status:
		status.text = s

func _random_name() -> String:
	var pool := ["Tiger", "Sher", "Raja", "Veer", "Bunty", "Ace", "Hero", "Bravo"]
	return pool[randi() % pool.size()] + str(randi() % 90 + 10)

func _local_ip() -> String:
	var best := ""
	for a in IP.get_local_addresses():
		if ":" in a or a == "127.0.0.1":
			continue
		if a.begins_with("192.168."):
			return a
		if best == "":
			best = a
	return best if best != "" else "127.0.0.1"
