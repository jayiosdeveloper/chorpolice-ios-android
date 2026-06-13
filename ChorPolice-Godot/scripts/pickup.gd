## Pickup — a crate the player walks into: health, a weapon, or grenades.
## Tells game.gd via the "combat" group; game.gd grants it and respawns the spot.
class_name Pickup
extends Area2D

var kind := "health"     # "health" | "weapon" | "nades"
var weapon_type := 0
var spot := 0
var taken := false
var bob: Node2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2          # only the player (layer 2) collects
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(60, 50)
	cs.shape = r
	cs.position = Vector2(0, -20)
	add_child(cs)

	bob = Node2D.new()
	bob.position = Vector2(0, -18)
	add_child(bob)
	_build()
	body_entered.connect(_on_body)

	var tw := create_tween().set_loops()
	tw.tween_property(bob, "position:y", -24.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bob, "position:y", -18.0, 0.9).set_trans(Tween.TRANS_SINE)

func _on_body(body: Node) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("combat", "on_pickup", self)

func _build() -> void:
	var accent := Color(0.30, 0.85, 0.40)
	if kind == "weapon":
		accent = Color(0.96, 0.62, 0.10)
	elif kind == "nades":
		accent = Color(0.55, 0.80, 0.30)

	var shadow := Shapes.circ(1, Color(0, 0, 0, 0.22))
	shadow.scale = Vector2(28, 6)
	shadow.position = Vector2(0, 26)
	bob.add_child(shadow)

	var box := Shapes.rrect(Vector2(58, 46), 8, Color(0.15, 0.17, 0.24))
	bob.add_child(box)
	var stripe := Shapes.rrect(Vector2(58, 8), 2, accent)
	stripe.position = Vector2(0, -18)
	bob.add_child(stripe)
	var pane := Shapes.rrect(Vector2(50, 32), 5, Color(0.80, 0.83, 0.88))
	pane.position = Vector2(0, 4)
	bob.add_child(pane)

	if kind == "health":
		var v := Shapes.rrect(Vector2(7, 22), 2, accent)
		v.position = Vector2(0, 4)
		bob.add_child(v)
		var h := Shapes.rrect(Vector2(22, 7), 2, accent)
		h.position = Vector2(0, 4)
		bob.add_child(h)
	elif kind == "nades":
		var g := Shapes.circ(10, Color(0.22, 0.32, 0.18))
		g.position = Vector2(0, 5)
		bob.add_child(g)
		var lv := Shapes.rrect(Vector2(4, 7), 1, Color(0.7, 0.7, 0.72))
		lv.position = Vector2(3, -4)
		bob.add_child(lv)
	else:
		var icon := Weapons.art(weapon_type)
		icon.scale = Vector2(0.82, 0.82)
		icon.position = Vector2(-24, 4)
		bob.add_child(icon)
