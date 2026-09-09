## Settings (autoload) — persisted player prefs (ConfigFile at user://). Mirrors the
## iOS GameSettings: name, robot skin (Colors / Army / Custom), audio, controls, match.
extends Node

const PATH := "user://chorpolice.cfg"

# 20 character colours — first 10 solid, last 10 unique vertical gradients (a=top, b=bottom).
const COLORS := [
	{"a": Color(0.27, 0.55, 0.97), "b": Color(0.27, 0.55, 0.97)},   # Blue
	{"a": Color(0.93, 0.30, 0.32), "b": Color(0.93, 0.30, 0.32)},   # Red
	{"a": Color(0.30, 0.78, 0.40), "b": Color(0.30, 0.78, 0.40)},   # Green
	{"a": Color(0.62, 0.45, 0.95), "b": Color(0.62, 0.45, 0.95)},   # Purple
	{"a": Color(0.96, 0.60, 0.20), "b": Color(0.96, 0.60, 0.20)},   # Orange
	{"a": Color(0.20, 0.80, 0.85), "b": Color(0.20, 0.80, 0.85)},   # Cyan
	{"a": Color(0.95, 0.40, 0.70), "b": Color(0.95, 0.40, 0.70)},   # Pink
	{"a": Color(0.95, 0.85, 0.25), "b": Color(0.95, 0.85, 0.25)},   # Yellow
	{"a": Color(0.15, 0.65, 0.60), "b": Color(0.15, 0.65, 0.60)},   # Teal
	{"a": Color(0.50, 0.55, 0.66), "b": Color(0.50, 0.55, 0.66)},   # Slate
	{"a": Color(1.00, 0.58, 0.15), "b": Color(0.95, 0.22, 0.45)},   # Sunset
	{"a": Color(0.25, 0.85, 0.95), "b": Color(0.15, 0.35, 0.88)},   # Ocean
	{"a": Color(0.70, 0.35, 0.97), "b": Color(0.96, 0.28, 0.70)},   # Grape
	{"a": Color(0.72, 0.95, 0.28), "b": Color(0.13, 0.62, 0.36)},   # Lime
	{"a": Color(1.00, 0.85, 0.25), "b": Color(0.90, 0.18, 0.15)},   # Fire
	{"a": Color(0.28, 0.96, 0.66), "b": Color(0.13, 0.52, 0.78)},   # Aurora
	{"a": Color(1.00, 0.45, 0.66), "b": Color(0.52, 0.18, 0.72)},   # Berry
	{"a": Color(0.58, 0.72, 0.97), "b": Color(0.24, 0.28, 0.52)},   # Steel
	{"a": Color(1.00, 0.80, 0.30), "b": Color(0.95, 0.42, 0.10)},   # Mango
	{"a": Color(0.38, 0.46, 0.97), "b": Color(0.66, 0.24, 0.86)},   # Galaxy
]

# country army uniforms (jacket + accent). Mirrors iOS ArmySkins.
const ARMY := [
	{"name": "India", "jacket": Color(0.33, 0.42, 0.18), "accent": Color(1.00, 0.60, 0.20)},
	{"name": "USA", "jacket": Color(0.16, 0.22, 0.38), "accent": Color(0.90, 0.25, 0.30)},
	{"name": "Russia", "jacket": Color(0.24, 0.32, 0.20), "accent": Color(0.92, 0.20, 0.20)},
	{"name": "China", "jacket": Color(0.72, 0.16, 0.16), "accent": Color(1.00, 0.82, 0.20)},
	{"name": "UK", "jacket": Color(0.13, 0.18, 0.32), "accent": Color(0.92, 0.92, 0.96)},
	{"name": "Japan", "jacket": Color(0.84, 0.85, 0.88), "accent": Color(0.90, 0.15, 0.20)},
	{"name": "Germany", "jacket": Color(0.35, 0.37, 0.33), "accent": Color(0.95, 0.75, 0.20)},
	{"name": "Brazil", "jacket": Color(0.10, 0.55, 0.30), "accent": Color(0.98, 0.85, 0.20)},
	{"name": "France", "jacket": Color(0.20, 0.30, 0.60), "accent": Color(0.88, 0.22, 0.26)},
	{"name": "Pakistan", "jacket": Color(0.05, 0.40, 0.25), "accent": Color(0.95, 0.95, 0.95)},
]

