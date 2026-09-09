## Bullet3D — a fast projectile (tracer or flame puff) stepped with a ray each physics
## tick so it never tunnels through walls or bodies. Hits are reported to the game
## (game.bullet_hit) which applies victim-authoritative damage.
class_name Bullet3D
extends Node3D

var game: Node
var vel := Vector3.ZERO
var dmg := 10.0
var life := 1.5
var from_player := true
var owner_id := 0
var is_flame := false
var _mi: MeshInstance3D
var _age := 0.0

static var _tracer_mesh: BoxMesh
static var _flame_mesh: SphereMesh
static var _round_mesh: Mesh            # real brass round (assets/real/guns/bullet.res)

func _ready() -> void:
	_mi = MeshInstance3D.new()
	if is_flame:
		if not _flame_mesh:
			_flame_mesh = SphereMesh.new()
			_flame_mesh.radius = 0.22
			_flame_mesh.height = 0.44
			_flame_mesh.radial_segments = 8
			_flame_mesh.rings = 4
		_mi.mesh = _flame_mesh
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.55, 0.15, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(1.0, 0.45, 0.1)
		m.emission_energy_multiplier = 2.0
		_mi.material_override = m
	else:
		# a real brass round at the front + a slim hot streak trailing behind it
		if not _round_mesh and ResourceLoader.exists("res://assets/real/guns/bullet.res"):
			_round_mesh = load("res://assets/real/guns/bullet.res")
		if not _tracer_mesh:
			_tracer_mesh = BoxMesh.new()
			_tracer_mesh.size = Vector3(0.022, 0.022, 1.3)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.9, 0.5, 0.6) if from_player else Color(1.0, 0.55, 0.35, 0.6)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(m.albedo_color.r, m.albedo_color.g, m.albedo_color.b)
		m.emission_energy_multiplier = 4.0
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		if _round_mesh:
			_mi.mesh = _round_mesh
			_mi.scale = Vector3(0.25, 0.25, 0.25)       # ~15 cm round, readable in flight
			var streak := MeshInstance3D.new()
			streak.mesh = _tracer_mesh
			streak.material_override = m
			streak.position = Vector3(0, 0, 0.72)        # trails behind (forward is -Z)
			streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(streak)
		else:
			_mi.mesh = _tracer_mesh
			_mi.material_override = m
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	_orient()

func _orient() -> void:
	if vel.length_squared() < 0.001:
		return
	var up := Vector3.UP if absf(vel.normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	look_at(global_position + vel, up)

func _physics_process(delta: float) -> void:
	_age += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + vel * delta
	var mask := 1
	if from_player:
		mask |= 4 | 8          # bots + remote avatars
	else:
		mask |= 2              # the local player
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		if game:
			game.bullet_hit(self, hit)
		queue_free()
		return
	global_position = to
	if is_flame:
		var s := 1.0 + _age * 6.0
		_mi.scale = Vector3(s, s, s)
		var m := _mi.material_override as StandardMaterial3D
		m.albedo_color.a = clampf(1.0 - _age / 0.3, 0.0, 0.85)
