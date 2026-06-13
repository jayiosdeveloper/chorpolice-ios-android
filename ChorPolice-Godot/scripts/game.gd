## Game — builds the selected map (terrain, platforms, blocks, structures, death
## pits), a follow camera with parallax + sky + weather, twin-stick touch controls
## (plus keyboard/mouse for desktop), and the full G3 combat: 9 weapons + grenades
## + crate pickups + random bot waves with AI.  Godot is y-DOWN, so the maps'
## up-positive heights are placed at  godot_y = -height.
extends Node2D

const STICK_R := 70.0
const DEATH_Y := 320.0
const ZOOM := 0.62
const GRENADE_GRAVITY := 2940.0    # project gravity 980 × grenade gravity_scale 3.0

# Bot difficulty profiles (index = MatchCfg.bot_level 0..3) — ported from iOS.
const BOT_PROFILES := [
	{"speed": 190.0, "fireMin": 0.85, "fireMax": 1.40, "aimError": 0.160, "range": 700.0,
	 "chaseBias": 0.30, "standoff": 330.0, "dodgeProb": 0.00, "lead": 0.0, "maxAlive": 3},
	{"speed": 240.0, "fireMin": 0.55, "fireMax": 0.90, "aimError": 0.090, "range": 950.0,
	 "chaseBias": 0.55, "standoff": 300.0, "dodgeProb": 0.25, "lead": 0.35, "maxAlive": 4},
	{"speed": 285.0, "fireMin": 0.34, "fireMax": 0.58, "aimError": 0.050, "range": 1150.0,
	 "chaseBias": 0.80, "standoff": 270.0, "dodgeProb": 0.50, "lead": 0.7, "maxAlive": 5},
	{"speed": 320.0, "fireMin": 0.22, "fireMax": 0.40, "aimError": 0.022, "range": 1400.0,
	 "chaseBias": 0.95, "standoff": 240.0, "dodgeProb": 0.75, "lead": 1.0, "maxAlive": 5},
]
# Crate cycle (weapon ints: 1 uzi 2 shotgun 3 sniper 4 magnum 5 mp5 6 ak47 7 flamer 8 rocket)
const PICKUP_PATTERN := [
	{"kind": "health"}, {"kind": "weapon", "w": 2}, {"kind": "weapon", "w": 1},
	{"kind": "weapon", "w": 3}, {"kind": "nades"}, {"kind": "weapon", "w": 6},
	{"kind": "health"}, {"kind": "weapon", "w": 4}, {"kind": "weapon", "w": 5},
	{"kind": "weapon", "w": 8}, {"kind": "nades"}, {"kind": "weapon", "w": 7},
]
const BOT_NAMES := ["Raju", "Pappu", "Chintu", "Golu", "Bunty", "Montu", "Tillu", "Babloo"]

const NET_INTERVAL := 0.05           # 20 Hz local-player state broadcast
const SKIN_PALETTE := [
	Color(0.27, 0.55, 0.97), Color(0.90, 0.30, 0.32), Color(0.30, 0.80, 0.45),
	Color(0.96, 0.62, 0.10), Color(0.65, 0.45, 0.95), Color(0.20, 0.78, 0.80),
]

var map: Dictionary
var theme: Dictionary
var level_length := 6000.0

var player: Player
var cam: Camera2D
var hud: CanvasLayer
var terrain: Node2D
var spawns: Array = []
var spawns_godot: Array = []

# combat state
var bot_level := 1
var kills := 0
var current_weapon := 0
var ammo := -1
var grenades := 3
var unlimited_ammo := false
var fire_cooldown := 0.0
var time_remaining := 300.0
var match_over := false
var shake_mag := 0.0
var flame_count := 0
var jet_sound_on := false

# multiplayer (G4)
var is_mp := false
var local_id := 0
var remotes := {}                    # peer_id -> Player avatar
var remote_targets := {}             # peer_id -> last received state Dictionary
var peer_kills := {}                 # peer_id -> int
var peer_teams := {}                 # peer_id -> int
var peer_captures := {}              # peer_id -> int (CTF)
var my_captures := 0
var net_timer := 0.0

# CTF (mode 2)
var flag_status: Array = []          # per team: {state:"home"/"dropped"/"carried", pos, by}
var base_pos: Array = []             # per team: Vector2 base
var flag_nodes: Array = []           # per team: flag visual
var my_carrying := -1                # which team's flag I carry (-1 none)

var bots: Array = []                 # Array[Bot] — live AI agents
var pending_spawns: Array = []       # Array[float] — countdowns to arrivals
var reinforce_timer := 9.0
var bot_name_bag: Array = []

var pickups := {}                    # spot:int -> Pickup
var pickup_cycles := {}              # spot:int -> int
var pickup_spots: Array = []

# HUD refs
var fuel_fill: ColorRect
var health_fill: ColorRect
var weapon_label: Label
var kills_label: Label
var timer_label: Label
var nade_button: Control
var next_button: Button
var center_label: Label
var pause_layer: CanvasLayer
var pause_box: VBoxContainer

# joystick state
var using_touch := false             # true once any real touch arrives → ignore mouse/keyboard
var nade_id := -1                    # touch dragging the grenade button (drag-to-aim)
var nade_aim := Vector2.ZERO
var nade_dots: Array = []
var move_id := -1
var aim_id := -1
var move_base := Vector2.ZERO
var aim_base := Vector2.ZERO
var move_vec := Vector2.ZERO
var aim_vec := Vector2.ZERO
var move_ring: Polygon2D
var move_knob: Polygon2D
var aim_ring: Polygon2D
var aim_knob: Polygon2D

func _ready() -> void:
	randomize()
	add_to_group("combat")
	is_mp = MatchCfg.is_multiplayer and Net.active
	if OS.has_environment("CP_MAP"):
		MatchCfg.map_index = int(OS.get_environment("CP_MAP"))
	map = Maps.get_map(MatchCfg.map_index)
	theme = map["theme"]
	level_length = map["length"]
	spawns = map["spawns"]
	for s in spawns:
		spawns_godot.append(Vector2(s.x, -s.y - 10.0))

	bot_level = clampi(MatchCfg.bot_level, 0, BOT_PROFILES.size() - 1)
	unlimited_ammo = MatchCfg.unlimited_ammo
	time_remaining = float(MatchCfg.minutes) * 60.0

	_build_sky()
	_build_parallax()
	terrain = Node2D.new()
	add_child(terrain)
	_build_terrain()
	_scatter_props()

	player = Player.new()
	var sk := _local_skin()
	player.skin_jacket = sk[0]
	player.skin_accent = sk[1]
	player.skin_helmet = sk[2]
	player.skin_pants = sk[3]
	player.skin_tone = sk[4]
	player.skin_jacket2 = sk[5]
	if is_mp:
		local_id = Net.my_id()
		player.position = _team_spawn(MatchCfg.local_team)
	else:
		player.position = spawns_godot[0]
	add_child(player)
	player.set_name_text(Net.local_name if is_mp else Settings.resolved_name())
	player.died.connect(_on_player_died)
	ammo = Weapons.data(0)["ammo"]

	_build_camera()
	_build_weather()
	_build_hud()
	_spawn_all_pickups()
	if is_mp and MatchCfg.mode == 2:
		_build_ctf()
		if OS.has_environment("CP_CTFGRAB") and MatchCfg.local_team == 0:
			print("[ctf] bases A=", base_pos[0], " B=", base_pos[1])
			get_tree().create_timer(3.0).timeout.connect(func() -> void:
				player.position = base_pos[1] + Vector2(0, -10))
			get_tree().create_timer(5.0).timeout.connect(func() -> void:
				player.position = base_pos[0] + Vector2(0, -10)
				print("[ctf] TP own base; carrying=", my_carrying, " y=", player.position.y))
	Audio.play_track("battle")

	if is_mp:
		Net.message.connect(_on_net_message)
		Net.peers_changed.connect(_reconcile_remotes)
		if OS.has_environment("CP_NET_LOG"):
			print("[game] MP start  id=", local_id, " team=", MatchCfg.local_team,
				" mode=", MatchCfg.mode, " map=", MatchCfg.map_index)
	elif OS.has_environment("CP_SHOT"):
		pending_spawns = [0.2, 0.5, 0.9, 1.3]   # bring opponents on fast for the screenshot
		_capture()
	else:
		_queue_wave(0.8)