# Selectable characters (locker). `owned` ones are playable now; the rest are slots to
# fill as rigged models are added — map each id → model in human_model.gd's char loader.
const CHARACTERS := [
	{"id": "bravo", "name": "Ghost", "tag": "Assault", "tier": "EPIC", "col": Color(1.0, 0.55, 0.15), "owned": true},
	{"id": "striker", "name": "Ace", "tag": "Striker", "tier": "RARE", "col": Color(0.35, 0.7, 1.0), "owned": true},
	{"id": "nova", "name": "Nova", "tag": "Sniper", "tier": "LEGENDARY", "col": Color(0.85, 0.4, 0.9), "owned": true},
	{"id": "vector", "name": "Vector", "tag": "Support", "tier": "RARE", "col": Color(0.4, 0.9, 0.7), "owned": false},
	{"id": "raptor", "name": "Raptor", "tag": "Scout", "tier": "COMMON", "col": Color(0.6, 0.66, 0.78), "owned": false},
]

var player_name := ""
var player_id := ""                      # auto, persistent — your account id for friends
var char_id := "bravo"                   # selected character (see CHARACTERS)
var skin_mode := 0                       # 0 Colors, 1 Army, 2 Custom
var color_index := 0
var army_index := 0
var custom_jacket := Color(0.27, 0.55, 0.97)
var custom_accent := Color(0.50, 0.95, 1.00)
var custom_helmet := Color(0.20, 0.42, 0.85)
var custom_pants := Color(0.16, 0.22, 0.42)
var custom_tone := Color(0.82, 0.62, 0.45)
var sound_on := true
var music_on := true
var zoom := 0.62
var left_handed := false
# HUD layout: kind -> Vector2 centre as a fraction of the screen (right-handed space)
const HUD_DEFAULTS := {
	"fire": Vector2(0.930, 0.800), "fire_l": Vector2(0.055, 0.440), "jump": Vector2(0.828, 0.675),
	"reload": Vector2(0.775, 0.865), "nade": Vector2(0.888, 0.915), "scope": Vector2(0.963, 0.575),
}
var hud_layout := {}
var hud_scale := 1.0
var hud_size := {}   # per-button size multiplier (kind -> float)
var auto_fire := true                    # fire by itself when an enemy is in the crosshair
var aim_sens := 1                        # 0 low, 1 normal, 2 high (touch look sensitivity)
var gyro_aim := false                    # tilt the phone to fine-aim (gyroscope)
var gyro_sens := 1.0                     # gyro aim strength multiplier
var bot_level := 1
var unlimited_ammo := false
var kills_to_win := 10

# resolved skin — recomputed from the mode/selection
var skin_jacket := Color(0.27, 0.55, 0.97)
var skin_jacket2 := Color(0.27, 0.55, 0.97)   # gradient bottom (== jacket when not a gradient)
var skin_accent := Color(0.50, 0.95, 1.00)
var skin_helmet := Color(0.27, 0.55, 0.97)
var skin_pants := Color(0.13, 0.27, 0.50)
var skin_tone := Color(0.86, 0.66, 0.50)

func _ready() -> void:
	load_cfg()
	resolve_skin()

func resolved_name() -> String:
	return player_name if player_name.strip_edges() != "" else "Player"

func _gen_id() -> String:
	var chars := "0123456789abcdefghijklmnopqrstuvwxyz"
	var s := ""
	for i in 20:
		s += chars[randi() % chars.length()]
	return s

static func accent_for(j: Color) -> Color:
	return Color(j.r + (1.0 - j.r) * 0.55, j.g + (1.0 - j.g) * 0.55, j.b + (1.0 - j.b) * 0.55)

## Recompute the 5 skin colours from the current mode (call after any skin change).
func resolve_skin() -> void:
	match skin_mode:
		1:
			var u: Dictionary = ARMY[clampi(army_index, 0, ARMY.size() - 1)]
			skin_jacket = u["jacket"]
			skin_jacket2 = skin_jacket
			skin_accent = u["accent"]
			skin_helmet = skin_jacket
			skin_pants = Color(skin_jacket.r * 0.45, skin_jacket.g * 0.45, skin_jacket.b * 0.5)
			skin_tone = Color(0.82, 0.62, 0.45)
		2:
			skin_jacket = custom_jacket
			skin_jacket2 = custom_jacket
			skin_accent = custom_accent
			skin_helmet = custom_helmet
			skin_pants = custom_pants
			skin_tone = custom_tone
		_:
			var e: Dictionary = COLORS[color_index % COLORS.size()]
			skin_jacket = e["a"]
			skin_jacket2 = e["b"]
			skin_accent = accent_for(e["a"])
			skin_helmet = e["a"]
			skin_pants = Color(skin_jacket.r * 0.45, skin_jacket.g * 0.45, skin_jacket.b * 0.5)
			skin_tone = Color(0.86, 0.66, 0.50)

