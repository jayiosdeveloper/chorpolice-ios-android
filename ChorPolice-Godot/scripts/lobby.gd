## Lobby / main menu — iOS-style two-column main screen (branding + your character on
## the left, icon cards on the right, settings gear) plus Host/Join sub-screens.
extends Control

enum Screen { MAIN, HOST, JOIN, WAIT, ONLINE, ON_LIST, ON_CREATE, ON_JOIN, ON_ROOM, ON_PLAYERS, ON_FRIENDS, ON_PROFILE }

var screen := Screen.MAIN
var sel_map := 0
var sel_mode := 0
var sel_minutes := 5
var sel_target := 10        # kills (DM/TDM) or flags (CTF) to win — host-set, applies to all

# online lobby state
var _quick := false
var _create_public := true
var _pw_edit: LineEdit
var _code_edit: LineEdit
var _jpw_edit: LineEdit
# social state
var _players_page := 0
var _profile_pid := ""
var _profile_data := {}

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
	Net.pid = Settings.player_id
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
	Net.rooms_changed.connect(_on_rooms_changed)
	Net.server_ready.connect(_on_server_ready)
	Net.online_error.connect(_on_online_error)
	Net.presence_changed.connect(_on_presence)
	Net.players_received.connect(_on_players)
	Net.friends_received.connect(_on_social_changed)
	Net.requests_received.connect(_on_social_changed)
	Net.friend_req_in.connect(_on_friend_req_in)
	Net.friend_accepted.connect(_on_friend_accepted)
	Net.profile_received.connect(_on_profile)

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
	elif OS.has_environment("CP_OCREATE") or OS.has_environment("CP_OJOIN"):
		_online()
	else:
		Net.online_connect()             # go online for presence/friends as soon as the menu opens

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
	if not root or not is_inside_tree():
		return
	for c in root.get_children():
		c.queue_free()
	match screen:
		Screen.MAIN: _main()
		Screen.ONLINE: _online_menu()
		Screen.ON_LIST: _online_list()
		Screen.ON_CREATE: _online_create()
		Screen.ON_JOIN: _online_joincode()
		Screen.ON_ROOM: _online_room()
		Screen.ON_PLAYERS: _online_players()
		Screen.ON_FRIENDS: _online_friends()
		Screen.ON_PROFILE: _online_profile()
		_: _centered()

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
	right.position = Vector2(vp.x - 460, vp.y * 0.11)
	right.add_theme_constant_override("separation", 12)
	root.add_child(right)
	_menu_card(right, "Practice", "Warm up vs bots", Color(0.20, 0.72, 0.36), _practice)
	_menu_card(right, "Host Game", "Nearby match (WiFi)", Color(0.18, 0.52, 0.92), _host)
	_menu_card(right, "Join Game", "Join nearby (WiFi)", Color(0.93, 0.57, 0.16), _join)
	_menu_card(right, "Online Game", ("%d players online" % Net.online_count) if Net.online_count > 0 else "Play over internet", Color(0.55, 0.45, 0.95), _online)

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

func _cfg() -> Dictionary:
	return {
		"map": sel_map, "mode": sel_mode,
		"target": sel_target,
		"minutes": sel_minutes, "unlimited": Settings.unlimited_ammo,
		"assign": _team_assign(),
	}

func _start() -> void:
	Net.start_match(_cfg())

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
	Net.online_connect()                 # back at the menu → go online again
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
	screen = Screen.ON_ROOM if Net.online else Screen.WAIT
	_set_status("")
	_rebuild()
	if Net.online and Net.is_owner and OS.has_environment("CP_OCREATE"):
		await get_tree().create_timer(7.0).timeout
		if Net.is_owner:
			_start()

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

# MARK: online lobby (over the WebSocket relay server)

func _online() -> void:
	Net.online_connect()
	screen = Screen.ONLINE
	_set_status("Connecting to server…")
	_rebuild()

func _goto(s: int) -> void:
	screen = s
	_set_status("")
	_rebuild()

func _online_back() -> void:        # sub-screen → online menu (stay connected)
	screen = Screen.ONLINE
	_set_status("")
	_rebuild()

func _leave_online() -> void:       # online menu → main (stay connected for presence)
	screen = Screen.MAIN
	_set_status("")
	_rebuild()