func _capture() -> void:
	await get_tree().create_timer(2.8).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/cp_shot.png")
	get_tree().quit()

func _build_camera() -> void:
	cam = Camera2D.new()
	var z: float = Settings.zoom if Settings.zoom > 0.1 else ZOOM
	cam.zoom = Vector2(z, z)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.limit_left = 0
	cam.limit_right = int(level_length)
	cam.limit_top = -1000
	cam.limit_bottom = 360
	cam.global_position = player.global_position
	add_child(cam)
	cam.make_current()

# MARK: terrain

func _col(key: String) -> Color:
	return theme[key]

func _build_terrain() -> void:
	for g in map["grounds"]:
		_ground_seg(g.x, g.y, g.z)        # Vector3(x0, x1, top)
	for p in map["platforms"]:
		_platform(p.x, p.y, p.z)          # Vector3(x, y, w)
	for b in map["blocks"]:
		_block(b)
	for s in map["structures"]:
		_structure(s)

func _static_box(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body.add_child(cs)
	body.position = center
	if theme["slippery"]:
		var mat := PhysicsMaterial.new()
		mat.friction = 0.02
		body.physics_material_override = mat
	add_child(body)

func _ground_seg(x0: float, x1: float, top: float) -> void:
	var top_y := -top
	var deep := 300.0
	_static_box(Vector2((x0 + x1) / 2.0, top_y + deep / 2.0), Vector2(x1 - x0, deep))
	_rock_chunk(x0, x1, top_y, deep)

func _platform(x: float, y: float, w: float) -> void:
	var top_y := -y
	_static_box(Vector2(x, top_y + 12.0), Vector2(w, 24.0))
	_rock_chunk(x - w / 2.0, x + w / 2.0, top_y, randf_range(20.0, 40.0))

func _rock_chunk(x0: float, x1: float, top_y: float, deep: float) -> void:
	var top_pts := PackedVector2Array()
	top_pts.append(Vector2(x0 - 4.0, top_y))
	var x := x0 + randf_range(18.0, 30.0)
	while x < x1 - 14.0:
		top_pts.append(Vector2(x, top_y + randf_range(-8.0, 4.0)))
		x += randf_range(24.0, 40.0)
	top_pts.append(Vector2(x1 + 4.0, top_y))

	var poly := PackedVector2Array(top_pts)
	poly.append(Vector2(x1 + 4.0, top_y + deep))
	poly.append(Vector2(x0 - 4.0, top_y + deep))
	var rock := Polygon2D.new()
	rock.polygon = poly
	rock.color = _col("rock")
	rock.z_index = -10
	terrain.add_child(rock)

	# speckles
	var n := int((x1 - x0) / 90.0)
	for i in n:
		var dot := Shapes.circ(randf_range(3.0, 7.0), _col("rock_dark"))
		dot.position = Vector2(randf_range(x0 + 14.0, x1 - 14.0), top_y + randf_range(14.0, deep - 12.0))
		dot.z_index = -9
		terrain.add_child(dot)

	# grass / snow strip hugging the jagged top
	if theme["grass_style"] != "none":
		var depth := 11.0 if theme["grass_style"] == "snow" else 9.0
		var g := PackedVector2Array(top_pts)
		for i in range(top_pts.size() - 1, -1, -1):
			g.append(top_pts[i] + Vector2(0, depth))
		var grass := Polygon2D.new()
		grass.polygon = g
		grass.color = _col("grass")
		grass.z_index = -8
		terrain.add_child(grass)

func _block(b: Dictionary) -> void:
	var bx: float = b["x"]
	var by: float = b["y"]
	var bw: float = b["w"]
	var bh: float = b["h"]
	var center := Vector2(bx, -by)
	_static_box(center, Vector2(bw, bh))
	var rock := Shapes.rrect(Vector2(bw, bh), 5, _col("rock"))
	rock.position = center
	rock.z_index = -10
	terrain.add_child(rock)
	var edge := Shapes.rrect(Vector2(bw, 5), 2, _col("rock_dark"))
	edge.position = center + Vector2(0, -bh / 2.0 + 3.0)
	edge.z_index = -9
	terrain.add_child(edge)
	if b["hang"]:
		var dx := -bw / 2.0 + 36.0
		while dx < bw / 2.0 - 24.0:
			var spike_len := randf_range(16.0, 44.0)
			var spike := Polygon2D.new()
			spike.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(0, spike_len), Vector2(7, 0)])
			spike.color = _col("rock_edge")
			spike.position = center + Vector2(dx, bh / 2.0 - 1.0)
			spike.z_index = -9
			terrain.add_child(spike)
			dx += randf_range(50.0, 110.0)

func _structure(s: Dictionary) -> void:
	var sx: float = s["x"]
	var fy: float = -float(s["floor"])
	var kind: String = s["kind"]
	var wall := Color(0.32, 0.31, 0.30)
	var roof := _col("rock_edge")
	var amber := Color(1.0, 0.76, 0.35)
	var node := Node2D.new()
	node.position = Vector2(sx, fy)
	node.z_index = -7
	terrain.add_child(node)

	if kind == "bunker":
		_part(node, Vector2(0, -30), Vector2(128, 60), wall)
		_part(node, Vector2(0, -64), Vector2(144, 13), roof)
		_part(node, Vector2(0, -22), Vector2(24, 36), roof)
		_glow(node, Vector2(-34, -38), amber); _glow(node, Vector2(34, -38), amber)
	elif kind == "tower":
		_part(node, Vector2(0, -80), Vector2(70, 160), wall)
		_part(node, Vector2(0, -156), Vector2(78, 10), roof)
		_glow(node, Vector2(0, -120), amber); _glow(node, Vector2(0, -76), amber)
	else:  # house
		_part(node, Vector2(0, -32), Vector2(116, 64), wall)
		var r := Polygon2D.new()
		r.polygon = PackedVector2Array([Vector2(-68, -60), Vector2(0, -98), Vector2(68, -60)])
		r.color = roof
		node.add_child(r)
		_glow(node, Vector2(22, -36), amber)

func _part(parent: Node2D, pos: Vector2, size: Vector2, col: Color) -> void:
	var r := Shapes.rrect(size, 4, col)
	r.position = pos
	parent.add_child(r)

func _glow(parent: Node2D, pos: Vector2, col: Color) -> void:
	var w := Shapes.rrect(Vector2(14, 12), 2, col)
	w.position = pos
	parent.add_child(w)

# MARK: Kenney CC0 props (match the iOS look)

func _scatter_props() -> void:
	var props: Array = theme.get("props", [])
	if props.is_empty():
		return
	var layer := Node2D.new()
	add_child(layer)
	for g in map["grounds"]:
		var x: float = float(g.x) + randf_range(80.0, 160.0)   # g = Vector3(x0, x1, top)
		while x < float(g.y) - 60.0:
			_place_prop(layer, props[randi() % props.size()], x, g.z, randf_range(0.55, 0.85))
			x += randf_range(240.0, 500.0)
	var small: Array = props.filter(func(p): return not ("igloo" in p or "deadTree" in p or "fence" in p))
	if small.is_empty():
		small = props
	for p in map["platforms"]:                        # p = Vector3(x, y, w)
		if randi() % 10 < 4:
			_place_prop(layer, small[randi() % small.size()], p.x + randf_range(-p.z / 4.0, p.z / 4.0), p.y + 10.0, randf_range(0.4, 0.6))

func _place_prop(parent: Node2D, prop_name: String, x: float, top: float, scl: float) -> void:
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/kenney/%s.png" % prop_name)
	var h: float = float(spr.texture.get_height()) * scl
	spr.scale = Vector2(scl, scl)
	if randf() < 0.5:
		spr.scale.x = -scl
	spr.position = Vector2(x, -top - h / 2.0 + 4.0)
	spr.z_index = -7
	parent.add_child(spr)

# MARK: sky / parallax / weather

func _build_sky() -> void:
	var grad := Gradient.new()
	var sky: Array = theme["sky"]
	grad.set_color(0, sky[0])
	grad.add_point(0.55, sky[1])
	grad.set_color(1, sky[2])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = -100
	layer.add_child(tr)
	add_child(layer)

