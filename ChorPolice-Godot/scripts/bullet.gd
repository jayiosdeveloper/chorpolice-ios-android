## Bullet — straight-flying projectile. from_player decides who it can hit
## (player bullets hit world+bots, bot bullets hit world+player).
class_name Bullet
extends Area2D

var vel := Vector2.ZERO
var dmg := 11.0
var life := 1.5
var from_player := true
var is_flame := false
var owner_id := 0                    # multiplayer: who fired it (for kill credit)

func _ready() -> void:
	collision_layer = 0
	# world is layer 1; bots layer 4; player layer 2; remote avatars layer 8.
	# Your own shots (from_player) also hit remote avatars so they STOP on enemies
	# instead of passing through; relayed shots only hit the local player (authoritative).
	collision_mask = (1 | 4 | 8) if from_player else (1 | 2)
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = (5.0 if is_flame else 3.0)
	cs.shape = c
	add_child(cs)
	rotation = vel.angle()

	if is_flame:
		var f := Shapes.circ(6, Color(1.0, 0.6, 0.15, 0.9))
		add_child(f)
		var core := Shapes.circ(3, Color(1.0, 0.92, 0.5, 0.95))
		add_child(core)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(2.2, 2.2), life)
		tw.parallel().tween_property(self, "modulate:a", 0.0, life)
	else:
		var tracer := Shapes.rrect(Vector2(14, 3.4), 1.6, Color(1.0, 0.86, 0.3))
		add_child(tracer)
		var tip := Shapes.circ(2.4, Color(1.0, 1.0, 0.7))
		tip.position = Vector2(8, 0)
		add_child(tip)

	body_entered.connect(_on_body)
	get_tree().create_timer(life).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += vel * delta

func _on_body(body: Node) -> void:
	if body.is_in_group("player"):
		# Victim-authoritative: the local player applies its own damage + reports it.
		get_tree().call_group("combat", "damage_local_player", dmg, owner_id, global_position)
		Audio.play("hit", -6.0)
	elif body.is_in_group("remote_player"):
		# Another player's avatar — stop the bullet here (visual); their own device
		# deals the real damage. Do NOT apply damage locally.
		Audio.play("hit", -6.0)
	elif body.has_method("take_hit"):
		body.take_hit(dmg)                 # practice bots
		Audio.play("hit", -6.0)
	if not is_flame:
		get_tree().call_group("combat", "spawn_spark", global_position)
		queue_free()
