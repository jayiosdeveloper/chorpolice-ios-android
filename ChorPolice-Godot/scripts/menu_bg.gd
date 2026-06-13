## MenuBg — animated backdrop shared by the splash + menu (mirrors the iOS MenuScene):
## a dusk sky, a city skyline, drifting embers, and two operatives idly jetpack-hopping.
## Lives in a low CanvasLayer so the menu UI draws on top.
class_name MenuBg
extends CanvasLayer

func _ready() -> void:
	layer = -5
	var vp := get_viewport().get_visible_rect().size
	var w := vp.x
	var h := vp.y
	var gy := h - 76.0

	var sky := _full_rect(_grad([Color(0.10, 0.10, 0.20), Color(0.32, 0.19, 0.30), Color(0.58, 0.32, 0.24)]))
	add_child(sky)

	# skyline silhouettes
	var x := -40.0
	while x < w + 60.0:
		var bw := randf_range(50, 120)
		var bh := randf_range(90, 260)
		var b := ColorRect.new()
		b.color = Color(0.13, 0.11, 0.24)
		b.position = Vector2(x, gy - bh + 22.0)
		b.size = Vector2(bw, bh)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
		x += bw + randf_range(20, 60)

	var ground := ColorRect.new()
	ground.color = Color(0.12, 0.13, 0.20)
	ground.position = Vector2(0, gy)
	ground.size = Vector2(w, 90)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	var embers := CPUParticles2D.new()
	embers.position = Vector2(w / 2.0, h)
	embers.amount = 26
	embers.lifetime = 6.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(w / 2.0, 6)
	embers.direction = Vector2(0, -1)
	embers.gravity = Vector2(0, -16)
	embers.initial_velocity_min = 18.0
	embers.initial_velocity_max = 40.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 4.0
	embers.color = Color(1, 0.7, 0.4, 0.5)
	add_child(embers)

	_operative(Vector2(w * 0.34, gy + 8.0), Color(0.27, 0.55, 0.97), 1.0, 0.0)
	_operative(Vector2(w * 0.66, gy + 8.0), Color(0.90, 0.30, 0.32), -1.0, 0.8)

	# dark vignette so the UI pops (drawn last → above the scene, below the UI layer)
	var ov := _full_rect(_grad([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.12), Color(0, 0, 0, 0.5)]))
	add_child(ov)

func _operative(pos: Vector2, jacket: Color, face: float, delay: float) -> void:
	var p := Player.new()
	p.is_remote = true
	p.skin_jacket = jacket
	p.skin_accent = jacket.lightened(0.45)
	p.position = pos
	p.z_index = 10                  # above the skyline/ground (else the legs (z -1) hide behind them)
	add_child(p)
	p.set_aim(0.0 if face > 0.0 else PI)
	p._overlay_visible(false)
	var tw := create_tween().set_loops()
	tw.tween_interval(delay)
	tw.tween_callback(p.set_thrust.bind(true))
	tw.tween_property(p, "position:y", pos.y - 72.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(p.set_thrust.bind(false))
	tw.tween_property(p, "position:y", pos.y, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_interval(1.3)

func _full_rect(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _grad(colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 8
	t.height = 256
	return t
