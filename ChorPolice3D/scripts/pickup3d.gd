## Pickup3D — a floating, spinning supply crate (health / weapon / grenades) with a
## label; the local player walking into it calls game.on_pickup(self).
class_name Pickup3D
extends Area3D

var game: Node
var kind := "health"
var weapon_type := 0
var spot := 0
var taken := false
var _root: Node3D
var _base_y := 0.0
var _t := 0.0

func _ready() -> void:
	collision_layer = 32
	collision_mask = 2
	monitoring = true
	monitorable = false
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	cs.shape = sh
	cs.position = Vector3(0, 0.6, 0)
	add_child(cs)

	_root = Node3D.new()
	add_child(_root)
	_base_y = 0.45
	var col: Color
	var label := ""
	match kind:
		"health":
			col = Color(0.92, 0.94, 0.96)
			label = "+ HEALTH"
		"nades":
			col = Color(0.36, 0.5, 0.28)
			label = "GRENADES"
		_:
			col = Color(0.95, 0.6, 0.18)
			label = String(Weapons.data(weapon_type)["name"])
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.7, 0.7, 0.7)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.6
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.25
	b.material = m
	mi.mesh = b
	_root.add_child(mi)
	if kind == "health":
		var cross := StandardMaterial3D.new()
		cross.albedo_color = Color(0.9, 0.2, 0.2)
		cross.emission_enabled = true
		cross.emission = Color(0.9, 0.2, 0.2)
		cross.emission_energy_multiplier = 0.6
		for face in [Vector3(0, 0, 0.36), Vector3(0, 0, -0.36), Vector3(0.36, 0, 0), Vector3(-0.36, 0, 0)]:
			var v := MeshInstance3D.new()
			var vb := BoxMesh.new()
			vb.size = Vector3(0.12, 0.4, 0.02) if face.z != 0.0 else Vector3(0.02, 0.4, 0.12)
			vb.material = cross
			v.mesh = vb
			v.position = face
			_root.add_child(v)
			var h := MeshInstance3D.new()
			var hb := BoxMesh.new()
			hb.size = Vector3(0.4, 0.12, 0.02) if face.z != 0.0 else Vector3(0.02, 0.12, 0.4)
			hb.material = cross
			h.mesh = hb
			h.position = face
			_root.add_child(h)
	var edge := StandardMaterial3D.new()
	edge.albedo_color = col.darkened(0.45)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var e := MeshInstance3D.new()
			var eb := BoxMesh.new()
			eb.size = Vector3(0.74, 0.06, 0.06)
			eb.material = edge
			e.mesh = eb
			e.position = Vector3(0, sy * 0.35, sx * 0.35)
			_root.add_child(e)
			var e2 := MeshInstance3D.new()
			var eb2 := BoxMesh.new()
			eb2.size = Vector3(0.06, 0.06, 0.74)
			eb2.material = edge
			e2.mesh = eb2
			e2.position = Vector3(sx * 0.35, sy * 0.35, 0)
			_root.add_child(e2)

	var lbl := Label3D.new()
	lbl.text = label
	lbl.font_size = 36
	lbl.pixel_size = 0.006
	lbl.outline_size = 8
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 1.25, 0)
	lbl.modulate = Color(1, 1, 1, 0.9)
	add_child(lbl)

	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 0.8
	light.omni_range = 2.5
	light.shadow_enabled = false
	light.position = Vector3(0, 0.6, 0)
	add_child(light)

	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	_t += delta
	_root.rotation.y += delta * 1.4
	_root.position.y = _base_y + sin(_t * 2.2) * 0.12

func _on_body(body: Node) -> void:
	if taken or not body.is_in_group("player"):
		return
	if game:
		game.on_pickup(self)