func _leave_room() -> void:         # room → online menu (stay connected)
	Net.leave_room()
	screen = Screen.ONLINE
	_set_status("")
	_rebuild()

func _quick_play() -> void:
	_quick = true
	_set_status("Finding a room…")
	Net.list_rooms()

func _online_menu() -> void:
	var vp := get_viewport().get_visible_rect().size
	var left := VBoxContainer.new()
	left.position = Vector2(56, vp.y * 0.2)
	left.add_theme_constant_override("separation", 4)
	root.add_child(left)
	_big(left, "ONLINE")
	var ul := ColorRect.new()
	ul.color = Color(0.55, 0.45, 0.95)
	ul.custom_minimum_size = Vector2(150, 7)
	left.add_child(ul)
	var sub := Label.new()
	sub.text = "Play with friends & players over the internet"
	sub.add_theme_font_size_override("font_size", 16)
	sub.modulate = Color(1, 1, 1, 0.8)
	left.add_child(sub)
	left.add_child(_op_control(0.6))
	var right := VBoxContainer.new()
	right.position = Vector2(vp.x - 460, vp.y * 0.12)
	right.add_theme_constant_override("separation", 12)
	root.add_child(right)
	_menu_card(right, "Quick Play", "Join any open room", Color(0.20, 0.72, 0.36), _quick_play)
	_menu_card(right, "Public Rooms", "Browse open rooms", Color(0.18, 0.52, 0.92), _goto.bind(Screen.ON_LIST))
	_menu_card(right, "Create Room", "Public or private", Color(0.55, 0.45, 0.95), _goto.bind(Screen.ON_CREATE))
	_menu_card(right, "Join with Code", "Enter a room code", Color(0.93, 0.57, 0.16), _goto.bind(Screen.ON_JOIN))
	_menu_card(right, "Players & Friends", "%d online" % Net.online_count, Color(0.30, 0.70, 0.95), _open_players)
	_back_button(_leave_online)

func _online_list() -> void:
	Net.list_rooms()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(540, 0)
	box.add_theme_constant_override("separation", 12)
	cc.add_child(box)
	var t := Label.new()
	t.text = "Public Rooms"
	t.add_theme_font_size_override("font_size", 28)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	if Net.rooms.is_empty():
		var e := Label.new()
		e.text = "No open rooms yet — create one or use Quick Play."
		e.add_theme_font_size_override("font_size", 15)
		e.modulate = Color(1, 1, 1, 0.6)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(e)
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(540, 360)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		box.add_child(scroll)
		var lst := VBoxContainer.new()
		lst.add_theme_constant_override("separation", 8)
		lst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(lst)
		for code in Net.rooms:
			var r: Dictionary = Net.rooms[code]
			var b := Button.new()
			b.custom_minimum_size = Vector2(520, 58)
			b.add_theme_font_size_override("font_size", 17)
			b.text = "%s      %d/%d      %s · %s" % [str(r.get("name", "Host")),
				int(r.get("players", 1)), int(r.get("max", 20)),
				_mode_name(int(r.get("mode", 0))), Maps.get_map(int(r.get("map", 0)))["name"]]
			b.pressed.connect(Net.join_room.bind(str(code), ""))
			lst.add_child(b)
	var rowc := CenterContainer.new()
	box.add_child(rowc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	rowc.add_child(row)
	var refresh := Button.new()
	refresh.text = "Refresh"
	refresh.custom_minimum_size = Vector2(160, 46)
	refresh.pressed.connect(Net.list_rooms)
	row.add_child(refresh)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 46)
	back.pressed.connect(_online_back)
	row.add_child(back)

