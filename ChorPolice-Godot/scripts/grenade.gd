## Grenade — physics body that bounces off terrain, blinks, then area-explodes
## after a fuse. Thrown with an initial velocity; damage via the "combat" group.
class_name Grenade
extends RigidBody2D

var init_vel := Vector2.ZERO
var from_player := true
var owner_id := 0
var dmg := 52.0
var radius := 125.0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	gravity_scale = 3.0          # ≈2940 px/s² — matches iOS grenade + the aim preview
	linear_damp = 0.25
	angular_damp = 0.6
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 7
	cs.shape = c
	add_child(cs)
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.45
	mat.friction = 0.6
	physics_material_override = mat

	add_child(Shapes.circ(7, Color(0.22, 0.32, 0.18)))
	var seg := Shapes.rrect(Vector2(15, 2), 1, Color(0.14, 0.20, 0.11))
	add_child(seg)
	var lever := Shapes.rrect(Vector2(4, 7), 1, Color(0.7, 0.7, 0.72))
	lever.position = Vector2(3, -6)
	add_child(lever)
	var light := Shapes.circ(2.3, Color(1, 0.2, 0.15))
	light.position = Vector2(-2, -7)
	add_child(light)
	var tw := create_tween().set_loops()
	tw.tween_property(light, "modulate:a", 0.2, 0.18)
	tw.tween_property(light, "modulate:a", 1.0, 0.18)

	linear_velocity = init_vel
	angular_velocity = 6.0
	get_tree().create_timer(2.2).timeout.connect(_explode)

func _explode() -> void:
	if not is_inside_tree():
		return
	get_tree().call_group("combat", "explode", global_position, radius, dmg, owner_id)
	queue_free()