func load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	player_name = c.get_value("s", "name", "")
	char_id = str(c.get_value("s", "char", "bravo"))
	player_id = c.get_value("s", "pid", "")
	if player_id == "":
		player_id = _gen_id()
		save_cfg()
	skin_mode = int(c.get_value("s", "skin_mode", 0))
	color_index = int(c.get_value("s", "color", 0))
	army_index = int(c.get_value("s", "army", 0))
	custom_jacket = c.get_value("s", "c_jacket", custom_jacket)
	custom_accent = c.get_value("s", "c_accent", custom_accent)
	custom_helmet = c.get_value("s", "c_helmet", custom_helmet)
	custom_pants = c.get_value("s", "c_pants", custom_pants)
	custom_tone = c.get_value("s", "c_tone", custom_tone)
	sound_on = bool(c.get_value("s", "sound", true))
	music_on = bool(c.get_value("s", "music", true))
	zoom = float(c.get_value("s", "zoom", 0.62))
	left_handed = bool(c.get_value("s", "left", false))
	auto_fire = bool(c.get_value("s", "autofire", true))
	gyro_aim = bool(c.get_value("s", "gyro", false))
	gyro_sens = float(c.get_value("s", "gyrosens", 1.0))
	hud_scale = float(c.get_value("hud", "scale", 1.0))
	hud_size = {}
	for hk in ["fire", "fire_l", "jump", "reload", "nade", "scope"]:
		if c.has_section_key("hud", "sz_" + hk):
			hud_size[hk] = float(c.get_value("hud", "sz_" + hk))
	hud_layout = {}
	for k in HUD_DEFAULTS:
		if c.has_section_key("hud", k):
			hud_layout[k] = c.get_value("hud", k)
	aim_sens = int(c.get_value("s", "aimsens", 1))
	bot_level = int(c.get_value("s", "bot", 1))
	unlimited_ammo = bool(c.get_value("s", "unlim", false))
	kills_to_win = int(c.get_value("s", "kills", 10))

func save_cfg() -> void:
	var c := ConfigFile.new()
	c.set_value("s", "name", player_name)
	c.set_value("s", "char", char_id)
	c.set_value("s", "pid", player_id)
	c.set_value("s", "skin_mode", skin_mode)
	c.set_value("s", "color", color_index)
	c.set_value("s", "army", army_index)
	c.set_value("s", "c_jacket", custom_jacket)
	c.set_value("s", "c_accent", custom_accent)
	c.set_value("s", "c_helmet", custom_helmet)
	c.set_value("s", "c_pants", custom_pants)
	c.set_value("s", "c_tone", custom_tone)
	c.set_value("s", "sound", sound_on)
	c.set_value("s", "music", music_on)
	c.set_value("s", "zoom", zoom)
	c.set_value("s", "left", left_handed)
	c.set_value("s", "autofire", auto_fire)
	c.set_value("s", "gyro", gyro_aim)
	c.set_value("s", "gyrosens", gyro_sens)
	c.set_value("hud", "scale", hud_scale)
	for k in hud_layout:
		c.set_value("hud", k, hud_layout[k])
	for k in hud_size:
		c.set_value("hud", "sz_" + k, hud_size[k])
	c.set_value("s", "aimsens", aim_sens)
	c.set_value("s", "bot", bot_level)
	c.set_value("s", "unlim", unlimited_ammo)
	c.set_value("s", "kills", kills_to_win)
	c.save(PATH)
	resolve_skin()

## Screen-space centre of a HUD button for this viewport (mirrors for left-handed).
func hud_size_of(kind: String) -> float:
	return float(hud_size.get(kind, 1.0))

func set_hud_size(kind: String, v: float) -> void:
	hud_size[kind] = clampf(v, 0.6, 1.8)

func hud_center(kind: String, vp: Vector2) -> Vector2:
	var f: Vector2 = hud_layout.get(kind, HUD_DEFAULTS.get(kind, Vector2(0.9, 0.9)))
	if left_handed:
		f.x = 1.0 - f.x
	return Vector2(f.x * vp.x, f.y * vp.y)

func set_hud_center(kind: String, center: Vector2, vp: Vector2) -> void:
	var f := Vector2(center.x / vp.x, center.y / vp.y)
	if left_handed:
		f.x = 1.0 - f.x
	hud_layout[kind] = f