func _online_create() -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	panel = VBoxContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.add_theme_constant_override("separation", 14)
	cc.add_child(panel)
	_label("Create Room", 28)
	var seg := CenterContainer.new()
	panel.add_child(seg)
	var segh := HBoxContainer.new()
	segh.add_theme_constant_override("separation", 10)
	seg.add_child(segh)
	var pub := Button.new()
	pub.text = "Public"
	pub.toggle_mode = true
	pub.button_pressed = _create_public
	pub.custom_minimum_size = Vector2(175, 48)
	pub.pressed.connect(func() -> void:
		_create_public = true
		_rebuild())
	segh.add_child(pub)
	var priv := Button.new()
	priv.text = "Private"
	priv.toggle_mode = true
	priv.button_pressed = not _create_public
	priv.custom_minimum_size = Vector2(175, 48)
	priv.pressed.connect(func() -> void:
		_create_public = false
		_rebuild())
	segh.add_child(priv)
	if not _create_public:
		_pw_edit = LineEdit.new()
		_pw_edit.placeholder_text = "Room password (optional)"
		_pw_edit.custom_minimum_size = Vector2(360, 46)
		panel.add_child(_pw_edit)
	_label("Public · max 20 players" if _create_public else "Private · share the code to invite", 14)
	var create := Button.new()
	create.text = "Create Room"
	create.custom_minimum_size = Vector2(360, 52)
	create.add_theme_font_size_override("font_size", 20)
	create.pressed.connect(_do_create)
	panel.add_child(create)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(360, 44)
	back.pressed.connect(_online_back)
	panel.add_child(back)

func _do_create() -> void:
	var pw := ""
	if _pw_edit and not _create_public:
		pw = _pw_edit.text.strip_edges()
	_set_status("Creating room…")
	Net.create_room(_create_public, pw, 20, _cfg())

func _online_joincode() -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	panel = VBoxContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_constant_override("separation", 14)
	cc.add_child(panel)
	_label("Join with Code", 28)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "Room code (e.g. ABC12)"
	_code_edit.custom_minimum_size = Vector2(360, 48)
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_code_edit)
	_jpw_edit = LineEdit.new()
	_jpw_edit.placeholder_text = "Password (if any)"
	_jpw_edit.custom_minimum_size = Vector2(360, 46)
	panel.add_child(_jpw_edit)
	var join := Button.new()
	join.text = "Join Room"
	join.custom_minimum_size = Vector2(360, 52)
	join.add_theme_font_size_override("font_size", 20)
	join.pressed.connect(_do_joincode)
	panel.add_child(join)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(360, 44)
	back.pressed.connect(_online_back)
	panel.add_child(back)

func _do_joincode() -> void:
	var code := _code_edit.text.strip_edges()
	if code == "":
		_set_status("Enter a room code")
		return
	var pw := _jpw_edit.text.strip_edges() if _jpw_edit else ""
	_set_status("Joining %s…" % code.to_upper())
	Net.join_room(code, pw)

func _online_room() -> void:
	var vp := get_viewport().get_visible_rect().size
	var left := VBoxContainer.new()
	left.position = Vector2(48, vp.y * 0.09)
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	var t := Label.new()
	t.text = "ROOM  %s" % Net.room_code
	t.add_theme_font_size_override("font_size", 30)
	left.add_child(t)
	var sub := Label.new()
	sub.text = "Share this code with friends to let them join"
	sub.add_theme_font_size_override("font_size", 14)
	sub.modulate = Color(1, 1, 1, 0.6)
	left.add_child(sub)
	_avatar_field(left, Vector2(vp.x * 0.46, vp.y * 0.52))
	var stat := Label.new()
	stat.text = "%d players in room" % Net.players.size()
	stat.add_theme_font_size_override("font_size", 14)
	stat.modulate = Color(1, 1, 1, 0.6)
	left.add_child(stat)
	var right := VBoxContainer.new()
	right.position = Vector2(vp.x * 0.57, vp.y * 0.16)
	right.add_theme_constant_override("separation", 12)
	root.add_child(right)
	panel = right
	if Net.is_owner:
		_btn("Mode:  %s" % _mode_name(sel_mode), _cycle_mode)
		_btn("Map:  %s" % Maps.get_map(sel_map)["name"], _cycle_map)
		_btn(("Flags to win:  %d" if sel_mode == 2 else "Kills to win:  %d") % sel_target, _cycle_target)
		_btn("Time:  %d min" % sel_minutes, _cycle_time)
		_btn("START MATCH", _start)
	else:
		_label("Waiting for the host to start…", 18)
	_btn("Leave", _leave_room)

