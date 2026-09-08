## Rocket3D — slow projectile with a smoke trail; explodes on contact or at end of
## life (game.explode applies radial damage).
class_name Rocket3D
extends Node3D

const RADIUS := 3.6

var game: Node
var vel := Vector3.ZERO
var dmg := 62.0
var life := 4.0
var from_player := true
var owner_id := 0
var _armed := 0.0
var _trail: CPUParticles3D

func _ready() -> void:
	var body := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.09
	c.bottom_radius = 0.11
	c.height = 0.7
	c.radial_segments = 8
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.38, 0.32)
	m.metallic = 0.5
	m.roughness = 0.5
	c.material = m
	body.mesh = c
	body.rotation.x = PI / 2.0
	add_child(body)
	var tip := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.11
	s.height = 0.22
	s.radial_segments = 8
	s.rings = 4
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.85, 0.2, 0.15)
	s.material = tm
	tip.mesh = s
	tip.position = Vector3(0, 0, -0.38)
	add_child(tip)

	_trail = CPUParticles3D.new()
	_trail.amount = 40
	_trail.lifetime = 0.6
	_trail.local_coords = false
	_trail.direction = Vector3(0, 0, 1)
	_trail.spread = 10.0
	_trail.initial_velocity_min = 1.0
	_trail.initial_velocity_max = 2.0
	_trail.gravity = Vector3(0, 0.6, 0)
	_trail.scale_amount_min = 0.6
	_trail.scale_amount_max = 1.4
	var pm := SphereMesh.new()
	pm.radius = 0.12
	pm.height = 0.24
	pm.radial_segments = 6
	pm.rings = 3
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(0.8, 0.8, 0.8, 0.6)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.material = pmat
	_trail.mesh = pm
	_trail.color_ramp = Fighter._ramp([Color(1, 0.7, 0.3, 1), Color(0.7, 0.7, 0.7, 0.6), Color(0.5, 0.5, 0.5, 0.0)])
	_trail.position = Vector3(0, 0, 0.4)
	add_child(_trail)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.5
	light.omni_range = 4.0
	light.shadow_enabled = false
	add_child(light)
	_orient()

func _orient() -> void:
	if vel.length_squared() < 0.001:
		return
	var up := Vector3.UP if absf(vel.normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	look_at(global_position + vel, up)

func _physics_process(delta: float) -> void:
	_armed += delta
	life -= delta
	if life <= 0.0:
		_explode(global_position)
		return
	var from := global_position
	var to := from + vel * delta
	var mask := 1
	if _armed > 0.1:
		mask |= (4 | 8) if from_player else 2
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		_explode(hit["position"] + hit["normal"] * 0.3)
		return
	global_position = to

func _explode(at: Vector3) -> void:
	if game:
		game.explode(at, RADIUS, dmg, owner_id)
	queue_free()
