## Game — the 3D match: builds the arena (Arena + Maps3D), a third-person follow
## camera, twin-stick touch controls (left = move, right = look + auto-fire, plus JUMP /
## jetpack and grenade buttons) with keyboard + mouse for desktop, and the full combat:
## 9 weapons, grenades, crate pickups, bot waves with AI, DM / TDM / CTF scoring and
## the victim-authoritative multiplayer sync over Net (LAN or online relay).
## Units: metres, +Y up, forward = -Z.
extends Node3D

const STICK_R := 70.0
const NET_INTERVAL := 0.05
const CAM_DIST := 4.6
const CAM_SIDE := 0.75
const CAM_UP := 1.55
const LOOK_SENS := 0.0042             # rad per screen pixel dragged (touch look)
const MAGNET_RATE := 4.0              # how fast the camera eases onto a target near the crosshair
const MOUSE_SENS := 0.0032
const PX_TO_M := 1.0 / 16.0           # 2D weapon speeds (px/s) → m/s
const AIM_ASSIST_DEG := 14.0
# magazine size + reload seconds per weapon (index = weapon type)
const MAG_SIZE := [30, 32, 6, 10, 6, 30, 30, 90, 1]
# enemy weapon pool (weighted): rifles most common, then SMGs, shotgun, SCAR
const BOT_LOADOUT := [0, 0, 0, 6, 6, 5, 1, 2, 3]
const RELOAD_TIME := [1.7, 1.5, 2.4, 1.9, 2.1, 1.6, 1.9, 2.8, 2.6]

# Bot difficulty profiles (index = MatchCfg.bot_level 0..3) — the 2D values in metres.
const BOT_PROFILES := [
	{"speed": 3.8, "fireMin": 0.85, "fireMax": 1.40, "aimError": 0.160, "range": 17.0,
	 "chaseBias": 0.30, "standoff": 8.5, "dodgeProb": 0.00, "lead": 0.0, "maxAlive": 3},
	{"speed": 4.8, "fireMin": 0.55, "fireMax": 0.90, "aimError": 0.090, "range": 23.0,
	 "chaseBias": 0.55, "standoff": 7.5, "dodgeProb": 0.25, "lead": 0.35, "maxAlive": 4},
	{"speed": 5.7, "fireMin": 0.34, "fireMax": 0.58, "aimError": 0.050, "range": 28.0,
	 "chaseBias": 0.80, "standoff": 6.8, "dodgeProb": 0.50, "lead": 0.7, "maxAlive": 5},
	{"speed": 6.4, "fireMin": 0.22, "fireMax": 0.40, "aimError": 0.022, "range": 35.0,
	 "chaseBias": 0.95, "standoff": 6.0, "dodgeProb": 0.75, "lead": 1.0, "maxAlive": 5},
]
const PICKUP_PATTERN := [
	{"kind": "health"}, {"kind": "weapon", "w": 2}, {"kind": "weapon", "w": 1},
	{"kind": "weapon", "w": 3}, {"kind": "nades"}, {"kind": "weapon", "w": 6},
	{"kind": "health"}, {"kind": "weapon", "w": 4}, {"kind": "weapon", "w": 5},
	{"kind": "weapon", "w": 0}, {"kind": "nades"}, {"kind": "health"},
]
const BOT_NAMES := ["Raju", "Pappu", "Chintu", "Golu", "Bunty", "Montu", "Tillu", "Babloo"]
const SKIN_PALETTE := [
	Color(0.27, 0.55, 0.97), Color(0.90, 0.30, 0.32), Color(0.30, 0.80, 0.45),
	Color(0.96, 0.62, 0.10), Color(0.65, 0.45, 0.95), Color(0.20, 0.78, 0.80),
]

var layout: Dictionary
var theme: Dictionary
var arena: Arena
var player: Fighter
var cam: Camera3D
var hud: CanvasLayer
var spawns: Array = []

# camera
var cam_yaw := 0.0
var cam_pitch := -0.12
var shake_mag := 0.0
var recoil_off := Vector2.ZERO       # transient aim kick from firing (x=yaw, y=pitch), recovers
var mouse_captured := false
var mouse_rel := Vector2.ZERO
var mouse_fire := false
var space_prev := false

# combat state
var bot_level := 1
var kills := 0
var current_weapon := 0
var ammo := -1                       # reserve rounds (-1 = infinite)
var mag := 30                        # rounds in the magazine
var grenades := 3
var unlimited_ammo := false
var fire_cooldown := 0.0
var time_remaining := 300.0
var match_over := false
var flame_count := 0
var jet_sound_on := false

# multiplayer
var is_mp := false
var local_id := 0
var remotes := {}                    # peer_id -> Fighter
var remote_targets := {}             # peer_id -> last state
var peer_kills := {}
var peer_teams := {}
var peer_captures := {}
var my_captures := 0
var net_timer := 0.0

# CTF
var flag_status: Array = []
var base_pos: Array = []
var flag_nodes: Array = []
var my_carrying := -1

var bots: Array = []
var pending_spawns: Array = []
var reinforce_timer := 9.0
var bot_name_bag: Array = []

var pickups := {}
var pickup_cycles := {}
var pickup_spots: Array = []

# HUD
var fuel_fill: ColorRect
var health_fill: ColorRect
var weapon_label: Label
var kills_label: Label
var timer_label: Label
var nade_button: Control
var jump_button: Control
var reload_button: Control
var reload_bar: ColorRect               # fills over RELOAD_TIME under the weapon label
var _reload_t0 := 0.0
var _reload_dur := 1.0
var fire_button: Control
var fire_button_l: Control
var scope_button: Control
var reticle: Control
const RECOIL_RECOVER := 9.0
var scope_overlay: Control
var ads := false
var ads_t := 0.0
var next_button: Button
var center_label: Label
var crosshair                       # _Crosshair (dynamic); untyped for inner-class access
var killfeed                        # _KillFeed
var dmg_ind                         # _DmgIndicator (red arcs toward attackers)
var minimap                         # _Minimap radar
var compass                         # _Compass heading strip
var announce_label: Label
var _streak := 0                    # kills without dying
var _multi := 0                     # kills within a short window
var _multi_t := 0.0
var pause_layer: CanvasLayer
var pause_box: VBoxContainer
var hit_vignette: ColorRect

# touch
var using_touch := false
var nade_id := -1
var nade_aim := Vector2.ZERO
var nade_dots: Array = []
var jump_id := -1
var jump_held := false
var jump_edge := false
var move_id := -1
var look_id := -1
var look_last := Vector2.ZERO
var look_delta := Vector2.ZERO
var fire_ids := {}                   # touch index -> true while a FIRE button is held
var move_base := Vector2.ZERO
var move_vec := Vector2.ZERO
var move_ring: Polygon2D
var move_knob: Polygon2D

var _fx_mesh: SphereMesh

func _ready() -> void:
	randomize()
	add_to_group("combat")
	is_mp = MatchCfg.is_multiplayer and Net.active
	if OS.has_environment("CP_MAP"):
		MatchCfg.map_index = int(OS.get_environment("CP_MAP"))
	layout = Maps3D.get_layout(MatchCfg.map_index)
	theme = layout["theme"]
	spawns = layout["spawns"]

	bot_level = clampi(MatchCfg.bot_level, 0, BOT_PROFILES.size() - 1)
	unlimited_ammo = MatchCfg.unlimited_ammo
	time_remaining = float(MatchCfg.minutes) * 60.0

	_fx_mesh = SphereMesh.new()
	_fx_mesh.radius = 0.09
	_fx_mesh.height = 0.18
	_fx_mesh.radial_segments = 6
	_fx_mesh.rings = 3

	arena = Arena.new()
	add_child(arena)
	arena.build(layout)

	player = Fighter.new()
	player.use_squad = true
	player.char_id = Settings.char_id
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
		player.position = spawns[0]
	add_child(player)
	player.set_name_text(Net.local_name if is_mp else Settings.resolved_name())
	player.died.connect(_on_player_died)
	player.slippery = bool(theme.get("slippery", false))
	player.footstep.connect(func() -> void:
		Audio.play("step", -14.0)
		spawn_dust(player.global_position, 0.6))
	# face the arena centre at spawn
	cam_yaw = atan2(player.position.x, player.position.z)
	player.set_aim(cam_yaw, 0.0)
	_equip(0)
	if OS.has_environment("CP_ADS"):
		_equip(int(OS.get_environment("CP_ADS")))
		_set_ads(true)

	_build_camera()
	_build_weather()
	_build_hud()
	_spawn_all_pickups()
	if is_mp and MatchCfg.mode == 2:
		_build_ctf()
	Audio.play_track("battle")

	if is_mp:
		Net.message.connect(_on_net_message)
		Net.peers_changed.connect(_reconcile_remotes)
	elif OS.has_environment("CP_SHOT"):
		pending_spawns = [0.2, 0.5, 0.9]
		_capture()
	else:
		_queue_wave(0.8)

func _capture() -> void:
	await get_tree().create_timer(float(OS.get_environment("CP_SHOT_DELAY")) if OS.has_environment("CP_SHOT_DELAY") else 3.0).timeout
	if OS.has_environment("CP_AERIAL"):
		var sz: Vector2 = layout["size"]
		var ac := Camera3D.new()
		ac.fov = 55.0
		ac.far = 500.0
		add_child(ac)
		ac.position = Vector3(0, maxf(sz.x, sz.y) * 0.95, sz.y * 0.75)
		ac.look_at(Vector3(0, 0, 0), Vector3.UP)
		ac.current = true
		hud.visible = false
		await get_tree().process_frame
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("CP_SHOT"))
	print("[shot] saved ", OS.get_environment("CP_SHOT"))
	get_tree().quit()

# MARK: camera

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.08
	cam.far = 260.0
	add_child(cam)
	cam.current = true
	_update_camera(1.0, true)

func _cam_dir() -> Vector3:
	var p := cam_pitch + recoil_off.y
	var y := cam_yaw + recoil_off.x
	var c := cos(p)
	return Vector3(-sin(y) * c, sin(p), -cos(y) * c)

## A clean FF-style dynamic crosshair: 4 ticks + a centre dot; `spread` pushes the ticks
## out when firing and eases back, so shots read as "spraying".
class _Crosshair:
	extends Control
	var spread := 0.0
	var hit_t := 0.0                     # hit-marker flash timer
	var hit_strong := false              # red (kill / headshot) instead of white
	func hit(strong: bool) -> void:
		hit_t = 0.22
		hit_strong = strong
		queue_redraw()
	func _process(delta: float) -> void:
		if hit_t > 0.0:
			hit_t -= delta
			queue_redraw()
	func _draw() -> void:
		var ctr := size / 2.0
		var gap := 5.0 + spread
		var ln := 7.0
		var th := 2.0
		var col := Color(1, 1, 1, 0.92)
		var sh := Color(0, 0, 0, 0.5)
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(ctr + d * gap + Vector2(1, 1), ctr + d * (gap + ln) + Vector2(1, 1), sh, th)
			draw_line(ctr + d * gap, ctr + d * (gap + ln), col, th)
		draw_circle(ctr, 1.7, col)
		if hit_t > 0.0:
			# FF/PUBG hit marker: four diagonal ticks that flash and shrink
			var k := clampf(hit_t / 0.22, 0.0, 1.0)
			var hc := (Color(1.0, 0.2, 0.15, k) if hit_strong else Color(1, 1, 1, k))
			var g2 := 6.0 + (1.0 - k) * 4.0
			var l2 := 9.0 if hit_strong else 7.0
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				var dn: Vector2 = (d as Vector2).normalized()
				draw_line(ctr + dn * g2 + Vector2(1, 1), ctr + dn * (g2 + l2) + Vector2(1, 1), Color(0, 0, 0, 0.5 * k), 3.0)
				draw_line(ctr + dn * g2, ctr + dn * (g2 + l2), hc, 3.0)

