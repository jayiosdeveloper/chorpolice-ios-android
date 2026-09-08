## Logo3D — a premium, genuinely-3D animated wordmark for the lobby. Two extruded metal
## words ("CHOR" in orange, "POLICE" in steel-blue) live in their own little 3D world:
## a key + rim light and a sweeping spotlight roll a real specular shine across the metal,
## while the whole emblem floats and tilts. Drop it in as a Control; it sizes its own
## SubViewport texture. Reads nothing external — pure eye-candy.
class_name Logo3D
extends Control

var _vp: SubViewport
var _pivot: Node3D
var _sweep: SpotLight3D
var _t := 0.0

const VW := 760
const VH := 360

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(VW, VH) * 0.5
	_vp = SubViewport.new()
	_vp.size = Vector2i(VW, VH)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.30, 0.36, 0.5)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.15
	e.glow_hdr_threshold = 0.9
	env.environment = e
	_vp.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, 38, 0)
	key.light_color = Color(1.0, 0.92, 0.82)
	key.light_energy = 1.5
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, -140, 0)
	rim.light_color = Color(0.5, 0.72, 1.0)
	rim.light_energy = 1.2
	_vp.add_child(rim)
	# the moving specular sweep — a tight spotlight that arcs across the metal
	_sweep = SpotLight3D.new()
	_sweep.light_color = Color(1.0, 0.96, 0.9)
	_sweep.light_energy = 6.0
	_sweep.spot_range = 12.0
	_sweep.spot_angle = 40.0
	_sweep.position = Vector3(0, 0, 4.0)
	_vp.add_child(_sweep)

	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.position = Vector3(0.15, 0.05, 6.4)
	cam.look_at_from_position(cam.position, Vector3(0.15, 0.0, 0), Vector3.UP)
	_vp.add_child(cam)

	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	var font := ThemeDB.fallback_font
	# CHOR — orange, upper; POLICE — blue, lower and nudged right (staggered wordmark)
	_word("CHOR", font, Color(1.0, 0.46, 0.12), Vector3(-1.55, 0.62, 0))
	_word("POLICE", font, Color(0.32, 0.66, 1.0), Vector3(-1.15, -0.66, 0))

	var tex := TextureRect.new()
	tex.texture = _vp.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tex)

func _word(txt: String, font: Font, col: Color, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var tm := TextMesh.new()
	tm.text = txt
	tm.font = font
	tm.font_size = 96
	tm.pixel_size = 0.0125
	tm.depth = 0.28
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = 0.95
	mat.metallic_specular = 0.9
	mat.roughness = 0.28
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.25
	tm.material = mat
	# darker bevel-ish side via the depth material (reuse a slightly darker one)
	mi.mesh = tm
	mi.position = at
	_pivot.add_child(mi)

func _process(delta: float) -> void:
	_t += delta
	if _pivot:
		_pivot.rotation.y = sin(_t * 0.6) * 0.22          # gentle left/right tilt
		_pivot.rotation.x = sin(_t * 0.9) * 0.05
		_pivot.position.y = sin(_t * 1.1) * 0.05          # slow float
	if _sweep:
		# arc the shine across the words
		_sweep.position = Vector3(sin(_t * 1.3) * 3.2, cos(_t * 0.7) * 0.8, 4.0)
		_sweep.look_at(Vector3(0, 0, 0), Vector3.UP)