func _build_parallax() -> void:
	var bg := ParallaxBackground.new()
	add_child(bg)
	var style: String = theme["hill_style"]
	var hcol: Color = theme["hill"]

	var hills := ParallaxLayer.new()
	hills.motion_scale = Vector2(0.5, 1)
	bg.add_child(hills)
	var x := 0.0
	while x < level_length:
		_hill(hills, style, hcol, x)
		x += randf_range(120.0, 260.0)

	if theme["cloud_alpha"] > 0.05:
		var clouds := ParallaxLayer.new()
		clouds.motion_scale = Vector2(0.35, 1)
		bg.add_child(clouds)
		var cx := 0.0
		while cx < level_length:
			var c := Sprite2D.new()
			c.texture = load("res://assets/kenney/kenney_cloud%d.png" % (randi() % 3 + 1))
			c.scale = Vector2.ONE * randf_range(0.9, 1.9)
			c.modulate = Color(1, 1, 1, float(theme["cloud_alpha"]) * randf_range(0.7, 1.0))
			c.position = Vector2(cx, -randf_range(420.0, 640.0))
			clouds.add_child(c)
			cx += randf_range(320.0, 560.0)

func _hill(layer: ParallaxLayer, style: String, col: Color, x: float) -> void:
	if style == "buildings":
		var bw := randf_range(60, 140)
		var bh := randf_range(120, 360)
		var b := Shapes.rrect(Vector2(bw, bh), 4, col)
		b.position = Vector2(x, -(bh / 2.0 - 24.0))
		layer.add_child(b)
	elif style == "trees":
		var th := randf_range(90, 200)
		var trunk := Shapes.rrect(Vector2(14, th), 3, col)
		trunk.position = Vector2(x, -(th / 2.0))
		layer.add_child(trunk)
		var canopy := Shapes.circ(randf_range(38, 70), col)
		canopy.position = Vector2(x, -(th + 10.0))
		layer.add_child(canopy)
	elif style == "mountains":
		var mw := randf_range(220, 420)
		var mh := randf_range(160, 380)
		var m := Polygon2D.new()
		m.polygon = PackedVector2Array([Vector2(-mw / 2.0, 0), Vector2(0, -mh), Vector2(mw / 2.0, 0)])
		m.color = col
		m.position = Vector2(x, 24)
		layer.add_child(m)
		var cap := Polygon2D.new()
		cap.polygon = PackedVector2Array([Vector2(-mw * 0.13, -mh * 0.74), Vector2(0, -mh), Vector2(mw * 0.13, -mh * 0.74)])
		cap.color = Color(0.92, 0.92, 0.95)
		cap.position = Vector2(x, 24)
		layer.add_child(cap)
	else:  # rocks / mesas
		var rw := randf_range(170, 340)
		var rh := randf_range(90, 230)
		var mesa := Shapes.rrect(Vector2(rw, rh), min(26.0, rh * 0.3), col)
		mesa.position = Vector2(x, -(rh / 2.0 - 10.0))
		layer.add_child(mesa)

func _build_weather() -> void:
	var w: String = theme["weather"]
	if w == "none":
		return
	var p := CPUParticles2D.new()
	p.amount = 60
	p.lifetime = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(800, 8)
	p.local_coords = false
	match w:
		"embers":
			p.position = Vector2(0, 360)
			p.direction = Vector2(0, -1)
			p.gravity = Vector2(0, -30)
			p.initial_velocity_min = 20; p.initial_velocity_max = 45
			p.scale_amount_min = 2.5; p.scale_amount_max = 5
			p.color = Color(1, 0.7, 0.4, 0.6)
		"snow":
			p.position = Vector2(0, -360)
			p.direction = Vector2(0, 1)
			p.gravity = Vector2(10, 60)
			p.initial_velocity_min = 30; p.initial_velocity_max = 60
			p.scale_amount_min = 2.5; p.scale_amount_max = 5
			p.color = Color(1, 1, 1, 0.85)
		"leaves":
			p.position = Vector2(0, -360)
			p.direction = Vector2(0.3, 1)
			p.gravity = Vector2(20, 50)
			p.initial_velocity_min = 35; p.initial_velocity_max = 70
			p.scale_amount_min = 3; p.scale_amount_max = 6
			p.color = Color(0.55, 0.78, 0.30, 0.85)
	cam.add_child(p)

# MARK: HUD

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	move_ring = Shapes.circ(STICK_R, Color(1, 1, 1, 0.12))
	move_knob = Shapes.circ(34, Color(1, 1, 1, 0.32))
	aim_ring = Shapes.circ(STICK_R, Color(1, 1, 1, 0.12))
	aim_knob = Shapes.circ(34, Color(1, 1, 1, 0.32))
	for n in [move_ring, move_knob, aim_ring, aim_knob]:
		n.visible = false
		hud.add_child(n)

	# fuel + health bars (top-left)
	_hud_text("JET FUEL", Vector2(20, 16), 12, Color(1, 1, 1, 0.65))
	fuel_fill = _bar(Vector2(20, 34), Color(0.96, 0.62, 0.10))
	_hud_text("HEALTH", Vector2(20, 56), 12, Color(1, 1, 1, 0.65))
	health_fill = _bar(Vector2(20, 74), Color(0.30, 0.85, 0.40))

	weapon_label = _hud_text("", Vector2(20, 96), 15, Color(1, 1, 1, 0.92))

	# kills + timer (top center)
	kills_label = Label.new()
	kills_label.add_theme_font_size_override("font_size", 18)
	kills_label.anchor_left = 0.0; kills_label.anchor_right = 1.0
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kills_label.offset_top = 14
	hud.add_child(kills_label)

	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.anchor_left = 0.0; timer_label.anchor_right = 1.0
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.offset_top = 38
	hud.add_child(timer_label)

	# map name + next-map dev button
	var name_label := Label.new()
	name_label.text = "%s    (map %d/6)" % [map["name"], MatchCfg.map_index + 1]
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.modulate = Color(1, 1, 1, 0.55)
	name_label.anchor_left = 0.0; name_label.anchor_right = 1.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.offset_top = 70
	hud.add_child(name_label)

	var vp := get_viewport().get_visible_rect().size
	# "Next map" is a solo-practice convenience only — never during a multiplayer
	# match (the map is the host's setting; changing it mid-game would desync).
	if not is_mp:
		next_button = Button.new()
		next_button.text = "Next map ▶"
		next_button.position = Vector2(vp.x - 230, 14)
		next_button.pressed.connect(_next_map)
		hud.add_child(next_button)

	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.position = Vector2(vp.x - 58, 14)
	pause_btn.size = Vector2(44, 38)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.pressed.connect(_pause)
	hud.add_child(pause_btn)
	_build_pause()

	# grenade button — a round icon; held & dragged to aim (handled in _input)
	nade_button = Control.new()
	nade_button.size = Vector2(92, 92)
	nade_button.position = Vector2(vp.x - 120, vp.y - 124)
	nade_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(nade_button)
	var ctr := Vector2(46, 46)
	var rim := Shapes.circ(42, Color(1, 1, 1, 0.4)); rim.position = ctr; nade_button.add_child(rim)
	var disc := Shapes.circ(40, Color(0, 0, 0, 0.38)); disc.position = ctr; nade_button.add_child(disc)
	var shell := Shapes.circ(16, Color(0.30, 0.44, 0.24)); shell.position = ctr + Vector2(0, 2); nade_button.add_child(shell)
	var seg := Shapes.rrect(Vector2(30, 4), 1, Color(0.16, 0.24, 0.12)); seg.position = ctr + Vector2(0, 2); nade_button.add_child(seg)
	var lev := Shapes.rrect(Vector2(7, 11), 2, Color(0.80, 0.80, 0.82)); lev.position = ctr + Vector2(9, -12); nade_button.add_child(lev)

	# grenade-throw trajectory markers (world space, hidden until dragging)
	for i in 16:
		var d := Shapes.circ(5.0 if i < 15 else 9.0, Color(1, 0.85, 0.35, 0.9))
		d.z_index = 90
		d.visible = false
		add_child(d)
		nade_dots.append(d)

	center_label = Label.new()
	center_label.add_theme_font_size_override("font_size", 40)
	center_label.anchor_left = 0.0; center_label.anchor_right = 1.0
	center_label.anchor_top = 0.0; center_label.anchor_bottom = 1.0
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.visible = false
	hud.add_child(center_label)

	_update_weapon_hud()