func _cam_right() -> Vector3:
	return Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))

func _update_camera(delta: float, snap := false) -> void:
	var pivot := player.global_position + Vector3(0, lerpf(CAM_UP, 1.5, ads_t), 0)
	var dir := _cam_dir()
	var rgt := _cam_right()
	var want := pivot - dir * lerpf(CAM_DIST, 1.45, ads_t) + rgt * lerpf(CAM_SIDE, 0.5, ads_t) + Vector3(0, lerpf(0.35, 0.12, ads_t), 0)
	# keep the camera out of walls
	var q := PhysicsRayQueryParameters3D.create(pivot, want, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		want = hit["position"] + hit["normal"] * 0.45 + (pivot - hit["position"]).normalized() * 0.3
	if snap:
		cam.global_position = want
	else:
		cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-delta * 16.0))
	var look := pivot + rgt * lerpf(CAM_SIDE, 0.5, ads_t) + dir * 10.0
	if ads_t > 0.01:
		look += Vector3(sin(Time.get_ticks_msec() * 0.0013), cos(Time.get_ticks_msec() * 0.0009), 0) * 0.02 * ads_t
	if shake_mag > 0.05:
		look += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake_mag * 0.06
		shake_mag = move_toward(shake_mag, 0.0, 60.0 * delta)
	cam.look_at(look, Vector3.UP)

func _build_weather() -> void:
	var w := arena.make_weather(String(theme.get("weather", "none")))
	if w:
		cam.add_child(w)

# MARK: HUD

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	move_ring = Shapes.circ(STICK_R, Color(1, 1, 1, 0.12))
	move_knob = Shapes.circ(34, Color(1, 1, 1, 0.32))
	for n in [move_ring, move_knob]:
		n.visible = false
		hud.add_child(n)

	hit_vignette = ColorRect.new()
	hit_vignette.color = Color(0.9, 0.1, 0.1, 0.0)
	hit_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hit_vignette)

	_hud_text("JET FUEL", Vector2(20, 16), 12, Color(1, 1, 1, 0.65))
	fuel_fill = _bar(Vector2(20, 34), Color(0.96, 0.62, 0.10))
	_hud_text("HEALTH", Vector2(20, 56), 12, Color(1, 1, 1, 0.65))
	health_fill = _bar(Vector2(20, 74), Color(0.30, 0.85, 0.40))
	weapon_label = _hud_text("", Vector2(20, 96), 15, Color(1, 1, 1, 0.92))
	reload_bar = ColorRect.new()
	reload_bar.color = Color(0.1, 0.1, 0.12, 0.7)
	reload_bar.size = Vector2(150, 5)
	reload_bar.position = Vector2(0, 30)
	reload_bar.visible = false
	var _rbf := ColorRect.new()
	_rbf.name = "fill"
	_rbf.color = Color(1.0, 0.8, 0.3)
	_rbf.size = Vector2(0, 5)
	reload_bar.add_child(_rbf)
	weapon_label.add_child(reload_bar)

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

	var name_label := Label.new()
	name_label.text = "%s    (map %d/6)" % [layout["name"], MatchCfg.map_index + 1]
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.modulate = Color(1, 1, 1, 0.55)
	name_label.anchor_left = 0.0; name_label.anchor_right = 1.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.offset_top = 70
	hud.add_child(name_label)

	# dynamic crosshair (4 ticks + dot; spreads on fire, tightens back — shooting feedback)
	var vp := get_viewport().get_visible_rect().size
	crosshair = _Crosshair.new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair)
	killfeed = _KillFeed.new()
	killfeed.set_anchors_preset(Control.PRESET_FULL_RECT)
	killfeed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(killfeed)
	dmg_ind = _DmgIndicator.new()
	dmg_ind.game = self
	dmg_ind.set_anchors_preset(Control.PRESET_FULL_RECT)
	dmg_ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dmg_ind)
	minimap = _Minimap.new()
	minimap.game = self
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(minimap)
	compass = _Compass.new()
	compass.game = self
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(compass)
	announce_label = Label.new()
	announce_label.add_theme_font_size_override("font_size", 34)
	announce_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	announce_label.add_theme_constant_override("outline_size", 8)
	announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announce_label.modulate.a = 0.0
	announce_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(announce_label)

	if not is_mp:
		pass   # map is chosen before the match (lobby map picker); no mid-game switching

	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.position = Vector2(vp.x - 58, 14)
	pause_btn.size = Vector2(44, 38)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.pressed.connect(_pause)
	hud.add_child(pause_btn)
	_build_pause()

	# on-screen buttons — positions come from Settings (HUD layout editor), same art as HudKit
	var hs: float = Settings.hud_scale
	nade_button = HudKit.make("nade", hs * Settings.hud_size_of("nade")); hud.add_child(nade_button)
	jump_button = HudKit.make("jump", hs * Settings.hud_size_of("jump")); hud.add_child(jump_button)
	fire_button = HudKit.make("fire", hs * Settings.hud_size_of("fire")); hud.add_child(fire_button)
	fire_button_l = HudKit.make("fire_l", hs * Settings.hud_size_of("fire_l")); hud.add_child(fire_button_l)
	reload_button = HudKit.make("reload", hs * Settings.hud_size_of("reload")); hud.add_child(reload_button)
	scope_button = HudKit.make("scope", hs * Settings.hud_size_of("scope")); hud.add_child(scope_button)
	reticle = _Reticle.new()
	reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.visible = false
	hud.add_child(reticle)
	scope_overlay = _ScopeOverlay.new()
	scope_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope_overlay.visible = false
	hud.add_child(scope_overlay)
	for pair in [[nade_button, "nade"], [jump_button, "jump"], [fire_button, "fire"], [fire_button_l, "fire_l"], [reload_button, "reload"], [scope_button, "scope"]]:
		HudKit.place(pair[0], Settings.hud_center(pair[1], vp))

	# grenade trajectory markers (3D, hidden until dragging)
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = Color(1, 0.85, 0.35, 0.9)
	dot_mat.no_depth_test = true
	for i in 16:
		var d := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09 if i < 15 else 0.18
		sm.height = sm.radius * 2.0
		sm.radial_segments = 6
		sm.rings = 3
		sm.material = dot_mat
		d.mesh = sm
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

	var hint := Label.new()
	hint.text = "Left: move   •   Right: drag to look   •   FIRE (auto-fires on target)   •   JUMP: hold = jetpack"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.anchor_left = 0.0; hint.anchor_right = 1.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_top = 1.0; hint.anchor_bottom = 1.0
	hint.offset_top = -26
	hud.add_child(hint)
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(hint, "modulate:a", 0.0, 1.0)

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
	if not weapon_label:
		return
	var d := Weapons.data(current_weapon)
	var reserve_text := "∞" if (unlimited_ammo or ammo == -1) else str(ammo)
	var nade_text := "∞" if unlimited_ammo else str(grenades)
	weapon_label.text = "%s  %d / %s   •   NADES %s" % [d["name"], mag, reserve_text, nade_text]
	if player and player.is_reloading():
		weapon_label.text += "   RELOADING…"

## Switch to weapon `w` with a full magazine + the weapon's reserve.
func _set_ads(on: bool) -> void:
	if ads == on:
		return
	ads = on
	if player and player.model:
		player.model.set_ads(on)
	Audio.play("swap", -10.0)

func _ads_fov() -> float:
	match current_weapon:
		Weapons.SNIPER: return 15.0
		Weapons.MAGNUM, Weapons.SHOTGUN: return 50.0
		Weapons.ROCKET, Weapons.FLAMER: return 56.0
		_: return 40.0

func _equip(w: int) -> void:
	_set_ads(false)
	current_weapon = w
	if player.model:
		player.model.cancel_reload()
	player.set_weapon(w)
	mag = MAG_SIZE[w]
	var total := int(Weapons.data(w)["ammo"])
	ammo = -1 if total < 0 else maxi(0, total)
	fire_cooldown = 0.0
	_update_weapon_hud()

func _start_reload() -> void:
	if player.dead or match_over or player.is_reloading():
		return
	if mag >= MAG_SIZE[current_weapon]:
		return
	if ammo == 0 and not unlimited_ammo:
		# dry: fall back to the rifle
		Audio.play("click")
		_equip(0)
		Audio.play("swap")
		return
	var dur: float = RELOAD_TIME[current_weapon]
	_reload_t0 = Time.get_ticks_msec() / 1000.0
	_reload_dur = dur
	Audio.play("reload")
	player.model.reload(dur, func() -> void:
		var need: int = MAG_SIZE[current_weapon] - mag
		if unlimited_ammo or ammo == -1:
			mag += need
		else:
			var take: int = mini(need, ammo)
			ammo -= take
			mag += take
		_update_weapon_hud())
	_update_weapon_hud()
	if is_mp:
		Net.send({"t": "rl", "w": current_weapon}, true)

func _next_map() -> void:
	MatchCfg.map_index = (MatchCfg.map_index + 1) % Maps.count()
	_release_mouse()
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
	_release_mouse()
	pause_layer.visible = true
	get_tree().paused = true
	Audio.set_jet(false)

func _resume() -> void:
	get_tree().paused = false
	pause_layer.visible = false

func _quit_to_menu() -> void:
	get_tree().paused = false
	_release_mouse()
	if Net.active:
		Net.leave()
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _release_mouse() -> void:
	mouse_captured = false
	mouse_fire = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# MARK: pickups

func _spawn_all_pickups() -> void:
	pickup_spots.clear()
	for v in layout["pickups"]:
		pickup_spots.append(v)
	for i in pickup_spots.size():
		_spawn_pickup(i)

func _spawn_pickup(spot: int) -> void:
	if pickups.has(spot) or spot >= pickup_spots.size():
		return
	var content: Dictionary = PICKUP_PATTERN[(spot + int(pickup_cycles.get(spot, 0))) % PICKUP_PATTERN.size()]
	var p := Pickup3D.new()
	p.game = self
	p.kind = content["kind"]
	p.weapon_type = int(content.get("w", 0))
	p.spot = spot
	p.position = pickup_spots[spot]
	add_child(p)
	pickups[spot] = p

