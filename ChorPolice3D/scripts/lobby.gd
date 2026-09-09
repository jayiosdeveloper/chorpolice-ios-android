## Lobby / main menu — iOS-style two-column main screen (branding + your character on
## the left, icon cards on the right, settings gear) plus Host/Join sub-screens.
extends Control

enum Screen { MAIN, HOST, JOIN, WAIT, ONLINE, ON_LIST, ON_CREATE, ON_JOIN, ON_ROOM, ON_PLAYERS, ON_FRIENDS, ON_PROFILE, MAP_PICK }

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
var bg: MenuBg
var _corner_logo: Control       # small top-left brand — hidden on MAIN (big 3D logo shows there)
var _safe_l := 0.0        # left/right safe-area insets in canvas units (notch / home bar)
var _safe_r := 0.0

## Notch/home-indicator safe insets converted from native px into canvas (1280×720) units.
func _compute_safe() -> void:
	var vp := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0:
		return
	var sx := vp.x / win.x
	var sa := DisplayServer.get_display_safe_area()
	_safe_l = maxf(0.0, float(sa.position.x) * sx)
	_safe_r = maxf(0.0, float(win.x - (sa.position.x + sa.size.x)) * sx)
	# a sensible floor so edges never hug the bezel / notch even when the OS reports none
	_safe_l = maxf(_safe_l, 52.0)
	_safe_r = maxf(_safe_r, 30.0)

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
	# The scene root and `root` must be pass-through so finger drags reach the 3D hero,
	# which lives in the MenuBg CanvasLayer *behind* this UI. Buttons (STOP) still work.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compute_safe()
	bg = MenuBg.new()
	add_child(bg)
	Audio.play_track("menu")

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var vp := get_viewport().get_visible_rect().size
	# top bar: logo left, player chip + settings right
	var logo := Logo.new()
	logo.mode = "wide"
	logo.show_tagline = false
	logo.glow = 0.5
	add_child(logo)
	logo.scale = Vector2(0.46, 0.46)
	logo.position = Vector2(_safe_l + 8, 16)
	_corner_logo = logo

	var chip := Button.new()
	chip.custom_minimum_size = Vector2(288, 72)
	chip.position = Vector2(vp.x - 288 - 100 - _safe_r, 18)
	var chsb := UI.glass(0.10, 36.0, Color(UI.CYAN.r, UI.CYAN.g, UI.CYAN.b, 0.5), 2)
	chsb.set_content_margin_all(0)
	var chhov := UI.glass(0.18, 36.0, UI.CYAN, 2); chhov.set_content_margin_all(0)
	chip.add_theme_stylebox_override("normal", chsb)
	chip.add_theme_stylebox_override("hover", chhov)
	chip.add_theme_stylebox_override("pressed", chhov)
	chip.add_theme_stylebox_override("focus", chsb)
	chip.pressed.connect(_open_settings)
	add_child(chip)
	# premium accent stripe on the chip's left edge
	var chstripe := ColorRect.new(); chstripe.color = UI.CYAN
	chstripe.position = Vector2(0, 16); chstripe.size = Vector2(4, 40)
	chstripe.mouse_filter = Control.MOUSE_FILTER_IGNORE; chip.add_child(chstripe)
	var ch := HBoxContainer.new()
	ch.set_anchors_preset(Control.PRESET_FULL_RECT)
	ch.offset_left = 10
	ch.add_theme_constant_override("separation", 10)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(ch)
	var av := Control.new()
	av.custom_minimum_size = Vector2(58, 70)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := Shapes.circ(27, Color(UI.CYAN.r, UI.CYAN.g, UI.CYAN.b, 0.18))
	ring.position = Vector2(29, 35)
	av.add_child(ring)
	var op := Player.new()
	op.is_remote = true
	op.skin_jacket = Settings.skin_jacket
	op.skin_accent = Settings.skin_accent
	op.scale = Vector2(0.42, 0.42)
	op.position = Vector2(29, 64)
	av.add_child(op)
	ch.add_child(av)
	var cv := VBoxContainer.new()
	cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cv.add_theme_constant_override("separation", 0)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(cv)
	cv.add_child(UI.label(Settings.resolved_name(), 21, UI.TEXT))
	cv.add_child(UI.label("EDIT CHARACTER  ✎", 12, UI.CYAN))

	var gear := Button.new()
	gear.custom_minimum_size = Vector2(72, 72)
	gear.position = Vector2(vp.x - 84 - _safe_r, 18)
	var gsb := UI.glass(0.10, 36.0, Color(UI.CYAN.r, UI.CYAN.g, UI.CYAN.b, 0.5), 2)
	gsb.set_content_margin_all(0)
	var ghov := UI.glass(0.18, 36.0, UI.CYAN, 2); ghov.set_content_margin_all(0)
	gear.add_theme_stylebox_override("normal", gsb)
	gear.add_theme_stylebox_override("hover", ghov)
	gear.add_theme_stylebox_override("pressed", ghov)
	gear.add_theme_stylebox_override("focus", gsb)
	gear.pressed.connect(_open_settings)
	add_child(gear)
	var gg := UI.glyph("gear", UI.TEXT, 16)
	gg.position = Vector2(36 - 16 * 1.2, 36 - 16 * 1.2)
	gear.add_child(gg)

	status = UI.label("", 15, UI.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	status.anchor_top = 1.0; status.anchor_right = 1.0; status.anchor_bottom = 1.0
	status.offset_top = -36
	add_child(status)

# MARK: screens

func _rebuild() -> void:
	if not root or not is_inside_tree():
		return
	for c in root.get_children():
		c.queue_free()
	if _corner_logo:
		_corner_logo.visible = screen != Screen.MAIN     # big 3D logo replaces it on MAIN
	if bg:
		if screen == Screen.MAIN:
			bg.set_hero(0.50, 1.0, 1.0, 0.92)
			bg.set_drag(true)
		else:
			bg.set_hero(0.50, 0.9, 0.10)
			bg.set_drag(false)
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
		Screen.MAP_PICK: _map_pick()
		_: _centered()

func _main() -> void:
	# Free Fire / BGMI style lobby: big rotatable hero centred, compact title top-left,
	# a bottom dock with multiplayer mode tiles (left) and one big START CTA (right).
	var vp := get_viewport().get_visible_rect().size
	var lx := _safe_l + 40.0

	# TOP-LEFT — live 3D animated metal wordmark (kept clear of the notch/top bar)
	var ty := vp.y * 0.17
	var logo3d := Logo3D.new()
	logo3d.size = Vector2(460, 250)
	logo3d.position = Vector2(lx - 12, ty)
	root.add_child(logo3d)

	var pills := HBoxContainer.new()
	pills.position = Vector2(lx + 8, ty + 232)
	pills.add_theme_constant_override("separation", 8)
	root.add_child(pills)
	pills.add_child(UI.pill("3D ARENA", UI.CYAN, 15))
	pills.add_child(UI.pill("6 MAPS", UI.ORANGE, 15))
	pills.add_child(UI.pill("9 GUNS", UI.BLUE, 15))
	var online := UI.label(("●  %d players online" % Net.online_count) if Net.online_count > 0 else "○  connecting…", 16, UI.GREEN if Net.online_count > 0 else UI.MUTED)
	online.position = Vector2(lx + 8, ty + 276)
	root.add_child(online)

	# CENTRE — drag-to-rotate hint under the hero's feet
	var hint := UI.label("↺  DRAG TO ROTATE", 15, Color(1, 1, 1, 0.55), false, HORIZONTAL_ALIGNMENT_CENTER)
	hint.size = Vector2(260, 22)
	hint.position = Vector2(vp.x * 0.5 - 130, vp.y * 0.905)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	# BOTTOM DOCK — multiplayer mode tiles (left) + big START CTA (right)
	var dock_y := vp.y - 158
	var tiles := HBoxContainer.new()
	tiles.position = Vector2(lx, dock_y)
	tiles.add_theme_constant_override("separation", 16)
	root.add_child(tiles)
	_mode_tile(tiles, "HOST", "WiFi", UI.BLUE, _host, "wifi")
	_mode_tile(tiles, "JOIN", "WiFi", UI.ORANGE, _join, "link")
	_mode_tile(tiles, "ONLINE", ("%d on" % Net.online_count) if Net.online_count > 0 else "Internet", UI.PURPLE, _online, "globe")

	_big_start()

## Stylised "CHOR / vs POLICE" wordmark: a slanted glass plate with an orange edge
## stripe, stacked heavy type with a soft glow, and a thin accent underline.
func _title_block(at: Vector2) -> void:
	var plate := Panel.new()
	plate.position = at + Vector2(-18, -14)
	plate.size = Vector2(360, 188)
	plate.rotation = deg_to_rad(-3.0)
	plate.pivot_offset = Vector2(0, 0)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.02, 0.03, 0.07, 0.34)
	psb.set_corner_radius_all(18)
	psb.border_width_left = 5
	psb.border_color = UI.ORANGE
	psb.shadow_color = Color(0, 0, 0, 0.35)
	psb.shadow_size = 14
	plate.add_theme_stylebox_override("panel", psb)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)

	var box := VBoxContainer.new()
	box.position = at
	box.add_theme_constant_override("separation", -6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	box.add_child(_glow_word("CHOR", 84, UI.ORANGE))
	var vs := HBoxContainer.new()
	vs.add_theme_constant_override("separation", 12)
	vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vlab := UI.label("VS", 26, Color(1, 1, 1, 0.5))
	vlab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vs.add_child(vlab)
	vs.add_child(_glow_word("POLICE", 84, UI.BLUE.lightened(0.2)))
	box.add_child(vs)
	var bar := UI.bar(250, 6, UI.ORANGE, UI.BLUE)
	root.add_child(bar)
	bar.position = at + Vector2(4, 176)

## A heavy word with a coloured drop-glow behind it (cheap faux-outline via a
## blurred duplicate) for that game-logo punch.
func _glow_word(txt: String, fsize: int, col: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(fsize * txt.length() * 0.62, fsize * 1.02)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := UI.label(txt, fsize, Color(col.r, col.g, col.b, 0.30))
	glow.position = Vector2(0, 3)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(glow)
	var main := UI.label(txt, fsize, col)
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(main)
	return c

const MAP_DESC := ["Desert military base", "Tiered tower over a pit", "Suburban streets", "Frozen lake & igloos", "Canyon fortresses", "Meadow farm & pond"]
const MAP_COL := [UI.ORANGE, UI.BLUE, UI.GREEN, UI.CYAN, UI.RED, UI.PURPLE]

## Pick which of the 6 arenas to play before the match starts (Practice).
func _map_pick() -> void:
	var vp := get_viewport().get_visible_rect().size
	if bg:
		bg.set_hero(0.5, 0.9, 0.0)          # hide the hero for a clean, full map picker

	# centred header
	var title := UI.label("CHOOSE YOUR MAP", 42, UI.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = vp.y * 0.07
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)
	var barc := UI.bar(180, 5, UI.ORANGE, UI.BLUE)
	barc.position = Vector2(vp.x * 0.5 - 90, vp.y * 0.07 + 52)
	root.add_child(barc)
	var sub := UI.label("Tap a map to drop into practice", 15, UI.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = vp.y * 0.07 + 62
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sub)

	# centred grid of real map-photo cards (columns fit the number of active maps)
	var n := Maps.count()
	var cols: int = mini(n, 3)
	var cw := 400.0 if n <= 2 else 340.0
	var ch := 236.0 if n <= 2 else 200.0
	var hs := 24.0
	var gw := cols * cw + (cols - 1) * hs
	var grid := GridContainer.new()
	grid.columns = cols
	grid.position = Vector2((vp.x - gw) / 2.0, vp.y * 0.28)
	grid.add_theme_constant_override("h_separation", int(hs))
	grid.add_theme_constant_override("v_separation", 22)
	root.add_child(grid)
	for i in Maps.count():
		grid.add_child(_map_card(i, cw, ch))
	_back_button(_goto.bind(Screen.MAIN))

## A premium map card: the real rendered map photo, a colour accent, a number badge,
## and a dark scrim with the map name + description. Tapping starts practice there.
func _map_card(i: int, cw: float, ch: float) -> Control:
	var m := Maps.get_map(i)
	var col: Color = MAP_COL[i % MAP_COL.size()]
	var b := Button.new()
	b.custom_minimum_size = Vector2(cw, ch)
	b.clip_contents = true
	var sb := UI.glass(0.05, 16.0, UI.LINE, 1); sb.set_content_margin_all(0)
	var hov := UI.glass(0.05, 16.0, col, 3); hov.set_content_margin_all(0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(_start_practice.bind(i))

	var pth := "res://assets/real/maps/map%d.png" % i
	if ResourceLoader.exists(pth):
		var pic := TextureRect.new()
		pic.texture = load(pth)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.offset_left = 3; pic.offset_top = 3; pic.offset_right = -3; pic.offset_bottom = -3
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pic)
	# dark scrim for text
	var scrim := TextureRect.new()
	scrim.texture = UI.grad_tex([Color(0, 0, 0, 0.0), Color(0.01, 0.02, 0.05, 0.9)])
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	scrim.offset_left = 3; scrim.offset_right = -3; scrim.offset_top = -78; scrim.offset_bottom = -3
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(scrim)
	# number badge (top-left)
	var badge := UI.pill("MAP %d" % (i + 1), col, 12)
	badge.position = Vector2(12, 12)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(badge)
	# name + description
	var nm := UI.label(str(m["name"]), 22, UI.TEXT)
	nm.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	nm.offset_left = 14; nm.offset_top = -50; nm.offset_right = cw - 8
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nm)
	var desc := UI.label(MAP_DESC[i % MAP_DESC.size()], 13, Color(col.r, col.g, col.b, 0.95))
	desc.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	desc.offset_left = 14; desc.offset_top = -26; desc.offset_right = cw - 8
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(desc)
	return b

func _centered() -> void:
	# HOST shows match setup; JOIN and WAIT show the same iOS-style "JOINING GAME"
	# avatar screen (auto-connects to the first host found — no manual host ID).
	_lobby_two_col(screen == Screen.HOST)

func _lobby_two_col(host_mode: bool) -> void:
	var vp := get_viewport().get_visible_rect().size
	# LEFT — title + player avatar field
	var left := VBoxContainer.new()
	left.position = Vector2(48, vp.y * 0.14)
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	left.add_child(UI.label("HOSTING GAME" if host_mode else "JOINING GAME", 30, UI.BLUE.lightened(0.15) if host_mode else UI.ORANGE))
	left.add_child(UI.bar(120, 4))
	left.add_child(UI.label("Friends on the same WiFi / hotspot connect automatically", 14, UI.MUTED))
	_avatar_field(left, Vector2(vp.x * 0.46, vp.y * 0.52))
	left.add_child(UI.pill(("%d players ready" % Net.players.size()) if Net.players.size() > 1 else "Searching for players nearby…", UI.GREEN if Net.players.size() > 1 else UI.CYAN))
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
	var sb := UI.glass(0.05, 18.0)
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
	_goto(Screen.MAP_PICK)

func _start_practice(map_i: int) -> void:
	sel_map = map_i
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
	left.add_child(UI.label("ONLINE", 66, UI.PURPLE))
	left.add_child(UI.bar(220, 5, UI.PURPLE, UI.CYAN))
	left.add_child(UI.label("Play with friends & players over the internet", 15, UI.MUTED))
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	left.add_child(pr)
	pr.add_child(UI.pill(("%d ONLINE" % Net.online_count) if Net.online_count > 0 else "CONNECTING…", UI.GREEN if Net.online_count > 0 else UI.MUTED))
	pr.add_child(UI.pill("ROOMS  %d" % Net.rooms.size(), UI.BLUE))
	var right := VBoxContainer.new()
	right.position = Vector2(vp.x - 470, vp.y * 0.13)
	right.add_theme_constant_override("separation", 10)
	root.add_child(right)
	_menu_card(right, "Quick Play", "Join any open room", UI.GREEN, _quick_play, "target")
	_menu_card(right, "Public Rooms", "Browse open rooms", UI.BLUE, _goto.bind(Screen.ON_LIST), "globe")
	_menu_card(right, "Create Room", "Public or private", UI.PURPLE, _goto.bind(Screen.ON_CREATE), "wifi")
	_menu_card(right, "Join with Code", "Enter a room code", UI.ORANGE, _goto.bind(Screen.ON_JOIN), "link")
	_menu_card(right, "Players & Friends", "%d online" % Net.online_count, UI.CYAN, _open_players, "friends")
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
	b.text = "   BACK"
	b.add_theme_font_size_override("font_size", 16)
	b.custom_minimum_size = Vector2(140, 48)
	b.position = Vector2(40, get_viewport().get_visible_rect().size.y - 76)
	UI.style_button(b, "dark", 24.0)
	b.pressed.connect(cb)
	root.add_child(b)
	var g := UI.glyph("back", UI.CYAN, 8)
	g.position = Vector2(12, 24 - 8 * 1.2)
	b.add_child(g)

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
	return UI.label(txt, 13, UI.MUTED, true)

func _card_style(alpha := 0.08) -> StyleBoxFlat:
	var sb := UI.glass(alpha, 14.0)
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	return sb

func _green_style(c := UI.GREEN) -> StyleBoxFlat:
	return UI.solid(c, 12.0)

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

## A compact BGMI-style mode tile: icon + title + sub, glass with an accent top stripe.
func _mode_tile(parent: Node, title: String, sub: String, accent: Color, cb: Callable, glyph := "target") -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(168, 136)
	var sb := UI.glass(0.08, 18.0, UI.LINE, 1); sb.set_content_margin_all(0)
	var hov := UI.glass(0.16, 18.0, Color(accent.r, accent.g, accent.b, 0.9), 2); hov.set_content_margin_all(0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(cb)
	parent.add_child(b)
	var stripe := ColorRect.new(); stripe.color = accent
	stripe.position = Vector2(18, 0); stripe.size = Vector2(132, 5)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(stripe)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 20
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := CenterContainer.new(); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(UI.glyph(glyph, accent, 26))
	v.add_child(ic)
	var tl := UI.label(title, 22, UI.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE; tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(tl)
	var sl := UI.label(sub, 14, UI.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE; sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(sl)

## The big glowing primary CTA at the bottom-right — starts a Practice match.
func _big_start() -> void:
	var vp := get_viewport().get_visible_rect().size
	var b := Button.new()
	b.custom_minimum_size = Vector2(360, 136)
	b.position = Vector2(vp.x - 360 - _safe_r - 40, vp.y - 158)
	# unique premium CTA: bright green with a soft outer glow + rounded corners
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.80, 0.42)
	sb.set_corner_radius_all(26)
	sb.shadow_color = Color(0.20, 0.85, 0.45, 0.5)
	sb.shadow_size = 20
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.28, 0.88, 0.52)
	hov.shadow_size = 26
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(_practice)
	root.add_child(b)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 28; hb.offset_right = -22
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 18)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	# circular play badge
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(58, 58)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(1, 1, 1, 0.92)
	bsb.set_corner_radius_all(29)
	badge.add_theme_stylebox_override("panel", bsb)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(badge)
	var tri := UI.label("▶", 26, Color(0.10, 0.55, 0.28))
	tri.set_anchors_preset(Control.PRESET_FULL_RECT)
	tri.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tri.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tri.offset_left = 4
	tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(tri)
	var tv := VBoxContainer.new()
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	tv.add_child(UI.label("START", 40, Color(0.02, 0.10, 0.04)))
	tv.add_child(UI.label("Practice vs Bots", 15, Color(0.03, 0.14, 0.06)))

func _menu_card(parent: Node, title: String, subtitle: String, accent: Color, cb: Callable, glyph := "target") -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(430, 92)
	var sb := UI.glass(0.07, 18.0, UI.LINE, 1)
	sb.set_content_margin_all(0)
	var hov := UI.glass(0.14, 18.0, Color(accent.r, accent.g, accent.b, 0.8), 1)
	hov.set_content_margin_all(0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(cb)
	parent.add_child(b)
	# accent stripe on the left edge
	var stripe := ColorRect.new()
	stripe.color = accent
	stripe.position = Vector2(0, 18)
	stripe.size = Vector2(5, 56)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(stripe)

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 18.0
	hb.offset_right = -18.0
	hb.add_theme_constant_override("separation", 14)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)

	var icon := UI.glyph(glyph, accent, 21)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(icon)

	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_theme_constant_override("separation", 1)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	tv.add_child(UI.label(title, 23, UI.TEXT))
	tv.add_child(UI.label(subtitle, 13, UI.MUTED))

	var ch := UI.label("›", 32, Color(accent.r, accent.g, accent.b, 0.9))
	ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ch)

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 52)
	b.add_theme_font_size_override("font_size", 19)
	var kind := "ghost"
	var up := text.to_upper()
	if up.begins_with("START") or up.begins_with("CREATE") or up.begins_with("JOIN") or up.begins_with("QUICK") or up.begins_with("PLAY"):
		kind = "primary"
	elif up == "BACK" or up.begins_with("LEAVE") or up.begins_with("CANCEL"):
		kind = "dark"
	UI.style_button(b, kind, 16.0)
	b.pressed.connect(cb)
	panel.add_child(b)
	return b

func _label(text: String, fsize := 18) -> Label:
	var l := UI.label(text, fsize, UI.TEXT if fsize >= 18 else UI.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
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
