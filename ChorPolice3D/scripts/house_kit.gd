## HouseKit — builds enterable houses from the CC0 Kenney "Building Kit" (2 m grid, real
## scale) re-skinned with our real PBR textures (triplanar), with box colliders that leave
## doorways / windows open, hinged auto-opening doors, stairs + upper floors and a roof.
## Spec (cells of 2 m): {w, d, floors, style, doors:[[side, i]], windows:[[side, i, floor]],
## stairs: [cx, cz] or null, roof: "flat"|"gable", inner: [[x, z, len, axis, doorway_i]]}
class_name HouseKit
extends RefCounted

const KIT := "res://assets/real/kits/building_kit/"
const MOD := "res://assets/real/kits/modular_buildings/"
const CELL := 2.0
const FLOOR_H := 3.6             # 2.4 m wall + 1.2 m band — roomy for the over-shoulder camera
const BAND_H := 1.2
const DOOR_W := 1.4              # clear opening (posts 0.3 each side of a 2 m cell)
const DOOR_H := 2.3
const STEP_R := 0.2              # stair rise / run per step
const STEP_T := 0.28
static var _cache := {}
static var _mats := {}
static var _rng := RandomNumberGenerator.new()
static var merge_enabled := true
const MODELS := "res://assets/real/models/"

const STYLES := {
	"concrete": {"wall": ["concrete", Color(0.74, 0.68, 0.58)], "wall_in": ["concrete", Color(0.8, 0.79, 0.75)], "floor0": ["concrete", Color(0.55, 0.55, 0.53)],
		"floor": ["wood_planks", Color(0.7, 0.6, 0.48)], "roof": ["concrete", Color(0.52, 0.5, 0.46)], "door": ["metal_rusted", Color(0.62, 0.58, 0.52)],
		"stairs": ["concrete", Color(0.6, 0.6, 0.58)], "trim": ["steel_wall", Color(0.5, 0.5, 0.52)]},
	"brick": {"wall": ["brick", Color(0.85, 0.78, 0.7)], "wall_in": ["concrete", Color(0.82, 0.8, 0.76)], "floor0": ["paving_stone", Color(0.6, 0.58, 0.55)],
		"floor": ["wood_planks", Color(0.82, 0.72, 0.58)], "roof": ["roof_tiles", Color(0.7, 0.55, 0.45)], "door": ["wood_planks", Color(0.4, 0.28, 0.18)],
		"stairs": ["wood_planks", Color(0.7, 0.6, 0.48)], "trim": ["concrete", Color(0.8, 0.8, 0.78)]},
	"metal": {"wall": ["steel_wall", Color(0.42, 0.44, 0.46)], "wall_in": ["metal_plate", Color(0.55, 0.55, 0.57)], "floor0": ["diamond_plate", Color(0.7, 0.7, 0.7)],
		"floor": ["diamond_plate", Color(0.7, 0.7, 0.7)], "roof": ["concrete", Color(0.45, 0.45, 0.43)], "door": ["metal_rusted", Color(0.55, 0.5, 0.45)],
		"stairs": ["diamond_plate", Color(0.6, 0.6, 0.6)], "trim": ["metal_rusted", Color(0.5, 0.45, 0.4)]},
	"sandstone": {"wall": ["concrete_worn", Color(0.86, 0.74, 0.55)], "wall_in": ["concrete", Color(0.85, 0.8, 0.72)], "floor0": ["paving_stone", Color(0.7, 0.64, 0.55)],
		"floor": ["wood_planks", Color(0.78, 0.66, 0.5)], "roof": ["concrete", Color(0.7, 0.62, 0.5)], "door": ["wood_planks", Color(0.45, 0.32, 0.2)],
		"stairs": ["concrete", Color(0.72, 0.66, 0.56)], "trim": ["concrete_worn", Color(0.66, 0.58, 0.46)]},
	"whitewash": {"wall": ["concrete", Color(0.92, 0.9, 0.86)], "wall_in": ["concrete", Color(0.9, 0.89, 0.86)], "floor0": ["paving_stone", Color(0.62, 0.6, 0.58)],
		"floor": ["wood_planks", Color(0.8, 0.7, 0.56)], "roof": ["roof_tiles", Color(0.62, 0.42, 0.34)], "door": ["wood_planks", Color(0.28, 0.36, 0.5)],
		"stairs": ["concrete", Color(0.86, 0.84, 0.8)], "trim": ["concrete", Color(0.5, 0.55, 0.62)]},
	"stone": {"wall": ["cliff_rock", Color(0.62, 0.58, 0.52)], "wall_in": ["concrete", Color(0.78, 0.76, 0.72)], "floor0": ["paving_stone", Color(0.58, 0.56, 0.52)],
		"floor": ["wood_planks", Color(0.66, 0.55, 0.42)], "roof": ["roof_tiles", Color(0.5, 0.44, 0.4)], "door": ["wood_planks", Color(0.38, 0.26, 0.16)],
		"stairs": ["cliff_rock", Color(0.6, 0.57, 0.52)], "trim": ["cliff_rock", Color(0.52, 0.5, 0.46)]},
	"redbrick": {"wall": ["brick", Color(0.74, 0.42, 0.34)], "wall_in": ["concrete", Color(0.84, 0.8, 0.76)], "floor0": ["paving_stone", Color(0.58, 0.55, 0.52)],
		"floor": ["wood_planks", Color(0.7, 0.58, 0.44)], "roof": ["roof_tiles", Color(0.42, 0.36, 0.34)], "door": ["metal_rusted", Color(0.5, 0.46, 0.42)],
		"stairs": ["concrete", Color(0.64, 0.62, 0.6)], "trim": ["concrete", Color(0.72, 0.7, 0.68)]},
}