func on_pickup(p: Pickup3D) -> void:
	if match_over or player.dead or not is_instance_valid(p) or p.taken:
		return
	p.taken = true
	match p.kind:
		"health":
			player.heal(40.0)
		"weapon":
			_equip(p.weapon_type)
			Audio.play("swap")
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
	# ease firing recoil + crosshair spread back to rest
	if recoil_off != Vector2.ZERO:
		recoil_off = recoil_off.lerp(Vector2.ZERO, 1.0 - exp(-delta * RECOIL_RECOVER))
	if crosshair and crosshair.spread > 0.01:
		crosshair.spread = move_toward(crosshair.spread, 0.0, 70.0 * delta)
		crosshair.queue_redraw()
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

	# --- resolve input: touch sticks own the device; keyboard/mouse are desktop-only
	var mv := move_vec
	var want_fire := not fire_ids.is_empty()
	var dragging := false
	var jump_now := jump_edge
	jump_edge = false
	var jet_hold := jump_held
	if not using_touch:
		var kb := _keyboard_move()
		if kb != Vector2.ZERO:
			mv = kb
		var sp := Input.is_key_pressed(KEY_SPACE)
		if sp and not space_prev:
			jump_now = true
		jet_hold = jet_hold or sp
		space_prev = sp
		if mouse_captured:
			var mk: float = lerpf(1.0, _ads_fov() / 72.0, ads_t)
			cam_yaw -= mouse_rel.x * MOUSE_SENS * mk
			cam_pitch = clampf(cam_pitch - mouse_rel.y * MOUSE_SENS * mk, -0.9, 0.7)
			mouse_rel = Vector2.ZERO
			if mouse_fire:
				want_fire = true
	ads_t = move_toward(ads_t, 1.0 if ads else 0.0, delta * 5.0)
	cam.fov = lerpf(72.0, _ads_fov(), ads_t)
	var zoom_k: float = lerpf(1.0, _ads_fov() / 72.0, ads_t)
	mouse_rel *= 1.0            # (mouse uses the same zoom factor below)
	if look_delta.length_squared() > 0.0:
		var sens: float = LOOK_SENS * [0.6, 1.0, 1.5][clampi(Settings.aim_sens, 0, 2)] * zoom_k
		cam_yaw -= look_delta.x * sens
		cam_pitch = clampf(cam_pitch - look_delta.y * sens, -0.9, 0.7)
		dragging = look_delta.length() > 0.8
		look_delta = Vector2.ZERO
	# gyroscope fine-aim (tilt the phone) — optional, combines with touch look
	if Settings.gyro_aim:
		var gy := Input.get_gyroscope()
		if gy.length_squared() > 0.0000004:
			var gs: float = [0.6, 1.0, 1.5][clampi(Settings.aim_sens, 0, 2)] * Settings.gyro_sens * zoom_k * 2.4
			cam_yaw += gy.y * delta * gs
			cam_pitch = clampf(cam_pitch + gy.x * delta * gs, -0.9, 0.7)
	# aim magnet + auto-fire: an enemy near the crosshair pulls the camera onto them
	if not player.dead and not match_over:
		var tgt := _assist_target(lerpf(10.0, 5.0, ads_t), lerpf(40.0, 80.0, ads_t))
		if tgt and not dragging:
			var to: Vector3 = (tgt.global_position + Vector3(0, 1.0, 0)) - player.eye_position()
			var ty := atan2(-to.x, -to.z)
			var tp := atan2(to.y, Vector2(to.x, to.z).length())
			var k := 1.0 - exp(-delta * MAGNET_RATE)
			cam_yaw = lerp_angle(cam_yaw, ty, k)
			cam_pitch = lerpf(cam_pitch, clampf(tp, -0.9, 0.7), k)
		if tgt and Settings.auto_fire and (using_touch or not mouse_captured):
			want_fire = true
	if OS.has_environment("CP_SHOT") and not want_fire:
		var t := _nearest_bot()
		if t:
			var to := (t.global_position + Vector3(0, 1, 0)) - player.eye_position()
			cam_yaw = atan2(-to.x, -to.z)
			cam_pitch = atan2(to.y, Vector2(to.x, to.z).length()) * 0.5
			want_fire = true
	if is_mp and OS.has_environment("CP_BOTPLAY") and not want_fire:
		var rt := _nearest_remote()
		if rt:
			var to := rt.global_position - player.global_position
			cam_yaw = atan2(-to.x, -to.z)
			want_fire = true
			mv = Vector2(0, -0.7)

	# camera-relative move
	var fwd := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
	var rgt := _cam_right()
	var move3 := rgt * mv.x + fwd * (-mv.y)
	if move3.length() > 1.0:
		move3 = move3.normalized()
	move3 *= lerpf(1.0, 0.5, ads_t)
	var scoped := ads_t > 0.5 and not player.dead
	reticle.visible = scoped and current_weapon != Weapons.SNIPER
	scope_overlay.visible = scoped and current_weapon == Weapons.SNIPER
	crosshair.visible = not scoped

	# facing: aiming/firing -> face the camera (shooter stance); else face the movement
	# direction (Free Fire style), except a backpedal which stays facing forward.
	var body_yaw := cam_yaw
	if move3.length() > 0.1 and not want_fire and ads_t < 0.5:
		var md := move3.normalized()
		var camfwd := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
		if md.dot(camfwd) > -0.35:
			body_yaw = atan2(-md.x, -md.z)     # face where we move
		else:
			body_yaw = cam_yaw                  # backpedal: keep facing forward
	player.set_aim(lerp_angle(player.aim_yaw, body_yaw, 1.0 - exp(-delta * 14.0)), cam_pitch)
	if player.model and player.model.has_method("set_aim_dir"):
		player.model.set_aim_dir(_shoot_dir())   # gun barrel follows the crosshair ray exactly
	if player.dead:
		player.velocity = Vector3(0, player.velocity.y - Fighter.GRAVITY * delta, 0)
		player.move_and_slide()
	else:
		player.control(move3, jet_hold, jump_now, delta)
	if player.jetting != jet_sound_on:
		jet_sound_on = player.jetting
		Audio.set_jet(jet_sound_on)

	if reload_bar:
		var rl := player.is_reloading()
		reload_bar.visible = rl
		if rl:
			var k := clampf((Time.get_ticks_msec() / 1000.0 - _reload_t0) / maxf(_reload_dur, 0.01), 0.0, 1.0)
			reload_bar.get_node("fill").size.x = reload_bar.size.x * k
	if want_fire:
		fire_cooldown -= delta
		if fire_cooldown <= 0.0 and not player.dead and not match_over:
			_fire()
			fire_cooldown = Weapons.data(current_weapon)["interval"]
	else:
		fire_cooldown = 0.0

	if player.global_position.y < Arena.DEATH_Y and not player.dead:
		_do_player_respawn()

	_update_camera(delta)

	fuel_fill.size.x = 170.0 * clampf(player.fuel / Fighter.MAX_FUEL, 0.0, 1.0)
	health_fill.size.x = 170.0 * clampf(player.health / player.max_health, 0.0, 1.0)
	hit_vignette.color.a = move_toward(hit_vignette.color.a, 0.0, delta * 1.2)
	_update_score_hud()
	if is_mp and not match_over:
		_check_win()

func _keyboard_move() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v

func _update_timer(delta: float) -> void:
	time_remaining = maxf(0.0, time_remaining - delta)
	var m := int(time_remaining) / 60
	var s := int(time_remaining) % 60
	timer_label.text = "%d:%02d" % [m, s]
	timer_label.modulate = Color(1, 0.4, 0.35) if time_remaining < 31.0 else Color.WHITE
	if time_remaining <= 0.0 and not match_over:
		_time_up()

# MARK: aiming + firing

func _enemies() -> Array:
	var out := []
	for b in bots:
		if not b.dead:
			out.append(b)
	for id in remotes:
		var r: Fighter = remotes[id]
		if not r.dead and not _is_friendly(id):
			out.append(r)
	return out

## Nearest visible enemy within `deg` of the crosshair and `max_d` metres (or null).
func _assist_target(deg: float, max_d: float) -> Fighter:
	var origin := player.eye_position()
	var base := _cam_dir()
	var best: Fighter = null
	var bestd := 1.0e9
	var space := get_world_3d().direct_space_state
	for f in _enemies():
		var chest: Vector3 = f.global_position + Vector3(0, 1.0, 0)
		var to := chest - origin
		var d := to.length()
		if d > max_d or d < 0.6:
			continue
		if base.angle_to(to) > deg_to_rad(deg):
			continue
		var q := PhysicsRayQueryParameters3D.create(origin, chest, 1)
		if space.intersect_ray(q):
			continue
		if d < bestd:
			bestd = d
			best = f
	return best

## Direction for the next shot: the assisted target if one sits near the crosshair,
## else the point the camera looks at (so bullets land on the crosshair).
func _shoot_dir() -> Vector3:
	var muzzle := player.muzzle_position()
	var space := get_world_3d().direct_space_state
	# Aim exactly where the on-screen crosshair points: cast from the CAMERA through
	# the screen centre (the camera is offset over-the-shoulder, so using the camera
	# ray — not the player's eye — is what makes bullets land on the crosshair).
	var sc := get_viewport().get_visible_rect().size * 0.5
	var ro := cam.project_ray_origin(sc)
	var rn := cam.project_ray_normal(sc)
	var far := ro + rn * 200.0
	var q2 := PhysicsRayQueryParameters3D.create(ro, far, 1)
	var hit := space.intersect_ray(q2)
	var target: Vector3 = hit["position"] if hit else far
	# tight aim-assist: only snap when an enemy sits very near the crosshair
	var best := _assist_target(AIM_ASSIST_DEG, 45.0)
	if best:
		var bp: Vector3 = best.global_position + Vector3(0, 1.0, 0)
		if (bp - ro).normalized().dot(rn) > cos(deg_to_rad(6.0)):
			target = bp
	if muzzle.distance_to(target) < 1.0:
		return rn
	return (target - muzzle).normalized()

static func _spread(dir: Vector3, amount: float) -> Vector3:
	if amount <= 0.0:
		return dir
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(dir).normalized()
	return (dir + side * randf_range(-amount, amount) + up * randf_range(-amount, amount)).normalized()

func _fire() -> void:
	if player.is_reloading():
		return
	if mag <= 0:
		_start_reload()
		return
	var d := Weapons.data(current_weapon)
	var muzzle := player.muzzle_position()
	var dir := _shoot_dir()
	var spread_k: float = lerpf(1.0, 0.3, ads_t)
	mag -= 1
	player.model.recoil(2.2 if current_weapon in [Weapons.SHOTGUN, Weapons.SNIPER, Weapons.MAGNUM, Weapons.ROCKET] else 1.0)
	player.model.fire_pose()
	match d["special"]:
		"rocket":
			_spawn_rocket(muzzle, dir, true, local_id)
		"flame":
			for i in int(d["pellets"]):
				_spawn_bullet(muzzle, _spread(dir, d["spread"] * spread_k), d, true, true, local_id)
		_:
			for i in int(d["pellets"]):
				_spawn_bullet(muzzle, _spread(dir, d["spread"] * spread_k), d, true, false, local_id)
			_muzzle_flash(muzzle, Color(1, 0.9, 0.4))
	_play_fire_sound()
	shake((1.5 if current_weapon != Weapons.SNIPER else 3.0) * lerpf(1.0, 0.5, ads_t))
	# recoil kick (view climbs + slight random horizontal) + crosshair bloom, per weapon
	var rf: float = 2.3 if current_weapon in [Weapons.SHOTGUN, Weapons.SNIPER, Weapons.MAGNUM, Weapons.ROCKET] else 1.0
	var ads_k := lerpf(1.0, 0.45, ads_t)
	recoil_off.y += 0.010 * rf * ads_k
	recoil_off.x += randf_range(-0.0045, 0.0045) * rf
	if crosshair:
		crosshair.spread = minf(crosshair.spread + 7.0 * rf * ads_k, 36.0)

	if is_mp:
		Net.send({"t": "fire", "x": muzzle.x, "y": muzzle.y, "z": muzzle.z,
			"dx": dir.x, "dy": dir.y, "dz": dir.z, "w": current_weapon}, false)

	_update_weapon_hud()
	if mag <= 0:
		_start_reload()

func _spawn_bullet(pos: Vector3, dir: Vector3, d: Dictionary, from_player: bool, flame: bool, owner_id := 0, shooter := "") -> void:
	var b := Bullet3D.new()
	b.game = self
	b.from_player = from_player
	b.owner_id = owner_id
	b.dmg = d["dmg"]
	b.life = d["life"]
	b.is_flame = flame
	b.wname = String(d.get("name", ""))
	b.shooter = shooter if shooter != "" else ("You" if from_player else "Enemy")
	b.vel = dir * float(d["speed"]) * PX_TO_M * (0.6 if flame else 1.0)
	b.position = pos
	add_child(b)