func _hud_text(txt: String, pos: Vector2, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	l.modulate = col
	hud.add_child(l)
	return l

func _bar(pos: Vector2, col: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.18)
	bg.position = pos
	bg.size = Vector2(170, 12)
	hud.add_child(bg)
	var fill := ColorRect.new()
	fill.color = col
	fill.position = pos
	fill.size = Vector2(170, 12)
	hud.add_child(fill)
	return fill

func _update_weapon_hud() -> void:
	var d := Weapons.data(current_weapon)
	var ammo_text := "∞" if (unlimited_ammo or int(d["ammo"]) == -1) else str(ammo)
	var nade_text := "∞" if unlimited_ammo else str(grenades)
	weapon_label.text = "%s  %s   •   NADES %s" % [d["name"], ammo_text, nade_text]

func _next_map() -> void:
	MatchCfg.map_index = (MatchCfg.map_index + 1) % Maps.count()
	get_tree().reload_current_scene()

# MARK: pause menu

func _build_pause() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 50
	pause_layer.visible = false
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(cc)
	pause_box = VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 12)
	cc.add_child(pause_box)
	_rebuild_pause()

func _rebuild_pause() -> void:
	for c in pause_box.get_children():
		c.queue_free()
	var t := Label.new()
	t.text = "PAUSED"
	t.add_theme_font_size_override("font_size", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(t)
	_pause_btn("Sound:  %s" % ("ON" if Settings.sound_on else "OFF"), func() -> void:
		Settings.sound_on = not Settings.sound_on
		Audio.set_sound(Settings.sound_on)
		Settings.save_cfg()
		_rebuild_pause())
	_pause_btn("Music:  %s" % ("ON" if Settings.music_on else "OFF"), func() -> void:
		Settings.music_on = not Settings.music_on
		Audio.set_music(Settings.music_on)
		Settings.save_cfg()
		_rebuild_pause())
	_pause_btn("Resume", _resume)
	_pause_btn("Quit to Menu", _quit_to_menu)

func _pause_btn(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	pause_box.add_child(b)

func _pause() -> void:
	pause_layer.visible = true
	get_tree().paused = true
	Audio.set_jet(false)

func _resume() -> void:
	get_tree().paused = false
	pause_layer.visible = false

func _quit_to_menu() -> void:
	get_tree().paused = false
	if Net.active:
		Net.leave()
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

# MARK: pickups

func _spawn_all_pickups() -> void:
	pickup_spots.clear()
	for v in map["pickups"]:
		pickup_spots.append(Vector2(v.x, -v.y))
	for i in pickup_spots.size():
		_spawn_pickup(i)

func _spawn_pickup(spot: int) -> void:
	if pickups.has(spot) or spot >= pickup_spots.size():
		return
	var content: Dictionary = PICKUP_PATTERN[(spot + int(pickup_cycles.get(spot, 0))) % PICKUP_PATTERN.size()]
	var p := Pickup.new()
	p.kind = content["kind"]
	p.weapon_type = int(content.get("w", 0))
	p.spot = spot
	p.position = pickup_spots[spot]
	add_child(p)
	pickups[spot] = p

func on_pickup(p: Pickup) -> void:           # called via "combat" group
	if match_over or player.dead or not is_instance_valid(p) or p.taken:
		return
	p.taken = true
	match p.kind:
		"health":
			player.heal(40.0)
		"weapon":
			current_weapon = p.weapon_type
			ammo = Weapons.data(current_weapon)["ammo"]
			player.set_weapon(current_weapon)
		"nades":
			grenades = min(grenades + 2, 6)
	_update_weapon_hud()
	Audio.play("pickup")
	var spot: int = p.spot
	if is_mp:
		Net.send({"t": "pickup", "spot": spot}, true)
	pickups.erase(spot)
	p.queue_free()
	pickup_cycles[spot] = int(pickup_cycles.get(spot, 0)) + 1
	get_tree().create_timer(7.0).timeout.connect(_spawn_pickup.bind(spot))

# MARK: loop + controls

func _physics_process(delta: float) -> void:
	if not match_over:
		if is_mp:
			_broadcast_state(delta)
		else:
			_update_bots(delta)
		_update_timer(delta)
	if is_mp:
		_update_remotes(delta)
		if MatchCfg.mode == 2 and not match_over:
			_update_ctf()
	if nade_id != -1:
		_update_nade_preview()

	# resolve input. Touch sticks own the device; mouse/keyboard are desktop-only and are
	# ignored the moment any touch is used — so the left (move) stick can never fire, and
	# both sticks work together via multitouch.
	var mv := move_vec
	var av := aim_vec
	var want_fire := av.length() > 0.3
	if not using_touch:
		if move_id == -1:
			var kb := _keyboard_move()
			if kb != Vector2.ZERO:
				mv = kb
		if aim_id == -1 and not want_fire and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
				and not _screen_on_ui(get_viewport().get_mouse_position()):
			var dir := get_global_mouse_position() - (player.global_position + Vector2(0, -40))
			if dir.length() > 4.0:
				av = dir; want_fire = true
	if OS.has_environment("CP_SHOT") and not want_fire:
		var t := _nearest_bot()
		if t:
			av = t.global_position - (player.global_position + Vector2(0, -40))
			want_fire = true
	if is_mp and OS.has_environment("CP_BOTPLAY") and not want_fire:   # auto-play test hook
		var goal := Vector2.ZERO
		var have := false
		if MatchCfg.mode == 2 and base_pos.size() == 2:
			var en := 1 - MatchCfg.local_team
			goal = base_pos[MatchCfg.local_team] if my_carrying >= 0 else base_pos[en]
			have = true
		else:
			var rt := _nearest_remote()
			if rt:
				goal = rt.global_position
				have = true
		if have:
			av = goal - (player.global_position + Vector2(0, -40))
			want_fire = true
			mv.x = signf(av.x) * 0.7

	player.control(mv, delta)
	if player.jet and player.jet.emitting != jet_sound_on:
		jet_sound_on = player.jet.emitting
		Audio.set_jet(jet_sound_on)

	if want_fire and av.length() > 0.1:
		var ang := av.angle()
		player.set_aim(ang)
		fire_cooldown -= delta
		if fire_cooldown <= 0.0 and not player.dead and not match_over:
			_fire(ang)
			fire_cooldown = Weapons.data(current_weapon)["interval"]
	else:
		if absf(mv.x) > 0.1:
			player.set_aim(0.0 if mv.x > 0.0 else PI)
		fire_cooldown = 0.0

	if player.global_position.y > DEATH_Y and not player.dead:
		_do_player_respawn()

	# camera follow + shake
	cam.global_position = cam.global_position.lerp(player.global_position + Vector2(0, -40), 0.12)
	if shake_mag > 0.05:
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_mag
		shake_mag = move_toward(shake_mag, 0.0, 60.0 * delta)
	else:
		cam.offset = Vector2.ZERO

	# HUD live values
	fuel_fill.size.x = 170.0 * clampf(player.fuel / Player.MAX_FUEL, 0.0, 1.0)
	health_fill.size.x = 170.0 * clampf(player.health / player.max_health, 0.0, 1.0)
	_update_score_hud()
	if is_mp and not match_over:
		_check_win()

func _keyboard_move() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE):
		v.y -= 1.0
	return v

func _update_timer(delta: float) -> void:
	time_remaining = maxf(0.0, time_remaining - delta)
	var m := int(time_remaining) / 60
	var s := int(time_remaining) % 60
	timer_label.text = "%d:%02d" % [m, s]
	timer_label.modulate = Color(1, 0.4, 0.35) if time_remaining < 31.0 else Color.WHITE
	if time_remaining <= 0.0 and not match_over:
		_time_up()

# MARK: firing

func _fire(angle: float) -> void:
	var d := Weapons.data(current_weapon)
	var muzzle := player.muzzle_position()
	match d["special"]:
		"rocket":
			_spawn_rocket(muzzle, angle, true, local_id)
		"flame":
			for i in int(d["pellets"]):
				var a := angle + randf_range(-d["spread"], d["spread"])
				_spawn_bullet(muzzle, a, d, true, true, local_id)
		_:
			for i in int(d["pellets"]):
				var a := angle + randf_range(-d["spread"], d["spread"])
				_spawn_bullet(muzzle, a, d, true, false, local_id)
			_muzzle_flash(muzzle, Color(1, 0.9, 0.4))
	_play_fire_sound()

	if is_mp:
		Net.send({"t": "fire", "x": muzzle.x, "y": muzzle.y, "ang": angle, "w": current_weapon}, false)

	if not unlimited_ammo and int(d["ammo"]) != -1:
		ammo -= 1
		if ammo <= 0:
			current_weapon = 0
			ammo = 0
			player.set_weapon(0)
		_update_weapon_hud()

func _spawn_bullet(pos: Vector2, angle: float, d: Dictionary, from_player: bool, flame: bool, owner_id := 0) -> void:
	var b := Bullet.new()
	b.from_player = from_player
	b.owner_id = owner_id
	b.dmg = d["dmg"]
	b.life = d["life"]
	b.is_flame = flame
	b.vel = Vector2(cos(angle), sin(angle)) * float(d["speed"])
	b.position = pos
	add_child(b)

func _spawn_rocket(pos: Vector2, angle: float, from_player: bool, owner_id := 0) -> void:
	var d := Weapons.data(Weapons.ROCKET)
	var r := Rocket.new()
	r.from_player = from_player
	r.owner_id = owner_id
	r.dmg = d["dmg"]
	r.vel = Vector2(cos(angle), sin(angle)) * float(d["speed"])
	r.position = pos
	add_child(r)
	_muzzle_flash(pos, Color(1, 0.7, 0.3))

func _play_fire_sound() -> void:
	match current_weapon:
		Weapons.UZI, Weapons.MP5:
			Audio.play("uzi")
		Weapons.SHOTGUN:
			Audio.play("shotgun")
		Weapons.SNIPER:
			Audio.play("sniper")
		Weapons.MAGNUM:
			Audio.play("sniper", -3.0)
		Weapons.FLAMER:
			flame_count += 1
			if flame_count % 3 == 0:
				Audio.play("flame")
		Weapons.ROCKET:
			Audio.play("rocket")
		_:
			Audio.play("rifle")

func _quick_grenade() -> void:
	_throw_grenade(player.aim_angle, 540.0)

func _throw_grenade(angle: float, power: float) -> void:
	if player.dead or match_over:
		return
	if not unlimited_ammo and grenades <= 0:
		return
	if not unlimited_ammo:
		grenades -= 1
	_update_weapon_hud()
	var start := player.global_position + Vector2(16.0 if cos(angle) >= 0.0 else -16.0, -46.0)
	var v := Vector2(cos(angle) * power, sin(angle) * power - 230.0)   # -230: upward lob (y-down)
	var g := Grenade.new()
	g.from_player = true
	g.owner_id = local_id
	g.init_vel = v
	g.position = start
	add_child(g)
	Audio.play("nade_throw")
	if is_mp:
		Net.send({"t": "nade", "x": start.x, "y": start.y, "vx": v.x, "vy": v.y}, true)

func _release_nade() -> void:
	for d in nade_dots:
		d.visible = false
	if nade_aim.length() > 18.0:
		var ang := nade_aim.angle()
		var t := clampf((nade_aim.length() - 18.0) / 110.0, 0.0, 1.0)
		_throw_grenade(ang, 360.0 + t * 400.0)
	else:
		_quick_grenade()                       # plain tap → quick throw toward aim
	nade_id = -1
	nade_aim = Vector2.ZERO

func _update_nade_preview() -> void:
	if nade_aim.length() <= 18.0:
		for d in nade_dots:
			d.visible = false
		return
	var ang := nade_aim.angle()
	var t := clampf((nade_aim.length() - 18.0) / 110.0, 0.0, 1.0)
	var power := 360.0 + t * 400.0
	var pos := player.global_position + Vector2(16.0 if cos(ang) >= 0.0 else -16.0, -46.0)
	var v := Vector2(cos(ang) * power, sin(ang) * power - 230.0)
	var grav := Vector2(0, GRENADE_GRAVITY)
	var prev := pos
	var landed := false
	var space := get_world_2d().direct_space_state
	for i in nade_dots.size():
		var d: Node2D = nade_dots[i]
		if landed:
			d.visible = false
			continue
		for _s in 2:
			v += grav * 0.05
			v *= (1.0 - 0.25 * 0.05)
			pos += v * 0.05
		var q := PhysicsRayQueryParameters2D.create(prev, pos, 1)
		var hit := space.intersect_ray(q)
		if hit:
			pos = hit["position"]
			landed = true
		d.visible = true
		d.global_position = pos
		d.scale = Vector2(1.7, 1.7) if landed else Vector2.ONE
		prev = pos

# MARK: combat group callbacks (bullets/rockets/grenades reach these via call_group)

func spawn_spark(pos: Vector2) -> void:
	var e := _burst(pos, 10, 0.28, 200.0, Color(1, 0.7, 0.25), 3.0)
	e.z_index = 60

func spawn_explosion(pos: Vector2) -> void:
	_spawn_explosion(pos)

func _spawn_explosion(pos: Vector2) -> void:
	var flash := Shapes.circ(60, Color(1, 0.85, 0.4, 0.8))
	flash.position = pos
	flash.z_index = 70
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector2(1.6, 1.6), 0.25)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.25)
	tw.tween_callback(flash.queue_free)
	var e := _burst(pos, 40, 0.6, 320.0, Color(1, 0.55, 0.2), 7.0)
	e.z_index = 71
	shake(9.0)
	Audio.play("explosion")