static func _scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

static func _mat(style: Dictionary, key: String, uv := 1.4) -> Material:
	var e: Array = style[key]
	var k := "%s|%s|%.2f" % [e[0], str(e[1]), uv]
	if not _mats.has(k):
		_mats[k] = RealTex.mat(e[0], uv, true, e[1]) if RealTex.has_assets() else _flat(e[1])
	return _mats[k]

static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 0.85
	return m

static func _glass() -> StandardMaterial3D:
	if not _mats.has("glass"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.85, 0.95, 0.35); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 0.4; m.roughness = 0.08; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats["glass"] = m
	return _mats["glass"]

## Instance a kit piece and re-skin its "colormap" surfaces with a real PBR material.
## A straight, walkable box-step staircase rising one floor from `base` along local +Z
## (before yaw). Builds visible treads + a stringer, a smooth ramp collider, and a
## side rail. Run spans `run_cells` * CELL so the pitch stays gentle (~30 deg).
static func _stairs(root: Node3D, base: Vector3, yaw: float, mat: Material, run_cells := 3, width := 1.7) -> void:
	var holder := Node3D.new(); holder.position = base; holder.rotation.y = yaw; root.add_child(holder)
	var total_run := run_cells * CELL - 0.4
	var nst := int(round(FLOOR_H / STEP_R))
	var rise := FLOOR_H / float(nst)
	var run := total_run / float(nst)
	for i in nst:
		var tread := MeshInstance3D.new(); var tb := BoxMesh.new(); tb.size = Vector3(width, rise + 0.02, run + 0.02); tb.material = mat
		tread.mesh = tb; tread.position = Vector3(0, rise * (i + 0.5), run * (i + 0.5)); holder.add_child(tread)
	# smooth wedge collider under the treads (so movement is a ramp, not stairs)
	var ramp := StaticBody3D.new(); ramp.collision_layer = 1; ramp.collision_mask = 0
	var rcs := CollisionShape3D.new(); var poly := ConvexPolygonShape3D.new()
	var hwx := width / 2.0
	poly.points = PackedVector3Array([
		Vector3(-hwx, 0, 0), Vector3(hwx, 0, 0),
		Vector3(-hwx, 0, total_run), Vector3(hwx, 0, total_run),
		Vector3(-hwx, FLOOR_H, total_run), Vector3(hwx, FLOOR_H, total_run),
		Vector3(-hwx, FLOOR_H - 0.1, total_run - 0.6), Vector3(hwx, FLOOR_H - 0.1, total_run - 0.6)])
	rcs.shape = poly; ramp.add_child(rcs); holder.add_child(ramp)
	# side rail (kerb) so the drop-off side reads and blocks a fall
	var rail := MeshInstance3D.new(); var rb := BoxMesh.new(); rb.size = Vector3(0.12, 0.9, total_run); rb.material = mat
	rail.mesh = rb; rail.position = Vector3(-hwx - 0.06, FLOOR_H / 2.0, total_run / 2.0); holder.add_child(rail)

static func piece(path: String, style: Dictionary, key: String, uv := 1.4) -> Node3D:
	var sc := _scene(path)
	if sc == null:
		push_warning("HouseKit: missing " + path); return Node3D.new()
	var n: Node3D = sc.instantiate()
	var m := _mat(style, key, uv)
	var st: Array = [n]
	while not st.is_empty():
		var c: Node = st.pop_back()
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mi := c as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			for s in mi.mesh.get_surface_count():
				var sm := mi.get_active_material(s)
				var nm := String(sm.resource_name).to_lower() if sm else ""
				mi.set_surface_override_material(s, _glass() if nm.contains("glass") else m)
		for ch in c.get_children():
			st.append(ch)
	return n