func _spawn_rocket(pos: Vector3, dir: Vector3, from_player: bool, owner_id := 0) -> void:
	var d := Weapons.data(Weapons.ROCKET)
	var r := Rocket3D.new()
	r.game = self
	r.from_player = from_player
	r.owner_id = owner_id
	r.dmg = d["dmg"]
	r.vel = dir * float(d["speed"]) * PX_TO_M
	r.position = pos
	add_child(r)
	_muzzle_flash(pos, Color(1, 0.7, 0.3))

## Each weapon gets a distinct fire sound — real SMG/pistol/explosion bases, tuned per
## gun by pitch + volume so an UZI, rifle, MP5, shotgun, sniper, magnum all sound different.
## Stream name of a weapon's real gunshot recording (see _play_fire_sound).
func _fire_sound_name(w: int) -> String:
	match w:
		Weapons.UZI: return "uzi"
		Weapons.MP5: return "mp5"
		Weapons.AK47: return "ak47"
		Weapons.SHOTGUN: return "shotgun"
		Weapons.SNIPER: return "sniper"
		Weapons.MAGNUM: return "magnum"
		Weapons.ROCKET: return "rocket"
		_: return "rifle"

func _play_fire_sound() -> void:
	# one REAL recording per weapon (fps-asset-kit CC0 firearm library), natural pitch
	match current_weapon:
		Weapons.UZI:
			Audio.play("uzi", -2.0)              # PPSh SMG
		Weapons.MP5:
			Audio.play("mp5", -1.5)              # 9mm SMG
		Weapons.AK47:
			Audio.play("ak47", 0.5)              # AK-47 7.62
		Weapons.SHOTGUN:
			Audio.play("shotgun", 1.5)           # 12ga pump
		Weapons.SNIPER:
			Audio.play("sniper", 2.0)            # 7.62x54 bolt rifle
		Weapons.MAGNUM:
			Audio.play("magnum", 0.5)            # .38 revolver
		Weapons.FLAMER:
			flame_count += 1
			if flame_count % 3 == 0:
				Audio.play("flame")
		Weapons.ROCKET:
			Audio.play("rocket")                 # real explosion launch
		_:
			Audio.play("rifle", 0.0)             # AR-15 / M4

## Called by Bullet3D when its ray hits something.
func bullet_hit(b: Bullet3D, hit: Dictionary) -> void:
	var col: Object = hit["collider"]
	var pos: Vector3 = hit["position"]
	if col is Fighter:
		var f := col as Fighter
		# head zone: the top ~30 cm of the body (2x damage, red numbers, announcer)
		var head := (pos.y - f.global_position.y) > 1.52 and not b.is_flame
		var dmg := b.dmg * (2.0 if head else 1.0)
		if f.is_remote:
			spawn_spark(pos)                       # cosmetic; the victim reports damage
			if b.from_player:
				_hit_feedback(pos, dmg, head, false)
		elif f.is_bot:
			if b.from_player:
				f.last_hit_wname = b.wname
				f.last_hit_by = "You"
				var died := f.take_hit(dmg)
				if not b.is_flame:
					spawn_spark(pos)
				_hit_feedback(pos, dmg, head, died)
				if died:
					shake(4.0)
					_register_kill(f.name_text, b.wname, head)
		elif f == player:
			damage_local_player(dmg, b.owner_id, pos, -b.vel.normalized(), b.shooter, b.wname)
	elif not b.is_flame:
		spawn_impact(pos, hit.get("normal", Vector3.UP), col)

# MARK: bullet decals + muzzle textures

static var _muzzle_tex: Texture2D
static var _hole_tex: Texture2D

func _muzzle_texture() -> Texture2D:
	if _muzzle_tex == null:
		_muzzle_tex = load("res://assets/real/fx/muzzle_flash.png")
	return _muzzle_tex

## A bullet hole stuck on a wall at the hit point, facing along the surface normal,
## fading out after a few seconds. Cheap unshaded quad (works on the Mobile renderer).
func spawn_bullet_hole(pos: Vector3, normal: Vector3) -> void:
	if _hole_tex == null:
		_hole_tex = load("res://assets/real/fx/bullethole.png")
	if _hole_tex == null:
		return
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _hole_tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.16)
	qm.material = m
	var q := MeshInstance3D.new()
	q.mesh = qm
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)
	q.global_position = pos + normal * 0.02
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	q.look_at(q.global_position + normal, up)
	q.rotate_object_local(Vector3(0, 0, 1), randf() * TAU)
	var tw := create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.0)
	tw.tween_callback(q.queue_free)

# MARK: grenades

func _quick_grenade() -> void:
	var base := _cam_dir()
	var flat := Vector3(base.x, 0, base.z).normalized()
	var p := clampf(cam_pitch + 0.45, -0.3, 1.2)
	_throw_grenade(flat * cos(p) + Vector3.UP * sin(p), 13.0)

func _throw_grenade(dir: Vector3, power: float) -> void:
	if player.dead or match_over:
		return
	if not unlimited_ammo and grenades <= 0:
		return
	if not unlimited_ammo:
		grenades -= 1
	_update_weapon_hud()
	var v := dir * power + Vector3(0, 1.5, 0)
	var spawn := func() -> void:
		var start: Vector3 = player.model.throw_hand_position() if player.model and player.model.has_method("throw_hand_position") else player.global_position + Vector3(0, 1.5, 0) + player.forward() * 0.6
		var g := Grenade3D.new()
		g.game = self
		g.from_player = true
		g.owner_id = local_id
		g.init_vel = v
		g.position = start
		add_child(g)
		Audio.play("nade_throw")
		if is_mp:
			Net.send({"t": "nade", "x": start.x, "y": start.y, "z": start.z, "vx": v.x, "vy": v.y, "vz": v.z}, true)
	if player.model and player.model.has_method("throw_pose"):
		player.model.throw_pose(0.55, spawn)      # arm wind-up -> release -> the grenade leaves the hand
	else:
		spawn.call()

func _nade_drag_dir_power() -> Array:
	var off := atan2(nade_aim.x, -nade_aim.y)
	var yaw := cam_yaw - off
	var flat := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var t := clampf((nade_aim.length() - 18.0) / 110.0, 0.0, 1.0)
	var pitch := 0.62
	return [flat * cos(pitch) + Vector3.UP * sin(pitch), 8.0 + t * 10.0]

func _release_nade() -> void:
	for d in nade_dots:
		d.visible = false
	if nade_aim.length() > 18.0:
		var dp := _nade_drag_dir_power()
		_throw_grenade(dp[0], dp[1])
	else:
		_quick_grenade()
	nade_id = -1
	nade_aim = Vector2.ZERO

func _update_nade_preview() -> void:
	if nade_aim.length() <= 18.0:
		for d in nade_dots:
			d.visible = false
		return
	var dp := _nade_drag_dir_power()
	var pos: Vector3 = player.global_position + Vector3(0, 1.5, 0) + player.forward() * 0.6
	var v: Vector3 = dp[0] * dp[1] + Vector3(0, 1.5, 0)
	var grav := Vector3(0, -Fighter.GRAVITY, 0)
	var prev := pos
	var landed := false
	var space := get_world_3d().direct_space_state
	for i in nade_dots.size():
		var d: MeshInstance3D = nade_dots[i]
		if landed:
			d.visible = false
			continue
		for _s in 2:
			v += grav * 0.06
			pos += v * 0.06
		var q := PhysicsRayQueryParameters3D.create(prev, pos, 1)
		var hit := space.intersect_ray(q)
		if hit:
			pos = hit["position"]
			landed = true
		d.visible = true
		d.global_position = pos
		d.scale = Vector3(1.7, 1.7, 1.7) if landed else Vector3.ONE
		prev = pos

# MARK: effects + damage

func spawn_spark(pos: Vector3) -> void:
	_burst(pos, 8, 0.28, 5.0, Color(1, 0.7, 0.25), 0.6)

func spawn_explosion(pos: Vector3) -> void:
	_spawn_explosion(pos)

func _spawn_explosion(pos: Vector3) -> void:
	# flash light
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.62, 0.25)
	light.light_energy = 14.0
	light.omni_range = 14.0
	light.shadow_enabled = false
	light.position = pos + Vector3(0, 0.6, 0)
	add_child(light)
	var tl := create_tween()
	tl.tween_property(light, "light_energy", 0.0, 0.35)
	tl.tween_callback(light.queue_free)
	# fireball: hot additive flame sprites bursting outward
	_fx_particles(pos, "res://assets/real/fx/flame_soft.png", 46, 0.55, 5.0, 11.0, Vector3(0, 3.0, 0), 0.9, 1.8,
		[Color(1, 0.98, 0.8, 1), Color(1, 0.6, 0.15, 1), Color(0.5, 0.15, 0.03, 0.6), Color(0.2, 0.1, 0.05, 0)], true, 0.16)
	# smoke: slow, rising, fading grey
	_fx_particles(pos + Vector3(0, 0.4, 0), "res://assets/real/fx/flame_soft.png", 34, 1.9, 1.2, 3.2, Vector3(0, 1.4, 0), 1.4, 2.8,
		[Color(0.25, 0.22, 0.2, 0.0), Color(0.3, 0.28, 0.26, 0.55), Color(0.35, 0.34, 0.33, 0.3), Color(0.4, 0.4, 0.4, 0)], false, 0.35)
	# debris: dark chunks thrown up with gravity
	_fx_debris(pos, 26, Color(0.16, 0.14, 0.12), 0.09, 9.0, 16.0, 1.6)
	# sparks
	_burst(pos, 30, 0.35, 12.0, Color(1, 0.75, 0.3), 0.7)
	# shockwave ring on the ground
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.75
	tm.outer_radius = 1.0
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_color = Color(1, 0.8, 0.5, 0.7)
	tm.material = rm
	ring.mesh = tm
	ring.position = pos + Vector3(0, 0.15, 0)
	ring.scale = Vector3(0.3, 0.12, 0.3)
	add_child(ring)
	var tr := create_tween()
	tr.set_parallel(true)
	tr.tween_property(ring, "scale", Vector3(7.0, 0.05, 7.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tr.tween_property(rm, "albedo_color:a", 0.0, 0.4)
	tr.chain().tween_callback(ring.queue_free)
	# scorch mark on whatever is below
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 1.0, 0), pos - Vector3(0, 3.0, 0), 1)
	var h := space.intersect_ray(q)
	if h:
		var dec := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(3.2, 3.2)
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.albedo_texture = load("res://assets/real/fx/scorch.png")
		dm.albedo_color = Color(1, 1, 1, 0.9)
		dm.cull_mode = BaseMaterial3D.CULL_DISABLED
		qm.material = dm
		dec.mesh = qm
		add_child(dec)
		var nrm: Vector3 = h["normal"]
		var up := Vector3.FORWARD if absf(nrm.dot(Vector3.UP)) > 0.95 else Vector3.UP
		dec.global_transform = Transform3D(Basis.looking_at(-nrm, up), h["position"] + nrm * 0.03)
		dec.rotate_object_local(Vector3.FORWARD, randf() * TAU)
		var td := create_tween()
		td.tween_interval(14.0)
		td.tween_property(dm, "albedo_color:a", 0.0, 3.0)
		td.tween_callback(dec.queue_free)
	# felt: shake by distance + positional boom
	if player:
		var d := player.global_position.distance_to(pos)
		shake(10.0 * clampf(1.0 - d / 30.0, 0.0, 1.0))
	Audio.play_at("explosion", pos, 4.0, 1.0, 120.0)

