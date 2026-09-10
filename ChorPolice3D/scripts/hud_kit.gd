## HudKit — the on-screen game buttons (FIRE, small FIRE, JUMP, RELOAD, GRENADE) built
## once here so the match HUD and the HUD-layout editor draw exactly the same thing.
## Buttons are Controls with a top-left pivot; `place()` centres them at a screen point
## using Settings.hud_center() + Settings.hud_scale.
class_name HudKit
extends RefCounted

const KINDS := ["fire", "fire_l", "jump", "reload", "nade", "scope", "med", "skill"]
const NAMES := {"fire": "FIRE", "fire_l": "FIRE (left)", "jump": "JUMP", "reload": "RELOAD", "nade": "GRENADE", "scope": "SCOPE", "med": "MEDKIT", "skill": "SKILL"}

static func make(kind: String, scl := 1.0) -> Control:
	var c: Control
	match kind:
		"fire": c = _round("FIRE", 56, Color(0.95, 0.35, 0.25))
		"fire_l": c = _round("FIRE", 36, Color(0.95, 0.35, 0.25))
		"jump": c = _jump()
		"reload": c = _reload()
		"scope": c = _scope()
		"med": c = _glyph_btn("✚", "MED", Color(0.35, 0.95, 0.5), 30)
		"skill": c = _glyph_btn("★", "SKILL", Color(1.0, 0.8, 0.3), 34)
		_: c = _nade()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.scale = Vector2(scl, scl)
	c.set_meta("kind", kind)
	return c

## Centre the button at `center` (top-left pivot, so account for the scale).
static func place(c: Control, center: Vector2) -> void:
	c.position = center - c.size * c.scale / 2.0

static func rect(c: Control, pad := 0.0) -> Rect2:
	return Rect2(c.position, c.size * c.scale).grow(pad) if c else Rect2()

## Adds an SVG icon centred in a button of half-size r, tinted `col`, size factor `k`.
static func _svg(c: Control, path: String, ctr: Vector2, r: float, col: Color, k := 1.15) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var icon := TextureRect.new()
	icon.texture = load(path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var isz := r * k
	icon.size = Vector2(isz, isz)
	icon.position = ctr - Vector2(isz / 2.0, isz / 2.0)
	icon.modulate = col
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(icon)
	return true

static func _round(text: String, r: float, col: Color) -> Control:
	var c := Control.new()
	c.size = Vector2(r * 2.0, r * 2.0)
	var ctr := Vector2(r, r)
	var rim := Shapes.circ(r - 2.0, Color(1, 1, 1, 0.4)); rim.position = ctr; c.add_child(rim)
	var disc := Shapes.circ(r - 4.0, Color(col.r, col.g, col.b, 0.42)); disc.position = ctr; c.add_child(disc)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/bullet.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var isz := r * 1.15
	icon.size = Vector2(isz, isz)
	icon.position = ctr - Vector2(isz / 2.0, isz / 2.0 + r * 0.08)
	icon.modulate = Color(1, 1, 1, 0.95)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(icon)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11 if r < 40 else 13)
	l.position = Vector2(r - 14, r * 2.0 - 20)
	l.modulate = Color(1, 1, 1, 0.75)
	c.add_child(l)
	return c

static func _jump() -> Control:
	var c := Control.new()
	c.size = Vector2(92, 92)
	var ctr := Vector2(46, 46)
	var rim := Shapes.circ(42, Color(1, 1, 1, 0.4)); rim.position = ctr; c.add_child(rim)
	var disc := Shapes.circ(40, Color(0, 0, 0, 0.38)); disc.position = ctr; c.add_child(disc)
	if not _svg(c, "res://assets/icons/jump.svg", ctr, 38, Color(0.96, 0.66, 0.14), 1.0):
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([Vector2(0, -18), Vector2(16, 2), Vector2(7, 2), Vector2(7, 16), Vector2(-7, 16), Vector2(-7, 2), Vector2(-16, 2)])
		arrow.color = Color(0.96, 0.62, 0.10)
		arrow.position = ctr
		c.add_child(arrow)
	var jl := Label.new()
	jl.text = "JUMP"
	jl.add_theme_font_size_override("font_size", 11)
	jl.position = Vector2(30, 66)
	jl.modulate = Color(1, 1, 1, 0.7)
	c.add_child(jl)
	return c