func _on_rooms_changed() -> void:
	if _quick and not Net.active:
		_quick = false
		if Net.rooms.is_empty():
			Net.create_room(true, "", 20, _cfg())
		else:
			Net.join_room(str(Net.rooms.keys()[0]))
	elif OS.has_environment("CP_OJOIN") and not Net.active:
		if not Net.rooms.is_empty():
			Net.join_room(str(Net.rooms.keys()[0]))
		else:
			await get_tree().create_timer(1.0).timeout
			Net.list_rooms()
	elif screen == Screen.ON_LIST:
		_rebuild()

func _on_server_ready() -> void:
	_set_status("" if screen == Screen.MAIN else "Connected — choose a room")
	if OS.has_environment("CP_OCREATE"):
		Net.create_room(true, "", 20, _cfg())
	elif OS.has_environment("CP_OJOIN") or _quick:
		Net.list_rooms()
	elif screen == Screen.ON_LIST:
		Net.list_rooms()

func _on_online_error(code: String) -> void:
	var m := {"room_full": "Room is full", "bad_password": "Wrong password",
		"no_room": "Room not found", "not_owner": "Only the host can do that"}
	_set_status(str(m.get(code, code)))

func _back_button(cb: Callable) -> void:
	var b := Button.new()
	b.text = "Back"
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(120, 46)
	b.position = Vector2(48, get_viewport().get_visible_rect().size.y - 78)
	b.pressed.connect(cb)
	root.add_child(b)

# MARK: social — players online + friends

func _open_players() -> void:
	_players_page = 0
	screen = Screen.ON_PLAYERS
	Net.req_players(0)
	_rebuild()

func _open_friends() -> void:
	screen = Screen.ON_FRIENDS
	Net.req_friends()
	Net.req_requests()
	_rebuild()

func _open_profile(p: String) -> void:
	if p == "":
		return
	_profile_pid = p
	_profile_data = {}
	screen = Screen.ON_PROFILE
	Net.req_profile(p)
	_rebuild()

func _players_goto(p: int) -> void:
	_players_page = p
	Net.req_players(p)
	_rebuild()

func _online_players() -> void:
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(cc)
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(560, 0); box.add_theme_constant_override("separation", 10); cc.add_child(box)
	var t := Label.new(); t.text = "Players Online  (%d)" % Net.online_count
	t.add_theme_font_size_override("font_size", 26); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(t)
	var items: Array = Net.players_data.get("items", [])
	if items.is_empty():
		var e := Label.new(); e.text = "No other players online right now."
		e.add_theme_font_size_override("font_size", 15); e.modulate = Color(1, 1, 1, 0.6)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(e)
	else:
		var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(560, 340)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(scroll)
		var lst := VBoxContainer.new(); lst.add_theme_constant_override("separation", 8); lst.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(lst)
		for it in items:
			lst.add_child(_player_row(it, true))
	var pages := int(Net.players_data.get("pages", 1))
	if pages > 1:
		var prow := HBoxContainer.new(); prow.alignment = BoxContainer.ALIGNMENT_CENTER; prow.add_theme_constant_override("separation", 12); box.add_child(prow)
		var prev := Button.new(); prev.text = "‹ Prev"; prev.custom_minimum_size = Vector2(120, 44); prev.disabled = _players_page <= 0
		prev.pressed.connect(_players_goto.bind(_players_page - 1)); prow.add_child(prev)
		var pl := Label.new(); pl.text = "Page %d / %d" % [_players_page + 1, pages]; prow.add_child(pl)
		var nxt := Button.new(); nxt.text = "Next ›"; nxt.custom_minimum_size = Vector2(120, 44); nxt.disabled = _players_page >= pages - 1
		nxt.pressed.connect(_players_goto.bind(_players_page + 1)); prow.add_child(nxt)
	var frow := HBoxContainer.new(); frow.alignment = BoxContainer.ALIGNMENT_CENTER; frow.add_theme_constant_override("separation", 12); box.add_child(frow)
	var fb := Button.new(); fb.text = "Friends"; fb.custom_minimum_size = Vector2(160, 46); fb.pressed.connect(_open_friends); frow.add_child(fb)
	var bb := Button.new(); bb.text = "Back"; bb.custom_minimum_size = Vector2(160, 46); bb.pressed.connect(_online_back); frow.add_child(bb)