## Generic one-shot sprite particle burst (billboard quads), additive or alpha.
func _fx_particles(pos: Vector3, tex: String, amount: int, life: float, v0: float, v1: float, gravity: Vector3,
		s0: float, s1: float, ramp: Array, additive: bool, size: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = gravity
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.angular_velocity_min = -120.0
	p.angular_velocity_max = 120.0
	p.scale_amount_min = s0
	p.scale_amount_max = s1
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5)); sc.add_point(Vector2(0.3, 1.0)); sc.add_point(Vector2(1.0, 0.7))
	p.scale_amount_curve = sc
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ResourceLoader.exists(tex):
		mat.albedo_texture = load(tex)
	q.material = mat
	p.mesh = q
	p.color_ramp = Fighter._ramp(ramp)
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)

## Solid chunks with gravity (debris, chips, splinters).
func _fx_debris(pos: Vector3, amount: int, col: Color, size: float, v0: float, v1: float, life: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = Vector3(0, -22.0, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var b := BoxMesh.new()
	b.size = Vector3(size, size * 0.6, size * 1.4)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	b.material = m
	p.mesh = b
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)

## Small dust puff at the feet (footsteps / landing).
func spawn_dust(pos: Vector3, k := 1.0) -> void:
	var col := _ground_dust_color()
	_fx_particles(pos + Vector3(0, 0.05, 0), "res://assets/real/fx/flame_soft.png", int(6 * k) + 3, 0.55, 0.4, 1.3 * k,
		Vector3(0, 0.6, 0), 0.5 * k, 1.0 * k, [Color(col, 0.0), Color(col, 0.45), Color(col, 0.25), Color(col, 0.0)], false, 0.32)

func _ground_dust_color() -> Color:
	var th := String(theme.get("ground", "")) if theme else ""
	if th.contains("sand") or th.contains("desert"):
		return Color(0.76, 0.66, 0.5)
	if th.contains("grass") or th.contains("forest"):
		return Color(0.45, 0.42, 0.3)
	return Color(0.55, 0.53, 0.5)

## What a bullet hit, judged from the collider's mesh material / texture name.
func _surface_kind(col: Object) -> String:
	var mi: MeshInstance3D = null
	var cands: Array = []
	if col is Node:
		cands.append(col)
		cands.append_array((col as Node).get_children())
		var par := (col as Node).get_parent()
		if par:
			cands.append(par)
			cands.append_array(par.get_children())
	for c in cands:
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			mi = c
			break
	if mi == null:
		return "stone"
	var mat := mi.get_active_material(0)
	var key := ""
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		if bm.albedo_texture:
			key = String(bm.albedo_texture.resource_path).to_lower()
		key += " " + String(bm.resource_name).to_lower()
		if key.strip_edges() == "":
			var c := bm.albedo_color
			if c.r > c.b + 0.15 and c.g > c.b + 0.05:
				return "sand"
			if c.r < 0.3 and c.g < 0.3 and c.b < 0.3:
				return "metal"
	for k in ["sand", "desert", "dirt", "ground", "gravel"]:
		if key.contains(k): return "sand"
	for k in ["grass", "forest", "moss", "leaves"]:
		if key.contains(k): return "dirt"
	for k in ["metal", "diamond", "steel", "container", "barrel"]:
		if key.contains(k): return "metal"
	for k in ["wood", "plank", "crate", "log", "bark"]:
		if key.contains(k): return "wood"
	return "stone"

## Surface-specific bullet impact (replaces the one-size spark).
func spawn_impact(pos: Vector3, normal: Vector3, col: Object) -> void:
	var kind := _surface_kind(col)
	var n := normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	var p := pos + n * 0.04
	match kind:
		"sand":
			var c := Color(0.78, 0.68, 0.5)
			_fx_particles(p, "res://assets/real/fx/flame_soft.png", 12, 0.6, 1.2, 3.0, Vector3(0, -1.5, 0), 0.5, 1.1,
				[Color(c, 0.0), Color(c, 0.6), Color(c, 0.35), Color(c, 0.0)], false, 0.28)
		"dirt":
			var c := Color(0.42, 0.36, 0.26)
			_fx_particles(p, "res://assets/real/fx/flame_soft.png", 10, 0.55, 1.0, 2.6, Vector3(0, -2.0, 0), 0.5, 1.0,
				[Color(c, 0.0), Color(c, 0.6), Color(c, 0.3), Color(c, 0.0)], false, 0.26)
			_fx_debris(p, 6, Color(0.3, 0.25, 0.18), 0.03, 2.0, 5.0, 0.6)
		"metal":
			_burst(p, 16, 0.22, 9.0, Color(1, 0.85, 0.45), 0.45)
			_fx_debris(p, 8, Color(1.0, 0.8, 0.35), 0.012, 4.0, 9.0, 0.5)
			var l := OmniLight3D.new()
			l.light_color = Color(1, 0.8, 0.4); l.light_energy = 2.5; l.omni_range = 2.5; l.shadow_enabled = false
			l.position = p; add_child(l)
			var tl := create_tween(); tl.tween_property(l, "light_energy", 0.0, 0.08); tl.tween_callback(l.queue_free)
			spawn_bullet_hole(pos, normal)
		"wood":
			_fx_debris(p, 10, Color(0.45, 0.3, 0.16), 0.03, 2.5, 6.0, 0.7)
			var c := Color(0.5, 0.4, 0.28)
			_fx_particles(p, "res://assets/real/fx/flame_soft.png", 6, 0.45, 0.8, 2.0, Vector3(0, -1.0, 0), 0.4, 0.8,
				[Color(c, 0.0), Color(c, 0.5), Color(c, 0.2), Color(c, 0.0)], false, 0.22)
			spawn_bullet_hole(pos, normal)
		_:
			var c := Color(0.6, 0.58, 0.55)
			_fx_particles(p, "res://assets/real/fx/flame_soft.png", 9, 0.5, 0.9, 2.4, Vector3(0, -1.2, 0), 0.5, 1.0,
				[Color(c, 0.0), Color(c, 0.6), Color(c, 0.3), Color(c, 0.0)], false, 0.26)
			_fx_debris(p, 7, Color(0.5, 0.48, 0.45), 0.025, 2.5, 6.0, 0.6)
			_burst(p, 5, 0.18, 5.0, Color(1, 0.75, 0.35), 0.35)
			spawn_bullet_hole(pos, normal)

	_burst(pos + Vector3(0, 0.3, 0), 18, 1.1, 3.0, Color(0.35, 0.35, 0.35), 2.4)
	shake(9.0)
	Audio.play("explosion")

func _burst(pos: Vector3, count: int, life: float, speed: float, col: Color, psize: float) -> CPUParticles3D:
	var e := CPUParticles3D.new()
	e.position = pos
	e.emitting = true
	e.one_shot = true
	e.explosiveness = 0.95
	e.amount = count
	e.lifetime = life
	e.local_coords = false
	e.direction = Vector3(0, 1, 0)
	e.spread = 180.0
	e.initial_velocity_min = speed * 0.5
	e.initial_velocity_max = speed
	e.gravity = Vector3(0, -6.0, 0)
	e.scale_amount_min = psize * 0.6
	e.scale_amount_max = psize
	e.mesh = _fx_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.5
	e.material_override = m
	e.color_ramp = Fighter._ramp([Color(col.r, col.g, col.b, 1.0), Color(col.r, col.g, col.b, 0.0)])
	add_child(e)
	get_tree().create_timer(life + 0.3).timeout.connect(e.queue_free)
	return e

func explode(pos: Vector3, radius: float, dmg: float, owner_id := 0) -> void:
	_spawn_explosion(pos)
	if not player.dead and not match_over and not _is_friendly(owner_id):
		var dp := (player.global_position + Vector3(0, 0.9, 0)).distance_to(pos)
		if dp < radius:
			var amount := dmg * maxf(0.45, 1.0 - dp / radius)
			if dmg_ind:
				dmg_ind.add((pos - player.global_position).normalized())
			var died := player.take_hit(amount)
			if died:
				_kill_feed("Enemy", "You", "GRENADE", false)
				_streak = 0
			hit_vignette.color.a = 0.45
			shake(12.0 if died else 7.0)
			if is_mp:
				Net.send({"t": "hit", "x": player.global_position.x, "y": player.global_position.y, "z": player.global_position.z,
					"hp": player.health, "dead": died, "by": owner_id}, true)
	for b in bots:
		if b.dead:
			continue
		var db: float = (b.global_position + Vector3(0, 0.9, 0)).distance_to(pos)
		if db < radius:
			var a := dmg * maxf(0.45, 1.0 - db / radius)
			var died: bool = b.take_hit(a)
			if owner_id == local_id or owner_id == 0:
				_dmg_number(b.global_position + Vector3(0, 1.7, 0), a, false)
				if died:
					_register_kill(b.name_text, "GRENADE", false)

func _is_friendly(shooter_id: int) -> bool:
	return is_mp and MatchCfg.mode >= 1 and shooter_id != local_id \
		and int(peer_teams.get(shooter_id, -1)) == MatchCfg.local_team

func damage_local_player(dmg: float, killer_id: int, _pos: Vector3, from_dir := Vector3.ZERO, shooter := "", wname := "") -> void:
	if player.dead or match_over or _is_friendly(killer_id):
		return
	if dmg_ind and from_dir.length_squared() > 0.001:
		dmg_ind.add(from_dir)
	var died := player.take_hit(dmg)
	if died:
		_kill_feed(shooter if shooter != "" else "Enemy", "You", wname, false)
		_streak = 0
	hit_vignette.color.a = minf(0.5, hit_vignette.color.a + 0.25)
	Audio.play("hit")
	shake(6.0 if died else 2.5)
	if is_mp:
		Net.send({"t": "hit", "x": player.global_position.x, "y": player.global_position.y, "z": player.global_position.z,
			"hp": player.health, "dead": died, "by": killer_id}, true)

func _muzzle_flash(pos: Vector3, col: Color) -> void:
	var dir := _cam_dir() if player else Vector3.FORWARD
	# bright star-burst flash (two crossed quads + a forward cone)
	var flash := Node3D.new()
	flash.position = pos
	add_child(flash)
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.albedo_color = Color(1.0, 0.9, 0.6, 1.0)
	fmat.albedo_texture = _muzzle_texture()
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.75, 0.35)
	fmat.emission_energy_multiplier = 4.0
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# a real muzzle-flash sprite (billboarded quad), random roll each shot
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.62, 0.62)
	qm.material = fmat
	q.mesh = qm
	q.rotation.z = randf() * TAU
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.add_child(q)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 5.0
	light.omni_range = 6.0
	light.shadow_enabled = false
	flash.add_child(light)
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector3(1.5, 1.5, 1.5), 0.05).from(Vector3(0.7, 0.7, 0.7))
	tw.parallel().tween_property(fmat, "albedo_color:a", 0.0, 0.06)
	tw.parallel().tween_property(light, "light_energy", 0.0, 0.06)
	tw.tween_callback(flash.queue_free)
	# quick smoke puff forward
	var smoke := CPUParticles3D.new()
	smoke.position = pos + dir * 0.15
	smoke.emitting = true
	smoke.one_shot = true
	smoke.amount = 6
	smoke.lifetime = 0.5
	smoke.explosiveness = 0.7
	smoke.direction = dir
	smoke.spread = 18.0
	smoke.initial_velocity_min = 1.5
	smoke.initial_velocity_max = 3.0
	smoke.gravity = Vector3(0, 0.4, 0)
	smoke.scale_amount_min = 0.15
	smoke.scale_amount_max = 0.35
	var sm2 := SphereMesh.new(); sm2.radius = 0.1; sm2.height = 0.2; sm2.radial_segments = 6; sm2.rings = 3
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.7, 0.65, 0.6, 0.35)
	sm2.material = smat
	smoke.mesh = sm2
	smoke.color_ramp = Fighter._ramp([Color(0.8, 0.75, 0.7, 0.4), Color(0.6, 0.6, 0.6, 0.0)])
	add_child(smoke)
	get_tree().create_timer(0.8).timeout.connect(smoke.queue_free)

