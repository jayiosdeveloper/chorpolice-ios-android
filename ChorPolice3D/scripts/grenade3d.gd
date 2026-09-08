## Grenade3D — a bouncing RigidBody3D with a 2.2 s fuse; explodes via game.explode.
class_name Grenade3D
extends RigidBody3D

const FUSE := 2.2
const RADIUS := 4.0
const DMG := 70.0

var game: Node
var init_vel := Vector3.ZERO
var from_player := true
var owner_id := 0
var _t := 0.0
var _light: OmniLight3D

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	mass = 0.4
	continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.45
	pm.friction = 0.8
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.14
	cs.shape = sh
	add_child(cs)
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.14
	s.height = 0.28
	s.radial_segments = 10
	s.rings = 5
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.44, 0.24)
	m.roughness = 0.6
	s.material = m
	mi.mesh = s
	add_child(mi)
	var lever := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.06, 0.12, 0.05)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.8, 0.8, 0.82)
	lm.metallic = 0.7
	b.material = lm
	lever.mesh = b
	lever.position = Vector3(0.06, 0.15, 0)
	add_child(lever)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.3, 0.2)
	_light.light_energy = 0.0
	_light.omni_range = 2.0
	_light.shadow_enabled = false
	add_child(_light)
	linear_velocity = init_vel
	angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))

func _physics_process(delta: float) -> void:
	_t += delta
	_light.light_energy = 1.2 if fmod(_t, 0.3) < 0.1 and _t > FUSE - 1.0 else 0.0
	if _t >= FUSE:
		if game:
			game.explode(global_position, RADIUS, DMG, owner_id)
		queue_free()
