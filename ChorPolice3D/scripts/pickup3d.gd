## Pickup3D — a floating, spinning supply crate (health / weapon / grenades) with a
## label; the local player walking into it calls game.on_pickup(self).
class_name Pickup3D
extends Area3D

var game: Node
var kind := "health"
var weapon_type := 0
var attach_type := ""                # for kind == "attach": supp / comp / scope
var spot := 0
var taken := false
var _root: Node3D
var _base_y := 0.0
var _t := 0.0
var _ring: MeshInstance3D          # pulsing highlight ring under a weapon drop

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
		"boost":
			col = Color(1.0, 0.6, 0.15)
			label = "ENERGY"
			model_path = ""
		"airdrop":
			col = Color(1.0, 0.3, 0.2)
			label = "AIRDROP"
			model_path = "res://assets/real/models/old_military_crate/old_military_crate_1k.gltf"
		"attach":
			col = Color(0.4, 0.85, 1.0)
			label = {"supp": "SUPPRESSOR", "comp": "COMPENSATOR", "scope": "RED DOT"}.get(attach_type, "ATTACHMENT")
			model_path = ""
		_:
			col = Color(0.95, 0.6, 0.18)
			label = String(Weapons.data(weapon_type)["name"])
			model_path = ""          # weapons show the actual gun (below), not a crate
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
	if kind == "boost":                             # energy can + ring
		var mi2 := MeshInstance3D.new()
		var mm := StandardMaterial3D.new()
		var cy := CylinderMesh.new(); cy.top_radius = 0.09; cy.bottom_radius = 0.09; cy.height = 0.3; cy.radial_segments = 14
		mm.albedo_color = Color(1.0, 0.55, 0.12); mm.metallic = 0.6; mm.roughness = 0.35
		mm.emission_enabled = true; mm.emission = Color(1.0, 0.5, 0.1); mm.emission_energy_multiplier = 0.4
		cy.material = mm; mi2.mesh = cy
		mi2.rotation.z = 0.3
		_root.add_child(mi2)
		_base_y = 0.6
		placed = true
		var ring2 := MeshInstance3D.new()
		var tm2 := TorusMesh.new(); tm2.inner_radius = 0.34; tm2.outer_radius = 0.44
		var rm2 := StandardMaterial3D.new()
		rm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; rm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; rm2.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		rm2.albedo_color = Color(col.r, col.g, col.b, 0.9); rm2.emission_enabled = true; rm2.emission = col; rm2.emission_energy_multiplier = 2.5
		tm2.material = rm2; ring2.mesh = tm2; ring2.position = Vector3(0, 0.03, 0); ring2.scale = Vector3(1, 0.22, 1)
		add_child(ring2); _ring = ring2
	if kind == "attach":                            # small floating attachment part + ring
		var pivot := Node3D.new()
		pivot.rotation.z = 0.35
		pivot.scale = Vector3(3.4, 3.4, 3.4)
		_root.add_child(pivot)
		var g := GunModel.new()
		g.type = 0
		pivot.add_child(g)
		g.add_attachment(attach_type)
		var part: Node3D = g.attachments.get(attach_type, null)
		for c in g.get_children():                  # keep only the attachment part itself
			if c != part:
				c.queue_free()
		if part:
			var pb := _merged_aabb(part)
			g.position = -(pb.position + pb.size * 0.5)   # spin the part about its own centre
		_base_y = 0.62
		placed = true
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = 0.34; tm.outer_radius = 0.44
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		rm.albedo_color = Color(col.r, col.g, col.b, 0.9); rm.emission_enabled = true; rm.emission = col; rm.emission_energy_multiplier = 2.5
		tm.material = rm; ring.mesh = tm; ring.position = Vector3(0, 0.03, 0); ring.scale = Vector3(1, 0.22, 1)
		add_child(ring); _ring = ring
	if kind == "weapon":       # the real gun: centred, tilted, spinning, glowing
		var pivot := Node3D.new()
		pivot.rotation.z = 0.32                    # jaunty tilt so it reads as a dropped weapon
		pivot.scale = Vector3(1.15, 1.15, 1.15)
		_root.add_child(pivot)
		var g := GunModel.build(weapon_type)
		pivot.add_child(g)
		var gb := _merged_aabb(g)
		if gb.size.length() > 0.001:
			g.position = -(gb.position + gb.size * 0.5)   # spin about the gun's centre
		_base_y = 0.62
		placed = true
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.54
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		rm.albedo_color = Color(col.r, col.g, col.b, 0.9)
		rm.emission_enabled = true
		rm.emission = col
		rm.emission_energy_multiplier = 2.5
		tm.material = rm
		ring.mesh = tm
		ring.position = Vector3(0, 0.03, 0)
		ring.scale = Vector3(1, 0.22, 1)
		add_child(ring)                            # on the Area (not _root) so it doesn't bob
		_ring = ring
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
	light.light_energy = 0.8 if (kind == "health" or kind == "nades") else (3.0 if kind == "airdrop" else 1.6)
	light.omni_range = 2.5 if (kind == "health" or kind == "nades") else 3.2
	light.shadow_enabled = false
	light.position = Vector3(0, 0.6, 0)
	add_child(light)

	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	_t += delta
	_root.rotation.y += delta * 1.4
	_root.position.y = _base_y + sin(_t * 2.2) * 0.12
	if _ring:
		var k := 1.0 + 0.07 * sin(_t * 3.0)
		_ring.scale = Vector3(k, 0.22, k)
		_ring.rotation.y -= delta * 0.8

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
