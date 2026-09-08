## UI — the shared design language for every menu screen ("tactical glass"): a deep
## navy ground, CHOR orange vs POLICE blue accents, cyan highlights, frosted dark panels
## with hairline borders, pill buttons and small uppercase headings.
class_name UI
extends RefCounted

const BG := Color(0.043, 0.055, 0.11)
const BG2 := Color(0.09, 0.11, 0.21)
const ORANGE := Color(1.0, 0.44, 0.16)
const BLUE := Color(0.20, 0.62, 1.0)
const CYAN := Color(0.33, 0.90, 1.0)
const GREEN := Color(0.26, 0.86, 0.52)
const PURPLE := Color(0.64, 0.52, 1.0)
const RED := Color(0.96, 0.32, 0.30)
const TEXT := Color(0.96, 0.97, 1.0)
const MUTED := Color(0.62, 0.68, 0.80)
const LINE := Color(1, 1, 1, 0.10)

static func glass(alpha := 0.07, radius := 18.0, border := LINE, bw := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	sb.set_corner_radius_all(int(radius))
	if bw > 0:
		sb.set_border_width_all(bw)
		sb.border_color = border
	sb.set_content_margin_all(14)
	return sb

static func solid(col: Color, radius := 14.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

## kind: "primary" (orange), "blue", "green", "ghost" (frosted), "danger", "dark"
static func style_button(b: Button, kind := "ghost", radius := 14.0) -> void:
	var normal: StyleBoxFlat
	var hover: StyleBoxFlat
	var fc := TEXT
	match kind:
		"primary":
			normal = solid(ORANGE, radius); hover = solid(ORANGE.lightened(0.12), radius); fc = Color(0.12, 0.06, 0.02)
		"blue":
			normal = solid(BLUE, radius); hover = solid(BLUE.lightened(0.12), radius); fc = Color(0.02, 0.06, 0.14)
		"green":
			normal = solid(GREEN, radius); hover = solid(GREEN.lightened(0.12), radius); fc = Color(0.02, 0.12, 0.06)
		"danger":
			normal = solid(RED, radius); hover = solid(RED.lightened(0.12), radius)
		"dark":
			normal = solid(Color(0, 0, 0, 0.45), radius); hover = solid(Color(0, 0, 0, 0.6), radius)
			normal.set_border_width_all(1); normal.border_color = LINE
			hover.set_border_width_all(1); hover.border_color = Color(1, 1, 1, 0.2)
		_:
			normal = solid(Color(1, 1, 1, 0.07), radius); hover = solid(Color(1, 1, 1, 0.14), radius)
			normal.set_border_width_all(1); normal.border_color = LINE
			hover.set_border_width_all(1); hover.border_color = CYAN
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = pressed.bg_color.darkened(0.15)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_focus_color", fc)

static func label(text: String, size: int, col := TEXT, upper := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text.to_upper() if upper else text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Small uppercase section heading with a coloured tick in front.
static func heading(text: String, col := CYAN) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var tick := ColorRect.new()
	tick.color = col
	tick.custom_minimum_size = Vector2(4, 14)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tick)
	h.add_child(label(text, 13, MUTED, true))
	return h

static func pill(text: String, col: Color, size := 13) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.18)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(1)
	sb.border_color = Color(col.r, col.g, col.b, 0.55)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 4; sb.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(label(text, size, col.lightened(0.25), true, HORIZONTAL_ALIGNMENT_CENTER))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc

static func grad_tex(colors: Array, vertical := true, offsets := []) -> GradientTexture2D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	if offsets.is_empty():
		for i in colors.size():
			offs.append(float(i) / float(maxi(colors.size() - 1, 1)))
	else:
		offs = PackedFloat32Array(offsets)
	g.offsets = offs
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1) if vertical else Vector2(1, 0)
	t.width = 8 if vertical else 256
	t.height = 256 if vertical else 8
	return t

