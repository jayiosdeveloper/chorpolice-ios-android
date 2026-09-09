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
	_base_y = 0.55
	var col: Color
	var label := ""
	var model_path := ""
	match kind:
		"health":
			col = Color(0.92, 0.94, 0.96)
			label = "+ HEALTH"
			model_path = "res://assets/real/models/wooden_crate_01/wooden_crate_01_1k.gltf"
		"nades":
			col = Color(0.36, 0.5, 0.28)
			label = "GRENADES"
			model_path = "res://assets/real/models/ammo_box/ammo_box_1k.gltf"
		_:
			col = Color(0.95, 0.6, 0.18)
			label = String(Weapons.data(weapon_type)["name"])
			model_path = "res://assets/real/models/old_military_crate/old_military_crate_1k.gltf"
	# a real crate/ammo-box model (falls back to a glowing box if the model is missing)
	var placed := false
	if ResourceLoader.exists(model_path):
		var inst: Node3D = load(model_path).instantiate()
		_root.add_child(inst)
		var ab := _merged_aabb(inst)
		if ab.size.length() > 0.001:
			var s: float = 0.9 / maxf(maxf(ab.size.x, ab.size.y), ab.size.z)
			inst.scale = Vector3(s, s, s)
			inst.position = -ab.position * s      # sit centred on the disc
		placed = true
	if not placed:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.7, 0.7, 0.7)
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.6
		b.material = m
		mi.mesh = b
		_root.add_child(mi)
	if kind == "health":                          # floating red cross so health reads instantly
		var cross := Label3D.new()
		cross.text = "✚"
		cross.font_size = 72
		cross.pixel_size = 0.006
		cross.modulate = Color(0.95, 0.2, 0.2)
		cross.outline_size = 6
		cross.outline_modulate = Color(1, 1, 1, 0.9)
		cross.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cross.position = Vector3(0, 0.55, 0)
		_root.add_child(cross)

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

## Merged local-space AABB of every mesh under a node (to centre + scale a model).
func _merged_aabb(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := node.global_transform.affine_inverse()
	for c in _walk(node):
		if c is VisualInstance3D:
			var a: AABB = inv * (c as Node3D).global_transform * (c as VisualInstance3D).get_aabb()
			if first:
				out = a
				first = false
			else:
				out = out.merge(a)
	return out

func _walk(n: Node) -> Array:
	var r: Array = [n]
	for c in n.get_children():
		r.append_array(_walk(c))
	return r