## Instance one of our downloaded real props (gltf folder name), scaled to `h` metres tall.
static func prop(name: String, h: float) -> Node3D:
	var dir := MODELS + name + "/"
	var files := DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()
	for f in files:
		if f.ends_with(".gltf") or f.ends_with(".glb"):
			var sc := _scene(dir + f)
			if sc == null: break
			var n: Node3D = sc.instantiate()
			var ab := AABB(); var first := true; var st: Array = [n]
			while not st.is_empty():
				var c: Node = st.pop_back()
				if c is MeshInstance3D and (c as MeshInstance3D).mesh:
					var a: AABB = (c as Node3D).transform * (c as MeshInstance3D).get_aabb()
					ab = a if first else ab.merge(a); first = false
					(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				for ch in c.get_children(): st.append(ch)
			if ab.size.y > 0.001:
				var k := h / ab.size.y
				n.scale = Vector3(k, k, k)
				n.position = -Vector3(ab.position.x + ab.size.x / 2.0, ab.position.y, ab.position.z + ab.size.z / 2.0) * k
			var holder := Node3D.new(); holder.add_child(n)
			return holder
	return Node3D.new()

static func _box(parent: Node3D, pos: Vector3, size: Vector3, yaw := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1; b.collision_mask = 0
	b.position = pos; b.rotation.y = yaw
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size; cs.shape = bs
	b.add_child(cs); parent.add_child(b)
	return b

## Real door leaves loaded once from doorset.glb (5 painted wooden doors + a frame).
## _door_leaves holds {mesh, aabb} for the 5 leaves; _real_door_leaf() returns a MeshInstance3D
## normalised into the Door\'s local space: hinge at origin, base at Y=0, leaf along +Z.
static var _door_leaves: Array = []
static var _door_loaded := false
const DOORSET := "res://assets/real/kits/doors/doorset.glb"

static func _load_door_leaves() -> void:
	if _door_loaded:
		return
	_door_loaded = true
	if not ResourceLoader.exists(DOORSET):
		return
	var scn: Node3D = (load(DOORSET) as PackedScene).instantiate()
	var found: Array = []
	_collect_mesh(scn, found)
	# the 5 leaves are the "Object00x" meshes (skip the frame "Box013"); keep in name order
	found.sort_custom(func(a, b): return String(a.name) < String(b.name))
	for mi in found:
		if String(mi.name).begins_with("Object"):
			_door_leaves.append({"mesh": (mi as MeshInstance3D).mesh, "aabb": (mi as MeshInstance3D).get_aabb()})
	scn.queue_free()

static func _collect_mesh(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_mesh(c, out)

## A normalised real door leaf, or null if the set is missing. idx picks the colour (wraps).
static func _real_door_leaf(idx: int, wdt: float, hgt: float) -> MeshInstance3D:
	_load_door_leaves()
	if _door_leaves.is_empty():
		return null
	var e: Dictionary = _door_leaves[posmod(idx, _door_leaves.size())]
	var ab: AABB = e["aabb"]
	# door-local axes: X = width, Y = thickness, Z = height (mm). Map to my X=thick, Y=up, Z=width.
	var sw := (wdt - 0.04) / maxf(ab.size.x, 0.001)     # width  -> my +Z
	var sh := hgt / maxf(ab.size.z, 0.001)              # height -> my +Y
	var mi := MeshInstance3D.new(); mi.mesh = e["mesh"]
	var basis := Basis(Vector3(0, 0, sw), Vector3(sh, 0, 0), Vector3(0, sh, 0))
	var thick_mid := ab.position.y + ab.size.y * 0.5
	var t := Vector3(-sh * thick_mid, -sh * ab.position.z, -sw * ab.position.x)
	mi.transform = Transform3D(basis, t)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Hinged door. Auto mode: opens while any fighter is inside its trigger, closes 1.5 s after
## everyone leaves (overlap-polled, so nothing gets stuck). Manual: DOOR button → toggle().
class Door:
	extends Node3D
	var is_open := false
	var _tw: Tween
	var _close_t := 0.0
	var _dir := 1.0
	var _base := 0.0
	var _area: Area3D
	var _manual_t := 0.0                   # after a manual toggle, auto mode waits a bit
	func _ready() -> void:
		_base = rotation.y
		add_to_group("doors")
	func setup(leaf_mat: Material, dir: float, wdt := 1.4, hgt := 2.3, leaf_idx := -1) -> void:
		_dir = dir
		var w := wdt - 0.06
		# a real textured door leaf (assets/real/kits/doors/doorset.glb); hinge at local origin,
		# leaf lies flat, extends along +Z (width) with the base at Y=0 — falls back to a box.
		var real: MeshInstance3D = HouseKit._real_door_leaf(leaf_idx, wdt, hgt)
		if real != null:
			add_child(real)
		else:
			var leaf := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.07, hgt - 0.05, w); bm.material = leaf_mat
			leaf.mesh = bm; leaf.position = Vector3(0.0, (hgt - 0.05) / 2.0, w / 2.0 + 0.03); add_child(leaf)
			var hm := MeshInstance3D.new(); var hb := BoxMesh.new(); hb.size = Vector3(0.16, 0.05, 0.14); hb.material = HouseKit._flat(Color(0.75, 0.72, 0.66))
			hm.mesh = hb; hm.position = Vector3(0.0, 1.05, w - 0.18); add_child(hm)
			var kp := MeshInstance3D.new(); var kb := BoxMesh.new(); kb.size = Vector3(0.085, 0.3, w - 0.1); kb.material = HouseKit._flat(Color(0.35, 0.34, 0.33))
			kp.mesh = kb; kp.position = Vector3(0.0, 0.16, w / 2.0 + 0.03); add_child(kp)
		var b := StaticBody3D.new(); b.collision_layer = 1; b.collision_mask = 0
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.08, hgt - 0.05, w); cs.shape = bs
		cs.position = Vector3(0.0, (hgt - 0.05) / 2.0, w / 2.0 + 0.03); b.add_child(cs); add_child(b)
		_area = Area3D.new(); _area.collision_layer = 0; _area.collision_mask = 2 | 4 | 8; _area.monitoring = true
		var acs := CollisionShape3D.new(); var sp := SphereShape3D.new(); sp.radius = 2.2; acs.shape = sp; acs.position = Vector3(0, 1.0, w / 2.0)
		_area.add_child(acs); add_child(_area)
	func someone_near() -> bool:
		return _area != null and _area.has_overlapping_bodies()
	func _process(delta: float) -> void:
		_manual_t = maxf(0.0, _manual_t - delta)
		var auto: bool = true
		var st := get_tree().root.get_node_or_null("Settings")
		if st != null and "door_auto" in st:
			auto = bool(st.door_auto)
		if not auto or _manual_t > 0.0:
			return
		if someone_near():
			_close_t = 1.5
			if not is_open:
				set_open(true)
		elif is_open:
			_close_t -= delta
			if _close_t <= 0.0:
				set_open(false)
	func toggle() -> void:
		_manual_t = 3.0
		set_open(not is_open)
	## Swing away from whoever is closest (push a door open, it moves away from you).
	func _pick_dir() -> void:
		if _area == null:
			return
		var best: Node3D = null; var bd := 1e9
		for b in _area.get_overlapping_bodies():
			if b is Node3D:
				var d: float = (b as Node3D).global_position.distance_to(global_position)
				if d < bd:
					bd = d; best = b
		if best:
			var lx := to_local(best.global_position).x
			_dir = -1.0 if lx > 0.0 else 1.0
	func set_open(o: bool) -> void:
		if o == is_open:
			return
		if o:
			_pick_dir()
		is_open = o
		if _tw: _tw.kill()
		_tw = create_tween()
		_tw.tween_property(self, "rotation:y", _base + ((deg_to_rad(105.0) * _dir) if o else 0.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var au := get_tree().root.get_node_or_null("Audio")
		if au:
			au.play_at("swap", global_position, -6.0, 0.55 if o else 0.45)

## Build a house; returns its root (already positioned / rotated by the caller).
static func build(spec: Dictionary, style_name := "concrete") -> Node3D:
	var style: Dictionary = STYLES.get(style_name, STYLES["concrete"])
	var root := Node3D.new()
	var w: int = int(spec.get("w", 3)); var d: int = int(spec.get("d", 2)); var floors: int = int(spec.get("floors", 1))
	var doors: Array = spec.get("doors", [["S", 0]])
	var windows: Array = spec.get("windows", [])
	var stairs = spec.get("stairs", null)
	var roof: String = String(spec.get("roof", "flat"))
	var inner: Array = spec.get("inner", [])
	var open_hall: bool = bool(spec.get("open", false))
	var W := w * CELL; var D := d * CELL
	for f in floors:
		var y0 := f * FLOOR_H
		# floors (skip the two cells over the stairs on upper floors)
		for cx in w:
			for cz in d:
				if f > 0 and open_hall:
					continue
				if f > 0 and stairs != null and cx == int(stairs[0]) and (cz == int(stairs[1]) or cz == int(stairs[1]) + 1 or cz == int(stairs[1]) + 2):
					continue
				var fl := piece(KIT + "floor.glb", style, "floor0" if f == 0 else "floor", 1.0)
				fl.position = Vector3(cx * CELL + 1.0, y0 + 0.02, cz * CELL + 1.0)
				root.add_child(fl)
		if f > 0 and not open_hall:
			_box(root, Vector3(W / 2.0, y0 - 0.05, D / 2.0), Vector3(W, 0.1, D))   # slab collider (stair hole is small enough)
		# perimeter walls
		for side in ["N", "S", "E", "W"]:
			var count := w if side in ["N", "S"] else d
			for i in count:
				var has_door := f == 0 and doors.any(func(x): return x[0] == side and int(x[1]) == i)
				var has_win := windows.any(func(x): return x[0] == side and int(x[1]) == i and int(x[2]) == f)
				var name := "wall-doorway-square.glb" if has_door else ("wall-window-square-detailed.glb" if has_win else "wall.glb")
				var pc := piece(KIT + name, style, "wall", 2.2)
				var pos: Vector3; var yaw: float
				match side:
					"N": pos = Vector3(i * CELL + 1.0, y0, 0.0); yaw = PI / 2.0
					"S": pos = Vector3(i * CELL + 1.0, y0, D); yaw = -PI / 2.0
					"E": pos = Vector3(W, y0, i * CELL + 1.0); yaw = PI
					_: pos = Vector3(0.0, y0, i * CELL + 1.0); yaw = 0.0
				pc.position = pos; pc.rotation.y = yaw; pc.scale = Vector3(2.5, 1, 1)
				root.add_child(pc)
				var band := piece(KIT + "wall-low.glb", style, "wall", 2.2)   # 0.72 m band -> 3.12 m rooms
				band.position = pos + Vector3(0, 2.4, 0); band.rotation.y = yaw; band.scale = Vector3(2.5, BAND_H / 1.2, 1)
				root.add_child(band)
				# colliders: solid wall, or posts + lintel around a doorway / window opening
				var along := Vector3(1, 0, 0) if side in ["N", "S"] else Vector3(0, 0, 1)
				var cy := yaw
				if has_door:
					_box(root, pos + along * -0.85 + Vector3(0, DOOR_H / 2.0, 0), Vector3(0.28, DOOR_H, 0.3), cy)
					_box(root, pos + along * 0.85 + Vector3(0, DOOR_H / 2.0, 0), Vector3(0.28, DOOR_H, 0.3), cy)
					_box(root, pos + Vector3(0, DOOR_H + (FLOOR_H - DOOR_H) / 2.0, 0), Vector3(0.28, FLOOR_H - DOOR_H, 2.0), cy)
					var zdir := Vector3(sin(cy), 0, cos(cy))
					var door := Door.new()
					door.setup(_mat(style, "door", 1.0), 1.0, DOOR_W, DOOR_H, int(spec.get("seed", 7)) + i)
					door.position = pos - zdir * (DOOR_W / 2.0)
					door.rotation.y = cy
					root.add_child(door)
				elif has_win:
					_box(root, pos + Vector3(0, 0.5, 0), Vector3(0.28, 1.0, 2.0), cy)      # sill
					_box(root, pos + Vector3(0, 1.85 + (FLOOR_H - 1.85) / 2.0, 0), Vector3(0.28, FLOOR_H - 1.85, 2.0), cy)     # lintel + band
					_box(root, pos + along * -0.75 + Vector3(0, 1.4, 0), Vector3(0.28, 0.9, 0.5), cy)
					_box(root, pos + along * 0.75 + Vector3(0, 1.4, 0), Vector3(0.28, 0.9, 0.5), cy)
				else:
					_box(root, pos + Vector3(0, FLOOR_H / 2.0, 0), Vector3(0.28, FLOOR_H, 2.0), cy)
		# interior walls: [x, z, len(cells), axis("x"|"z"), doorway_index]
		for seg in inner:
			var sx: float = float(seg[0]) * CELL; var sz: float = float(seg[1]) * CELL; var ln: int = int(seg[2]); var ax: String = String(seg[3]); var di: int = int(seg[4]) if seg.size() > 4 else -1
			for i in ln:
				var isdoor := i == di
				var pc2 := piece(KIT + ("wall-doorway-square.glb" if isdoor else "wall.glb"), style, "wall_in", 1.6)
				var p2 := Vector3(sx + (i * CELL + 1.0 if ax == "x" else 0.0), y0, sz + (i * CELL + 1.0 if ax == "z" else 0.0))
				var yw := PI / 2.0 if ax == "x" else 0.0
				pc2.position = p2; pc2.rotation.y = yw; pc2.scale = Vector3(2.0, 1, 1); root.add_child(pc2)
				var b2 := piece(KIT + "wall-low.glb", style, "wall_in", 1.6); b2.position = p2 + Vector3(0, 2.4, 0); b2.rotation.y = yw; b2.scale = Vector3(2.0, BAND_H / 1.2, 1); root.add_child(b2)
				var al := Vector3(1, 0, 0) if ax == "x" else Vector3(0, 0, 1)
				if isdoor:
					_box(root, p2 + al * -0.85 + Vector3(0, DOOR_H / 2.0, 0), Vector3(0.2, DOOR_H, 0.3), yw)
					_box(root, p2 + al * 0.85 + Vector3(0, DOOR_H / 2.0, 0), Vector3(0.2, DOOR_H, 0.3), yw)
					_box(root, p2 + Vector3(0, DOOR_H + (FLOOR_H - DOOR_H) / 2.0, 0), Vector3(0.2, FLOOR_H - DOOR_H, 2.0), yw)
					if f == 0:
						var zdi := Vector3(sin(yw), 0, cos(yw))
						var idoor := Door.new()
						idoor.setup(_mat(style, "door", 1.0), 1.0, DOOR_W, DOOR_H, int(spec.get("seed", 7)) + i + 2)
						idoor.position = p2 - zdi * (DOOR_W / 2.0); idoor.rotation.y = yw; root.add_child(idoor)
				else:
					_box(root, p2 + Vector3(0, FLOOR_H / 2.0, 0), Vector3(0.2, FLOOR_H, 2.0), yw)
		# interior stairs: a walkable box-step flight rising one floor along +Z (3-cell hole above)
		if stairs != null and f < floors - 1 and not open_hall:
			_stairs(root, Vector3(int(stairs[0]) * CELL + 1.0, y0, int(stairs[1]) * CELL + 0.2), 0.0, _mat(style, "stairs", 1.0), 3, 1.7)
	# roof
	var ytop := floors * FLOOR_H
	if roof == "gable" and w <= 3 and d <= 3:
		var gr := piece(MOD + "roof-gable.glb", STYLES["brick"], "roof", 1.2)   # tiled gable on every style
		gr.scale = Vector3(W / 1.09, 4.0, D / 1.0)
		gr.position = Vector3(W / 2.0, ytop, D / 2.0)
		root.add_child(gr)
		_box(root, Vector3(W / 2.0, ytop + 0.5, D / 2.0), Vector3(W, 1.0, D))
	else:
		for cx in w:
			for cz in d:
				var rp := piece(KIT + "floor.glb", style, "roof", 1.2)
				rp.position = Vector3(cx * CELL + 1.0, ytop, cz * CELL + 1.0)
				root.add_child(rp)
		_box(root, Vector3(W / 2.0, ytop + 0.05, D / 2.0), Vector3(W, 0.1, D))
		# parapet (low wall) around the roof edge
		for side in ["N", "S", "E", "W"]:
			var count := w if side in ["N", "S"] else d
			for i in count:
				var lw := piece(KIT + "wall-low.glb", style, "wall", 1.6)
				var pos: Vector3; var yaw: float
				match side:
					"N": pos = Vector3(i * CELL + 1.0, ytop, 0.0); yaw = PI / 2.0
					"S": pos = Vector3(i * CELL + 1.0, ytop, D); yaw = -PI / 2.0
					"E": pos = Vector3(W, ytop, i * CELL + 1.0); yaw = PI
					_: pos = Vector3(0.0, ytop, i * CELL + 1.0); yaw = 0.0
				lw.position = pos; lw.rotation.y = yaw; root.add_child(lw)
				_box(root, pos + Vector3(0, 0.5, 0), Vector3(0.12, 1.0, 2.0), yaw)
	# ---- dressing: what makes it read as a real lived-in building, not a box ----
	_rng.seed = int(spec.get("seed", 7)) * 7919 + w * 31 + d
	var wall_uv := 2.2
	for f in floors:
		var y0 := f * FLOOR_H
		for side in ["N", "S", "E", "W"]:
			var count := w if side in ["N", "S"] else d
			for i in count:
				var pos: Vector3; var yaw: float; var outn: Vector3
				match side:
					"N": pos = Vector3(i * CELL + 1.0, y0, 0.0); yaw = PI / 2.0; outn = Vector3(0, 0, -1)
					"S": pos = Vector3(i * CELL + 1.0, y0, D); yaw = -PI / 2.0; outn = Vector3(0, 0, 1)
					"E": pos = Vector3(W, y0, i * CELL + 1.0); yaw = PI; outn = Vector3(1, 0, 0)
					_: pos = Vector3(0.0, y0, i * CELL + 1.0); yaw = 0.0; outn = Vector3(-1, 0, 0)
				var has_door := f == 0 and doors.any(func(x): return x[0] == side and int(x[1]) == i)
				var has_win := windows.any(func(x): return x[0] == side and int(x[1]) == i and int(x[2]) == f)
				var r := _rng.randf()
				if has_win and r < 0.3:                                   # boarded-up window
					var bw := piece(KIT + "barricade-window-%s.glb" % ["a", "b", "c"][_rng.randi() % 3], style, "door", 0.6)
					bw.position = pos + outn * 0.14; bw.rotation.y = yaw; root.add_child(bw)
				elif has_win and r < 0.55 and f > 0:                       # AC unit under an upper window
					var ac := piece(MOD + "detail-ac-%s.glb" % ["a", "b"][_rng.randi() % 2], style, "trim", 1.0)
					ac.scale = Vector3(4, 4, 4); ac.position = pos + outn * 0.4 + Vector3(0, 0.55, 0); ac.rotation.y = yaw; root.add_child(ac)
				elif not has_win and not has_door and r < 0.28:           # rusty metal plating patch
					var pl := piece(KIT + ("plating-detailed.glb" if _rng.randf() < 0.5 else "plating-wide.glb"), style, "door", 1.0)
					pl.position = pos + outn * 0.14 + Vector3(0, _rng.randf_range(0.2, 0.9), 0); pl.rotation.y = yaw; root.add_child(pl)
				elif not has_win and not has_door and r < 0.40 and f == floors - 1:   # drain pipe
					var gp := piece(KIT + "gutter-vertical.glb", style, "trim", 1.0)
					gp.position = pos + outn * 0.16 + Vector3(0, 0, 0); gp.rotation.y = yaw; root.add_child(gp)
				if has_door and f == 0:                                   # sandbags beside the door
					var sb := prop("old_military_crate", 0.7) if _rng.randf() < 0.4 else null
					if sb:
						var along := Vector3(1, 0, 0) if side in ["N", "S"] else Vector3(0, 0, 1)
						sb.position = pos + outn * 0.9 + along * 0.9; sb.rotation.y = _rng.randf_range(0, TAU); root.add_child(sb)
						_box(root, sb.position + Vector3(0, 0.35, 0), Vector3(0.8, 0.7, 0.8))
	# roof: parapet trim + water tank / antenna / vents on flat roofs
	if roof != "gable":
		var yt := floors * FLOOR_H
		for side in ["N", "S", "E", "W"]:
			var count := w if side in ["N", "S"] else d
			for i in count:
				var bh := piece(KIT + "border-high.glb", style, "trim", 1.0)
				var pos: Vector3; var yaw: float
				match side:
					"N": pos = Vector3(i * CELL + 1.0, yt, -0.14); yaw = PI / 2.0
					"S": pos = Vector3(i * CELL + 1.0, yt, D + 0.14); yaw = -PI / 2.0
					"E": pos = Vector3(W + 0.14, yt, i * CELL + 1.0); yaw = PI
					_: pos = Vector3(-0.14, yt, i * CELL + 1.0); yaw = 0.0
				bh.position = pos; bh.rotation.y = yaw; root.add_child(bh)
		var tank := prop("propane_tank", 1.6) if _rng.randf() < 0.6 else prop("small_lpg_tank", 1.2)
		tank.position = Vector3(W - 1.4, yt + 0.12, 1.4); root.add_child(tank)
		_box(root, tank.position + Vector3(0, 0.8, 0), Vector3(1.2, 1.6, 1.2))
		# antenna mast
		var mast := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.03; cm.bottom_radius = 0.05; cm.height = 3.0; cm.material = _mat(style, "trim", 1.0)
		mast.mesh = cm; mast.position = Vector3(1.0, yt + 1.5, D - 1.0); root.add_child(mast)
		# exterior switchback fire-escape stairs: from the ground to the roof, outside the E wall.
		# Flights alternate direction each floor; a landing joins the top of one to the base of the next.
		if floors >= 2 and w >= 3 and spec.get("roof_stairs", true):
			var sm := _mat(style, "stairs", 1.0)
			var ex := W + 1.05                              # runs just outside the east wall
			var run_len := 1.6 * CELL - 0.4                 # 2.8 m of run per flight
			var za := 1.4                                   # near-corner z
			var zb := za + run_len                          # far end of a +Z flight
			for f in floors:
				var yy := f * FLOOR_H
				var even := (f % 2) == 0
				if even:
					_stairs(root, Vector3(ex, yy, za), 0.0, sm, 1.6, 1.4)
				else:
					_stairs(root, Vector3(ex, yy, zb), PI, sm, 1.6, 1.4)
				# landing slab at the TOP of this flight (floor f+1 level)
				var lz: float = zb if even else za
				var ly := yy + FLOOR_H - 0.06
				_box(root, Vector3(ex, ly, lz), Vector3(1.8, 0.12, 1.8), 0.0)
				var lm := MeshInstance3D.new(); var lb := BoxMesh.new(); lb.size = Vector3(1.8, 0.12, 1.8); lb.material = sm
				lm.mesh = lb; lm.position = Vector3(ex, ly, lz); root.add_child(lm)
				# outer guard rail along this flight so it reads as a fire escape
				var gr := MeshInstance3D.new(); var gb := BoxMesh.new(); gb.size = Vector3(0.08, 0.95, run_len); gb.material = sm
				gr.mesh = gb; gr.position = Vector3(ex + 0.75, yy + FLOOR_H / 2.0, (za + zb) / 2.0); root.add_child(gr)
			# short bridge from the top landing onto the roof deck
			var top_lz: float = zb if (floors % 2 == 1) else za
			_box(root, Vector3(W + 0.1, floors * FLOOR_H - 0.05, top_lz), Vector3(2.0, 0.12, 1.6), 0.0)
			var bm := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(2.0, 0.12, 1.6); bb.material = sm
			bm.mesh = bb; bm.position = Vector3(W + 0.1, floors * FLOOR_H - 0.05, top_lz); root.add_child(bm)
	# base trim (border) around the ground floor
	for side in ["N", "S", "E", "W"]:
		var count := w if side in ["N", "S"] else d
		for i in count:
			var bd := piece(KIT + "border.glb", style, "trim", 1.0)
			var pos: Vector3; var yaw: float
			match side:
				"N": pos = Vector3(i * CELL + 1.0, 0.0, -0.12); yaw = PI / 2.0
				"S": pos = Vector3(i * CELL + 1.0, 0.0, D + 0.12); yaw = -PI / 2.0
				"E": pos = Vector3(W + 0.12, 0.0, i * CELL + 1.0); yaw = PI
				_: pos = Vector3(-0.12, 0.0, i * CELL + 1.0); yaw = 0.0
			bd.position = pos; bd.rotation.y = yaw; root.add_child(bd)
	# a warm interior light per floor so rooms read as real spaces (not sky-blue caves)
	for f in floors:
		var li := OmniLight3D.new()
		li.light_color = Color(1.0, 0.92, 0.8)
		li.light_energy = 1.1
		li.omni_range = maxf(W, D) * 0.9
		li.omni_attenuation = 1.4
		li.shadow_enabled = false
		li.position = Vector3(W / 2.0, f * FLOOR_H + 2.6, D / 2.0)
		root.add_child(li)
	root.set_meta("size", Vector3(W, ytop, D))
	if merge_enabled:
		_merge_static(root)
	return root

## Merge every static MeshInstance3D under `root` (doors / lights / colliders excluded)
## into one mesh per material — a house drops from ~150 draw calls to ~8.
static func _merge_static(root: Node3D) -> void:
	var groups := {}           # material -> SurfaceTool
	var victims: Array = []
	var st: Array = [root]
	while not st.is_empty():
		var n: Node = st.pop_back()
		if n is Door:
			continue
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var mi := n as MeshInstance3D
			var xf: Transform3D = root.global_transform.affine_inverse() * mi.global_transform if root.is_inside_tree() else _rel_xf(root, mi)
			for si in mi.mesh.get_surface_count():
				var m := mi.get_active_material(si)
				if m == null:
					continue
				if not groups.has(m):
					var t := SurfaceTool.new()
					t.begin(Mesh.PRIMITIVE_TRIANGLES)
					groups[m] = t
				(groups[m] as SurfaceTool).append_from(mi.mesh, si, xf)
			victims.append(mi)
		for c in n.get_children():
			st.append(c)
	for mi in victims:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	for m in groups:
		var t: SurfaceTool = groups[m]
		var mesh := t.commit()
		var out := MeshInstance3D.new()
		out.mesh = mesh
		out.set_surface_override_material(0, m)
		out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(out)

## Transform of `n` relative to `root` when not in the tree (walk the parents).
static func _rel_xf(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