func _burst(pos: Vector2, count: int, life: float, speed: float, col: Color, psize: float) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.position = pos
	e.emitting = true
	e.one_shot = true
	e.explosiveness = 0.95
	e.amount = count
	e.lifetime = life
	e.direction = Vector2(0, -1)
	e.spread = 180.0
	e.initial_velocity_min = speed * 0.5
	e.initial_velocity_max = speed
	e.scale_amount_min = psize * 0.6
	e.scale_amount_max = psize
	e.color = col
	add_child(e)
	get_tree().create_timer(life + 0.3).timeout.connect(e.queue_free)
	return e

func explode(pos: Vector2, radius: float, dmg: float, owner_id := 0) -> void:
	_spawn_explosion(pos)
	if not player.dead and not match_over and not _is_friendly(owner_id):
		var dp := (player.global_position + Vector2(0, -36)).distance_to(pos)
		if dp < radius:
			var amount := dmg * maxf(0.45, 1.0 - dp / radius)
			var died := player.take_hit(amount)
			shake(12.0 if died else 7.0)
			if is_mp:
				Net.send({"t": "hit", "x": player.global_position.x, "y": player.global_position.y,
					"hp": player.health, "dead": died, "by": owner_id}, true)
	for b in get_tree().get_nodes_in_group("bots"):
		if b.dead:
			continue
		var db: float = (b.global_position + Vector2(0, -36)).distance_to(pos)
		if db < radius:
			b.take_hit(dmg * maxf(0.45, 1.0 - db / radius))

func _is_friendly(shooter_id: int) -> bool:
	return is_mp and MatchCfg.mode >= 1 and shooter_id != local_id \
		and int(peer_teams.get(shooter_id, -1)) == MatchCfg.local_team

func damage_local_player(dmg: float, killer_id: int, _pos: Vector2) -> void:
	if player.dead or match_over or _is_friendly(killer_id):
		return
	var died := player.take_hit(dmg)
	shake(11.0 if died else 4.0)
	if is_mp:
		Net.send({"t": "hit", "x": player.global_position.x, "y": player.global_position.y,
			"hp": player.health, "dead": died, "by": killer_id}, true)
		if died and OS.has_environment("CP_NET_LOG"):
			print("[game] DIED — killed by ", killer_id)

func _muzzle_flash(pos: Vector2, col: Color) -> void:
	var f := Shapes.circ(20, Color(col.r, col.g, col.b, 0.9))
	f.position = pos
	f.z_index = 45
	add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "scale", Vector2(0.3, 0.3), 0.08)
	tw.parallel().tween_property(f, "modulate:a", 0.0, 0.08)
	tw.tween_callback(f.queue_free)

func shake(mag: float) -> void:
	shake_mag = maxf(shake_mag, mag)

# MARK: player death / respawn

func _on_player_died() -> void:
	_drop_flag_on_death()
	_spawn_explosion(player.global_position)
	shake(12.0)
	get_tree().create_timer(1.8).timeout.connect(_do_player_respawn)

func _do_player_respawn() -> void:
	if match_over:
		return
	var sp: Vector2 = _team_spawn(MatchCfg.local_team) if is_mp else spawns_godot[randi() % spawns_godot.size()]
	player.respawn(sp)
	current_weapon = 0
	ammo = Weapons.data(0)["ammo"]
	player.set_weapon(0)
	_update_weapon_hud()

# MARK: multiplayer (G4) — ENet + relay via Net; victim-authoritative damage