func _online_friends() -> void:
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(cc)
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(560, 0); box.add_theme_constant_override("separation", 10); cc.add_child(box)
	var t := Label.new(); t.text = "Friends"; t.add_theme_font_size_override("font_size", 26); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(t)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(560, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(scroll)
	var lst := VBoxContainer.new(); lst.add_theme_constant_override("separation", 8); lst.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(lst)
	if not Net.requests.is_empty():
		lst.add_child(_section("Requests  (%d)" % Net.requests.size()))
		for r in Net.requests:
			lst.add_child(_request_row(r))
	lst.add_child(_section("Your Friends  (%d)" % Net.friends.size()))
	if Net.friends.is_empty():
		var e := Label.new(); e.text = "No friends yet — add players from the Players list."
		e.add_theme_font_size_override("font_size", 14); e.modulate = Color(1, 1, 1, 0.6); lst.add_child(e)
	else:
		for f in Net.friends:
			lst.add_child(_player_row(f, false))
	var frow := HBoxContainer.new(); frow.alignment = BoxContainer.ALIGNMENT_CENTER; frow.add_theme_constant_override("separation", 12); box.add_child(frow)
	var pb := Button.new(); pb.text = "Players"; pb.custom_minimum_size = Vector2(160, 46); pb.pressed.connect(_open_players); frow.add_child(pb)
	var bb := Button.new(); bb.text = "Back"; bb.custom_minimum_size = Vector2(160, 46); bb.pressed.connect(_online_back); frow.add_child(bb)

func _section(txt: String) -> Label:
	var l := Label.new(); l.text = txt; l.add_theme_font_size_override("font_size", 14); l.modulate = Color(1, 1, 1, 0.55)
	return l

func _card_style(alpha := 0.08) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	return sb

func _green_style(c := Color(0.20, 0.72, 0.36)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(12)
	return sb

func _player_row(it: Dictionary, show_add: bool) -> Control:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(520, 56)
	hb.add_theme_constant_override("separation", 8)
	# left: rounded card (dot + name) → profile
	var pbtn := Button.new()
	pbtn.custom_minimum_size = Vector2(370, 52)
	pbtn.add_theme_stylebox_override("normal", _card_style())
	pbtn.add_theme_stylebox_override("hover", _card_style(0.14))
	pbtn.add_theme_stylebox_override("pressed", _card_style(0.14))
	pbtn.pressed.connect(_open_profile.bind(str(it.get("pid", ""))))
	var inner := HBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 14
	inner.add_theme_constant_override("separation", 10)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pbtn.add_child(inner)
	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 13)
	dot.modulate = Color(0.3, 0.85, 0.4) if bool(it.get("online", false)) else Color(1, 1, 1, 0.35)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(dot)
	var nm := Label.new()
	nm.text = str(it.get("name", "Player"))
	nm.add_theme_font_size_override("font_size", 17)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(nm)
	hb.add_child(pbtn)
	# right: Add (green) or ✓ Friend
	if not show_add or bool(it.get("friend", false)):
		var fl := Label.new()
		fl.text = "✓ Friend"
		fl.add_theme_font_size_override("font_size", 14)
		fl.modulate = Color(0.3, 0.85, 0.4)
		fl.custom_minimum_size = Vector2(130, 52)
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(fl)
	else:
		var act := Button.new()
		act.text = "+ Add"
		act.custom_minimum_size = Vector2(130, 52)
		act.add_theme_font_size_override("font_size", 15)
		act.add_theme_stylebox_override("normal", _green_style())
		act.add_theme_stylebox_override("hover", _green_style(Color(0.24, 0.80, 0.42)))
		act.add_theme_stylebox_override("pressed", _green_style(Color(0.24, 0.80, 0.42)))
		act.pressed.connect(func() -> void:
			Net.friend_request(str(it.get("pid", "")))
			act.text = "Sent"; act.disabled = true
			_set_status("Request sent to %s" % str(it.get("name", ""))))
		hb.add_child(act)
	return hb

func _request_row(r: Dictionary) -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(520, 56)
	pc.add_theme_stylebox_override("panel", _card_style(0.06))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	pc.add_child(hb)
	var nm := Label.new(); nm.text = str(r.get("name", "Player")); nm.add_theme_font_size_override("font_size", 17)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(nm)
	var acc := Button.new(); acc.text = "Accept"; acc.custom_minimum_size = Vector2(110, 44)
	acc.add_theme_stylebox_override("normal", _green_style())
	acc.add_theme_stylebox_override("hover", _green_style(Color(0.24, 0.80, 0.42)))
	acc.add_theme_stylebox_override("pressed", _green_style(Color(0.24, 0.80, 0.42)))
	acc.pressed.connect(func() -> void: Net.friend_accept(str(r.get("pid", ""))))
	hb.add_child(acc)
	var dec := Button.new(); dec.text = "Decline"; dec.custom_minimum_size = Vector2(110, 44)
	dec.pressed.connect(func() -> void: Net.friend_decline(str(r.get("pid", ""))))
	hb.add_child(dec)
	return pc

func _online_profile() -> void:
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(cc)
	panel = VBoxContainer.new(); panel.custom_minimum_size = Vector2(420, 0); panel.add_theme_constant_override("separation", 12); cc.add_child(panel)
	var d := _profile_data
	if d.is_empty():
		_label("Loading…", 18)
		_btn("Back", _open_players)
		return
	var disc := Control.new(); disc.custom_minimum_size = Vector2(120, 120)
	var sk: Dictionary = d.get("skin", {})
	var jak := Color(float(sk.get("jr", 0.3)), float(sk.get("jg", 0.5)), float(sk.get("jb", 0.9)))
	var ring := Shapes.circ(54, Color(jak.r, jak.g, jak.b, 0.22)); ring.position = Vector2(60, 60); disc.add_child(ring)
	var op := Player.new(); op.is_remote = true; op.skin_jacket = jak; op.skin_accent = jak.lightened(0.45); op.z_index = 10
	op.scale = Vector2(0.7, 0.7); op.position = Vector2(60, 100); disc.add_child(op)
	var setup := func() -> void:
		op.set_aim(0.0)
		op._overlay_visible(false)
	if op.is_node_ready():
		setup.call()
	else:
		op.ready.connect(setup)
	var dc := CenterContainer.new(); dc.add_child(disc); panel.add_child(dc)
	_label(str(d.get("name", "Player")), 28)
	_label("●  Online" if bool(d.get("online", false)) else "○  Offline", 15)
	_label("%d friends" % int(d.get("friends", 0)), 14)
	var p := str(d.get("pid", _profile_pid))
	var is_friend := false
	for f in Net.friends:
		if str(f.get("pid", "")) == p:
			is_friend = true
	var has_req := false
	for r in Net.requests:
		if str(r.get("pid", "")) == p:
			has_req = true
	if is_friend:
		_btn("Unfriend", func() -> void: Net.unfriend_player(p); _open_players())
	elif has_req:
		_btn("Accept Request", func() -> void: Net.friend_accept(p); _set_status("Friend added"))
	else:
		_btn("+ Add Friend", func() -> void: Net.friend_request(p); _set_status("Request sent"))
	_btn("Back", _open_players)

func _on_presence(_c: int) -> void:
	if screen == Screen.ON_PLAYERS:
		Net.req_players(_players_page)      # refresh the list when someone joins/leaves
	elif screen == Screen.ONLINE or screen == Screen.MAIN:
		_rebuild()                          # update the "N online" count on the card

func _on_players(_d: Dictionary) -> void:
	if screen == Screen.ON_PLAYERS:
		_rebuild()

func _on_social_changed(_x: Array) -> void:
	if screen == Screen.ON_FRIENDS or screen == Screen.ON_PROFILE:
		_rebuild()

func _on_friend_req_in(f: Dictionary) -> void:
	_set_status("Friend request from %s" % str(f.get("name", "?")))
	if screen == Screen.ON_FRIENDS:
		_rebuild()

func _on_friend_accepted(w: Dictionary) -> void:
	_set_status("%s accepted your request" % str(w.get("name", "?")))
	if screen == Screen.ON_FRIENDS or screen == Screen.ON_PLAYERS:
		_rebuild()

func _on_profile(d: Dictionary) -> void:
	_profile_data = d
	if screen == Screen.ON_PROFILE:
		_rebuild()

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