func shake(mag: float) -> void:
	shake_mag = maxf(shake_mag, mag)

# MARK: player death / respawn

func _on_player_died() -> void:
	_set_ads(false)
	_drop_flag_on_death()
	shake(8.0)
	get_tree().create_timer(1.8).timeout.connect(_do_player_respawn)

func _do_player_respawn() -> void:
	if match_over:
		return
	var sp: Vector3 = _team_spawn(MatchCfg.local_team) if is_mp else spawns[randi() % spawns.size()]
	player.respawn(sp)
	cam_yaw = atan2(sp.x, sp.z)
	cam_pitch = -0.12
	player.set_aim(cam_yaw, cam_pitch)
	_update_camera(1.0, true)
	_equip(0)

# MARK: multiplayer — victim-authoritative damage, 20 Hz state

func _local_skin() -> Array:
	if is_mp and MatchCfg.local_team == 0:
		var j := Color(0.27, 0.55, 0.97)
		return [j, Color(0.5, 0.95, 1.0), j, Color(j.r * 0.45, j.g * 0.45, j.b * 0.5), Color(0.86, 0.66, 0.5), j]
	if is_mp and MatchCfg.local_team == 1:
		var j := Color(0.90, 0.30, 0.32)
		return [j, Color(1.0, 0.82, 0.40), j, Color(j.r * 0.45, j.g * 0.45, j.b * 0.5), Color(0.74, 0.52, 0.38), j]
	return [Settings.skin_jacket, Settings.skin_accent, Settings.skin_helmet, Settings.skin_pants, Settings.skin_tone, Settings.skin_jacket2]

func _team_spawn(team: int) -> Vector3:
	if team < 0:
		return spawns[randi() % spawns.size()]
	var target: Vector3 = layout["bases"][team]
	var best: Vector3 = spawns[0]
	var bestd := 1.0e20
	for s in spawns:
		var dd: float = (s as Vector3).distance_squared_to(target)
		if dd < bestd:
			bestd = dd; best = s
	return best

func _broadcast_state(delta: float) -> void:
	net_timer -= delta
	if net_timer > 0.0:
		return
	net_timer = NET_INTERVAL
	var p := player.global_position
	Net.send({"t": "state",
		"x": p.x, "y": p.y, "z": p.z,
		"vx": player.velocity.x, "vy": player.velocity.y, "vz": player.velocity.z,
		"yaw": player.aim_yaw, "pit": player.aim_pitch, "hp": player.health, "dead": player.dead,
		"jet": player.jetting, "gr": player.is_on_floor(),
		"w": current_weapon, "k": kills, "c": my_captures, "team": MatchCfg.local_team,
		"jr": player.jacket.r, "jg": player.jacket.g, "jb": player.jacket.b,
		"ar": player.accent.r, "ag": player.accent.g, "ab": player.accent.b}, false)

func _update_remotes(delta: float) -> void:
	for id in remotes:
		var r: Fighter = remotes[id]
		var t: Dictionary = remote_targets.get(id, {})
		if t.is_empty():
			continue
		if r.global_position.y < Arena.DEATH_Y and not r.dead:
			r.dead = true
			r._set_body_visible(false)
			continue
		var target := Vector3(float(t["x"]), float(t["y"]), float(t["z"]))
		r.global_position = r.global_position.lerp(target, 0.3)
		r.velocity = Vector3(float(t["vx"]), float(t["vy"]), float(t["vz"]))
		r.set_aim(lerp_angle(r.aim_yaw, float(t["yaw"]), 0.4), float(t.get("pit", 0.0)))
		if int(t["w"]) != r.current_weapon:
			r.set_weapon(int(t["w"]))
		var now_dead: bool = bool(t["dead"])
		r.health = float(t["hp"])
		r._update_hp()
		if now_dead and not r.dead:
			r.dead = true
			r._set_body_visible(false)
		elif r.dead and not now_dead:
			r.dead = false
			r._set_body_visible(true)
		if not now_dead:
			r.set_thrust(bool(t.get("jet", false)))
			r.animate(delta, bool(t.get("gr", true)), Vector2(r.velocity.x, r.velocity.z).length())

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
			if remotes.has(sender) and remotes[sender].model and remotes[sender].model.has_method("throw_pose"):
				remotes[sender].model.throw_pose(0.55)
			var g := Grenade3D.new()
			g.game = self
			g.from_player = false
			g.owner_id = sender
			g.init_vel = Vector3(float(msg["vx"]), float(msg["vy"]), float(msg["vz"]))
			g.position = Vector3(float(msg["x"]), float(msg["y"]), float(msg["z"]))
			add_child(g)
		"hit":
			_remote_hit(sender, msg)
		"rl":
			if remotes.has(sender):
				var rw := clampi(int(msg.get("w", 0)), 0, RELOAD_TIME.size() - 1)
				remotes[sender].model.reload(RELOAD_TIME[rw])
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
	var r := Fighter.new()
	r.is_remote = true
	r.use_squad = true                    # remote players use the real rigged character too
	r.skin_jacket = Color(float(s.get("jr", 0.3)), float(s.get("jg", 0.5)), float(s.get("jb", 0.9)))
	r.skin_accent = Color(float(s.get("ar", 0.6)), float(s.get("ag", 0.9)), float(s.get("ab", 1.0)))
	r.name_text = Net.name_of(sender)
	r.position = Vector3(float(s["x"]), float(s["y"]), float(s["z"]))
	add_child(r)
	remotes[sender] = r

func _remote_fire(sender: int, msg: Dictionary) -> void:
	var w := int(msg["w"])
	var d := Weapons.data(w)
	var origin := Vector3(float(msg["x"]), float(msg["y"]), float(msg["z"]))
	var dir := Vector3(float(msg["dx"]), float(msg["dy"]), float(msg["dz"])).normalized()
	match d["special"]:
		"rocket":
			_spawn_rocket(origin, dir, false, sender)
		"flame":
			for i in int(d["pellets"]):
				_spawn_bullet(origin, _spread(dir, d["spread"]), d, false, true, sender)
		_:
			for i in int(d["pellets"]):
				_spawn_bullet(origin, _spread(dir, d["spread"]), d, false, false, sender, (remotes[sender].name_text if remotes.has(sender) else "Enemy"))
			_muzzle_flash(origin, Color(1, 0.5, 0.3))
	var dist := origin.distance_to(player.global_position)
	Audio.play_at(_fire_sound_name(w), origin, -2.0)
	if remotes.has(sender) and remotes[sender].model:
		remotes[sender].model.recoil()
		remotes[sender].model.fire_pose()

func _remote_hit(sender: int, msg: Dictionary) -> void:
	spawn_spark(Vector3(float(msg["x"]), float(msg["y"]) + 1.0, float(msg["z"])))
	if remotes.has(sender):
		var r: Fighter = remotes[sender]
		r.health = float(msg["hp"])
		r._update_hp()
		r._flash()
		if bool(msg["dead"]):
			_spawn_explosion(r.global_position + Vector3(0, 0.9, 0))
	if bool(msg["dead"]) and int(msg.get("by", 0)) == local_id:
		kills += 1
		shake(6.0)

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
	_release_mouse()
	Audio.play("win")

# MARK: CTF (mode 2)

func _build_ctf() -> void:
	base_pos = [layout["bases"][0], layout["bases"][1]]
	flag_status = [
		{"state": "home", "pos": base_pos[0], "by": 0},
		{"state": "home", "pos": base_pos[1], "by": 0}]
	for t in 2:
		var col := Color(0.27, 0.55, 0.97) if t == 0 else Color(0.90, 0.30, 0.32)
		var fn := _make_flag(col)
		fn.position = base_pos[t]
		add_child(fn)
		flag_nodes.append(fn)
		var pad := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.8
		cm.bottom_radius = 1.8
		cm.height = 0.08
		cm.radial_segments = 24
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(col.r, col.g, col.b, 0.55)
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.emission_enabled = true
		pm.emission = col
		pm.emission_energy_multiplier = 0.6
		cm.material = pm
		pad.mesh = cm
		pad.position = base_pos[t] + Vector3(0, 0.05, 0)
		add_child(pad)

func _make_flag(col: Color) -> Node3D:
	var n := Node3D.new()
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.06
	cm.height = 2.4
	cm.radial_segments = 8
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.85, 0.85, 0.85)
	pm.metallic = 0.6
	cm.material = pm
	pole.mesh = cm
	pole.position = Vector3(0, 1.2, 0)
	n.add_child(pole)
	var banner := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.55, 0.04)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = col
	bmat.emission_enabled = true
	bmat.emission = col
	bmat.emission_energy_multiplier = 0.8
	bm.material = bmat
	banner.mesh = bm
	banner.position = Vector3(0.47, 2.05, 0)
	n.add_child(banner)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.shadow_enabled = false
	light.position = Vector3(0, 2.0, 0)
	n.add_child(light)
	return n

func _near(p: Vector3, dist: float) -> bool:
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
					flag_nodes[t].position = player.global_position + Vector3(0, 1.0, 0.3)
				elif remotes.has(by):
					flag_nodes[t].position = remotes[by].global_position + Vector3(0, 1.0, 0.3)
	if player.dead or match_over or MatchCfg.local_team < 0:
		return
	var enemy := 1 - MatchCfg.local_team
	if my_carrying == -1:
		var es: Dictionary = flag_status[enemy]
		var can_take := false
		if es["state"] == "home":
			can_take = _near(base_pos[enemy], 2.2)
		elif es["state"] == "dropped":
			can_take = _near(es["pos"], 2.2)
		if can_take:
			flag_status[enemy] = {"state": "carried", "pos": Vector3.ZERO, "by": local_id}
			my_carrying = enemy
			Audio.play("pickup")
			Net.send({"t": "flag", "kind": 0, "team": enemy, "x": 0, "y": 0, "z": 0}, true)
		var ms: Dictionary = flag_status[MatchCfg.local_team]
		if ms["state"] == "dropped" and _near(ms["pos"], 2.2):
			flag_status[MatchCfg.local_team] = {"state": "home", "pos": base_pos[MatchCfg.local_team], "by": 0}
			Audio.play("pickup")
			Net.send({"t": "flag", "kind": 2, "team": MatchCfg.local_team, "x": 0, "y": 0, "z": 0}, true)
	elif _near(base_pos[MatchCfg.local_team], 2.5):
		if flag_status[MatchCfg.local_team]["state"] == "home":
			flag_status[my_carrying] = {"state": "home", "pos": base_pos[my_carrying], "by": 0}
			Net.send({"t": "flag", "kind": 3, "team": my_carrying, "x": 0, "y": 0, "z": 0}, true)
			my_carrying = -1
			my_captures += 1
			Audio.play("capture")
			shake(7.0)

func _apply_flag_event(by: int, msg: Dictionary) -> void:
	if flag_status.is_empty():
		return
	var team := int(msg["team"])
	if team < 0 or team > 1:
		return
	match int(msg["kind"]):
		0:
			flag_status[team] = {"state": "carried", "pos": Vector3.ZERO, "by": by}
		1:
			flag_status[team] = {"state": "dropped", "pos": Vector3(float(msg["x"]), float(msg["y"]), float(msg["z"])), "by": 0}
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
	Net.send({"t": "flag", "kind": 1, "team": my_carrying, "x": p.x, "y": p.y, "z": p.z}, true)
	my_carrying = -1