func _local_skin() -> Array:
	# [jacket, accent, helmet, pants, tone, jacket2]
	if is_mp and MatchCfg.local_team == 0:
		var j := Color(0.27, 0.55, 0.97)
		return [j, Color(0.5, 0.95, 1.0), j, Color(j.r * 0.45, j.g * 0.45, j.b * 0.5), Color(0.86, 0.66, 0.5), j]
	if is_mp and MatchCfg.local_team == 1:
		var j := Color(0.90, 0.30, 0.32)
		return [j, Color(1.0, 0.82, 0.40), j, Color(j.r * 0.45, j.g * 0.45, j.b * 0.5), Color(0.74, 0.52, 0.38), j]
	return [Settings.skin_jacket, Settings.skin_accent, Settings.skin_helmet, Settings.skin_pants, Settings.skin_tone, Settings.skin_jacket2]

func _team_or_color(team: int, color_idx: int) -> Array:
	if team == 0:
		return [Color(0.27, 0.55, 0.97), Color(0.5, 0.95, 1.0)]    # Team A blue
	if team == 1:
		return [Color(0.90, 0.30, 0.32), Color(1.0, 0.82, 0.40)]   # Team B red
	var j: Color = SKIN_PALETTE[color_idx % SKIN_PALETTE.size()]   # FFA: own colour
	return [j, j.lightened(0.45)]

func _team_spawn(team: int) -> Vector2:
	if team < 0:
		return spawns_godot[randi() % spawns_godot.size()]
	var target_x := 350.0 if team == 0 else level_length - 350.0
	var best: Vector2 = spawns_godot[0]
	var bestd := 1.0e20
	for s in spawns_godot:
		var dd: float = absf(s.x - target_x)
		if dd < bestd:
			bestd = dd; best = s
	return best

func _broadcast_state(delta: float) -> void:
	net_timer -= delta
	if net_timer > 0.0:
		return
	net_timer = NET_INTERVAL
	Net.send({"t": "state",
		"x": player.global_position.x, "y": player.global_position.y,
		"vx": player.velocity.x, "vy": player.velocity.y,
		"aim": player.aim_angle, "hp": player.health, "dead": player.dead,
		"w": current_weapon, "k": kills, "c": my_captures, "team": MatchCfg.local_team,
		"jr": player.skin_jacket.r, "jg": player.skin_jacket.g, "jb": player.skin_jacket.b,
		"j2r": player.skin_jacket2.r, "j2g": player.skin_jacket2.g, "j2b": player.skin_jacket2.b,
		"ar": player.skin_accent.r, "ag": player.skin_accent.g, "ab": player.skin_accent.b,
		"hr": player.skin_helmet.r, "hg": player.skin_helmet.g, "hb": player.skin_helmet.b,
		"pr": player.skin_pants.r, "pg": player.skin_pants.g, "pb": player.skin_pants.b,
		"tr": player.skin_tone.r, "tg": player.skin_tone.g, "tb": player.skin_tone.b}, false)

func _update_remotes(delta: float) -> void:
	for id in remotes:
		var r: Player = remotes[id]
		var t: Dictionary = remote_targets.get(id, {})
		if t.is_empty():
			continue
		r.position = r.position.lerp(Vector2(t["x"], t["y"]), 0.25)
		r.set_aim(float(t["aim"]))
		if int(t["w"]) != r.current_weapon:
			r.set_weapon(int(t["w"]))
		var now_dead: bool = bool(t["dead"])
		r.health = float(t["hp"])
		r._update_hp()
		if now_dead and not r.dead:
			r.dead = true
			r.body_group.visible = false
			r.arm_rig.visible = false
			r._overlay_visible(false)
		elif r.dead and not now_dead:
			r.dead = false
			r.body_group.visible = true
			r.arm_rig.visible = true
			r._overlay_visible(true)
		if not now_dead:
			r.animate(delta, absf(float(t["vy"])) < 28.0, absf(float(t["vx"])), false)
			r.set_thrust(float(t["vy"]) < -120.0)

func _on_net_message(sender: int, msg: Dictionary) -> void:
	match msg.get("t", ""):
		"state":
			peer_kills[sender] = int(msg.get("k", 0))
			peer_captures[sender] = int(msg.get("c", 0))
			peer_teams[sender] = int(msg.get("team", -1))
			if not remotes.has(sender):
				_make_remote(sender, msg)
			remote_targets[sender] = msg
		"fire":
			_remote_fire(sender, msg)
		"nade":
			var g := Grenade.new()
			g.from_player = false
			g.owner_id = sender
			g.init_vel = Vector2(float(msg["vx"]), float(msg["vy"]))
			g.position = Vector2(float(msg["x"]), float(msg["y"]))
			add_child(g)
		"hit":
			_remote_hit(sender, msg)
		"pickup":
			var spot := int(msg["spot"])
			if pickups.has(spot):
				pickups[spot].queue_free()
				pickups.erase(spot)
			pickup_cycles[spot] = int(pickup_cycles.get(spot, 0)) + 1
			get_tree().create_timer(7.0).timeout.connect(_spawn_pickup.bind(spot))
		"flag":
			_apply_flag_event(sender, msg)

func _make_remote(sender: int, s: Dictionary) -> void:
	var r := Player.new()
	r.is_remote = true
	r.skin_jacket = Color(float(s.get("jr", 0.3)), float(s.get("jg", 0.5)), float(s.get("jb", 0.9)))
	r.skin_jacket2 = Color(float(s.get("j2r", s.get("jr", 0.3))), float(s.get("j2g", s.get("jg", 0.5))), float(s.get("j2b", s.get("jb", 0.9))))
	r.skin_accent = Color(float(s.get("ar", 0.6)), float(s.get("ag", 0.9)), float(s.get("ab", 1.0)))
	r.skin_helmet = Color(float(s.get("hr", 0.3)), float(s.get("hg", 0.5)), float(s.get("hb", 0.9)))
	r.skin_pants = Color(float(s.get("pr", 0.13)), float(s.get("pg", 0.13)), float(s.get("pb", 0.22)))
	r.skin_tone = Color(float(s.get("tr", 0.86)), float(s.get("tg", 0.66)), float(s.get("tb", 0.5)))
	r.name_text = Net.name_of(sender)
	r.position = Vector2(float(s["x"]), float(s["y"]))
	add_child(r)
	remotes[sender] = r
	if OS.has_environment("CP_NET_LOG"):
		print("[game] remote ", sender, " (", Net.name_of(sender), ") entered the arena")

func _remote_fire(sender: int, msg: Dictionary) -> void:
	var w := int(msg["w"])
	var d := Weapons.data(w)
	var origin := Vector2(float(msg["x"]), float(msg["y"]))
	var angle := float(msg["ang"])
	match d["special"]:
		"rocket":
			_spawn_rocket(origin, angle, false, sender)
		"flame":
			for i in int(d["pellets"]):
				_spawn_bullet(origin, angle + randf_range(-d["spread"], d["spread"]), d, false, true, sender)
		_:
			for i in int(d["pellets"]):
				_spawn_bullet(origin, angle + randf_range(-d["spread"], d["spread"]), d, false, false, sender)
			_muzzle_flash(origin, Color(1, 0.5, 0.3))

func _remote_hit(sender: int, msg: Dictionary) -> void:
	spawn_spark(Vector2(float(msg["x"]), float(msg["y"])))
	if remotes.has(sender):
		var r: Player = remotes[sender]
		r.health = float(msg["hp"])
		r._update_hp()
		r._flash()
		if bool(msg["dead"]):
			_spawn_explosion(r.global_position)
	if bool(msg["dead"]) and int(msg.get("by", 0)) == local_id:
		kills += 1
		shake(6.0)
		if OS.has_environment("CP_NET_LOG"):
			print("[game] +KILL  (downed ", Net.name_of(sender), ")  total=", kills)

func _reconcile_remotes() -> void:
	for id in remotes.keys():
		if not Net.players.has(id):
			_remove_remote(id)

func _remove_remote(id: int) -> void:
	if remotes.has(id):
		remotes[id].queue_free()
		remotes.erase(id)
	remote_targets.erase(id)
	peer_kills.erase(id)
	peer_teams.erase(id)

