## Rocket (SMAW) — flies straight, arms after a beat, then area-explodes on any
## contact or after its lifetime. Damage is dealt by game.gd via the "combat" group.
class_name Rocket
extends Area2D

var vel := Vector2.ZERO
var dmg := 62.0
var from_player := true
var owner_id := 0
var radius := 115.0
var _armed := false
var _t := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2 | 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(24, 8)
	cs.shape = r
	add_child(cs)
	rotation = vel.angle()

	var tube := Shapes.rrect(Vector2(24, 7), 3, Color(0.25, 0.27, 0.30))
	add_child(tube)
	var tip := Shapes.rrect(Vector2(9, 8), 3, Color(0.85, 0.28, 0.22))
	tip.position = Vector2(13, 0)
	add_child(tip)
	var fin := Shapes.rrect(Vector2(6, 11), 2, Color(0.4, 0.42, 0.46))
	fin.position = Vector2(-11, 0)
	add_child(fin)
	var flame := Shapes.circ(5, Color(1.0, 0.7, 0.2, 0.9))
	flame.position = Vector2(-15, 0)
	add_child(flame)

	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	position += vel * delta
	_t += delta
	if _t > 0.1:
		_armed = true
	if _t > 4.0:
		_explode()

func _on_body(_b: Node) -> void:
	if _armed:
		_explode()

func _explode() -> void:
	if not is_inside_tree():
		return
	get_tree().call_group("combat", "explode", global_position, radius, dmg, owner_id)
	queue_free()