static func full_rect(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## A gradient bar (orange → blue by default).
static func bar(w: float, h: float, a := ORANGE, b := BLUE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = grad_tex([a, b], false)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Menu-card glyphs drawn from primitives: "target", "wifi", "link", "globe", "gear", "user".
static func glyph(kind: String, col: Color, r := 22.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(r * 2.4, r * 2.4)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ctr := Vector2(r * 1.2, r * 1.2)
	var disc := Shapes.circ(r * 1.2, Color(col.r, col.g, col.b, 0.16))
	disc.position = ctr
	c.add_child(disc)
	var g := _Glyph.new()
	g.kind = kind
	g.col = col
	g.r = r
	g.position = ctr
	c.add_child(g)
	return c

class _Glyph:
	extends Node2D
	var kind := "target"
	var col := Color.WHITE
	var r := 22.0
	func _draw() -> void:
		var w := maxf(2.5, r * 0.13)
		match kind:
			"target":
				draw_arc(Vector2.ZERO, r * 0.75, 0, TAU, 40, col, w, true)
				draw_arc(Vector2.ZERO, r * 0.42, 0, TAU, 32, col, w, true)
				draw_circle(Vector2.ZERO, r * 0.14, col)
				for i in 4:
					var d := Vector2(cos(i * PI / 2.0), sin(i * PI / 2.0))
					draw_line(d * r * 0.55, d * r * 0.95, col, w)
			"wifi":
				for i in 3:
					draw_arc(Vector2(0, r * 0.45), r * (0.3 + i * 0.28), -PI * 0.78, -PI * 0.22, 24, col, w, true)
				draw_circle(Vector2(0, r * 0.45), r * 0.12, col)
			"link":
				draw_arc(Vector2(-r * 0.22, 0), r * 0.36, PI * 0.5, PI * 1.5, 20, col, w, true)
				draw_arc(Vector2(r * 0.22, 0), r * 0.36, -PI * 0.5, PI * 0.5, 20, col, w, true)
				draw_line(Vector2(-r * 0.22, -r * 0.36), Vector2(r * 0.22, -r * 0.36), col, w)
				draw_line(Vector2(-r * 0.22, r * 0.36), Vector2(r * 0.22, r * 0.36), col, w)
				draw_line(Vector2(-r * 0.3, 0), Vector2(r * 0.3, 0), col, w)
			"globe":
				draw_arc(Vector2.ZERO, r * 0.78, 0, TAU, 40, col, w, true)
				draw_line(Vector2(-r * 0.78, 0), Vector2(r * 0.78, 0), col, w * 0.8)
				draw_line(Vector2(0, -r * 0.78), Vector2(0, r * 0.78), col, w * 0.8)
				var pts := PackedVector2Array()
				for i in 25:
					var a := -PI / 2.0 + PI * float(i) / 24.0
					pts.append(Vector2(sin(a) * r * 0.36, -cos(a) * r * 0.78))
				draw_polyline(pts, col, w * 0.8, true)
				var pts2 := PackedVector2Array()
				for i in 25:
					var a := -PI / 2.0 + PI * float(i) / 24.0
					pts2.append(Vector2(-sin(a) * r * 0.36, -cos(a) * r * 0.78))
				draw_polyline(pts2, col, w * 0.8, true)
			"gear":
				for i in 8:
					var a := float(i) / 8.0 * TAU
					draw_line(Vector2(cos(a), sin(a)) * r * 0.45, Vector2(cos(a), sin(a)) * r * 0.85, col, w * 1.6)
				draw_arc(Vector2.ZERO, r * 0.5, 0, TAU, 32, col, w * 1.4, true)
				draw_circle(Vector2.ZERO, r * 0.2, col)
			"user":
				draw_circle(Vector2(0, -r * 0.3), r * 0.3, col)
				draw_arc(Vector2(0, r * 0.75), r * 0.6, PI, TAU, 24, col, w * 1.6, true)
			"friends":
				draw_circle(Vector2(-r * 0.28, -r * 0.25), r * 0.24, col)
				draw_circle(Vector2(r * 0.28, -r * 0.25), r * 0.24, col)
				draw_arc(Vector2(-r * 0.28, r * 0.7), r * 0.48, PI, TAU, 20, col, w * 1.4, true)
				draw_arc(Vector2(r * 0.28, r * 0.7), r * 0.48, PI, TAU, 20, col, w * 1.4, true)
			"back":
				draw_line(Vector2(r * 0.3, -r * 0.5), Vector2(-r * 0.3, 0), col, w * 1.4)
				draw_line(Vector2(-r * 0.3, 0), Vector2(r * 0.3, r * 0.5), col, w * 1.4)
			_:
				draw_circle(Vector2.ZERO, r * 0.5, col)
