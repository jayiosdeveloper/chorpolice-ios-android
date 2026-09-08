## Player — the 2D *preview widget* used by the menus (splash / lobby / settings /
## menu backdrop): a Node2D that renders the real 3D robot (RobotModel) into a small
## transparent SubViewport and shows it as a Sprite2D, feet at the node origin.
## It keeps the same public surface the old 2D character had (skin_* colours,
## is_remote, set_aim, set_thrust, _overlay_visible, animate …) so the menu code is
## untouched. The in-game body is Fighter (CharacterBody3D).
class_name Player
extends Node2D

const VP_SIZE := Vector2i(220, 300)
const SPRITE_SCALE := 0.45        # → ~135 px tall robot at scale 1 (matches the old 2D size)

var team := "player"
var is_remote := false
var name_text := ""
var skin_jacket := Color(0, 0, 0, 0)
var skin_jacket2 := Color(0, 0, 0, 0)
var skin_accent := Color(0, 0, 0, 0)
var skin_helmet := Color(0, 0, 0, 0)
var skin_pants := Color(0, 0, 0, 0)
var skin_tone := Color(0, 0, 0, 0)
var dead := false
var health := 100.0
var max_health := 100.0
var current_weapon := 0
var facing := 1.0
var aim_angle := 0.0

var vp: SubViewport
var model: HumanModel
var sprite: Sprite2D
var pivot: Node3D
var _static := false

func _ready() -> void:
	var jacket: Color = skin_jacket if skin_jacket.a > 0.0 else (Color(0.90, 0.30, 0.32) if team == "enemy" else Color(0.27, 0.55, 0.97))
	var accent: Color = skin_accent if skin_accent.a > 0.0 else jacket.lightened(0.45)

	vp = SubViewport.new()
	vp.size = VP_SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.75)
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.light_energy = 1.6
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -140, 0)
	rim.light_energy = 0.7
	rim.light_color = Color(0.7, 0.85, 1.0)
	vp.add_child(rim)

	var cam := Camera3D.new()
	cam.fov = 28.0
	cam.position = Vector3(0, 1.05, 4.9)
	cam.look_at_from_position(cam.position, Vector3(0, 0.98, 0), Vector3.UP)
	vp.add_child(cam)

	pivot = Node3D.new()
	vp.add_child(pivot)
	model = HumanModel.new()
	model.jacket = jacket
	model.accent = accent
	pivot.add_child(model)
	pivot.rotation.y = PI + 0.55

	sprite = Sprite2D.new()
	sprite.texture = vp.get_texture()
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.offset = Vector2(0, -VP_SIZE.y / 2.0)    # feet at the node origin (like the 2D art)
	add_child(sprite)

	# tiny tiles (settings grid, lobby bubbles) don't need 60 fps — render a few frames, then freeze
	_static = scale.x < 0.5
	if _static:
		_freeze_later()

func _freeze_later() -> void:
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(vp):
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE

func _thaw(seconds: float) -> void:
	if not _static or not is_instance_valid(vp):
		return
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(vp):
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE

# MARK: old 2D API (menus)

func set_aim(angle: float) -> void:
	aim_angle = angle
	facing = 1.0 if cos(angle) >= 0.0 else -1.0
	if pivot:
		pivot.rotation.y = PI + 0.55 * facing
	_thaw(0.2)

func set_thrust(on: bool) -> void:
	if model:
		model.play("jump" if on else "idle")

func set_weapon(_t: int) -> void:
	pass

func animate(_delta: float, _grounded := true, _hspeed := 0.0, _use_physics := true) -> void:
	pass

func _overlay_visible(_v: bool) -> void:
	pass

func _update_hp() -> void:
	pass

func _flash() -> void:
	if model:
		model.flash()

func set_name_text(s: String) -> void:
	name_text = s
