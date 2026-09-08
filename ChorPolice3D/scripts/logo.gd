## Logo — the Chor Police mark, drawn procedurally so it is crisp at any size:
## a police-badge shield split by a diagonal into the CHOR half (orange, bandit mask)
## and the POLICE half (blue, star), plus the two-tone wordmark and a gradient bar.
## mode: "emblem" (shield only, 200x200), "wide" (shield + wordmark, 560x150),
## "stacked" (shield above wordmark, 440x400). Scale the Control to resize.
class_name Logo
extends Control

const ORANGE := Color(1.0, 0.44, 0.16)
const ORANGE_D := Color(0.72, 0.24, 0.08)
const BLUE := Color(0.20, 0.62, 1.0)
const BLUE_D := Color(0.08, 0.30, 0.66)
const INK := Color(0.05, 0.06, 0.12)

var mode := "wide"
var show_tagline := true
var glow := 1.0

func _ready() -> void:
	match mode:
		"emblem": custom_minimum_size = Vector2(200, 200)
		"stacked": custom_minimum_size = Vector2(440, 400)
		_: custom_minimum_size = Vector2(560, 150)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

static func shield(c: Vector2, s: float) -> PackedVector2Array:
	# badge outline: flat-ish top with ears, tapering to a point at the bottom
	var pts := PackedVector2Array()
	var raw := [Vector2(-0.92, -0.86), Vector2(-0.55, -0.98), Vector2(0.0, -0.9), Vector2(0.55, -0.98), Vector2(0.92, -0.86),
		Vector2(0.98, -0.2), Vector2(0.86, 0.42), Vector2(0.5, 0.82), Vector2(0.0, 1.02), Vector2(-0.5, 0.82), Vector2(-0.86, 0.42), Vector2(-0.98, -0.2)]
	for p in raw:
		pts.append(c + p * s)
	return pts

static func star(c: Vector2, ro: float, ri: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * (ro if i % 2 == 0 else ri))
	return pts

func _draw_emblem(c: Vector2, s: float) -> void:
	var sh := shield(c, s)
	# glow + shadow
	if glow > 0.0:
		for i in 3:
			var g := shield(c, s * (1.06 + i * 0.05))
			draw_colored_polygon(g, Color(0.3, 0.7, 1.0, 0.07 * glow))
	draw_colored_polygon(shield(c + Vector2(0, s * 0.06), s * 1.02), Color(0, 0, 0, 0.45))
	# blue base
	draw_colored_polygon(sh, BLUE_D)
	var inner := shield(c, s * 0.9)
	draw_colored_polygon(inner, BLUE)
	# orange half: everything left of the diagonal (top-right → bottom-left)
	var half := PackedVector2Array([c + Vector2(-2.0, -2.0) * s, c + Vector2(0.62, -2.0) * s, c + Vector2(-0.62, 2.0) * s, c + Vector2(-2.0, 2.0) * s])
	for poly in Geometry2D.intersect_polygons(sh, half):
		draw_colored_polygon(poly, ORANGE_D)
	for poly in Geometry2D.intersect_polygons(inner, half):
		draw_colored_polygon(poly, ORANGE)
	# subtle top sheen
	var sheen := PackedVector2Array([c + Vector2(-0.9, -0.86) * s, c + Vector2(0.9, -0.86) * s, c + Vector2(0.9, -0.55) * s, c + Vector2(-0.9, -0.55) * s])
	for poly in Geometry2D.intersect_polygons(inner, sheen):
		draw_colored_polygon(poly, Color(1, 1, 1, 0.10))
	# bandit mask (chor) on the orange side
	var mc := c + Vector2(-0.36, -0.12) * s
	var mw := s * 0.62
	var mh := s * 0.26
	var mask := PackedVector2Array([mc + Vector2(-mw / 2.0, -mh * 0.35), mc + Vector2(-mw * 0.15, -mh / 2.0), mc + Vector2(mw * 0.15, -mh * 0.2), mc + Vector2(mw / 2.0, -mh * 0.35),
		mc + Vector2(mw * 0.42, mh / 2.0), mc + Vector2(0, mh * 0.25), mc + Vector2(-mw * 0.42, mh / 2.0)])
	draw_colored_polygon(mask, INK)
	draw_circle(mc + Vector2(-mw * 0.2, 0), mh * 0.2, ORANGE.lightened(0.3))
	draw_circle(mc + Vector2(mw * 0.16, mh * 0.02), mh * 0.17, ORANGE.lightened(0.3))
	# police star on the blue side
	var sc := c + Vector2(0.36, 0.14) * s
	draw_colored_polygon(star(sc, s * 0.3, s * 0.13), Color(0.98, 0.95, 0.85))
	draw_colored_polygon(star(sc, s * 0.2, s * 0.085), Color(0.86, 0.72, 0.30))
	draw_circle(sc, s * 0.05, INK)
	# diagonal split + outline
	draw_line(c + Vector2(0.56, -0.98) * s, c + Vector2(-0.56, 1.0) * s, Color(0.08, 0.09, 0.14), s * 0.09)
	draw_line(c + Vector2(0.56, -0.98) * s, c + Vector2(-0.56, 1.0) * s, Color(1, 1, 1, 0.9), s * 0.035)
	var outline := shield(c, s)
	outline.append(outline[0])
	draw_polyline(outline, Color(0.98, 0.98, 1.0), s * 0.06, true)
	var outline2 := shield(c, s * 0.9)
	outline2.append(outline2[0])
	draw_polyline(outline2, Color(0, 0, 0, 0.35), s * 0.02, true)

func _draw_wordmark(pos: Vector2, fs: int, center := false) -> Vector2:
	var font := ThemeDB.fallback_font
	var w1 := font.get_string_size("CHOR", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w2 := font.get_string_size("POLICE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var gap := fs * 0.28
	var total := w1 + gap + w2
	var x := pos.x - (total / 2.0 if center else 0.0)
	var y := pos.y
	# faux bold: outline in ink + a 2-px doubled fill
	draw_string_outline(font, Vector2(x, y), "CHOR", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.12), INK)
	draw_string(font, Vector2(x, y), "CHOR", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ORANGE)
	draw_string(font, Vector2(x + 1.5, y), "CHOR", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ORANGE)
	var x2 := x + w1 + gap
	draw_string_outline(font, Vector2(x2, y), "POLICE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.12), INK)
	draw_string(font, Vector2(x2, y), "POLICE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, BLUE.lightened(0.15))
	draw_string(font, Vector2(x2 + 1.5, y), "POLICE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, BLUE.lightened(0.15))
	# gradient bar under the wordmark
	var by := y + fs * 0.22
	var bh := maxf(3.0, fs * 0.09)
	draw_polygon(PackedVector2Array([Vector2(x, by), Vector2(x + total, by), Vector2(x + total, by + bh), Vector2(x, by + bh)]),
		PackedColorArray([ORANGE, BLUE, BLUE, ORANGE]))
	if show_tagline:
		var tag := "A R E N A   S H O O T E R"
		var ts := int(fs * 0.24)
		var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		draw_string(font, Vector2(x + (total - tw) / 2.0, by + bh + ts * 1.2), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.75, 0.82, 0.95, 0.9))
	return Vector2(total, fs)

func _draw() -> void:
	match mode:
		"emblem":
			_draw_emblem(Vector2(100, 100), 84)
		"stacked":
			_draw_emblem(Vector2(220, 150), 118)
			_draw_wordmark(Vector2(220, 352), 72, true)
		_:
			_draw_emblem(Vector2(75, 75), 62)
			_draw_wordmark(Vector2(160, 92), 56, false)