func _update_score_hud() -> void:
	if is_mp and MatchCfg.mode == 2:
		kills_label.text = "⚑ A %d  —  %d B" % [_team_captures(0), _team_captures(1)]
	elif is_mp and MatchCfg.mode == 1:
		kills_label.text = "A %d  —  %d B" % [_team_kills(0), _team_kills(1)]
	else:
		kills_label.text = "Kills %d" % kills

func _team_captures(t: int) -> int:
	var total := my_captures if MatchCfg.local_team == t else 0
	for id in peer_captures:
		if int(peer_teams.get(id, -1)) == t:
			total += int(peer_captures[id])
	return total

func _team_kills(t: int) -> int:
	var total := kills if MatchCfg.local_team == t else 0
	for id in peer_kills:
		if int(peer_teams.get(id, -1)) == t:
			total += int(peer_kills[id])
	return total

func _check_win() -> void:
	if MatchCfg.mode == 2:
		if _team_captures(0) >= MatchCfg.target:
			_end("Team A Wins!")
		elif _team_captures(1) >= MatchCfg.target:
			_end("Team B Wins!")
	elif MatchCfg.mode == 1:
		if _team_kills(0) >= MatchCfg.target:
			_end("Team A Wins!")
		elif _team_kills(1) >= MatchCfg.target:
			_end("Team B Wins!")
	else:
		var best := kills
		var best_id := local_id
		for id in peer_kills:
			if int(peer_kills[id]) > best:
				best = int(peer_kills[id]); best_id = id
		if best >= MatchCfg.target:
			_end("You Win!" if best_id == local_id else "%s Wins!" % Net.name_of(best_id))

func _time_up() -> void:
	if is_mp and MatchCfg.mode == 2:
		var a := _team_captures(0)
		var b := _team_captures(1)
		_end("TIME UP\n" + ("Draw!" if a == b else ("Team A Wins!" if a > b else "Team B Wins!")))
	elif is_mp and MatchCfg.mode == 1:
		var a := _team_kills(0)
		var b := _team_kills(1)
		_end("TIME UP\n" + ("Draw!" if a == b else ("Team A Wins!" if a > b else "Team B Wins!")))
	elif is_mp:
		var best := kills
		var best_id := local_id
		for id in peer_kills:
			if int(peer_kills[id]) > best:
				best = int(peer_kills[id]); best_id = id
		_end("TIME UP\n" + ("You Win!" if best_id == local_id else "%s Wins!" % Net.name_of(best_id)))
	else:
		_end("TIME UP\nKills %d" % kills)

func _end(text: String) -> void:
	match_over = true
	center_label.text = text
	center_label.visible = true
	Audio.play("win")

# MARK: CTF (mode 2)

func _ground_top_at(x: float) -> float:
	for g in map["grounds"]:
		if x >= float(g.x) and x <= float(g.y):
			return -float(g.z)
	return -200.0

func _build_ctf() -> void:
	base_pos = [Vector2(350.0, _ground_top_at(350.0)),
		Vector2(level_length - 350.0, _ground_top_at(level_length - 350.0))]
	flag_status = [
		{"state": "home", "pos": base_pos[0], "by": 0},
		{"state": "home", "pos": base_pos[1], "by": 0}]
	for t in 2:
		var col := Color(0.27, 0.55, 0.97) if t == 0 else Color(0.90, 0.30, 0.32)
		var fn := _make_flag(col)
		fn.position = base_pos[t]
		add_child(fn)
		flag_nodes.append(fn)
		var pad := Shapes.rrect(Vector2(130, 8), 4, Color(col.r, col.g, col.b, 0.5))
		pad.position = base_pos[t] + Vector2(0, -2)
		pad.z_index = 4
		add_child(pad)

func _make_flag(col: Color) -> Node2D:
	var n := Node2D.new()
	n.z_index = 30
	var glow := Shapes.circ(34, Color(col.r, col.g, col.b, 0.25))
	glow.position = Vector2(0, -40)
	n.add_child(glow)
	var pole := Shapes.rrect(Vector2(4, 74), 2, Color(0.85, 0.85, 0.85))
	pole.position = Vector2(0, -37)
	n.add_child(pole)
	var banner := Polygon2D.new()
	banner.polygon = PackedVector2Array([Vector2(2, -72), Vector2(36, -60), Vector2(2, -48)])
	banner.color = col
	n.add_child(banner)
	n.add_child(Shapes.circ(7, Color(0.6, 0.6, 0.6)))
	return n

func _near(p: Vector2, dist: float) -> bool:
	return player.global_position.distance_to(p) < dist

func _update_ctf() -> void:
	for t in 2:
		var st: Dictionary = flag_status[t]
		match st["state"]:
			"home":
				flag_nodes[t].position = base_pos[t]
			"dropped":
				flag_nodes[t].position = st["pos"]
			"carried":
				var by := int(st["by"])
				if by == local_id:
					flag_nodes[t].position = player.global_position + Vector2(0, -78)
				elif remotes.has(by):
					flag_nodes[t].position = remotes[by].global_position + Vector2(0, -78)
	if player.dead or match_over or MatchCfg.local_team < 0:
		return
	var enemy := 1 - MatchCfg.local_team
	if my_carrying == -1:
		var es: Dictionary = flag_status[enemy]
		var can_take := false
		if es["state"] == "home":
			can_take = _near(base_pos[enemy], 64.0)
		elif es["state"] == "dropped":
			can_take = _near(es["pos"], 64.0)
		if can_take:
			flag_status[enemy] = {"state": "carried", "pos": Vector2.ZERO, "by": local_id}
			my_carrying = enemy
			Audio.play("pickup")
			Net.send({"t": "flag", "kind": 0, "team": enemy, "x": 0, "y": 0}, true)
			if OS.has_environment("CP_NET_LOG"):
				print("[ctf] took enemy flag (team ", enemy, ")")
		var ms: Dictionary = flag_status[MatchCfg.local_team]
		if ms["state"] == "dropped" and _near(ms["pos"], 64.0):
			flag_status[MatchCfg.local_team] = {"state": "home", "pos": base_pos[MatchCfg.local_team], "by": 0}
			Audio.play("pickup")
			Net.send({"t": "flag", "kind": 2, "team": MatchCfg.local_team, "x": 0, "y": 0}, true)
	elif _near(base_pos[MatchCfg.local_team], 70.0):
		if OS.has_environment("CP_NET_LOG"):
			print("[ctf] at own base — carrying=", my_carrying, " ownflag=", flag_status[MatchCfg.local_team]["state"])
		if flag_status[MatchCfg.local_team]["state"] == "home":
			flag_status[my_carrying] = {"state": "home", "pos": base_pos[my_carrying], "by": 0}
			Net.send({"t": "flag", "kind": 3, "team": my_carrying, "x": 0, "y": 0}, true)
			my_carrying = -1
			my_captures += 1
			Audio.play("capture")
			shake(7.0)
			if OS.has_environment("CP_NET_LOG"):
				print("[ctf] CAPTURED!  my_captures=", my_captures)

func _apply_flag_event(by: int, msg: Dictionary) -> void:
	if flag_status.is_empty():
		return
	var team := int(msg["team"])
	if team < 0 or team > 1:
		return
	match int(msg["kind"]):
		0:
			flag_status[team] = {"state": "carried", "pos": Vector2.ZERO, "by": by}
		1:
			flag_status[team] = {"state": "dropped", "pos": Vector2(float(msg["x"]), float(msg["y"])), "by": 0}
		2:
			flag_status[team] = {"state": "home", "pos": base_pos[team], "by": 0}
		3:
			flag_status[team] = {"state": "home", "pos": base_pos[team], "by": 0}
			Audio.play("capture")

func _drop_flag_on_death() -> void:
	if MatchCfg.mode != 2 or my_carrying < 0:
		return
	var p := player.global_position
	flag_status[my_carrying] = {"state": "dropped", "pos": p, "by": 0}
	Net.send({"t": "flag", "kind": 1, "team": my_carrying, "x": p.x, "y": p.y}, true)
	my_carrying = -1

# MARK: bots — waves + AI (ported from iOS)

func _profile() -> Dictionary:
	return BOT_PROFILES[bot_level]

func _nearest_bot() -> Bot:
	var best: Bot = null
	var bestd := 1e20
	for b in bots:
		if b.dead:
			continue
		var dd: float = b.global_position.distance_squared_to(player.global_position)
		if dd < bestd:
			bestd = dd; best = b
	return best