## Round button with a big glyph + caption (MED / GLOO / SKILL). A "count"/"cd" Label child
## named Count is updated by the game (item count or cooldown seconds).
static func _glyph_btn(glyph: String, caption: String, col: Color, r: float) -> Control:
	var c := Control.new()
	c.size = Vector2(r * 2.0, r * 2.0)
	var ctr := Vector2(r, r)
	var rim := Shapes.circ(r - 2.0, Color(1, 1, 1, 0.4)); rim.position = ctr; c.add_child(rim)
	var disc := Shapes.circ(r - 4.0, Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.55)); disc.position = ctr; c.add_child(disc)
	var g := Label.new()
	g.text = glyph
	g.add_theme_font_size_override("font_size", int(r * 0.9))
	g.add_theme_color_override("font_color", col)
	g.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	g.add_theme_constant_override("outline_size", 4)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.size = Vector2(r * 2.0, r * 2.0)
	g.position = Vector2(0, -r * 0.18)
	c.add_child(g)
	var l := Label.new()
	l.text = caption
	l.add_theme_font_size_override("font_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(r * 2.0, 14)
	l.position = Vector2(0, r * 2.0 - 20)
	l.modulate = Color(1, 1, 1, 0.75)
	c.add_child(l)
	var n := Label.new()
	n.name = "Count"
	n.text = ""
	n.add_theme_font_size_override("font_size", 13)
	n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	n.add_theme_constant_override("outline_size", 4)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.size = Vector2(28, 18)
	n.position = Vector2(r * 2.0 - 26, -2)
	c.add_child(n)
	return c

static func _reload() -> Control:
	var c := Control.new()
	c.size = Vector2(64, 64)
	var rc := Vector2(32, 32)
	var rrim := Shapes.circ(29, Color(1, 1, 1, 0.35)); rrim.position = rc; c.add_child(rrim)
	var rdisc := Shapes.circ(27, Color(0, 0, 0, 0.38)); rdisc.position = rc; c.add_child(rdisc)
	if not _svg(c, "res://assets/icons/reload.svg", rc, 40, Color(0.9, 0.95, 1.0), 1.0):
		var rl := Label.new()
		rl.text = "R"
		rl.add_theme_font_size_override("font_size", 22)
		rl.position = Vector2(23, 14)
		c.add_child(rl)
	return c

static func _scope() -> Control:
	var c := Control.new()
	c.size = Vector2(72, 72)
	var ctr := Vector2(36, 36)
	var rim := Shapes.circ(33, Color(1, 1, 1, 0.4)); rim.position = ctr; c.add_child(rim)
	var disc := Shapes.circ(31, Color(0, 0, 0, 0.42)); disc.position = ctr; c.add_child(disc)
	if not _svg(c, "res://assets/icons/scope.svg", ctr, 44, Color(0.33, 0.9, 1.0), 1.0):
		var g := UI.glyph("target", Color(0.33, 0.9, 1.0), 15)
		g.position = ctr - Vector2(15 * 1.2, 15 * 1.2)
		c.add_child(g)
	var l := Label.new()
	l.text = "SCOPE"
	l.add_theme_font_size_override("font_size", 10)
	l.position = Vector2(18, 54)
	l.modulate = Color(1, 1, 1, 0.75)
	c.add_child(l)
	return c

static func _nade() -> Control:
	var c := Control.new()
	c.size = Vector2(92, 92)
	var ctr := Vector2(46, 46)
	var rim := Shapes.circ(42, Color(1, 1, 1, 0.4)); rim.position = ctr; c.add_child(rim)
	var disc := Shapes.circ(40, Color(0, 0, 0, 0.38)); disc.position = ctr; c.add_child(disc)
	var ic := "res://assets/icons/grenade.svg"
	if ResourceLoader.exists(ic):
		var g := TextureRect.new()
		g.texture = load(ic)
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		g.size = Vector2(46, 46); g.position = ctr - Vector2(23, 23)
		g.modulate = Color(0.55, 0.85, 0.45)
		c.add_child(g)
	else:
		var shell := Shapes.circ(16, Color(0.30, 0.44, 0.24)); shell.position = ctr + Vector2(0, 2); c.add_child(shell)
		var seg := Shapes.rrect(Vector2(30, 4), 1, Color(0.16, 0.24, 0.12)); seg.position = ctr + Vector2(0, 2); c.add_child(seg)
	return c
