## MenuBg — the animated backdrop behind every menu: a deep navy gradient, sweeping
## orange / blue light beams, a dotted grid, floating dust, and a live 3D hero — the
## soldier standing on a glowing disc, slowly turning. Lives in a low CanvasLayer so
## the menu UI draws on top. `set_hero(x_frac, scale, alpha)` places / dims the hero.
class_name MenuBg
extends CanvasLayer

var hero: TextureRect
var _hero_vp: SubViewport
var _pivot: Node3D
var _model: HumanModel
var _beams: Array = []
var _t := 0.0
var _lobby_gun := false
var _base_yaw := PI + 0.35
var _drag_on := false
var _dragging := false
var _spin := 0.0                 # angular momentum after a flick
var _idle_t := 0.0               # time since last touch — resume gentle auto-spin

func _ready() -> void:
	layer = -5
	var vp := get_viewport().get_visible_rect().size
	var w := vp.x
	var h := vp.y

	add_child(UI.full_rect(UI.grad_tex([Color(0.03, 0.04, 0.09), Color(0.07, 0.09, 0.18), Color(0.05, 0.06, 0.13)])))

	# soft radial glows (orange bottom-left, blue top-right)
	_glow(Vector2(w * 0.12, h * 0.95), 520, Color(1.0, 0.44, 0.16, 0.16))
	_glow(Vector2(w * 0.9, h * 0.05), 560, Color(0.2, 0.62, 1.0, 0.16))
	_glow(Vector2(w * 0.5, h * 0.55), 420, Color(0.33, 0.9, 1.0, 0.06))

	# dotted grid
	var grid := _Grid.new()
	grid.size = vp
	add_child(grid)

	# light beams (rotated translucent bars) that drift slowly
	for i in 4:
		var b := ColorRect.new()
		b.color = (Color(1.0, 0.44, 0.16, 0.05) if i % 2 == 0 else Color(0.2, 0.62, 1.0, 0.05))
		b.size = Vector2(w * 0.16 + i * 40, h * 2.4)
		b.pivot_offset = b.size / 2.0
		b.position = Vector2(w * (0.15 + i * 0.22), -h * 0.7)
		b.rotation = deg_to_rad(28.0)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
		_beams.append(b)

	# dust
	var dust := CPUParticles2D.new()
	dust.position = Vector2(w / 2.0, h / 2.0)
	dust.amount = 40
	dust.lifetime = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(w / 2.0, h / 2.0)
	dust.direction = Vector2(0, -1)
	dust.spread = 60.0
	dust.gravity = Vector2(0, -6)
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 16.0
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	dust.color = Color(0.6, 0.85, 1.0, 0.35)
	add_child(dust)

	_build_hero(w, h)

	# vignette
	add_child(UI.full_rect(UI.grad_tex([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55)])))

func _glow(at: Vector2, r: float, col: Color) -> void:
	var g := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 1.0])
	gr.colors = PackedColorArray([col, Color(col.r, col.g, col.b, 0.0)])
	g.gradient = gr
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.width = 256
	g.height = 256
	var tr := TextureRect.new()
	tr.texture = g
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(r * 2.0, r * 2.0)
	tr.position = at - Vector2(r, r)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