func _nearest_remote() -> Player:
	var best: Player = null
	var bestd := 1.0e20
	for id in remotes:
		var r: Player = remotes[id]
		if r.dead:
			continue
		var dd: float = r.global_position.distance_squared_to(player.global_position)
		if dd < bestd:
			bestd = dd; best = r
	return best

func _update_bots(delta: float) -> void:
	var i := 0
	while i < pending_spawns.size():
		pending_spawns[i] -= delta
		if pending_spawns[i] <= 0.0:
			pending_spawns.remove_at(i)
			_spawn_bot()
		else:
			i += 1

	if bots.is_empty() and pending_spawns.is_empty():
		_queue_wave(randf_range(1.0, 2.2))
	elif not bots.is_empty():
		reinforce_timer -= delta
		if reinforce_timer <= 0.0:
			reinforce_timer = randf_range(7.0, 13.0)
			if bots.size() + pending_spawns.size() < int(_profile()["maxAlive"]) and randi() % 2 == 0:
				pending_spawns.append(randf_range(0.2, 1.0))

	for b in bots:
		if not b.dead:
			_run_bot_ai(b, delta)

func _queue_wave(initial_delay: float) -> void:
	var roll := randi() % 100 + 1
	var size := 1 if roll <= 30 else 2 if roll <= 60 else 3 if roll <= 80 else 4 if roll <= 92 else 5
	size = min(size, int(_profile()["maxAlive"]) - bots.size() - pending_spawns.size())
	if size <= 0:
		return
	var delay := initial_delay
	for n in size:
		pending_spawns.append(delay)
		delay += randf_range(0.5, 1.3)
	if size >= 2:
		_show_incoming(size)

func _spawn_bot() -> void:
	if bots.size() >= int(_profile()["maxAlive"]):
		return
	if bot_name_bag.is_empty():
		bot_name_bag = BOT_NAMES.duplicate()
		bot_name_bag.shuffle()
	var nm: String = bot_name_bag.pop_front()

	# teleport in off the player's side of the screen when possible
	var far: Array = spawns_godot.filter(func(s): return absf(s.x - player.global_position.x) > 600.0)
	var pool: Array = far if not far.is_empty() else spawns_godot
	var pos: Vector2 = pool[randi() % pool.size()]

	var b := Bot.new()
	b.name_text = nm
	b.position = pos
	add_child(b)
	b.died.connect(_on_bot_died.bind(b))
	bots.append(b)
	_spawn_flash(pos)

func _on_bot_died(b: Bot) -> void:
	kills += 1
	shake(8.0)
	_spawn_explosion(b.global_position)
	bots.erase(b)
	b.queue_free()

func _spawn_flash(pos: Vector2) -> void:
	var f := Shapes.circ(45, Color(1, 1, 1, 0.9))
	f.position = pos + Vector2(0, -26)
	f.z_index = 60
	f.scale = Vector2(0.2, 0.2)
	add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "scale", Vector2(1.4, 1.4), 0.2)
	tw.parallel().tween_property(f, "modulate:a", 0.0, 0.25)
	tw.tween_callback(f.queue_free)

func _show_incoming(n: int) -> void:
	var l := Label.new()
	l.text = "+%d INCOMING!" % n
	l.add_theme_font_size_override("font_size", 22)
	l.modulate = Color(1, 0.55, 0.35)
	l.anchor_left = 0.0; l.anchor_right = 1.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.offset_top = 96
	hud.add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)

func _run_bot_ai(b: Bot, delta: float) -> void:
	var prof := _profile()
	var dx := player.global_position.x - b.global_position.x
	var dy := player.global_position.y - b.global_position.y
	var dist := sqrt(dx * dx + dy * dy)

	b.think_t -= delta
	if b.think_t <= 0.0:
		b.think_t = randf_range(0.4, 0.9)
		if not player.dead and randf() < float(prof["chaseBias"]):
			if absf(dx) > float(prof["standoff"]) + 60.0:
				b.move_dir = 1.0 if dx > 0.0 else -1.0
			elif absf(dx) < float(prof["standoff"]) - 60.0:
				b.move_dir = -1.0 if dx > 0.0 else 1.0
			else:
				b.move_dir = [-1.0, 0.0, 1.0][randi() % 3]
		else:
			b.move_dir = [-1.0, 0.0, 1.0][randi() % 3]
		b.wants_dodge = randf() < float(prof["dodgeProb"])

	# drive (bots ignore fuel; use their profile speed)
	b.velocity.x = b.move_dir * float(prof["speed"])
	var want_thrust := (player.global_position.y < b.global_position.y - 40.0 and randi() % 2 == 0) \
		or b.wants_dodge or b.global_position.y > 220.0
	if want_thrust:
		b.velocity.y = -300.0
	else:
		b.velocity.y += Player.GRAVITY * delta
	b.set_thrust(want_thrust)
	b.move_and_slide()
	b.animate(delta)

	# aim (higher levels lead the moving target)
	var pv := player.velocity
	var flight := dist / float(Weapons.data(0)["speed"])
	var tx := dx + pv.x * flight * float(prof["lead"])
	var ty := dy + pv.y * flight * float(prof["lead"])
	var angle := atan2(ty, tx)
	b.set_aim(angle)

	b.fire_t -= delta
	if b.fire_t <= 0.0 and not player.dead and dist < float(prof["range"]) and not match_over:
		var a := angle + randf_range(-prof["aimError"], prof["aimError"])
		var rifle := Weapons.data(0)
		_spawn_bullet(b.muzzle_position(), a, rifle, false, false)
		_muzzle_flash(b.muzzle_position(), Color(1, 0.5, 0.3))
		Audio.play("rifle", linear_to_db(clampf(1.0 - dist / 1600.0, 0.2, 1.0)))
		b.fire_t = randf_range(prof["fireMin"], prof["fireMax"])

# MARK: input (touch sticks + keyboard shortcuts)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_quick_grenade()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var w: int = event.keycode - KEY_1
			current_weapon = w
			ammo = Weapons.data(w)["ammo"]
			player.set_weapon(w)
			_update_weapon_hud()
		return

	var vp := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		using_touch = true
		if event.pressed:
			# Grenade button → hold & DRAG to aim (iOS style), release to throw.
			if _btn_rect(nade_button, 14.0).has_point(event.position):
				nade_id = event.index
				nade_aim = Vector2.ZERO
				return
			if _btn_rect(next_button, 4.0).has_point(event.position):
				return                       # let the GUI button handle this tap
			# Left half = MOVE stick (movement only). Right half = AIM stick (aim + fire).
			if event.position.x < vp.x / 2.0 and move_id == -1:
				move_id = event.index; move_base = event.position
				_show(move_ring, move_knob, move_base)
			elif event.position.x >= vp.x / 2.0 and aim_id == -1:
				aim_id = event.index; aim_base = event.position
				_show(aim_ring, aim_knob, aim_base)
		else:
			if event.index == nade_id:
				_release_nade()
			elif event.index == move_id:
				move_id = -1; move_vec = Vector2.ZERO
				move_ring.visible = false; move_knob.visible = false
			elif event.index == aim_id:
				aim_id = -1; aim_vec = Vector2.ZERO
				aim_ring.visible = false; aim_knob.visible = false
	elif event is InputEventScreenDrag:
		if event.index == nade_id:
			nade_aim = event.position - _btn_rect(nade_button, 0.0).get_center()
		elif event.index == move_id:
			move_vec = _drag(move_base, event.position, move_knob)
		elif event.index == aim_id:
			aim_vec = _drag(aim_base, event.position, aim_knob)

func _btn_rect(b: Control, pad: float) -> Rect2:
	return b.get_global_rect().grow(pad) if b else Rect2()

func _screen_on_ui(p: Vector2) -> bool:
	return _btn_rect(nade_button, 12.0).has_point(p) or _btn_rect(next_button, 4.0).has_point(p)

func _tap_button(b: Button) -> void:
	var tw := create_tween()
	tw.tween_property(b, "modulate", Color(0.6, 0.85, 1.0), 0.05)
	tw.tween_property(b, "modulate", Color.WHITE, 0.14)

func _show(ring: Polygon2D, knob: Polygon2D, at: Vector2) -> void:
	ring.position = at; knob.position = at
	ring.visible = true; knob.visible = true

func _drag(base: Vector2, pos: Vector2, knob: Polygon2D) -> Vector2:
	var d := pos - base
	if d.length() > STICK_R:
		d = d.normalized() * STICK_R
	knob.position = base + d
	return d / STICK_R