# MARK: bots — waves + AI

func _profile() -> Dictionary:
	return BOT_PROFILES[bot_level]

func _nearest_bot() -> Fighter:
	var best: Fighter = null
	var bestd := 1e20
	for b in bots:
		if b.dead:
			continue
		var dd: float = b.global_position.distance_squared_to(player.global_position)
		if dd < bestd:
			bestd = dd; best = b
	return best

func _nearest_remote() -> Fighter:
	var best: Fighter = null
	var bestd := 1.0e20
	for id in remotes:
		var r: Fighter = remotes[id]
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

	for b in bots.duplicate():
		if not b.dead:
			if b.global_position.y < Arena.DEATH_Y:
				b.take_hit(9999.0)
			else:
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
	var far: Array = spawns.filter(func(s): return (s as Vector3).distance_to(player.global_position) > 22.0)
	var pool: Array = far if not far.is_empty() else spawns
	var pos: Vector3 = pool[randi() % pool.size()]

	var b := Fighter.new()
	b.is_bot = true
	b.use_squad = true                    # enemies use the real rigged character (proper hands/gun)
	b.team = "enemy"
	b.current_weapon = BOT_LOADOUT[randi() % BOT_LOADOUT.size()]   # mixed enemy weapons
	b.name_text = nm
	b.position = pos
	b.slippery = bool(theme.get("slippery", false))
	add_child(b)
	b.set_weapon(b.current_weapon)
	b.footstep.connect(func() -> void:
		var dd: float = b.global_position.distance_to(player.global_position)
		if dd < 18.0:
			Audio.play_at("step", b.global_position, -6.0)
			spawn_dust(b.global_position, 0.5))
	b.died.connect(_on_bot_died.bind(b))
	bots.append(b)
	_spawn_flash(pos + Vector3(0, 1, 0))

func _on_bot_died(b: Fighter) -> void:
	kills += 1
	shake(2.5)
	Audio.play("hit", -3.0, 0.8)                      # kill confirm
	bots.erase(b)
	b._set_body_visible(false)                        # death fall, then a corpse is left behind
	get_tree().create_timer(1.7).timeout.connect(func() -> void:
		if is_instance_valid(b):
			b.queue_free())

func _spawn_flash(pos: Vector3) -> void:
	var f := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = m
	f.mesh = sm
	f.position = pos
	f.scale = Vector3(0.2, 0.2, 0.2)
	add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "scale", Vector3(1.6, 1.6, 1.6), 0.2)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.25)
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

func _run_bot_ai(b: Fighter, delta: float) -> void:
	var prof := _profile()
	var to := player.global_position - b.global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var dist := flat.length()
	var toward := flat.normalized() if dist > 0.01 else Vector3.FORWARD
	var side := toward.cross(Vector3.UP)

	b.think_t -= delta
	if b.think_t <= 0.0:
		b.think_t = randf_range(0.4, 0.9)
		b.strafe_sign = 1.0 if randf() < 0.5 else -1.0
		# line of sight: can this bot actually see the player?
		var q := PhysicsRayQueryParameters3D.create(b.eye_position(), player.global_position + Vector3(0, 1.0, 0), 1)
		b.los = get_world_3d().direct_space_state.intersect_ray(q).is_empty()
		if not player.dead and not b.los:
			# hunt: close in on the player's position until we see them
			b.move_dir = (toward + side * b.strafe_sign * 0.2).normalized()
			b.wants_dodge = false
		elif not player.dead and randf() < float(prof["chaseBias"]):
			if dist > float(prof["standoff"]) + 2.0:
				b.move_dir = (toward + side * b.strafe_sign * 0.35).normalized()
			elif dist < float(prof["standoff"]) - 2.0:
				b.move_dir = (-toward + side * b.strafe_sign * 0.5).normalized()
			else:
				b.move_dir = side * b.strafe_sign
		else:
			b.move_dir = [Vector3.ZERO, side, -side, toward * 0.6][randi() % 4]
		b.wants_dodge = randf() < float(prof["dodgeProb"])
		if b.wants_dodge:
			b.move_dir = side * b.strafe_sign
	if b.is_on_wall() and b.think_t > 0.2:
		b.move_dir = b.move_dir.rotated(Vector3.UP, 1.2)
		b.think_t = 0.2

	var speed_k: float = float(prof["speed"]) / Fighter.SPEED
	var want_jet := to.y > 2.5 and b.fuel > 20.0 and not b.is_on_floor()
	var jump := false
	b.jump_t -= delta
	if b.jump_t <= 0.0 and b.is_on_floor():
		if (to.y > 1.5 and randf() < 0.6) or b.is_on_wall() or (b.wants_dodge and randf() < 0.3):
			jump = true
			b.jump_t = randf_range(1.0, 2.5)
	b.control(b.move_dir * speed_k, want_jet, jump, delta)

	# aim (higher levels lead the moving target)
	var wd := Weapons.data(b.current_weapon)
	var flight := dist / (float(wd["speed"]) * PX_TO_M)
	var target := player.global_position + Vector3(0, 1.0, 0) + player.velocity * flight * float(prof["lead"])
	var m := b.muzzle_position()
	var ad := target - m
	var yaw := atan2(-ad.x, -ad.z)
	var pitch := atan2(ad.y, Vector2(ad.x, ad.z).length())
	b.set_aim(yaw, pitch)

	b.fire_t -= delta
	if b.fire_t <= 0.0 and not player.dead and dist < float(prof["range"]) and not match_over and b.los:
		var dir := _spread(ad.normalized(), float(prof["aimError"]))
		b.model.recoil(0.8)
		for i in int(wd["pellets"]):
			_spawn_bullet(m, _spread(dir, float(wd["spread"]) * 0.6), wd, false, false, 0, b.name_text)
		_muzzle_flash(m, Color(1, 0.5, 0.3))
		if b.model.has_method("fire_pose"): b.model.fire_pose()
		Audio.play_at(_fire_sound_name(b.current_weapon), m, -2.0)
		b.fire_t = maxf(randf_range(prof["fireMin"], prof["fireMax"]), float(wd["interval"]) * 1.6)

# MARK: input (touch sticks + keyboard/mouse)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_quick_grenade()
		elif event.keycode == KEY_ESCAPE:
			_release_mouse()
		elif event.keycode == KEY_R:
			_start_reload()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_7:
			_equip(event.keycode - KEY_1)   # weapons 0-6 (Rocket + Flamer removed)
			Audio.play("swap")
		return

	var vp := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		using_touch = true
		if event.pressed:
			if _btn_rect(nade_button, 14.0).has_point(event.position):
				nade_id = event.index
				nade_aim = Vector2.ZERO
				return
			if _btn_rect(jump_button, 14.0).has_point(event.position):
				jump_id = event.index
				jump_held = true
				jump_edge = true
				return
			if _btn_rect(reload_button, 10.0).has_point(event.position):
				_start_reload()
				return
			if _btn_rect(scope_button, 10.0).has_point(event.position):
				_set_ads(not ads)
				return
			if _btn_rect(fire_button, 16.0).has_point(event.position) or _btn_rect(fire_button_l, 12.0).has_point(event.position):
				fire_ids[event.index] = true
				return
			if _btn_rect(next_button, 4.0).has_point(event.position):
				return
			var move_side: bool = (event.position.x < vp.x / 2.0) != Settings.left_handed
			if move_side and move_id == -1:
				move_id = event.index; move_base = event.position
				_show(move_ring, move_knob, move_base)
			elif not move_side and look_id == -1:
				look_id = event.index; look_last = event.position
		else:
			if event.index == nade_id:
				_release_nade()
			elif event.index == jump_id:
				jump_id = -1
				jump_held = false
			elif fire_ids.has(event.index):
				fire_ids.erase(event.index)
			elif event.index == move_id:
				move_id = -1; move_vec = Vector2.ZERO
				move_ring.visible = false; move_knob.visible = false
			elif event.index == look_id:
				look_id = -1
	elif event is InputEventScreenDrag:
		if event.index == nade_id:
			nade_aim = event.position - _btn_rect(nade_button, 0.0).get_center()
		elif event.index == move_id:
			move_vec = _drag(move_base, event.position, move_knob)
		elif event.index == look_id:
			look_delta += event.position - look_last
			look_last = event.position
	elif not using_touch:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not mouse_captured:
					if not _screen_on_ui(event.position):
						mouse_captured = true
						Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				else:
					mouse_fire = true
			else:
				mouse_fire = false
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and mouse_captured:
			_set_ads(event.pressed)
		elif event is InputEventMouseMotion and mouse_captured:
			mouse_rel += event.relative

func _btn_rect(b: Control, pad: float) -> Rect2:
	if b == null:
		return Rect2()
	if b.has_meta("kind"):
		return HudKit.rect(b, pad)
	return b.get_global_rect().grow(pad)

func _screen_on_ui(p: Vector2) -> bool:
	return _btn_rect(nade_button, 12.0).has_point(p) or _btn_rect(jump_button, 12.0).has_point(p) or _btn_rect(reload_button, 8.0).has_point(p) or _btn_rect(scope_button, 8.0).has_point(p) \
		or _btn_rect(fire_button, 12.0).has_point(p) or _btn_rect(fire_button_l, 8.0).has_point(p) \
		or _btn_rect(next_button, 4.0).has_point(p) or p.y < 60.0 and p.x > get_viewport().get_visible_rect().size.x - 240.0

func _show(ring: Polygon2D, knob: Polygon2D, at: Vector2) -> void:
	ring.position = at; knob.position = at
	ring.visible = true; knob.visible = true

func _drag(base: Vector2, pos: Vector2, knob: Polygon2D) -> Vector2:
	var d := pos - base
	if d.length() > STICK_R:
		d = d.normalized() * STICK_R
	knob.position = base + d
	return d / STICK_R


## Red-dot style reticle for aimed shots (rifles / SMGs / pistols).
class _Reticle:
	extends Control
	func _draw() -> void:
		var c := size / 2.0
		var col := Color(1.0, 0.3, 0.2, 0.95)
		draw_arc(c, 22, 0, TAU, 48, Color(1, 1, 1, 0.55), 1.5, true)
		draw_circle(c, 2.6, col)
		for i in 4:
			var d := Vector2(cos(i * PI / 2.0), sin(i * PI / 2.0))
			draw_line(c + d * 8, c + d * 18, Color(1, 1, 1, 0.9), 1.8)
		# soft vignette
		draw_arc(c, size.length() * 0.9, 0, TAU, 64, Color(0, 0, 0, 0.35), size.length() * 0.9, false)

## Sniper scope: black outside a circle, glass tint, crosshair with mil-dots, range marks.
## Hit feedback for the local player's shots: crosshair marker, tick, floating damage number.
func _hit_feedback(pos: Vector3, dmg: float, head: bool, killed: bool) -> void:
	if crosshair:
		crosshair.hit(head or killed)
	Audio.play("hitmarker", -5.0 if not head else -2.0, 1.55 if head else 1.25)
	_dmg_number(pos + Vector3(0, 0.25, 0), dmg, head)

## FF-style floating "-23" (red + bigger for headshots).
func _dmg_number(pos: Vector3, dmg: float, head: bool) -> void:
	var l := Label3D.new()
	l.text = "-%d" % int(round(dmg))
	l.font_size = 88 if head else 64
	l.pixel_size = 0.005
	l.outline_size = 12
	l.modulate = Color(1.0, 0.25, 0.2) if head else Color(1.0, 0.92, 0.55)
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 0.9, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)

