## Shape helpers — build rounded rects, circles and limb capsules as Polygon2D
## nodes (the Godot equivalent of the SpriteKit SKShapeNodes used on iOS).
class_name Shapes
extends RefCounted

static func rrect(size: Vector2, radius: float, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = _rrect_points(size, radius)
	p.color = color
	return p

static func circ(radius: float, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	p.polygon = pts
	p.color = color
	return p

## A capsule limb running from a → b, used for arms/legs.
static func limb(a: Vector2, b: Vector2, w: float, color: Color) -> Polygon2D:
	var length := maxf(w, (b - a).length())
	var p := rrect(Vector2(w, length + w * 0.3), w / 2.0, color)
	p.position = (a + b) / 2.0
	p.rotation = (b - a).angle() - PI / 2.0
	return p

static func _rrect_points(size: Vector2, radius: float) -> PackedVector2Array:
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	var r := minf(radius, minf(hw, hh))
	var pts := PackedVector2Array()
	var seg := 4
	# four corner arcs, traced around the perimeter
	var arcs := [
		[Vector2(-hw + r, -hh + r), PI, 1.5 * PI],        # top-left
		[Vector2(hw - r, -hh + r), 1.5 * PI, 2.0 * PI],   # top-right
		[Vector2(hw - r, hh - r), 0.0, 0.5 * PI],         # bottom-right
		[Vector2(-hw + r, hh - r), 0.5 * PI, PI],         # bottom-left
	]
	for arc in arcs:
		var center: Vector2 = arc[0]
		var a0: float = arc[1]
		var a1: float = arc[2]
		for s in seg + 1:
			var a := lerpf(a0, a1, float(s) / float(seg))
			pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts
