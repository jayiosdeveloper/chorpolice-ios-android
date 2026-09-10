## GunModel — the nine guns as detailed low-poly 3D models built from primitives
## (receiver, barrel, handguard, sights, stock, grip, magazine, …) with markers the
## character rig uses: `muzzle`, `grip` (right hand), `foregrip` (left hand), `mag`
## (detachable magazine node — animated during reloads) and `eject` (shell port).
## Gun space: barrel along -Z, +Y up, +X right. Sizes are metres.
class_name GunModel
extends Node3D

var type := 0
var muzzle: Marker3D
var grip: Marker3D
var foregrip: Marker3D
var mag: Node3D
var eject: Marker3D
var bolt: MeshInstance3D           # slides back on each shot (if the gun has one)
var length := 0.8
var attachments := {}                # "supp" / "comp" / "scope" -> Node3D

static var _mats := {}

# Real gun meshes (user-supplied FBX, long axis +X = muzzle) that replace the primitive
# placeholders; markers / hand grips from the primitive build are kept, so the rig,
# muzzle flash and reload keep working unchanged.
const REAL := {
	Weapons.RIFLE: "res://assets/real/guns/models/M16.fbx",
	Weapons.UZI: "res://assets/real/guns/models/VectorSMG.fbx",
	Weapons.SNIPER: "res://assets/real/guns/models/SCAR-H.fbx",
	Weapons.MAGNUM: "res://assets/real/guns/models/DesertEagle.fbx",
	Weapons.MP5: "res://assets/real/guns/models/MP5.fbx",
	Weapons.AK47: "res://assets/real/guns/models/AK47.fbx",
}

static func mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"steel":
			m.albedo_color = Color(0.16, 0.17, 0.19); m.metallic = 0.85; m.roughness = 0.38
		"black":
			m.albedo_color = Color(0.07, 0.07, 0.08); m.metallic = 0.3; m.roughness = 0.6
		"polymer":
			m.albedo_color = Color(0.13, 0.13, 0.14); m.metallic = 0.0; m.roughness = 0.75
		"tan":
			m.albedo_color = Color(0.55, 0.47, 0.34); m.metallic = 0.0; m.roughness = 0.8
		"wood":
			m.albedo_color = Color(0.42, 0.24, 0.12); m.metallic = 0.0; m.roughness = 0.65
		"wood_dark":
			m.albedo_color = Color(0.30, 0.17, 0.09); m.metallic = 0.0; m.roughness = 0.7
		"chrome":
			m.albedo_color = Color(0.75, 0.76, 0.78); m.metallic = 1.0; m.roughness = 0.22
		"brass":
			m.albedo_color = Color(0.80, 0.62, 0.25); m.metallic = 1.0; m.roughness = 0.35
		"olive":
			m.albedo_color = Color(0.30, 0.36, 0.22); m.metallic = 0.1; m.roughness = 0.8
		"red":
			m.albedo_color = Color(0.70, 0.12, 0.10); m.metallic = 0.2; m.roughness = 0.5
		"glass":
			m.albedo_color = Color(0.6, 0.8, 1.0, 0.7); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.roughness = 0.1
			m.emission_enabled = true; m.emission = Color(0.3, 0.6, 1.0); m.emission_energy_multiplier = 0.6
		"glow":
			m.albedo_color = Color(1.0, 0.35, 0.1); m.emission_enabled = true; m.emission = Color(1.0, 0.35, 0.1); m.emission_energy_multiplier = 2.0
		_:
			m.albedo_color = Color(0.2, 0.2, 0.2)
	_mats[key] = m
	return m

## Bolt-on attachments: suppressor / compensator on the muzzle, red-dot scope on top.
func add_attachment(a: String) -> void:
	if attachments.has(a) or muzzle == null:
		return
	var n := Node3D.new()
	match a:
		"supp":
			var c := CylinderMesh.new(); c.top_radius = 0.022; c.bottom_radius = 0.022; c.height = 0.17; c.radial_segments = 12
			c.material = mat("black")
			var mi := MeshInstance3D.new(); mi.mesh = c; mi.rotation.x = PI / 2.0
			mi.position = Vector3(muzzle.position.x, muzzle.position.y, muzzle.position.z - 0.075)
			n.add_child(mi)
			muzzle.position.z -= 0.15
		"comp":
			var c := CylinderMesh.new(); c.top_radius = 0.02; c.bottom_radius = 0.026; c.height = 0.07; c.radial_segments = 8
			c.material = mat("steel")
			var mi := MeshInstance3D.new(); mi.mesh = c; mi.rotation.x = PI / 2.0
			mi.position = Vector3(muzzle.position.x, muzzle.position.y, muzzle.position.z - 0.03)
			n.add_child(mi)
			for k in 3:
				var slot := BoxMesh.new(); slot.size = Vector3(0.06, 0.006, 0.012); slot.material = mat("black")
				var sm := MeshInstance3D.new(); sm.mesh = slot; sm.position = mi.position + Vector3(0, 0.02, -0.02 + k * 0.016)
				n.add_child(sm)
			muzzle.position.z -= 0.06
		"scope":
			var body := BoxMesh.new(); body.size = Vector3(0.03, 0.03, 0.07); body.material = mat("black")
			var mi := MeshInstance3D.new(); mi.mesh = body; mi.position = Vector3(0, 0.115, -0.02)
			n.add_child(mi)
			var lens := BoxMesh.new(); lens.size = Vector3(0.024, 0.024, 0.004); lens.material = mat("glass")
			var lm := MeshInstance3D.new(); lm.mesh = lens; lm.position = Vector3(0, 0.115, -0.056)
			n.add_child(lm)
			var mount := BoxMesh.new(); mount.size = Vector3(0.02, 0.03, 0.05); mount.material = mat("steel")
			var mm := MeshInstance3D.new(); mm.mesh = mount; mm.position = Vector3(0, 0.09, -0.02)
			n.add_child(mm)
	add_child(n)
	attachments[a] = n

static func build(t: int) -> GunModel:
	var g := GunModel.new()
	g.type = t
	return g

func _ready() -> void:
	match type:
		Weapons.UZI: _uzi()
		Weapons.SHOTGUN: _shotgun()
		Weapons.SNIPER: _m14()
		Weapons.MAGNUM: _magnum()
		Weapons.MP5: _mp5()
		Weapons.AK47: _ak47()
		Weapons.FLAMER: _flamer()
		Weapons.ROCKET: _smaw()
		_: _m4()
	_apply_real()

# MARK: primitives

## Swap the primitive placeholder for the real mesh, aligned to the placeholder's bounds.
func _apply_real() -> void:
	if not REAL.has(type) or not ResourceLoader.exists(REAL[type]):
		return
	var pb := _rel_aabb(self)                      # placeholder bounds (gun space) before stripping
	if pb.size.z < 0.05:
		return
	for c in _all(self):
		if c is MeshInstance3D:
			c.queue_free()
	bolt = null
	var inst: Node3D = load(REAL[type]).instantiate()
	add_child(inst)
	# model long axis is X; find which end is the muzzle (the thin barrel half has the
	# smaller vertical extent) and turn that end toward gun -Z
	inst.rotation.y = PI / 2.0 if _muzzle_is_plus_x(inst) else -PI / 2.0
	var ab := _rel_aabb(inst)
	if ab.size.z < 0.001:
		return
	var s := pb.size.z / ab.size.z
	inst.scale = Vector3(s, s, s)
	var pc := pb.position + pb.size * 0.5
	var rc := (ab.position + ab.size * 0.5) * s
	inst.position = pc - rc
	if muzzle:
		muzzle.position = Vector3(pc.x, muzzle.position.y, ab.position.z * s + inst.position.z - 0.01)
	_pbr(inst)

## True when the thinner (barrel) half of the mesh lies at +X.
func _muzzle_is_plus_x(inst: Node3D) -> bool:
	var pts: PackedVector3Array = []
	var inv := inst.global_transform.affine_inverse()
	for c in _all(inst):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var xf := inv * (c as Node3D).global_transform
			var m: Mesh = (c as MeshInstance3D).mesh
			for si in m.get_surface_count():
				var arr := m.surface_get_arrays(si)
				if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
					for v in arr[Mesh.ARRAY_VERTEX]:
						pts.append(xf * v)
	if pts.size() < 8:
		return true
	var lo := 1e20; var hi := -1e20
	for v in pts:
		lo = minf(lo, v.x); hi = maxf(hi, v.x)
	var mid := (lo + hi) * 0.5
	var q := (hi - lo) * 0.25
	# compare vertical extent of the outer quarters (stock / grip end is tall, barrel is thin)
	var ylo_p := 1e20; var yhi_p := -1e20; var ylo_m := 1e20; var yhi_m := -1e20
	for v in pts:
		if v.x > mid + q:
			ylo_p = minf(ylo_p, v.y); yhi_p = maxf(yhi_p, v.y)
		elif v.x < mid - q:
			ylo_m = minf(ylo_m, v.y); yhi_m = maxf(yhi_m, v.y)
	return (yhi_p - ylo_p) < (yhi_m - ylo_m)

func _rel_aabb(n: Node3D) -> AABB:
	var inv := global_transform.affine_inverse()
	var out := AABB(); var first := true
	for c in _all(n):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh and not c.is_queued_for_deletion():
			var a: AABB = (inv * (c as Node3D).global_transform) * (c as MeshInstance3D).get_aabb()
			out = a if first else out.merge(a); first = false
	return out

func _all(n: Node) -> Array:
	var r: Array = [n]
	for c in n.get_children():
		r.append_array(_all(c))
	return r

## Give the untextured real meshes believable PBR (by material name) and shadows.
func _pbr(n: Node) -> void:
	for c in _all(n):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mi := c as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			for si in mi.mesh.get_surface_count():
				var m := mi.get_active_material(si)
				if m is StandardMaterial3D:
					var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					var nm := String(d.resource_name).to_lower()
					if nm.contains("wood"):
						d.metallic = 0.0; d.roughness = 0.62
					elif nm.contains("metal") or nm.contains("mag") or nm.contains("inside") or nm.contains("smooth"):
						d.metallic = 0.75; d.roughness = 0.42
					elif nm.contains("white") or nm.contains("red"):
						d.metallic = 0.1; d.roughness = 0.5
					else:
						d.metallic = 0.3; d.roughness = 0.55   # black polymer / receiver
					mi.set_surface_override_material(si, d)

func _box(pos: Vector3, size: Vector3, m: String, parent: Node3D = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = mat(m)
	mi.mesh = b
	mi.position = pos
	mi.rotation = rot
	(parent if parent else self).add_child(mi)
	return mi

## Cylinder along -Z (barrel style). `len` along z, centred at pos.
func _tube(pos: Vector3, r: float, len: float, m: String, parent: Node3D = null, r2 := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r2 if r2 >= 0.0 else r
	c.height = len
	c.radial_segments = 10
	c.rings = 1
	c.material = mat(m)
	mi.mesh = c
	mi.position = pos
	mi.rotation = Vector3(PI / 2.0, 0, 0)
	(parent if parent else self).add_child(mi)
	return mi

## Vertical cylinder (revolver cylinder = rotate later).
func _cylv(pos: Vector3, r: float, h: float, m: String, parent: Node3D = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 1
	c.material = mat(m)
	mi.mesh = c
	mi.position = pos
	mi.rotation = rot
	(parent if parent else self).add_child(mi)
	return mi

func _marker(pos: Vector3) -> Marker3D:
	var mk := Marker3D.new()
	mk.position = pos
	add_child(mk)
	return mk

## Hand target basis: Y = finger direction, X = back-of-hand direction.
static func hand_basis(fingers: Vector3, back: Vector3) -> Basis:
	var y := fingers.normalized()
	var x := (back - y * back.dot(y)).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)

func _set_hands(grip_pos: Vector3, fore_pos: Vector3) -> void:
	grip = _marker(grip_pos)
	grip.basis = hand_basis(Vector3(0.15, -0.55, -0.82), Vector3(1, 0, 0))
	foregrip = _marker(fore_pos)
	foregrip.basis = hand_basis(Vector3(0.75, 0.55, -0.35), Vector3(-0.35, -0.94, 0))

func _magazine(pos: Vector3, size: Vector3, m: String, tilt := 0.0, curved := false) -> void:
	mag = Node3D.new()
	mag.position = pos
	add_child(mag)
	var body := _box(Vector3(0, -size.y / 2.0, 0), size, m, mag, Vector3(tilt, 0, 0))
	_box(Vector3(0, -size.y - 0.004, 0), Vector3(size.x + 0.006, 0.012, size.z + 0.006), "steel", mag, Vector3(tilt, 0, 0))   # base plate
	if curved:
		body.rotation.x = -0.35
		_box(Vector3(0, -size.y * 0.85, -size.z * 0.35), size * Vector3(1, 0.5, 1), m, mag, Vector3(-0.7, 0, 0))

func _iron_sights(z_rear: float, z_front: float, y: float) -> void:
	_box(Vector3(0, y, z_rear), Vector3(0.024, 0.02, 0.012), "steel")
	_box(Vector3(0, y + 0.004, z_front), Vector3(0.006, 0.026, 0.006), "steel")

func _rail(z: float, len: float, y: float, w := 0.028) -> void:
	for i in int(len / 0.014):
		_box(Vector3(0, y, z - len / 2.0 + i * 0.014 + 0.004), Vector3(w, 0.006, 0.007), "black")

# MARK: guns

func _m4() -> void:
	length = 0.82
	_box(Vector3(0, 0, 0.02), Vector3(0.05, 0.075, 0.26), "black")                        # upper + lower receiver
	_box(Vector3(0, 0.05, -0.02), Vector3(0.03, 0.03, 0.2), "black")                      # carry rail block
	_rail(-0.02, 0.2, 0.068)
	_box(Vector3(0, -0.005, -0.27), Vector3(0.048, 0.05, 0.26), "polymer")                # handguard
	_rail(-0.27, 0.22, 0.03)
	_tube(Vector3(0, 0.005, -0.5), 0.011, 0.2, "steel")                                    # barrel
	_tube(Vector3(0, 0.005, -0.63), 0.016, 0.07, "black")                                  # flash hider
	_box(Vector3(0, 0.0, -0.36), Vector3(0.016, 0.04, 0.02), "black")                      # gas block
	_box(Vector3(0, -0.08, 0.06), Vector3(0.03, 0.09, 0.045), "polymer", null, Vector3(0.3, 0, 0))   # pistol grip
	_box(Vector3(0, -0.02, 0.12), Vector3(0.03, 0.02, 0.06), "steel")                      # trigger guard
	_box(Vector3(0, 0.01, 0.22), Vector3(0.036, 0.04, 0.16), "polymer")                    # buffer tube + stock
	_box(Vector3(0, -0.02, 0.29), Vector3(0.04, 0.09, 0.08), "polymer")                    # stock butt
	bolt = _box(Vector3(0.03, 0.01, 0.0), Vector3(0.016, 0.014, 0.05), "steel")            # charging handle
	_iron_sights(0.05, -0.32, 0.09)
	_box(Vector3(0, 0.085, -0.05), Vector3(0.03, 0.03, 0.07), "black")                    # red-dot body
	_box(Vector3(0, 0.085, -0.085), Vector3(0.026, 0.026, 0.004), "glass")
	_magazine(Vector3(0, -0.035, -0.06), Vector3(0.03, 0.14, 0.06), "steel", 0.15, true)
	muzzle = _marker(Vector3(0, 0.005, -0.67))
	eject = _marker(Vector3(0.03, 0.01, 0.0))
	_set_hands(Vector3(0.0, -0.09, 0.07), Vector3(-0.005, -0.03, -0.27))

func _uzi() -> void:
	length = 0.45
	_box(Vector3(0, 0, 0), Vector3(0.05, 0.08, 0.26), "steel")                             # receiver
	_box(Vector3(0, 0.045, 0.0), Vector3(0.04, 0.012, 0.2), "black")
	_tube(Vector3(0, 0.015, -0.19), 0.012, 0.12, "steel")
	_tube(Vector3(0, 0.015, -0.24), 0.017, 0.03, "black")
	_box(Vector3(0, -0.08, 0.02), Vector3(0.034, 0.09, 0.05), "polymer", null, Vector3(0.12, 0, 0))   # grip (mag goes in here)
	_box(Vector3(0, -0.03, 0.08), Vector3(0.026, 0.02, 0.05), "steel")                     # trigger guard
	_box(Vector3(0, 0.01, 0.2), Vector3(0.024, 0.04, 0.16), "steel")                        # folded stock
	_box(Vector3(0, -0.06, -0.09), Vector3(0.03, 0.06, 0.05), "polymer")                    # front grip
	bolt = _box(Vector3(0, 0.05, 0.02), Vector3(0.014, 0.008, 0.03), "steel")
	_iron_sights(0.1, -0.1, 0.06)
	_magazine(Vector3(0, -0.12, 0.03), Vector3(0.024, 0.12, 0.04), "steel", 0.12)
	muzzle = _marker(Vector3(0, 0.015, -0.26))
	eject = _marker(Vector3(0.03, 0.02, 0.0))
	_set_hands(Vector3(0, -0.1, 0.03), Vector3(0, -0.06, -0.1))

func _shotgun() -> void:
	length = 0.95
	_box(Vector3(0, 0, 0.06), Vector3(0.045, 0.06, 0.2), "steel")                           # receiver
	_tube(Vector3(0, 0.02, -0.28), 0.012, 0.5, "steel")                                     # barrel
	_tube(Vector3(0, -0.012, -0.24), 0.014, 0.42, "steel")                                  # mag tube
	_box(Vector3(0, -0.005, -0.2), Vector3(0.04, 0.045, 0.12), "wood")                      # pump
	for i in 6:
		_box(Vector3(0, -0.005, -0.25 + i * 0.02), Vector3(0.042, 0.047, 0.004), "wood_dark")
	_box(Vector3(0, -0.03, 0.22), Vector3(0.036, 0.06, 0.16), "wood", null, Vector3(-0.12, 0, 0))   # stock
	_box(Vector3(0, -0.055, 0.32), Vector3(0.04, 0.11, 0.05), "wood_dark")               # butt
	_box(Vector3(0, -0.05, 0.1), Vector3(0.03, 0.05, 0.04), "wood_dark")                   # grip area
	_box(Vector3(0, -0.04, 0.13), Vector3(0.024, 0.016, 0.05), "steel")                    # trigger guard
	_iron_sights(0.12, -0.5, 0.055)
	for i in 4:
		_tube(Vector3(0.028, 0.03, 0.0 + i * 0.03), 0.009, 0.026, "red")                   # side saddle shells
	mag = Node3D.new(); mag.position = Vector3(0, -0.02, -0.02); add_child(mag)
	muzzle = _marker(Vector3(0, 0.02, -0.54))
	eject = _marker(Vector3(0.028, 0.0, 0.03))
	_set_hands(Vector3(0, -0.06, 0.12), Vector3(0, -0.03, -0.2))

func _m14() -> void:
	length = 1.1
	_box(Vector3(0, -0.01, 0.0), Vector3(0.045, 0.06, 0.5), "wood")                        # stock body
	_box(Vector3(0, -0.04, 0.3), Vector3(0.04, 0.09, 0.2), "wood", null, Vector3(-0.1, 0, 0))   # butt stock
	_box(Vector3(0, -0.02, 0.4), Vector3(0.044, 0.11, 0.03), "wood_dark")
	_box(Vector3(0, 0.03, -0.05), Vector3(0.04, 0.03, 0.3), "steel")                        # receiver top
	_tube(Vector3(0, 0.03, -0.42), 0.011, 0.44, "steel")                                    # barrel
	_tube(Vector3(0, 0.03, -0.66), 0.014, 0.06, "black")                                    # flash suppressor
	_box(Vector3(0, 0.01, -0.35), Vector3(0.03, 0.03, 0.06), "steel")                       # gas cylinder / hand stop
	_box(Vector3(0, -0.055, -0.05), Vector3(0.03, 0.09, 0.06), "steel")                    # magazine well
	_box(Vector3(0, -0.035, 0.08), Vector3(0.024, 0.018, 0.06), "steel")                    # trigger guard
	# scope
	_tube(Vector3(0, 0.085, 0.0), 0.017, 0.2, "black")
	_tube(Vector3(0, 0.085, -0.1), 0.022, 0.04, "black")
	_tube(Vector3(0, 0.085, 0.1), 0.02, 0.04, "black")
	_box(Vector3(0, 0.085, -0.12), Vector3(0.036, 0.036, 0.004), "glass")
	_box(Vector3(0, 0.06, -0.04), Vector3(0.012, 0.03, 0.02), "steel")
	_box(Vector3(0, 0.06, 0.04), Vector3(0.012, 0.03, 0.02), "steel")
	bolt = _box(Vector3(0.03, 0.04, -0.02), Vector3(0.016, 0.012, 0.04), "steel")
	_magazine(Vector3(0, -0.06, -0.06), Vector3(0.028, 0.09, 0.06), "steel", 0.08)
	muzzle = _marker(Vector3(0, 0.03, -0.7))
	eject = _marker(Vector3(0.03, 0.04, -0.02))
	_set_hands(Vector3(0, -0.05, 0.13), Vector3(0, -0.03, -0.28))

func _magnum() -> void:
	length = 0.32
	_box(Vector3(0, 0.02, -0.05), Vector3(0.034, 0.05, 0.14), "chrome")                     # frame
	_tube(Vector3(0, 0.03, -0.2), 0.013, 0.2, "chrome")                                     # barrel
	_box(Vector3(0, 0.05, -0.2), Vector3(0.016, 0.014, 0.2), "chrome")                      # vent rib
	_box(Vector3(0, 0.0, -0.2), Vector3(0.018, 0.03, 0.2), "chrome")                        # under-lug
	_cylv(Vector3(0, 0.02, -0.03), 0.022, 0.05, "chrome", null, Vector3(PI / 2.0, 0, 0))   # cylinder
	for i in 6:
		var a := float(i) / 6.0 * TAU
		_tube(Vector3(cos(a) * 0.014, 0.02 + sin(a) * 0.014, -0.03), 0.004, 0.052, "black")
	_box(Vector3(0, 0.055, 0.0), Vector3(0.012, 0.02, 0.03), "chrome")                      # hammer
	_box(Vector3(0, -0.05, 0.03), Vector3(0.03, 0.09, 0.04), "wood", null, Vector3(0.35, 0, 0))   # grip
	_box(Vector3(0, -0.015, -0.01), Vector3(0.02, 0.014, 0.045), "chrome")                  # trigger guard
	_iron_sights(0.02, -0.28, 0.06)
	mag = Node3D.new(); mag.position = Vector3(0, 0.02, -0.03); add_child(mag)
	muzzle = _marker(Vector3(0, 0.03, -0.31))
	eject = _marker(Vector3(0.03, 0.03, -0.03))
	_set_hands(Vector3(0, -0.06, 0.035), Vector3(-0.03, -0.075, 0.03))

func _mp5() -> void:
	length = 0.68
	_box(Vector3(0, 0, -0.02), Vector3(0.046, 0.06, 0.3), "black")                          # receiver
	_box(Vector3(0, -0.01, -0.25), Vector3(0.048, 0.055, 0.16), "polymer")                  # handguard
	_tube(Vector3(0, 0.005, -0.38), 0.011, 0.14, "steel")
	_tube(Vector3(0, 0.005, -0.46), 0.015, 0.03, "black")
	_box(Vector3(0, -0.075, 0.05), Vector3(0.032, 0.09, 0.05), "polymer", null, Vector3(0.25, 0, 0))   # grip
	_box(Vector3(0, -0.04, 0.1), Vector3(0.03, 0.02, 0.06), "polymer")
	_box(Vector3(0, 0.0, 0.2), Vector3(0.04, 0.045, 0.14), "polymer")                       # stock
	_box(Vector3(0, -0.015, 0.28), Vector3(0.04, 0.08, 0.04), "polymer")
	_tube(Vector3(0, 0.05, -0.05), 0.014, 0.05, "black")                                    # drum rear sight
	_box(Vector3(0, 0.05, -0.36), Vector3(0.02, 0.02, 0.01), "black")                       # front sight hood
	bolt = _box(Vector3(0.0, 0.035, -0.14), Vector3(0.014, 0.014, 0.04), "steel")           # charging handle
	_magazine(Vector3(0, -0.03, -0.09), Vector3(0.026, 0.13, 0.05), "steel", 0.1, true)
	muzzle = _marker(Vector3(0, 0.005, -0.48))
	eject = _marker(Vector3(0.03, 0.01, -0.05))
	_set_hands(Vector3(0, -0.085, 0.06), Vector3(0, -0.04, -0.26))

func _ak47() -> void:
	length = 0.88
	_box(Vector3(0, 0, 0.0), Vector3(0.044, 0.065, 0.24), "steel")                          # receiver
	_box(Vector3(0, 0.04, -0.05), Vector3(0.036, 0.02, 0.16), "steel")                      # dust cover
	_box(Vector3(0, -0.005, -0.25), Vector3(0.05, 0.05, 0.16), "wood")                      # handguard
	_box(Vector3(0, 0.035, -0.25), Vector3(0.044, 0.02, 0.14), "wood")                      # upper handguard
	_tube(Vector3(0, 0.02, -0.42), 0.012, 0.22, "steel")                                    # barrel
	_tube(Vector3(0, 0.04, -0.36), 0.01, 0.12, "steel")                                     # gas tube
	_tube(Vector3(0, 0.02, -0.55), 0.015, 0.04, "black")                                    # muzzle brake
	_box(Vector3(0, -0.075, 0.08), Vector3(0.032, 0.09, 0.045), "wood", null, Vector3(0.28, 0, 0))   # grip
	_box(Vector3(0, -0.04, 0.12), Vector3(0.024, 0.02, 0.06), "steel")
	_box(Vector3(0, 0.0, 0.25), Vector3(0.04, 0.055, 0.26), "wood", null, Vector3(-0.08, 0, 0))    # stock
	_box(Vector3(0, -0.03, 0.37), Vector3(0.042, 0.1, 0.04), "wood_dark")
	bolt = _box(Vector3(0.03, 0.02, -0.02), Vector3(0.016, 0.012, 0.03), "steel")
	_iron_sights(-0.06, -0.5, 0.075)
	_magazine(Vector3(0, -0.035, -0.06), Vector3(0.03, 0.15, 0.065), "steel", 0.2, true)
	muzzle = _marker(Vector3(0, 0.02, -0.58))
	eject = _marker(Vector3(0.03, 0.03, -0.02))
	_set_hands(Vector3(0, -0.085, 0.09), Vector3(0, -0.03, -0.26))

func _flamer() -> void:
	length = 0.9
	_box(Vector3(0, 0, 0.0), Vector3(0.05, 0.07, 0.3), "olive")                             # body
	_tube(Vector3(0, 0.0, -0.35), 0.03, 0.4, "steel")                                       # feed tube
	_tube(Vector3(0, 0.0, -0.6), 0.04, 0.1, "black", null, 0.03)                            # nozzle
	_tube(Vector3(0, 0.0, -0.66), 0.012, 0.04, "glow")                                      # pilot
	for i in 3:
		_tube(Vector3(0, 0.0, -0.2 - i * 0.12), 0.036, 0.02, "black")                       # rings
	_box(Vector3(0, -0.08, 0.06), Vector3(0.034, 0.09, 0.05), "polymer", null, Vector3(0.25, 0, 0))   # grip
	_box(Vector3(0, -0.06, -0.2), Vector3(0.03, 0.06, 0.05), "polymer")                     # front grip
	_tube(Vector3(0.0, 0.06, 0.12), 0.05, 0.22, "red")                                      # fuel tank (on the gun)
	_tube(Vector3(0, 0.06, 0.24), 0.02, 0.03, "steel")
	_box(Vector3(0, 0.03, 0.15), Vector3(0.02, 0.02, 0.2), "steel")                          # hose block
	_box(Vector3(0, -0.02, 0.22), Vector3(0.036, 0.05, 0.12), "olive")                        # stock
	mag = Node3D.new(); mag.position = Vector3(0, 0.06, 0.12); add_child(mag)
	muzzle = _marker(Vector3(0, 0.0, -0.7))
	eject = _marker(Vector3(0.03, 0.02, 0.0))
	_set_hands(Vector3(0, -0.09, 0.07), Vector3(0, -0.06, -0.2))

func _smaw() -> void:
	length = 1.2
	_tube(Vector3(0, 0.04, -0.1), 0.05, 0.9, "olive")                                       # launch tube
	_tube(Vector3(0, 0.04, -0.58), 0.056, 0.06, "black")                                    # front ring
	_tube(Vector3(0, 0.04, 0.36), 0.056, 0.06, "black")                                     # rear ring
	_tube(Vector3(0, 0.04, -0.62), 0.045, 0.02, "black")
	_box(Vector3(0, -0.04, 0.02), Vector3(0.04, 0.1, 0.05), "polymer", null, Vector3(0.2, 0, 0))    # grip
	_box(Vector3(0, -0.04, -0.2), Vector3(0.03, 0.09, 0.04), "polymer")                     # front grip
	_box(Vector3(0, -0.005, -0.1), Vector3(0.05, 0.03, 0.3), "steel")                        # trigger housing
	_box(Vector3(0.06, 0.09, -0.05), Vector3(0.04, 0.06, 0.1), "black")                      # sight box
	_box(Vector3(0.06, 0.09, -0.1), Vector3(0.03, 0.03, 0.004), "glass")
	_box(Vector3(0, 0.1, 0.1), Vector3(0.02, 0.02, 0.3), "olive")                             # carry handle
	_box(Vector3(0, -0.055, 0.25), Vector3(0.04, 0.05, 0.1), "polymer")                      # shoulder rest
	mag = Node3D.new(); mag.position = Vector3(0, 0.04, 0.4); add_child(mag)
	_tube(Vector3(0, 0, 0), 0.03, 0.2, "red", mag)                                          # rocket (visible at the back)
	muzzle = _marker(Vector3(0, 0.04, -0.66))
	eject = _marker(Vector3(0, 0.04, 0.45))
	_set_hands(Vector3(0, -0.09, 0.03), Vector3(0, -0.085, -0.2))

## Kick the bolt back briefly (called on each shot).
func cycle_bolt() -> void:
	if not bolt:
		return
	var home := bolt.position
	var tw := create_tween()
	tw.tween_property(bolt, "position:z", home.z + 0.03, 0.03)
	tw.tween_property(bolt, "position:z", home.z, 0.06)