## A kill by the local player: feed entry + streak / multi-kill announcer.
func _register_kill(victim: String, wname: String, head: bool) -> void:
	_kill_feed("You", victim, wname, head)
	_streak += 1
	var now := Time.get_ticks_msec() / 1000.0
	_multi = _multi + 1 if now - _multi_t < 3.5 else 1
	_multi_t = now
	if head:
		_announce("HEADSHOT", Color(1.0, 0.3, 0.2))
	if _multi == 2:
		_announce("DOUBLE KILL", Color(1.0, 0.75, 0.2))
	elif _multi == 3:
		_announce("TRIPLE KILL", Color(1.0, 0.55, 0.15))
	elif _multi >= 4:
		_announce("RAMPAGE", Color(1.0, 0.35, 0.1))
	elif _streak == 5:
		_announce("KILLING SPREE", Color(1.0, 0.8, 0.3))
	elif _streak == 10:
		_announce("UNSTOPPABLE", Color(1.0, 0.5, 0.2))

func _kill_feed(killer: String, victim: String, wname: String, head: bool) -> void:
	if killfeed:
		killfeed.add(killer, victim, wname, head)

## Centre-top banner ("HEADSHOT", "DOUBLE KILL" …) with a punch-in + fade.
func _announce(text: String, col: Color) -> void:
	if not announce_label:
		return
	var vp := get_viewport().get_visible_rect().size
	announce_label.text = text
	announce_label.add_theme_color_override("font_color", col)
	announce_label.reset_size()
	announce_label.position = Vector2(vp.x * 0.5 - announce_label.size.x * 0.5, vp.y * 0.24)
	announce_label.pivot_offset = announce_label.size * 0.5
	announce_label.scale = Vector2(1.6, 1.6)
	announce_label.modulate.a = 1.0
	Audio.play("hitmarker", 2.0, 0.55)
	var tw := create_tween()
	tw.tween_property(announce_label, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.1)
	tw.tween_property(announce_label, "modulate:a", 0.0, 0.35)

## Top-right kill feed: "You ▶ Bravo15 [AK-47]"; entries fade after a few seconds.
class _KillFeed:
	extends Control
	var _box: VBoxContainer
	func _ready() -> void:
		_box = VBoxContainer.new()
		_box.alignment = BoxContainer.ALIGNMENT_BEGIN
		_box.add_theme_constant_override("separation", 2)
		add_child(_box)
		_layout()
		get_viewport().size_changed.connect(_layout)
	func _layout() -> void:
		var vp := get_viewport().get_visible_rect().size
		_box.position = Vector2(vp.x - 320, 62 + 150)   # right column, just under the minimap
		_box.size = Vector2(300, 0)
	func add(killer: String, victim: String, wname: String, head: bool) -> void:
		var l := Label.new()
		l.text = "%s  ▶  %s   [%s]%s" % [killer, victim, wname if wname != "" else "?", "  ☠" if head else ""]
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if killer == "You" and false else (Color(1, 0.9, 0.6) if killer == "You" else Color(1, 0.6, 0.55)))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 5)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_box.add_child(l)
		while _box.get_child_count() > 5:
			_box.get_child(0).queue_free()
			_box.remove_child(_box.get_child(0))
		var tw := l.create_tween()
		tw.tween_interval(4.5)
		tw.tween_property(l, "modulate:a", 0.0, 0.6)
		tw.tween_callback(l.queue_free)

## Red arcs at the screen edge pointing toward whoever just hurt you.
class _DmgIndicator:
	extends Control
	var game
	var _arcs: Array = []      # [angle_rad, t]
	func add(world_dir: Vector3) -> void:
		var fwd: Vector3 = game._cam_dir()
		var rgt: Vector3 = game._cam_right()
		var d := Vector3(world_dir.x, 0.0, world_dir.z).normalized()
		var ang := atan2(d.dot(rgt), d.dot(fwd))    # 0 = ahead, +right
		_arcs.append([ang, 1.0])
		queue_redraw()
	func _process(delta: float) -> void:
		if _arcs.is_empty():
			return
		for a in _arcs:
			a[1] -= delta * 1.1
		_arcs = _arcs.filter(func(a): return a[1] > 0.0)
		queue_redraw()
	func _draw() -> void:
		var ctr := size * 0.5
		var r := minf(size.x, size.y) * 0.21
		for a in _arcs:
			var k: float = clampf(a[1], 0.0, 1.0)
			var mid: float = a[0] - PI * 0.5          # screen: up = ahead
			draw_arc(ctr, r, mid - 0.45, mid + 0.45, 24, Color(1.0, 0.15, 0.1, 0.85 * k), 9.0, true)
			draw_arc(ctr, r + 7.0, mid - 0.3, mid + 0.3, 16, Color(1.0, 0.4, 0.3, 0.45 * k), 4.0, true)

## Radar minimap: camera-up, enemies red, pickups yellow, range ring.
class _Minimap:
	extends Control
	var game
	const RANGE := 42.0
	const R := 66.0
	func _ready() -> void:
		_layout()
		get_viewport().size_changed.connect(_layout)
	func _layout() -> void:
		var vp := get_viewport().get_visible_rect().size
		size = Vector2(R * 2 + 12, R * 2 + 12)
		position = Vector2(vp.x - size.x - 18, 62)
	func _process(_d: float) -> void:
		queue_redraw()
	func _to_map(world: Vector3) -> Vector2:
		var rel: Vector3 = world - game.player.global_position
		var fwd: Vector3 = game._cam_dir(); fwd.y = 0; fwd = fwd.normalized()
		var rgt: Vector3 = game._cam_right()
		var p := Vector2(rel.dot(rgt), -rel.dot(fwd)) * (R / RANGE)
		if p.length() > R - 4.0:
			p = p.normalized() * (R - 4.0)
		return p
	func _draw() -> void:
		if game == null or game.player == null:
			return
		var c := size * 0.5
		draw_circle(c, R + 3.0, Color(0, 0, 0, 0.45))
		draw_circle(c, R, Color(0.08, 0.1, 0.12, 0.72))
		draw_arc(c, R, 0, TAU, 48, Color(1, 1, 1, 0.35), 1.5, true)
		draw_arc(c, R * 0.5, 0, TAU, 32, Color(1, 1, 1, 0.12), 1.0, true)
		draw_line(c - Vector2(R, 0), c + Vector2(R, 0), Color(1, 1, 1, 0.08), 1.0)
		draw_line(c - Vector2(0, R), c + Vector2(0, R), Color(1, 1, 1, 0.08), 1.0)
		# view cone
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(-R * 0.55, -R), c + Vector2(R * 0.55, -R)]), Color(1, 1, 1, 0.06))
		# pickups
		for k in game.pickups:
			var pk = game.pickups[k]
			if is_instance_valid(pk) and not pk.taken:
				draw_circle(c + _to_map(pk.global_position), 2.2, Color(1.0, 0.85, 0.3, 0.9))
		# enemies
		for b in game.bots:
			if is_instance_valid(b) and not b.dead:
				var mp := c + _to_map(b.global_position)
				draw_circle(mp, 4.5, Color(0, 0, 0, 0.6))
				draw_circle(mp, 3.4, Color(1.0, 0.22, 0.18))
		for id in game.remotes:
			var r = game.remotes[id]
			if is_instance_valid(r) and not r.dead:
				var mp := c + _to_map(r.global_position)
				draw_circle(mp, 4.5, Color(0, 0, 0, 0.6))
				draw_circle(mp, 3.4, Color(1.0, 0.45, 0.2))
		# player arrow (always up)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(-5, 5), c + Vector2(5, 5)]), Color(1, 1, 1, 0.98))
		# north tick
		var fwd: Vector3 = game._cam_dir(); fwd.y = 0; fwd = fwd.normalized()
		var rgt: Vector3 = game._cam_right()
		var n := Vector2(Vector3.FORWARD.dot(rgt), -Vector3.FORWARD.dot(fwd)).normalized() * (R - 9.0)
		draw_string(ThemeDB.fallback_font, c + n + Vector2(-4, 5), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1, 1, 1, 0.8))

## PUBG-style heading strip at the top centre.
class _Compass:
	extends Control
	var game
	func _ready() -> void:
		_layout()
		get_viewport().size_changed.connect(_layout)
	func _layout() -> void:
		var vp := get_viewport().get_visible_rect().size
		size = Vector2(260, 22)
		position = Vector2(vp.x * 0.5 - 130, 100)
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if game == null:
			return
		var w := size.x
		draw_rect(Rect2(0, 0, w, size.y), Color(0, 0, 0, 0.35))
		# heading in degrees (0 = north = -Z)
		var fwd: Vector3 = game._cam_dir(); fwd.y = 0; fwd = fwd.normalized()
		var heading := rad_to_deg(atan2(fwd.x, -fwd.z))
		var px_per_deg := w / 120.0
		var labels := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
		for deg in range(-180, 541, 15):
			var d := float(deg) - heading
			if d < -60.0 or d > 60.0:
				continue
			var x := w * 0.5 + d * px_per_deg
			var key := int(posmod(deg, 360))
			if labels.has(key):
				draw_string(ThemeDB.fallback_font, Vector2(x - 8, 16), labels[key], HORIZONTAL_ALIGNMENT_CENTER, 16, 12, Color(1, 1, 1, 0.9))
			else:
				draw_line(Vector2(x, 14), Vector2(x, 20), Color(1, 1, 1, 0.5), 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5, 1), Vector2(w * 0.5 - 5, -6), Vector2(w * 0.5 + 5, -6)]), Color(1, 0.8, 0.3))
		draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 14, size.y + 12), "%d°" % int(posmod(int(heading), 360)), HORIZONTAL_ALIGNMENT_CENTER, 28, 11, Color(1, 1, 1, 0.75))

class _ScopeOverlay:
	extends Control
	func _draw() -> void:
		var c := size / 2.0
		var R := minf(size.x, size.y) * 0.46
		draw_arc(c, R + 2000.0, 0, TAU, 96, Color(0.01, 0.01, 0.02), 4000.0, false)
		draw_arc(c, R, 0, TAU, 96, Color(0.2, 0.55, 0.9, 0.08), R * 0.25, false)
		draw_arc(c, R, 0, TAU, 128, Color(0.05, 0.05, 0.06), 10.0, true)
		draw_arc(c, R - 8, 0, TAU, 128, Color(0.35, 0.8, 1.0, 0.35), 2.0, true)
		var line := Color(0.05, 0.05, 0.05, 0.95)
		draw_line(c + Vector2(-R, 0), c + Vector2(R, 0), line, 2.0)
		draw_line(c + Vector2(0, -R), c + Vector2(0, R), line, 2.0)
		draw_line(c + Vector2(-R, 0), c + Vector2(-R * 0.35, 0), line, 6.0)
		draw_line(c + Vector2(R * 0.35, 0), c + Vector2(R, 0), line, 6.0)
		draw_line(c + Vector2(0, R * 0.35), c + Vector2(0, R), line, 6.0)
		for i in range(1, 5):
			var o := i * R * 0.08
			draw_circle(c + Vector2(o, 0), 2.5, line)
			draw_circle(c + Vector2(-o, 0), 2.5, line)
			draw_circle(c + Vector2(0, o), 2.5, line)
			draw_circle(c + Vector2(0, -o), 2.5, line)
		draw_circle(c, 3.0, Color(1.0, 0.25, 0.2))
		var f := ThemeDB.fallback_font
		draw_string(f, c + Vector2(R * 0.55, -R * 0.62), "8x", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.9, 1.0, 0.7))