func _build_hero(w: float, h: float) -> void:
	_hero_vp = SubViewport.new()
	_hero_vp.size = Vector2i(640, 820)
	_hero_vp.transparent_bg = true
	_hero_vp.own_world_3d = true
	_hero_vp.msaa_3d = Viewport.MSAA_4X
	_hero_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_hero_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.42, 0.6)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_hdr_threshold = 1.0
	env.environment = e
	_hero_vp.add_child(env)
	var key := DirectionalLight3D.new()            # warm key from the left (CHOR)
	key.rotation_degrees = Vector3(-30, 55, 0)
	key.light_color = Color(1.0, 0.72, 0.5)
	key.light_energy = 1.6
	_hero_vp.add_child(key)
	var rim := DirectionalLight3D.new()            # cold rim from the right-back (POLICE)
	rim.rotation_degrees = Vector3(-15, -125, 0)
	rim.light_color = Color(0.45, 0.7, 1.0)
	rim.light_energy = 1.4
	_hero_vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.position = Vector3(0, 1.02, 5.7)
	cam.look_at_from_position(cam.position, Vector3(0, 0.82, 0), Vector3.UP)   # aim lower → full disc fits
	_hero_vp.add_child(cam)

	_pivot = Node3D.new()
	_hero_vp.add_child(_pivot)
	_model = HumanModel.new()
	_model.use_squad = true
	_lobby_gun = true
	_model.jacket = Settings.skin_jacket if Settings.skin_jacket.a > 0.0 else Color(0.27, 0.55, 0.97)
	_model.accent = Settings.skin_accent if Settings.skin_accent.a > 0.0 else Color(0.5, 0.95, 1.0)
	_pivot.add_child(_model)
	_pivot.rotation.y = PI + 0.35
	if _lobby_gun:
		_model.set_weapon(6)
		if _model.anim and _model.anim.has_animation("fire"):
			_model.anim.get_animation("fire").loop_mode = Animation.LOOP_LINEAR
			_model.anim.play("fire")
			_model.state = "fire"
	# glowing disc under the feet
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.1
	cm.bottom_radius = 1.1
	cm.height = 0.06
	cm.radial_segments = 40
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.05, 0.07, 0.14)
	dm.metallic = 0.6
	dm.roughness = 0.25
	cm.material = dm
	disc.mesh = cm
	disc.position = Vector3(0, -0.03, 0)
	_pivot.add_child(disc)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.06
	tm.outer_radius = 1.14
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.33, 0.9, 1.0)
	rm.emission_enabled = true
	rm.emission = Color(0.33, 0.9, 1.0)
	rm.emission_energy_multiplier = 3.0
	tm.material = rm
	ring.mesh = tm
	ring.position = Vector3(0, 0.0, 0)
	_pivot.add_child(ring)

	hero = TextureRect.new()
	hero.texture = _hero_vp.get_texture()
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.gui_input.connect(_on_hero_input)
	add_child(hero)
	set_hero(0.5, 1.0, 1.0)
	_pivot.rotation.y = _base_yaw

## Turn finger drag-to-rotate on (lobby main) or off (other screens).
func set_drag(on: bool) -> void:
	_drag_on = on
	if hero:
		hero.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if not on:
		_dragging = false
		_spin = 0.0

func _on_hero_input(ev: InputEvent) -> void:
	if not _drag_on:
		return
	if ev is InputEventScreenTouch or ev is InputEventMouseButton:
		_dragging = ev.pressed
		if ev.pressed:
			_spin = 0.0
		_idle_t = 0.0
	elif ev is InputEventScreenDrag or (ev is InputEventMouseMotion and _dragging):
		var dx: float = ev.relative.x
		_pivot.rotation.y -= dx * 0.011
		_spin = -dx * 0.011 / maxf(get_process_delta_time(), 0.0001)
		_spin = clampf(_spin, -8.0, 8.0)
		_idle_t = 0.0

## Place the hero: x as a fraction of the screen width, scale 1 = ~85 % of the screen height.
func set_hero(x_frac: float, scl: float, alpha: float, bottom_frac := 1.0) -> void:
	if not hero:
		return
	var vp := get_viewport().get_visible_rect().size
	var hh := vp.y * 0.86 * scl
	var ww := hh * 640.0 / 820.0
	hero.size = Vector2(ww, hh)
	hero.position = Vector2(vp.x * x_frac - ww / 2.0, vp.y * bottom_frac - hh + 6.0)
	hero.modulate.a = alpha
	hero.visible = alpha > 0.01

func set_hero_colors(j: Color, a: Color) -> void:
	if _model:
		_model.set_colors(j, a)

func set_hero_weapon(t: int) -> void:
	if _model:
		_model.set_weapon(t)

func _process(delta: float) -> void:
	_t += delta
	for i in _beams.size():
		var b: ColorRect = _beams[i]
		b.position.x += sin(_t * 0.25 + i) * 0.35
		b.color.a = 0.035 + 0.025 * sin(_t * 0.6 + i * 1.7)
	if _pivot:
		if _drag_on:
			if _dragging:
				pass
			elif absf(_spin) > 0.05:
				_pivot.rotation.y += _spin * delta      # flick momentum
				_spin = move_toward(_spin, 0.0, delta * 6.0)
				_idle_t = 0.0
			else:
				_idle_t += delta
				if _idle_t > 3.0:                        # idle → gentle showcase spin
					_pivot.rotation.y += delta * 0.35
		else:
			# other screens: quiet sway around the base pose
			_pivot.rotation.y = _base_yaw + sin(_t * 0.5) * 0.4

class _Grid:
	extends Control
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var step := 44.0
		var y := step
		while y < size.y:
			var x := step
			while x < size.x:
				draw_circle(Vector2(x, y), 1.2, Color(1, 1, 1, 0.07))
				x += step
			y += step
