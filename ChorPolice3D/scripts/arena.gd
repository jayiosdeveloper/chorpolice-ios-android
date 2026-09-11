## Arena — builds a 3D map from a Maps3D layout: sky + sun + fog, ground slabs (with
## pit walls), perimeter, crates / rock / walls / pillars, floating platforms, ramps,
## structures (bunker / tower / house), trees and scatter. Everything is primitive
## meshes with theme-tinted PBR materials, so it runs on any phone.
class_name Arena
extends Node3D

const DEATH_Y := -4.0
const WALL_H := 2.6

var layout: Dictionary
var theme: Dictionary
var sun: DirectionalLight3D
var _mats := {}
var _noise_tex: NoiseTexture2D
var _rng := RandomNumberGenerator.new()
var real := false
var _rs := {}
var _rt := {}
var _tree_scene: PackedScene
var _tree_h := 0.0
var _clutter: Array = []          # real ground props (fallen logs, stumps, shrubs)
var _tree_variants: Array = []
var _plants: Array = []
var _fence_scene: PackedScene
var _grass_scene: PackedScene
var _container_scene: PackedScene
var _window_scene: PackedScene
var _wall_lamp_scene: PackedScene
var nav_region: NavigationRegion3D
var nav_ready := false

func build(l: Dictionary) -> void:
	layout = l
	theme = l["theme"]
	_rng.seed = hash(String(l["name"]))
	_noise_tex = _make_noise()
	real = bool(l.get("real", false)) and RealTex.has_assets()
	_rs = l.get("real_surfaces", {})
	_rt = l.get("real_tints", {})
	if real and l.has("real_tree"):
		var tp: String = "res://assets/real/trees/%s/%s_1k.gltf" % [l["real_tree"], l["real_tree"]]
		if ResourceLoader.exists(tp):
			_tree_scene = load(tp)
	if real and l.has("real_trees"):
		for tv in l["real_trees"]:
			var nm: String = tv if tv is String else String(tv.get("model", ""))
			var h: float = 6.0 if tv is String else float(tv.get("h", 6.0))
			for pth in ["res://assets/real/trees/%s/%s_1k.gltf" % [nm, nm], "res://assets/real/models/%s/%s.glb" % [nm, nm], "res://assets/real/models/%s/%s_1k.gltf" % [nm, nm]]:
				if ResourceLoader.exists(pth):
					_tree_variants.append({"scene": load(pth), "h": h})
					break
	if real and l.has("real_plants"):
		for pv in l["real_plants"]:
			var pm: String = "res://assets/real/models/%s/%s.glb" % [pv["model"], pv["model"]]
			if ResourceLoader.exists(pm):
				_plants.append({"scene": load(pm), "h": float(pv.get("h", 0.7)), "n": int(pv.get("n", 40))})
	if real:
		if ResourceLoader.exists("res://assets/real/models/shipping_containers/shipping_containers.glb"):
			_container_scene = load("res://assets/real/models/shipping_containers/shipping_containers.glb")
		if ResourceLoader.exists("res://assets/real/models/rollershutter_window_01/rollershutter_window_01_1k.gltf"):
			_window_scene = load("res://assets/real/models/rollershutter_window_01/rollershutter_window_01_1k.gltf")
		if ResourceLoader.exists("res://assets/real/models/industrial_wall_lamp/industrial_wall_lamp_1k.gltf"):
			_wall_lamp_scene = load("res://assets/real/models/industrial_wall_lamp/industrial_wall_lamp_1k.gltf")
	if real and l.has("real_grass"):
		var gp: String = "res://assets/real/models/%s/%s_1k.gltf" % [l["real_grass"], l["real_grass"]]
		if ResourceLoader.exists(gp):
			_grass_scene = load(gp)
	if real and l.has("real_props"):
		for nm in l["real_props"]:
			var mp: String = "res://assets/real/models/%s/%s_1k.gltf" % [nm, nm]
			if not ResourceLoader.exists(mp):
				continue
			var e := {"scene": load(mp), "kind": "log", "smin": 0.9, "smax": 1.35, "collide": true, "weight": 2}
			var low: String = nm.to_lower()
			if low.contains("shrub"):
				e = {"scene": e["scene"], "kind": "bush", "smin": 0.9, "smax": 1.4, "collide": false, "weight": 3}
			elif low.contains("barrel"):
				e = {"scene": e["scene"], "kind": "barrel", "smin": 1.1, "smax": 1.5, "collide": true, "weight": 3}
			elif low.contains("ammo") or low.contains("crate"):
				e = {"scene": e["scene"], "kind": "box", "smin": 1.6, "smax": 2.6, "collide": true, "weight": 3}
			elif low.contains("boulder") or low.contains("rock_moss") or low.contains("rock_face") or low.contains("namaqualand"):
				e = {"scene": e["scene"], "kind": "boulder", "smin": 0.9, "smax": 1.6, "collide": true, "weight": 1}
			elif low.contains("fern") or low.contains("flower") or low.contains("weed") or low.contains("nettle") or low.contains("sorrel") or low.contains("rooibos") or low.contains("plant") or low.contains("moss"):
				e = {"scene": e["scene"], "kind": "bush", "smin": 0.8, "smax": 1.5, "collide": false, "weight": 4}
			elif low.contains("moon_rock") or low.contains("rock"):
				e = {"scene": e["scene"], "kind": "pebble", "smin": 1.0, "smax": 2.4, "collide": false, "weight": 2, "tint": Color(0.78, 0.74, 0.68)}
			elif low.contains("stump"):
				e = {"scene": e["scene"], "kind": "stump", "smin": 0.9, "smax": 1.3, "collide": true, "weight": 1}
			elif low.contains("fern") or low.contains("flower") or low.contains("weed") or low.contains("sorrel") or low.contains("banana") or low.contains("rooibos") or low.contains("roots"):
				e = {"scene": e["scene"], "kind": "bush", "smin": 0.9, "smax": 1.5, "collide": false, "weight": 4}
			elif low.contains("moss_set"):
				e = {"scene": e["scene"], "kind": "rock", "smin": 0.9, "smax": 1.5, "collide": true, "weight": 2}
			elif low.contains("bench") or low.contains("wine") or low.contains("planter") or low.contains("pot"):
				e = {"scene": e["scene"], "kind": "cover", "smin": 0.9, "smax": 1.2, "collide": true, "weight": 1}
			elif low.contains("fence"):
				_fence_scene = e["scene"]
				continue
			elif low.contains("lamp") or low.contains("light") or low.contains("ladder") or low.contains("tank") or low.contains("jerrycan") or low.contains("extinguisher") or low.contains("chest") or low.contains("pipe") or low.contains("duct") or low.contains("gutter") or low.contains("airduct"):
				e = {"scene": e["scene"], "kind": "gear", "smin": 0.9, "smax": 1.2, "collide": true, "weight": 2}
			_clutter.append(e)
	_build_environment()
	_build_grounds()
	_build_perimeter()
	for b in l["blocks"]:
		_block(b)
	for p in l["platforms"]:
		_platform(p)
	for r in l["ramps"]:
		_ramp(r)
	for s in l["structures"]:
		_structure(s)
	for pl in l.get("real_place", []):
		var mp := ""
		for ext in ["glb", "fbx", "gltf"]:
			var cand: String = "res://assets/real/models/%s/%s.%s" % [pl["model"], pl["model"], ext]
			if ResourceLoader.exists(cand):
				mp = cand; break
		if mp == "":
			push_warning("real_place: model not found: " + String(pl["model"]))
		else:
			_place_model(load(mp), pl["pos"], pl.get("yaw", 0.0), pl.get("len", 10.0), pl.get("collide", "box"), pl.get("scale", 0.0), pl.get("rot_x", 0.0), pl.get("sink", 0.0))
	for h in l.get("houses", []):
		_kit_house(h)
	for rd in l.get("roads", []):
		_road(rd)
	for t in l["trees"]:
		_tree(t)
	if bool(l.get("scatter", true)):
		_scatter()
	if not _plants.is_empty():
		_scatter_plants(l["size"])
	if _grass_scene:
		_grass_field(l["size"])
	if _fence_scene:
		_build_fence(l["size"])
	if bool(l.get("nav", false)):
		_bake_nav()

## Runtime navmesh over every static collider (roads, houses, doorways, containers) so
## bots can path through the town instead of walking into walls.
func _bake_nav() -> void:
	nav_region = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "navsource"
	add_to_group("navsource")
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.45
	nm.agent_height = 1.9
	nm.agent_max_climb = 0.55
	nm.agent_max_slope = 50.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.region_min_size = 4.0
	nm.edge_max_error = 1.5
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	nav_region.bake_finished.connect(func() -> void:
		nav_ready = true
		print("[nav] baked polys=", nm.get_polygon_count()))
	nav_region.bake_navigation_mesh(true)

## Enterable HouseKit house centred on `pos` (spec in 2 m cells).
func _kit_house(h: Dictionary) -> void:
	var n := HouseKit.build(h["spec"], String(h.get("style", "concrete")))
	var sz: Vector3 = n.get_meta("size", Vector3(6, 3, 6))
	var yaw: float = float(h.get("yaw", 0.0))
	n.rotation.y = yaw
	n.position = (h["pos"] as Vector3) - Vector3(sz.x / 2.0, 0, sz.z / 2.0).rotated(Vector3.UP, yaw)
	add_child(n)

## Flat asphalt strip between two points (visual only, sits just above the ground).
func _road(rd: Dictionary) -> void:
	var a: Vector3 = rd["from"]; var b: Vector3 = rd["to"]; var w: float = float(rd.get("w", 5.0))
	var len := a.distance_to(b)
	if len < 0.1:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(w, 0.06, len)
	bm.material = surf("road", "rock_dark", 3.0) if _rs.has("road") else mat(Color(0.2, 0.2, 0.2))
	mi.mesh = bm
	mi.position = (a + b) * 0.5 + Vector3(0, 0.03, 0)
	mi.look_at_from_position(mi.position, mi.position + (b - a).normalized(), Vector3.UP)
	add_child(mi)
	# edge lines
	for sgn in [-1.0, 1.0]:
		var ln := MeshInstance3D.new(); var lm := BoxMesh.new(); lm.size = Vector3(0.18, 0.02, len); lm.material = mat(Color(0.85, 0.82, 0.7), 0.9, false)
		ln.mesh = lm; ln.position = Vector3(sgn * (w / 2.0 - 0.3), 0.05, 0); mi.add_child(ln)


# MARK: island surroundings — beach, ocean, distant mountains, drifting clouds, birds

var _water_mat: ShaderMaterial
var _water_t := 0.0
var _w_off1 := Vector2.ZERO
var _w_off2 := Vector2.ZERO
var _cloud_mats: Array = []
var _birds: Array = []

func _build_island(sz: Vector2) -> void:
	var hw := sz.x / 2.0; var hd := sz.y / 2.0
	# beach skirt: ground slopes from the map edge down into the water (30 m wide)
	var skirt := 34.0
	var sand := RealTex.mat("ground_sand", 12.0, false) if RealTex.has_assets() else mat(Color(0.8, 0.72, 0.55))
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array = [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]
	var outer: Array = [Vector3(-hw - skirt, -3.0, -hd - skirt), Vector3(hw + skirt, -3.0, -hd - skirt), Vector3(hw + skirt, -3.0, hd + skirt), Vector3(-hw - skirt, -3.0, hd + skirt)]
	for i in 4:
		var a: Vector3 = ring[i]; var b: Vector3 = ring[(i + 1) % 4]; var c: Vector3 = outer[(i + 1) % 4]; var d: Vector3 = outer[i]
		for tri in [[a, b, c], [a, c, d]]:
			var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			if n.y < 0: n = -n
			for v in tri:
				st.set_normal(n); st.set_uv(Vector2(v.x, v.z) * 0.08); st.add_vertex(v)
	st.generate_tangents()
	var skm := MeshInstance3D.new(); skm.mesh = st.commit(); skm.material_override = sand; add_child(skm)
	var skb := StaticBody3D.new(); skb.collision_layer = 1
	var scs := CollisionShape3D.new(); scs.shape = skm.mesh.create_trimesh_shape(); skb.add_child(scs); add_child(skb)
	# ocean: big plane with two scrolling procedural normal layers (no download needed, CC0-free)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(2400, 2400); pm.subdivide_depth = 160; pm.subdivide_width = 160
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://assets/real/fx/ocean.gdshader")
	var nz := FastNoiseLite.new(); nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; nz.frequency = 0.02; nz.fractal_octaves = 3
	var nt := NoiseTexture2D.new(); nt.noise = nz; nt.as_normal_map = true; nt.bump_strength = 9.0; nt.seamless = true; nt.width = 256; nt.height = 256
	_water_mat.set_shader_parameter("nmap", nt)
	_water_mat.set_shader_parameter("half_w", hw); _water_mat.set_shader_parameter("half_d", hd)
	pm.material = _water_mat; water.mesh = pm; water.position = Vector3(0, -1.2, 0); add_child(water)
	# distant mountain range built from REAL Himalaya elevation data (AWS terrain tiles).
	_build_real_mountains(hw, hd)
	_build_clouds()
	_build_birds()

## A continuous mountain range wrapping the island, displaced by a real Himalayan heightmap
## (assets/real/terrain/himalaya_height.png — decoded from AWS terrarium tiles). Sampled as a
## polar ridge: distance from centre + height read from concentric bands of the map.
func _build_real_mountains(hw: float, hd: float) -> void:
	# a ring of REAL photogrammetry mountains (hero_mountain.glb, snow-capped) placed around
	# the island, sunk so their flat tile base hides below the horizon and only peaks show.
	# Each one gets a HeightMapShape3D built from the tile's own vertices, so you can land on
	# and climb the slopes but never pass through the rock.
	var mp := "res://assets/real/models/hero_mountain/hero_mountain.glb"
	if not ResourceLoader.exists(mp):
		return
	var scene: PackedScene = load(mp)
	var hm := _mountain_heightmap(scene)      # {n, min, size, data(PackedFloat32Array)}
	var rng := RandomNumberGenerator.new(); rng.seed = 771
	var n := 11
	for i in n:
		var ang := TAU * float(i) / float(n) + rng.randf_range(-0.12, 0.12)
		# leave the east side (open sea) mostly clear
		if cos(ang) > 0.45 and absf(sin(ang)) < 0.55:
			continue
		var S := rng.randf_range(520.0, 760.0)                 # tile is 1 m wide -> S metres
		# keep the tile's near edge at least ~200 m past the island: the tiles are S wide, so
		# the centre must sit S/2 + margin out (a fixed 440 m let ridges run over the town)
		var dist := S * 0.5 + 330.0 + rng.randf_range(0.0, 60.0)
		var yf := rng.randf_range(1.0, 1.45)                   # a bit taller than the flat tile
		var inst: Node3D = scene.instantiate()
		add_child(inst)
		inst.scale = Vector3(S, S * yf, S)
		inst.rotation.y = rng.randf_range(0.0, TAU)
		# place the tile's GEOMETRIC centre at `dist` (the model's origin is not at its centre)
		var centre := Vector3(cos(ang) * dist, -0.16 * S, sin(ang) * dist)  # sink the base underwater
		var off := Vector3.ZERO
		if not hm.is_empty():
			var mn0: Vector3 = hm["min"]; var sz0: Vector3 = hm["size"]
			off = Vector3((mn0.x + sz0.x * 0.5) * S, 0.0, (mn0.z + sz0.z * 0.5) * S).rotated(Vector3.UP, inst.rotation.y)
		inst.position = centre - off
		for c in _all_mesh_instances(inst):
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if hm.is_empty():
			continue
		var N: int = hm["n"]; var mn: Vector3 = hm["min"]; var sz: Vector3 = hm["size"]
		var k: float = S * sz.x / float(N - 1)                 # metres per heightmap cell
		var shape := HeightMapShape3D.new()
		shape.map_width = N; shape.map_depth = N
		var data: PackedFloat32Array = hm["data"].duplicate()
		var sy := S * yf / k
		for j in data.size():
			data[j] *= sy
		shape.map_data = data
		var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 0
		body.position = inst.position; body.rotation.y = inst.rotation.y
		var cs := CollisionShape3D.new(); cs.shape = shape
		cs.scale = Vector3(k, k, k)
		cs.position = Vector3((mn.x + sz.x * 0.5) * S, 0.0, (mn.z + sz.z * 0.5) * S)
		body.add_child(cs); add_child(body)

## Max-height grid (N x N) of a terrain-tile scene's vertices, in the tile's own units.
## Computed once per session (the mesh is shared by every instance).
static var _mtn_hm := {}
func _mountain_heightmap(scene: PackedScene) -> Dictionary:
	if not _mtn_hm.is_empty():
		return _mtn_hm
	var N := 129
	var tmp: Node3D = scene.instantiate()
	var mis := _all_mesh_instances(tmp)
	var mn := Vector3(1e9, 1e9, 1e9); var mx := -mn
	var verts: Array = []       # [PackedVector3Array, Transform3D]
	for mi in mis:
		if mi.mesh == null:
			continue
		var xf: Transform3D = _rel_transform(tmp, mi)
		for si in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(si)
			var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			verts.append([pv, xf])
			var ab: AABB = xf * mi.mesh.get_aabb()
			mn = Vector3(minf(mn.x, ab.position.x), minf(mn.y, ab.position.y), minf(mn.z, ab.position.z))
			mx = Vector3(maxf(mx.x, ab.end.x), maxf(mx.y, ab.end.y), maxf(mx.z, ab.end.z))
	tmp.queue_free()
	var sz := mx - mn
	if sz.x < 0.001 or sz.z < 0.001:
		return {}
	var data := PackedFloat32Array(); data.resize(N * N); data.fill(0.0)
	var have := PackedByteArray(); have.resize(N * N); have.fill(0)
	for e in verts:
		var pv: PackedVector3Array = e[0]; var xf: Transform3D = e[1]
		for v in pv:
			var p: Vector3 = xf * v
			var i := int(round((p.x - mn.x) / sz.x * float(N - 1)))
			var j := int(round((p.z - mn.z) / sz.z * float(N - 1)))
			i = clampi(i, 0, N - 1); j = clampi(j, 0, N - 1)
			var idx := j * N + i
			var h := p.y - mn.y
			if have[idx] == 0 or h > data[idx]:
				data[idx] = h; have[idx] = 1
	# fill any empty cells from a neighbour so there are no holes in the collider
	for j in N:
		for i in N:
			var idx := j * N + i
			if have[idx] == 0:
				var best := 0.0
				for dj in [-1, 0, 1]:
					for di in [-1, 0, 1]:
						var ii := clampi(i + di, 0, N - 1); var jj := clampi(j + dj, 0, N - 1)
						if have[jj * N + ii] == 1: best = maxf(best, data[jj * N + ii])
				data[idx] = best
	_mtn_hm = {"n": N, "min": mn, "size": sz, "data": data}
	return _mtn_hm

## Transform of `node` relative to `root` (both in the same detached scene).
func _rel_transform(root: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf

func _mountain_mesh(r: float, h: float, nz: FastNoiseLite, seed_: int) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 64; var rings := 16
	var pts: Array = []
	for ri in range(rings + 1):
		var t := float(ri) / float(rings)
		var row: Array = []
		for si in segs:
			var a := TAU * float(si) / float(segs)
			var wob: float = 1.0 + 0.3 * nz.get_noise_2d(float(seed_) + cos(a) * 3.0, sin(a) * 3.0 + t * 5.0) + 0.12 * nz.get_noise_2d(float(seed_) * 2.0 + cos(a) * 9.0, sin(a) * 9.0 + t * 11.0)
			var rr := r * (1.0 - t) * wob
			var yy := h * pow(t, 1.35) * (1.0 + 0.15 * nz.get_noise_2d(float(seed_) * 0.3 + a * 2.0, t * 7.0))
			row.append(Vector3(cos(a) * rr, yy, sin(a) * rr))
		pts.append(row)
	for ri in rings:
		for si in segs:
			var a: Vector3 = pts[ri][si]; var b: Vector3 = pts[ri][(si + 1) % segs]; var c: Vector3 = pts[ri + 1][(si + 1) % segs]; var d: Vector3 = pts[ri + 1][si]
			for tri in [[a, b, c], [a, c, d]]:
				for v in tri:
					st.set_uv(Vector2(v.x, v.z) * 0.02); st.add_vertex(v)
	st.index()
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

## Two big soft cloud layers high above the map, drifting at different speeds.
func _build_clouds() -> void:
	var ctex: Texture2D = load("res://assets/real/sky/clouds_real.png") if ResourceLoader.exists("res://assets/real/sky/clouds_real.png") else null
	for k in 2:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.cast_shadow = false
		if ctex:
			m.albedo_texture = ctex
			m.uv1_scale = Vector3(2.0 + k, 2.0 + k, 1)
			m.albedo_color = Color(1, 1, 1, 0.92 if k == 0 else 0.6)
		else:
			m.albedo_color = Color(1, 1, 1, 0.5)
		var q := PlaneMesh.new(); q.size = Vector2(2600, 2600); q.material = m
		var mi := MeshInstance3D.new(); mi.mesh = q; mi.position = Vector3(0, 300.0 + k * 55.0, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_cloud_mats.append([m, Vector3(0.0035, 0.0012, 0) * (1.0 if k == 0 else 1.8)])

## A few birds gliding on slow elliptical paths high over the map (random timing).
func _build_birds() -> void:
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 32:
		var t := absf(float(x) - 15.5) / 15.5
		var y := int(7.0 - 5.0 * (1.0 - t) * (1.0 - t))
		for dy in 2:
			img.set_pixel(x, clampi(y + dy, 0, 15), Color(0.05, 0.05, 0.06, 0.9))
	var tex := ImageTexture.create_from_image(img)
	var rng := RandomNumberGenerator.new(); rng.seed = 99
	for i in 9:
		var sp := Sprite3D.new(); sp.texture = tex; sp.pixel_size = 0.06; sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false; sp.double_sided = true
		add_child(sp)
		_birds.append({"n": sp, "c": Vector3(rng.randf_range(-80, 80), rng.randf_range(45, 90), rng.randf_range(-80, 80)), "rx": rng.randf_range(25, 70), "rz": rng.randf_range(18, 50), "sp": rng.randf_range(0.08, 0.16) * (1.0 if rng.randf() < 0.5 else -1.0), "ph": rng.randf_range(0, TAU), "flap": rng.randf_range(4.0, 7.0)})

func _process(delta: float) -> void:
	if _water_mat:
		_water_t += delta
		_w_off1 += Vector2(0.010, 0.006) * delta
		_w_off2 -= Vector2(0.007, 0.011) * delta
		_water_mat.set_shader_parameter("time_s", _water_t)
		_water_mat.set_shader_parameter("off1", _w_off1)
		_water_mat.set_shader_parameter("off2", _w_off2)
	for e in _cloud_mats:
		(e[0] as StandardMaterial3D).uv1_offset += e[1] * delta
	var t := Time.get_ticks_msec() / 1000.0
	for b in _birds:
		var a: float = b["ph"] + t * b["sp"]
		var p: Vector3 = b["c"] + Vector3(cos(a) * b["rx"], sin(t * 0.3 + b["ph"]) * 4.0, sin(a) * b["rz"])
		(b["n"] as Sprite3D).position = p
		(b["n"] as Sprite3D).scale = Vector3(1.0, 0.45 + 0.55 * absf(sin(t * b["flap"] + b["ph"])), 1.0)

# MARK: materials

func _make_noise() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.02
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.72, 0.72, 0.72), Color(1.0, 1.0, 1.0)])
	t.color_ramp = g
	return t

func mat(col: Color, rough := 0.9, textured := true, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%s|%.2f" % [col.to_html(), rough, textured, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if textured:
		m.albedo_texture = _noise_tex
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.35, 0.35, 0.35)
	_mats[key] = m
	return m

func _c(key: String, fallback := Color(0.5, 0.5, 0.5)) -> Color:
	return theme.get(key, fallback)

## A real PBR material for logical surface `surface` (when the map is "real" and a folder
## is mapped for it), otherwise the themed noise material tinted with `fallback_key`.
func surf(surface: String, fallback_key: String, uv := 2.0, tint := Color.WHITE, rough := 0.9) -> Material:
	if real and _rs.has(surface):
		var t: Color = tint if tint != Color.WHITE else _rt.get(surface, Color.WHITE)
		return RealTex.mat(_rs[surface], uv, true, t)
	return mat(_c(fallback_key), rough)

func crate_color() -> Color:
	return Color(0.58, 0.42, 0.24) if not bool(theme.get("slippery", false)) else Color(0.55, 0.62, 0.70)

# MARK: environment

func _build_environment() -> void:
	var sky_cols: Array = theme.get("sky", [Color(0.1, 0.1, 0.2), Color(0.3, 0.3, 0.5), Color(0.7, 0.6, 0.5)])
	var top: Color = sky_cols[0]
	var mid: Color = sky_cols[1]
	var hor: Color = sky_cols[2]

	if real and layout.has("real_sky"):
		var hdr := RealTex.sky(layout["real_sky"])
		if hdr:
			_build_hdri_env(hdr, hor, mid)
			return

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = top.lightened(0.15)
	sky_mat.sky_horizon_color = hor
	sky_mat.sky_curve = 0.18
	sky_mat.ground_horizon_color = hor.darkened(0.25)
	sky_mat.ground_bottom_color = top.darkened(0.4)
	sky_mat.sun_angle_max = 22.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = mid.lerp(hor, 0.6)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.15
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 32, 0)
	sun.light_color = hor.lerp(Color.WHITE, 0.65)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.5
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, -150, 0)
	fill.light_color = top.lerp(Color.WHITE, 0.5)
	fill.light_energy = 0.35
	add_child(fill)

## Realistic environment driven by a captured sky (HDRI): image-based lighting + sun + fog.
func _build_hdri_env(hdr: Texture2D, hor: Color, mid: Color) -> void:
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = hdr
	pano.energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = pano
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.tonemap_white = 2.4
	env.ambient_light_energy = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.3
	env.ssao_enabled = false
	env.fog_enabled = true
	env.fog_light_color = mid.lerp(hor, 0.6)
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.04
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.03
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 40, 0)
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.light_energy = 1.35
	sun.light_angular_distance = 1.5
	sun.shadow_blur = 2.5
	sun.shadow_opacity = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.5
	add_child(sun)

## Weather particles the game parents to its camera ("snow" / "embers" / "none").
func make_weather(kind: String) -> CPUParticles3D:
	if kind != "snow" and kind != "embers":
		return null
	var p := CPUParticles3D.new()
	p.amount = 260 if kind == "snow" else 110
	p.lifetime = 6.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(22, 9, 22)
	p.direction = Vector3(0, -1, 0) if kind == "snow" else Vector3(0, 1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, -1.2, 0) if kind == "snow" else Vector3(0, 0.4, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var m := SphereMesh.new()
	m.radius = 0.05 if kind == "snow" else 0.035
	m.height = m.radius * 2.0
	m.radial_segments = 5
	m.rings = 3
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if kind == "snow":
		mm.albedo_color = Color(1, 1, 1, 0.9)
	else:
		mm.albedo_color = Color(1.0, 0.55, 0.15)
		mm.emission_enabled = true
		mm.emission = Color(1.0, 0.4, 0.1)
		mm.emission_energy_multiplier = 2.5
	m.material = mm
	p.mesh = m
	p.position = Vector3(0, 6, 0)
	return p

# MARK: geometry helpers

func _static_box(pos: Vector3, size: Vector3, m: Material, yaw := 0.0, pitch := 0.0, visible := true, shadow := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation = Vector3(pitch, yaw, 0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	if visible:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		bm.material = m
		mi.mesh = bm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mi)
	add_child(body)
	return body

func _visual(mesh: Mesh, pos: Vector3, m: Material, parent: Node = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	(parent if parent else self).add_child(mi)
	return mi

func _cyl(top_r: float, bottom_r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	return c

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 7
	return s

# MARK: ground / perimeter

func _build_grounds() -> void:
	var grass: Material
	if real and _rs.has("ground"):
		grass = RealTex.mat(_rs["ground"], 9.0, false, _rt.get("ground", Color.WHITE))
	else:
		grass = surf("ground", "grass", 5.0)
	var rock_dark := surf("rock", "rock_dark", 4.0, Color(0.7, 0.7, 0.7))
	for r in layout["grounds"]:
		var rect: Rect2 = r
		var c := rect.get_center()
		_static_box(Vector3(c.x, -0.5, c.y), Vector3(rect.size.x, 1.0, rect.size.y), grass, 0, 0, true, false)
		# pit walls: a dark skirt under every slab (only visible where slabs don't touch)
		_visual(_box_mesh(Vector3(rect.size.x, 8.0, rect.size.y)), Vector3(c.x, -5.0, c.y), rock_dark)
	# abyss floor far below (visual only) so pits read as deep, not as void
	var sz: Vector2 = layout["size"]
	_visual(_box_mesh(Vector3(sz.x + 40, 1.0, sz.y + 40)), Vector3(0, -14, 0), mat(_c("hill", Color(0.15, 0.13, 0.15)), 1.0, false))

func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _build_perimeter() -> void:
	var sz: Vector2 = layout["size"]
	var hw := sz.x / 2.0
	var hd := sz.y / 2.0
	var rock := surf("rock", "rock", 3.0)
	var edge := mat(_c("rock_edge", Color(0.3, 0.25, 0.2)))
	var island: bool = bool(layout.get("island", false))
	if island:
		_build_island(sz)
		var we := get_node_or_null("WorldEnvironment")
		for c in get_children():
			if c is WorldEnvironment and (c as WorldEnvironment).environment:
				var en := (c as WorldEnvironment).environment
				en.fog_density = 0.00035
				en.fog_light_color = Color(0.7, 0.8, 0.9)
				en.fog_aerial_perspective = 0.25
				en.fog_sky_affect = 0.0
				# coastal sky: blue overhead, pale horizon, sea-coloured ground half (drives reflections)
				var skm2 := en.sky.sky_material if en.sky else null
				if skm2 is ProceduralSkyMaterial:
					var ps := skm2 as ProceduralSkyMaterial
					ps.sky_top_color = Color(0.2, 0.42, 0.78)
					ps.sky_horizon_color = Color(0.68, 0.8, 0.92)
					ps.sky_curve = 0.12
					ps.ground_horizon_color = Color(0.18, 0.34, 0.48)
					ps.ground_bottom_color = Color(0.04, 0.1, 0.18)
	# low visible walls
	if not island:
		_static_box(Vector3(0, WALL_H / 2.0, -hd - 0.5), Vector3(sz.x + 2.0, WALL_H, 1.0), rock)
	if not island:
		_static_box(Vector3(0, WALL_H / 2.0, hd + 0.5), Vector3(sz.x + 2.0, WALL_H, 1.0), rock)
	if not island:
		_static_box(Vector3(-hw - 0.5, WALL_H / 2.0, 0), Vector3(1.0, WALL_H, sz.y + 2.0), rock)
	if not island:
		_static_box(Vector3(hw + 0.5, WALL_H / 2.0, 0), Vector3(1.0, WALL_H, sz.y + 2.0), rock)
	# cap trim
	if not island:
		_visual(_box_mesh(Vector3(sz.x + 2.4, 0.3, 1.4)), Vector3(0, WALL_H + 0.15, -hd - 0.5), edge)
	if not island:
		_visual(_box_mesh(Vector3(sz.x + 2.4, 0.3, 1.4)), Vector3(0, WALL_H + 0.15, hd + 0.5), edge)
	if not island:
		_visual(_box_mesh(Vector3(1.4, 0.3, sz.y + 2.4)), Vector3(-hw - 0.5, WALL_H + 0.15, 0), edge)
	if not island:
		_visual(_box_mesh(Vector3(1.4, 0.3, sz.y + 2.4)), Vector3(hw + 0.5, WALL_H + 0.15, 0), edge)
	# invisible tall fence so jetpacks can't leave the arena
	var fh := 40.0
	_static_box(Vector3(0, fh / 2.0, -hd - 0.5), Vector3(sz.x + 2.0, fh, 1.0), null, 0, 0, false)
	_static_box(Vector3(0, fh / 2.0, hd + 0.5), Vector3(sz.x + 2.0, fh, 1.0), null, 0, 0, false)
	_static_box(Vector3(-hw - 0.5, fh / 2.0, 0), Vector3(1.0, fh, sz.y + 2.0), null, 0, 0, false)
	_static_box(Vector3(hw + 0.5, fh / 2.0, 0), Vector3(1.0, fh, sz.y + 2.0), null, 0, 0, false)
	# distant hills ring (visual) — skip when a real HDRI sky provides the horizon
	if real and layout.has("real_sky"):
		return
	var hill := mat(_c("hill", Color(0.2, 0.18, 0.2)), 1.0, false)
	for i in 14:
		var a := float(i) / 14.0 * TAU
		var rr := maxf(hw, hd) + 28.0 + _rng.randf_range(-4, 6)
		var s := _sphere(1.0)
		var hmi := _visual(s, Vector3(cos(a) * rr, -4.0, sin(a) * rr), hill)
		hmi.scale = Vector3(_rng.randf_range(16, 26), _rng.randf_range(9, 15), _rng.randf_range(16, 26))
		hmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# MARK: blocks / platforms / ramps

func _block(b: Dictionary) -> void:
	var pos: Vector3 = b["pos"]
	var size: Vector3 = b["size"]
	match String(b.get("kind", "crate")):
		"wall":
			_static_box(pos, size, surf("wall", "rock", 3.0))
			_visual(_box_mesh(Vector3(size.x + 0.2, 0.2, size.z + 0.2)), pos + Vector3(0, size.y / 2.0 + 0.1, 0), mat(_c("rock_edge")))
			if real and size.y >= 3.0:
				_wall_windows(pos, size)
		"rock":
			var body := _static_box(pos, size * Vector3(0.9, 0.9, 0.9), null, 0, 0, false)
			var s := _visual(_sphere(1.0), Vector3.ZERO, surf("rock", "rock", 2.0), body)
			s.scale = size * 0.6
			s.rotation = Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(0, TAU), _rng.randf_range(-0.2, 0.2))
			var s2 := _visual(_sphere(1.0), Vector3(size.x * 0.25, -size.y * 0.15, size.z * 0.2), surf("rock", "rock_dark", 1.6, Color(0.75, 0.75, 0.75)), body)
			s2.scale = size * 0.42
		"container":
			var pal := [Color(0.72, 0.4, 0.16), Color(0.2, 0.42, 0.55), Color(0.35, 0.5, 0.3), Color(0.66, 0.58, 0.2)]
			var col: Color = pal[int(abs(pos.x * 0.7 + pos.z * 3.0)) % pal.size()]
			var cbody := _static_box(pos, size, (RealTex.mat(_rs.get("metal", "metal_rusted"), 2.2, true, col.lerp(Color(0.8,0.8,0.8), 0.5)) if real and _rs.has("metal") else mat(col, 0.78, false, 0.2)))
			var rib := mat(col.darkened(0.22), 0.78, false, 0.2)
			var n := maxi(2, int(size.z / 0.55))
			for i in n + 1:
				_visual(_box_mesh(Vector3(size.x + 0.04, size.y * 0.92, 0.05)), Vector3(0, 0, -size.z / 2.0 + i * (size.z / n)), rib, cbody)
			_visual(_box_mesh(Vector3(0.05, size.y * 0.92, size.z + 0.04)), Vector3(size.x / 2.0, 0, 0), rib, cbody)
			_visual(_box_mesh(Vector3(0.05, size.y * 0.92, size.z + 0.04)), Vector3(-size.x / 2.0, 0, 0), rib, cbody)
			_visual(_box_mesh(Vector3(size.x + 0.1, 0.12, size.z + 0.1)), Vector3(0, size.y / 2.0, 0), rib, cbody)
			if real and _container_scene:
				cbody.get_parent().remove_child(cbody)
				cbody.queue_free()
			elif real:
				_dress_container(pos, size)
		"barrier":
			var bmat := surf("sandbag", "rock", 1.0)
			var body2 := _static_box(pos, Vector3(size.x, size.y, size.z * 0.5), bmat, 0, 0, false)
			_visual(_box_mesh(Vector3(size.x, size.y * 0.5, size.z)), Vector3(0, -size.y * 0.15, 0), bmat, body2)
			_visual(_box_mesh(Vector3(size.x, size.y * 0.7, size.z * 0.35)), Vector3(0, size.y * 0.1, 0), bmat, body2)
			_visual(_box_mesh(Vector3(size.x, 0.08, size.z * 0.3)), Vector3(0, size.y * 0.48, 0), mat(Color(0.9, 0.7, 0.15), 0.8), body2)
		"metal":
			_static_box(pos, size, mat(Color(0.3, 0.32, 0.36), 0.4, false, 0.7))
		"ice":
			var im := StandardMaterial3D.new()
			im.albedo_color = Color(0.78, 0.9, 1.0, 0.85)
			im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			im.roughness = 0.08
			im.metallic = 0.1
			_static_box(pos, size, im, 0, 0, true, false)
		"water":
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.15, 0.42, 0.62, 0.75)
			wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wm.roughness = 0.05
			wm.metallic = 0.3
			var wv := _visual(_box_mesh(size), pos, wm)
			wv.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"pillar":
			var body := _static_box(pos, size, null, 0, 0, false)
			var m := mat(Color(0.75, 0.88, 0.98), 0.15, false, 0.1)
			_visual(_cyl(size.x * 0.42, size.x * 0.55, size.y), Vector3.ZERO, m, body)
			_visual(_cyl(size.x * 0.2, size.x * 0.42, size.y * 0.35), Vector3(0, size.y * 0.5 + size.y * 0.17, 0), m, body)
		_:
			var body := _static_box(pos, size, surf("wood", "crate", 1.0) if real and _rs.has("wood") else mat(crate_color(), 0.85))
			var edge := mat(crate_color().darkened(0.35), 0.9, false)
			var e := 0.08
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					_visual(_box_mesh(Vector3(size.x + e, e * 1.5, e * 1.5)), Vector3(0, sy * size.y / 2.0, sx * size.z / 2.0), edge, body)
					_visual(_box_mesh(Vector3(e * 1.5, e * 1.5, size.z + e)), Vector3(sx * size.x / 2.0, sy * size.y / 2.0, 0), edge, body)
					_visual(_box_mesh(Vector3(e * 1.5, size.y + e, e * 1.5)), Vector3(sx * size.x / 2.0, 0, sy * size.z / 2.0), edge, body)

## Recessed dark windows + a concrete lintel band on a large wall face (both long sides).
## Places a thin panel model (door/window) flat on a wall, facing outward `dir`,
## scaled to target width x height, sitting so its base is at world y = base_y.
func _place_panel(scene: PackedScene, at: Vector3, dir: Vector3, tw: float, th: float, base_y := -1.0) -> void:
	var inst := scene.instantiate()
	var raw := _inst_aabb(inst)
	var sx: float = tw / maxf(raw.size.x, 0.05)
	var sy: float = th / maxf(raw.size.y, 0.05)
	inst.scale = Vector3(sx, sy, maxf(sx, sy))
	inst.rotation.y = atan2(dir.x, dir.z)
	var y := at.y
	if base_y >= 0.0:
		y = base_y + th / 2.0
	inst.position = Vector3(at.x, y, at.z) + dir * 0.06
	for mi in _all_mesh_instances(inst):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)

func _wall_lamp(at: Vector3, dir: Vector3) -> void:
	if not _wall_lamp_scene:
		return
	var inst := _wall_lamp_scene.instantiate()
	inst.rotation.y = atan2(dir.x, dir.z)
	inst.position = at + dir * 0.06
	add_child(inst)
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.85, 0.6)
	lt.light_energy = 2.0
	lt.omni_range = 6.0
	lt.shadow_enabled = false
	lt.position = at + dir * 0.4
	add_child(lt)

## A real shipping container: corrugated body (already built) + roller door on one end
## + eight corner castings.
func _dress_container(pos: Vector3, size: Vector3) -> void:
	# corner castings (dark steel blocks at all 8 corners)
	var cast := mat(Color(0.15, 0.16, 0.17), 0.5, false, 0.7)
	var e := 0.18
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				_visual(_box_mesh(Vector3(e, e, e)), pos + Vector3(sx * (size.x / 2.0 - e * 0.3), sy * (size.y / 2.0 - e * 0.3), sz * (size.z / 2.0 - e * 0.3)), cast)
	# top rails (edge frame)
	var rail := mat(Color(0.2, 0.21, 0.22), 0.6, false, 0.5)
	for sy: float in [-1.0, 1.0]:
		_visual(_box_mesh(Vector3(size.x + 0.02, 0.12, 0.12)), pos + Vector3(0, sy * size.y / 2.0, size.z / 2.0), rail)
		_visual(_box_mesh(Vector3(size.x + 0.02, 0.12, 0.12)), pos + Vector3(0, sy * size.y / 2.0, -size.z / 2.0), rail)
		_visual(_box_mesh(Vector3(0.12, 0.12, size.z + 0.02)), pos + Vector3(size.x / 2.0, sy * size.y / 2.0, 0), rail)
		_visual(_box_mesh(Vector3(0.12, 0.12, size.z + 0.02)), pos + Vector3(-size.x / 2.0, sy * size.y / 2.0, 0), rail)
	# cargo doors on one END (the short face): two leaves + locking rods + handles
	var long_x := size.x >= size.z
	var dir := Vector3(1, 0, 0) if long_x else Vector3(0, 0, 1)
	var side := Vector3(0, 0, 1) if long_x else Vector3(1, 0, 0)     # across the door face
	var face_w: float = (size.z if long_x else size.x)
	var face_c := pos + dir * ((size.x if long_x else size.z) / 2.0 + 0.03)
	face_c.y = pos.y
	var door_mat := mat(Color(0.20, 0.34, 0.24).lerp(Color(0.3,0.3,0.3), 0.3), 0.7, false, 0.2)   # weathered steel-green
	var rod := mat(Color(0.5, 0.5, 0.52), 0.4, false, 0.7)
	# two door leaves
	for lf: float in [-1.0, 1.0]:
		var leaf := _box_mesh(Vector3(face_w * 0.48, size.y * 0.92, 0.06)) if not long_x else _box_mesh(Vector3(0.06, size.y * 0.92, face_w * 0.48))
		var lc := face_c + side * (lf * face_w * 0.24)
		_visual(leaf, lc, door_mat)
		# 2 vertical locking rods per leaf
		for r: float in [-1.0, 1.0]:
			var rmesh := _box_mesh(Vector3(0.05, size.y * 0.86, 0.05))
			var rc := lc + side * (r * face_w * 0.16) + dir * 0.05
			_visual(rmesh, rc, rod)
			# handle
			_visual(_box_mesh(Vector3(0.18, 0.06, 0.06)), rc + Vector3(0, 0, 0) + dir * 0.02 + Vector3(0, -0.1, 0), rod)

func _wall_windows(pos: Vector3, size: Vector3) -> void:
	# real building windows + a roller door at the base centre (when models are available)
	if _window_scene:
		var long_x := size.x >= size.z
		var span: float = (size.x if long_x else size.z)
		var n := clampi(int(span / 4.0), 1, 4)
		for sgn: float in [-1.0, 1.0]:
			var dir := Vector3(0, 0, sgn) if long_x else Vector3(sgn, 0, 0)
			var face_off: float = (size.z if long_x else size.x) / 2.0
			for i in n:
				var f := (float(i) + 0.5) / float(n) - 0.5
				var at: Vector3
				if long_x:
					at = Vector3(pos.x + f * span * 0.8, 0, pos.z + sgn * face_off)
				else:
					at = Vector3(pos.x + sgn * face_off, 0, pos.z + f * span * 0.8)
				_place_panel(_window_scene, at, dir, minf(span / float(n) * 0.7, 2.2), minf(size.y * 0.4, 1.8), pos.y + size.y * 0.2)
			_wall_lamp(Vector3(pos.x + (span * 0.4 if long_x else sgn * face_off), pos.y + size.y * 0.42, pos.z + (sgn * face_off if long_x else span * 0.4)), dir)
		return

func _plat_top() -> Material:
	if real and layout.has("real_platform"):
		return RealTex.mat(layout["real_platform"], 2.0, false, Color(0.6, 0.61, 0.64))
	return surf("ground", "grass", 4.0)

func _plat_body() -> Material:
	if real and layout.has("real_platform"):
		return RealTex.mat(layout["real_platform"], 2.0, true, Color(0.45, 0.46, 0.5))
	return surf("wall", "rock_edge", 3.0)

func _platform(p: Dictionary) -> void:
	var pos: Vector3 = p["pos"]
	var size: Vector2 = p["size"]
	var th := 0.4
	var body := _static_box(Vector3(pos.x, pos.y - th / 2.0, pos.z), Vector3(size.x, th, size.y), _plat_body())
	_visual(_box_mesh(Vector3(size.x + 0.15, 0.12, size.y + 0.15)), Vector3(0, th / 2.0 + 0.02, 0), _plat_top(), body)
	# support legs down to the ground (visual)
	var leg := mat(_c("rock_dark"), 0.9, false)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var lx := pos.x + sx * (size.x / 2.0 - 0.35)
			var lz := pos.z + sz * (size.y / 2.0 - 0.35)
			if _ground_under(Vector2(lx, lz)):
				_visual(_cyl(0.16, 0.22, pos.y), Vector3(lx, pos.y / 2.0, lz), leg)

func _ground_under(p: Vector2) -> bool:
	for r in layout["grounds"]:
		if (r as Rect2).has_point(p):
			return true
	return false

func _ramp(r: Dictionary) -> void:
	var pos: Vector3 = r["pos"]
	var size: Vector3 = r["size"]      # w, h, len
	var yaw: float = r["yaw"]
	var slope_len := sqrt(size.z * size.z + size.y * size.y)
	var pitch := atan2(size.y, size.z)
	var body := _static_box(pos + Vector3(0, size.y / 2.0, 0), Vector3(size.x, 0.3, slope_len), _plat_body(), yaw, pitch)
	body.position += Vector3(0, -0.15, 0)
	_visual(_box_mesh(Vector3(size.x + 0.1, 0.06, slope_len)), Vector3(0, 0.17, 0), _plat_top(), body)
	# side rails
	var rail := mat(_c("rock"), 0.9, false)
	for sx: float in [-1.0, 1.0]:
		_visual(_box_mesh(Vector3(0.12, 0.5, slope_len)), Vector3(sx * (size.x / 2.0 + 0.06), 0.3, 0), rail, body)

# MARK: structures

func _structure(s: Dictionary) -> void:
	var pos: Vector3 = s["pos"]
	var yaw: float = s.get("yaw", 0.0)
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	match String(s["kind"]):
		"bunker": _bunker(root)
		"tower": _tower(root)
		"silo": _silo(root)
		"barn": _barn(root)
		_: _house(root)

func _part(root: Node3D, pos: Vector3, size: Vector3, m: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = m
	mi.mesh = bm
	body.add_child(mi)
	root.add_child(body)

func _bunker(root: Node3D) -> void:
	var wall := surf("concrete", "rock", 3.0)
	var dark := surf("concrete", "rock_dark", 2.0, Color(0.7, 0.7, 0.7))
	_part(root, Vector3(0, 1.3, 2.4), Vector3(6.4, 2.6, 0.6), wall)           # back wall
	_part(root, Vector3(-3.0, 1.3, 0.4), Vector3(0.6, 2.6, 4.6), wall)         # sides
	_part(root, Vector3(3.0, 1.3, 0.4), Vector3(0.6, 2.6, 4.6), wall)
	_part(root, Vector3(-1.9, 0.5, -1.7), Vector3(1.8, 1.0, 0.5), dark)        # front sandbag stubs
	_part(root, Vector3(1.9, 0.5, -1.7), Vector3(1.8, 1.0, 0.5), dark)
	_part(root, Vector3(0, 2.8, 0.3), Vector3(7.2, 0.4, 5.6), dark)            # roof (walkable)
	_visual(_box_mesh(Vector3(0.6, 0.6, 0.6)), Vector3(2.4, 3.3, 1.6), mat(crate_color()), root)
	# firing slit (dark recessed band) across the back wall
	var slit := StandardMaterial3D.new()
	slit.albedo_color = Color(0.03, 0.04, 0.05)
	_visual(_box_mesh(Vector3(4.6, 0.5, 0.12)), Vector3(0, 1.7, 2.71), slit, root)
	_visual(_box_mesh(Vector3(4.8, 0.16, 0.16)), Vector3(0, 2.0, 2.72), dark, root)
	_visual(_box_mesh(Vector3(4.8, 0.16, 0.16)), Vector3(0, 1.4, 2.72), dark, root)

func _tower(root: Node3D) -> void:
	var h := 5.2
	var leg := surf("metal", "rock_dark", 2.0) if real and _rs.has("metal") else mat(_c("rock_dark"), 0.9, false)
	var deck := surf("wood", "rock_edge", 1.2) if real and _rs.has("wood") else mat(_c("rock_edge"))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_part(root, Vector3(sx * 1.4, h / 2.0, sz * 1.4), Vector3(0.4, h, 0.4), leg)
	_part(root, Vector3(0, h + 0.2, 0), Vector3(3.8, 0.4, 3.8), deck)
	_part(root, Vector3(0, 2.6, 0), Vector3(3.2, 0.3, 3.2), deck)             # mid landing
	_part(root, Vector3(-2.4, 1.2, 0), Vector3(1.4, 0.3, 1.4), deck)          # step-up crates
	_part(root, Vector3(-3.0, 0.5, 1.6), Vector3(1.0, 1.0, 1.0), mat(crate_color()))
	# railing
	for sx: float in [-1.0, 1.0]:
		_visual(_box_mesh(Vector3(0.1, 0.9, 3.8)), Vector3(sx * 1.9, h + 0.85, 0), leg, root)
		_visual(_box_mesh(Vector3(3.8, 0.9, 0.1)), Vector3(0, h + 0.85, sx * 1.9), leg, root)
	# roof canopy
	_visual(_box_mesh(Vector3(4.4, 0.2, 4.4)), Vector3(0, h + 3.2, 0), mat(_c("rock_dark")), root)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_visual(_box_mesh(Vector3(0.15, 2.0, 0.15)), Vector3(sx * 1.9, h + 2.2, sz * 1.9), leg, root)

func _house(root: Node3D) -> void:
	var wall_col := Color(0.86, 0.80, 0.68) if not bool(theme.get("slippery", false)) else Color(0.80, 0.86, 0.92)
	var wall := mat(wall_col, 0.85)
	var roof_col := Color(0.55, 0.22, 0.18)
	_part(root, Vector3(0, 1.5, 0), Vector3(6.0, 3.0, 5.0), wall)
	# roof (prism, convex collider) — players can climb onto it with the jetpack
	var prism := PrismMesh.new()
	prism.size = Vector3(6.8, 2.0, 5.8)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = Vector3(0, 4.0, 0)
	var cs := CollisionShape3D.new()
	cs.shape = prism.create_convex_shape()
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = prism
	mi.material_override = mat(roof_col, 0.8)
	body.add_child(mi)
	root.add_child(body)
	# windows (flat quads on the front face, z = -2.5) — no door leaf, the opening stays open
	var win := StandardMaterial3D.new()
	win.albedo_color = Color(0.95, 0.85, 0.55)
	win.emission_enabled = true
	win.emission = Color(1.0, 0.8, 0.45)
	win.emission_energy_multiplier = 1.4
	for sx: float in [-1.0, 1.0]:
		_visual(_box_mesh(Vector3(0.9, 0.9, 0.08)), Vector3(sx * 1.9, 1.8, -2.52), win, root)
		_visual(_box_mesh(Vector3(0.08, 0.9, 0.9)), Vector3(sx * 3.02, 1.8, 0.8), win, root)
	# chimney
	_visual(_box_mesh(Vector3(0.6, 1.4, 0.6)), Vector3(1.8, 4.6, 0.8), mat(_c("rock_dark")), root)

func _silo(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.2
	cyl.height = 9.0
	cs.shape = cyl
	cs.position = Vector3(0, 4.5, 0)
	body.add_child(cs)
	root.add_child(body)
	var m := mat(Color(0.78, 0.78, 0.8), 0.45, false, 0.6)
	_visual(_cyl(2.2, 2.2, 9.0), Vector3(0, 4.5, 0), m, body)
	for i in 5:
		_visual(_cyl(2.28, 2.28, 0.12), Vector3(0, 1.0 + i * 1.8, 0), mat(Color(0.5, 0.5, 0.52), 0.5, false, 0.6), body)
	_visual(_cyl(0.0, 2.4, 1.6), Vector3(0, 9.8, 0), mat(Color(0.55, 0.22, 0.18), 0.8), body)
	_visual(_box_mesh(Vector3(0.3, 8.0, 0.3)), Vector3(2.4, 4.0, 0), mat(Color(0.4, 0.4, 0.42), 0.5, false, 0.6), body)

func _barn(root: Node3D) -> void:
	var red := mat(Color(0.6, 0.18, 0.14), 0.85)
	var trim := mat(Color(0.92, 0.9, 0.85), 0.8, false)
	_part(root, Vector3(0, 2.0, 0), Vector3(9.0, 4.0, 7.0), red)
	var prism := PrismMesh.new()
	prism.size = Vector3(10.0, 2.6, 7.8)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = Vector3(0, 5.3, 0)
	var cs := CollisionShape3D.new()
	cs.shape = prism.create_convex_shape()
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = prism
	mi.material_override = mat(Color(0.35, 0.3, 0.28), 0.85)
	body.add_child(mi)
	root.add_child(body)
	_visual(_box_mesh(Vector3(0.2, 3.4, 0.12)), Vector3(-1.4, 1.7, -3.56), trim, root)
	_visual(_box_mesh(Vector3(0.2, 3.4, 0.12)), Vector3(1.4, 1.7, -3.56), trim, root)
	_visual(_box_mesh(Vector3(3.0, 0.2, 0.12)), Vector3(0, 3.3, -3.56), trim, root)
	_visual(_box_mesh(Vector3(9.2, 0.2, 7.2)), Vector3(0, 4.05, 0), trim, root)
	for sx: float in [-1.0, 1.0]:
		_visual(_box_mesh(Vector3(0.1, 0.8, 0.8)), Vector3(sx * 4.52, 2.6, 1.5), trim, root)
		_visual(_box_mesh(Vector3(0.1, 0.8, 0.8)), Vector3(sx * 4.52, 2.6, -1.5), trim, root)
	# hay bales beside it
	for i in 3:
		_part(root, Vector3(6.2, 0.45, -2.0 + i * 1.6), Vector3(1.2, 0.9, 1.2), mat(Color(0.82, 0.68, 0.3), 0.95))

# MARK: trees + scatter

func _tree(p: Vector3) -> void:
	if not _tree_variants.is_empty():
		_real_tree_variant(p)
		return
	if _tree_scene:
		_real_tree(p, _tree_scene)
		return
	var snowy := bool(theme.get("slippery", false))
	var trunk := mat(Color(0.36, 0.25, 0.15), 0.95)
	var leaf_col: Color = _c("grass", Color(0.3, 0.5, 0.2)).darkened(0.15)
	if snowy:
		leaf_col = Color(0.20, 0.42, 0.30)
	var leaf := mat(leaf_col, 0.95)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = p
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 2.6
	cs.shape = cyl
	cs.position = Vector3(0, 1.3, 0)
	body.add_child(cs)
	add_child(body)
	var h := _rng.randf_range(2.0, 2.8)
	_visual(_cyl(0.2, 0.3, h), Vector3(0, h / 2.0, 0), trunk, body)
	if snowy:
		var c1 := _visual(_cyl(0.0, 1.5, 2.6), Vector3(0, h + 0.9, 0), leaf, body)
		var c2 := _visual(_cyl(0.0, 1.1, 2.2), Vector3(0, h + 2.3, 0), leaf, body)
		var snow := mat(Color(0.95, 0.97, 1.0), 0.9)
		_visual(_cyl(0.0, 1.55, 0.35), Vector3(0, h - 0.2, 0), snow, body)
		c1.rotation.y = _rng.randf_range(0, TAU)
		c2.rotation.y = _rng.randf_range(0, TAU)
	else:
		var s := _visual(_sphere(1.0), Vector3(0, h + 1.0, 0), leaf, body)
		s.scale = Vector3(1.9, 1.5, 1.9) * _rng.randf_range(0.85, 1.15)
		var s2 := _visual(_sphere(1.0), Vector3(0.6, h + 1.7, 0.3), mat(leaf_col.lightened(0.12), 0.95), body)
		s2.scale = Vector3(1.2, 1.0, 1.2)

## Scatters real ground props (logs, stumps, shrubs) across the arena grounds.
func _pick_prop() -> Dictionary:
	var total := 0
	for e in _clutter:
		total += int(e.get("weight", 1))
	var r := _rng.randi() % maxi(total, 1)
	for e in _clutter:
		r -= int(e.get("weight", 1))
		if r < 0:
			return e
	return _clutter[0]

func _place_prop(e: Dictionary, at: Vector3, yaw := -1.0) -> void:
	var inst := (e["scene"] as PackedScene).instantiate()
	if e.get("kind", "") == "bush":
		_fix_foliage(inst, Color(0.85, 0.9, 0.65))
	var scl: float = _rng.randf_range(e["smin"], e["smax"])
	inst.scale = Vector3(scl, scl * _rng.randf_range(0.95, 1.08), scl)
	inst.rotation.y = yaw if yaw >= 0.0 else _rng.randf_range(0.0, TAU)
	inst.position = at
	if e.has("tint"):
		for mi in _all_mesh_instances(inst):
			var mm: Material = mi.get_active_material(0)
			if mm is StandardMaterial3D:
				var d := (mm as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.albedo_color = e["tint"]
				mi.material_override = d
	for mi in _all_mesh_instances(inst):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(inst)
	if e.get("collide", false):
		var aabb := _inst_aabb(inst)
		if aabb.size.y > 0.3:
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.position = at
			var cs := CollisionShape3D.new()
			if e["kind"] == "barrel":
				var cyl := CylinderShape3D.new()
				cyl.radius = maxf(aabb.size.x, aabb.size.z) * 0.5
				cyl.height = maxf(aabb.size.y, 0.4)
				cs.shape = cyl
				cs.position = Vector3(0, aabb.size.y / 2.0, 0)
			elif e.get("kind", "") in ["box", "crate"]:
				var bs := BoxShape3D.new()
				bs.size = Vector3(aabb.size.x, aabb.size.y, aabb.size.z)
				cs.shape = bs
				cs.position = Vector3(0, aabb.size.y / 2.0, 0)
			else:
				# rocks / boulders / stumps: hull that follows the actual shape, so you can walk
				# right up to it instead of hitting an invisible box
				var pts := PackedVector3Array()
				var xf_inv: Transform3D = inst.global_transform.affine_inverse() if inst.is_inside_tree() else Transform3D.IDENTITY
				for mi2 in _all_mesh_instances(inst):
					if mi2.mesh:
						var rel: Transform3D = xf_inv * mi2.global_transform if mi2.is_inside_tree() else mi2.transform
						for si in mi2.mesh.get_surface_count():
							var arr: Array = mi2.mesh.surface_get_arrays(si)
							if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
								var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
								var step: int = maxi(1, verts.size() / 400)
								for vi in range(0, verts.size(), step):
									pts.append((rel * verts[vi]) * inst.scale)
				if pts.size() >= 8:
					var hull := ConvexPolygonShape3D.new()
					hull.points = pts
					cs.shape = hull
					cs.rotation.y = inst.rotation.y
				else:
					var bs := BoxShape3D.new()
					bs.size = Vector3(aabb.size.x, aabb.size.y, aabb.size.z)
					cs.shape = bs
					cs.position = Vector3(0, aabb.size.y / 2.0, 0)
			body.add_child(cs)
			add_child(body)

## Lines a chainlink fence just inside the arena perimeter (visual border, no collision —
## the invisible wall already blocks movement).
func _build_fence(sz: Vector2) -> void:
	var hw := sz.x / 2.0 - 1.2
	var hd := sz.y / 2.0 - 1.2
	var seg := _fence_aabb()
	var step: float = maxf(seg.x, 1.5)
	var edges := [[Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd)], [Vector3(-hw, 0, hd), Vector3(hw, 0, hd)],
		[Vector3(-hw, 0, -hd), Vector3(-hw, 0, hd)], [Vector3(hw, 0, -hd), Vector3(hw, 0, hd)]]
	for e in edges:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var length := a.distance_to(b)
		var n := int(length / step)
		var yaw := atan2((b - a).x, (b - a).z)
		for i in n:
			var pos: Vector3 = a.lerp(b, (float(i) + 0.5) / float(n))
			if not _ground_under(Vector2(pos.x, pos.z)):
				continue
			var inst := _fence_scene.instantiate()
			var s := step / maxf(seg.x, 0.1)
			inst.scale = Vector3(s * 1.02, _rng.randf_range(0.95, 1.1), 1.0)
			inst.rotation.y = yaw
			inst.position = pos
			for mi in _all_mesh_instances(inst):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(inst)

func _fence_aabb() -> Vector3:
	var inst := _fence_scene.instantiate()
	var a := _inst_aabb(inst)
	inst.free()
	return a.size

## A dense MultiMesh grass field (thousands of real grass clumps) across the grounds —
## the biggest single "lush meadow" win, drawn in one call so it stays mobile-friendly.
func _grass_field(sz: Vector2) -> void:
	var src := _grass_scene.instantiate()
	var best: MeshInstance3D = null
	var best_tris := 0
	for mi in _all_mesh_instances(src):
		var t := 0
		if mi.mesh:
			for si in mi.mesh.get_surface_count():
				var arr: Array = mi.mesh.surface_get_arrays(si)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				t += (idx.size() / 3) if idx else 0
		if t > best_tris:
			best_tris = t; best = mi
	if not best or not best.mesh:
		src.free()
		return
	var clump_mesh: Mesh = best.mesh
	var clump_mat := best.get_active_material(0)
	src.free()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = clump_mesh
	var count := clampi(int(sz.x * sz.y * 1.7), 500, 4000)
	mm.instance_count = count
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 4:
		tries += 1
		var x := _rng.randf_range(-sz.x / 2.0 + 1.0, sz.x / 2.0 - 1.0)
		var z := _rng.randf_range(-sz.y / 2.0 + 1.0, sz.y / 2.0 - 1.0)
		if not _ground_under(Vector2(x, z)):
			continue
		var sc := _rng.randf_range(1.3, 2.6)
		var b := Basis().rotated(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(sc, sc * _rng.randf_range(1.0, 1.6), sc))
		mm.set_instance_transform(placed, Transform3D(b, Vector3(x, 0.0, z)))
		placed += 1
	mm.instance_count = placed
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if clump_mat:
		mmi.material_override = clump_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 8.0
	add_child(mmi)

func _scatter_real(sz: Vector2) -> void:
	var count := int(sz.x * sz.y / 70.0)
	for i in count:
		var x := _rng.randf_range(-sz.x / 2.0 + 2.0, sz.x / 2.0 - 2.0)
		var z := _rng.randf_range(-sz.y / 2.0 + 2.0, sz.y / 2.0 - 2.0)
		if not _ground_under(Vector2(x, z)) or Vector2(x, z).length() < 6.0:
			continue
		var e := _pick_prop()
		# barrels & boxes like to cluster in 2-3 for that "supply dump" look
		var n := 1
		if e["kind"] in ["barrel", "box"] and _rng.randf() < 0.5:
			n = 2 + _rng.randi() % 2
		for k in n:
			var off := Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6)) if k > 0 else Vector3.ZERO
			if _ground_under(Vector2(x + off.x, z + off.z)):
				_place_prop(e, Vector3(x + off.x, 0, z + off.z))

func _inst_aabb(inst: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in _all_mesh_instances(inst):
		var a: AABB = m.transform * m.get_aabb()
		if first: out = a; first = false
		else: out = out.merge(a)
	out.size *= (inst as Node3D).scale
	return out

## Places a shared real GLTF tree: random yaw + slight scale, trunk collision, ground shadow.
## Places a downloaded real GLB: auto-fixes Z-up models, scales so its longest horizontal
## side = target_len, sits it on the ground at (pos, yaw), and adds a collider.
func _place_model(scene: PackedScene, pos: Vector3, yaw: float, target_len: float, collide := "box", scale_override := 0.0, rot_x := 0.0, sink := 0.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	add_child(holder)
	var inst := scene.instantiate()
	holder.add_child(inst)
	if rot_x != 0.0:
		inst.rotation.x = rot_x
	var raw := _model_aabb(inst)
	var horiz: float = maxf(raw.size.x, raw.size.z)
	var scl: float = scale_override if scale_override > 0.0 else target_len / maxf(horiz, 0.01)
	inst.scale = Vector3(scl, scl, scl)
	raw = _model_aabb(inst)
	# centre on x/z and sit the lowest point on the ground (y = 0)
	inst.position -= Vector3(raw.position.x + raw.size.x / 2.0, raw.position.y + sink, raw.position.z + raw.size.z / 2.0)
	for mi in _all_mesh_instances(inst):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var fin := _model_aabb(inst)
	if collide == "trimesh":
		for mi in _all_mesh_instances(inst):
			mi.create_trimesh_collision()
			var sb: Node = mi.get_child(mi.get_child_count() - 1)
			if sb is StaticBody3D:
				(sb as StaticBody3D).collision_layer = 1
	else:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		holder.add_child(body)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(fin.size.x, fin.size.y, fin.size.z)
		cs.shape = bs
		cs.position = Vector3(fin.position.x + fin.size.x / 2.0, fin.position.y + fin.size.y / 2.0, fin.position.z + fin.size.z / 2.0)
		body.add_child(cs)

func _model_aabb(inst: Node) -> AABB:
	var out := AABB(); var first := true
	for m in _all_mesh_instances(inst):
		var a: AABB = m.transform * m.get_aabb()
		var pnode: Node = m.get_parent()
		while pnode and pnode != inst:
			a = (pnode as Node3D).transform * a
			pnode = pnode.get_parent()
		a = (inst as Node3D).transform * a
		if first: out = a; first = false
		else: out = out.merge(a)
	return out

static var _foliage_shader: Shader

static func _get_foliage_shader() -> Shader:
	if _foliage_shader:
		return _foliage_shader
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, unshaded;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float cutoff = 0.4;
uniform float black_key = 0.16;
void fragment() {
	vec4 c = texture(albedo_tex, UV);
	float lum = (c.r + c.g + c.b) / 3.0;
	if (c.a < cutoff || lum < black_key) { discard; }
	vec3 col = c.rgb * tint.rgb;
	ALBEDO = max(col, vec3(0.30, 0.34, 0.16));
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
"""
	_foliage_shader = sh
	return sh

## Fix imported foliage: black-background + alpha cards are keyed out by a shader,
## double-sided, and lifted toward the ground colour so grass blends in.
func _fix_foliage(inst: Node, tint: Color, key_black := true) -> void:
	if key_black:
		_fix_foliage_walk(inst, tint)
		return
	_fix_foliage_std(inst, tint)

## Applies the foliage shader to MeshInstance3D AND MultiMeshInstance3D (instanced grass packs).
func _fix_foliage_walk(n: Node, tint: Color) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(si)
			mi.set_surface_override_material(si, _foliage_mat_for(m, tint))
	elif n is MultiMeshInstance3D:
		var mmi := n as MultiMeshInstance3D
		var src: Material = mmi.material_override
		if src == null and mmi.multimesh and mmi.multimesh.mesh and mmi.multimesh.mesh.get_surface_count() > 0:
			src = mmi.multimesh.mesh.surface_get_material(0)
		mmi.material_override = _foliage_mat_for(src, tint)
	for c in n.get_children():
		_fix_foliage_walk(c, tint)

func _foliage_mat_for(m: Material, tint: Color) -> Material:
	var sm := ShaderMaterial.new()
	sm.shader = _get_foliage_shader()
	if m is StandardMaterial3D and (m as StandardMaterial3D).albedo_texture:
		sm.set_shader_parameter("albedo_tex", (m as StandardMaterial3D).albedo_texture)
	sm.set_shader_parameter("tint", tint)
	return sm

func _fix_foliage_std(inst: Node, tint: Color) -> void:
	for mi in _all_mesh_instances(inst):
		if not mi.mesh:
			continue
		for si in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(si)
			if m is StandardMaterial3D:
				var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				if d.albedo_texture:
					d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					d.alpha_scissor_threshold = 0.4
				d.cull_mode = BaseMaterial3D.CULL_DISABLED
				d.albedo_color = d.albedo_color * tint
				d.roughness = 0.9
				d.metallic_specular = 0.15
				mi.set_surface_override_material(si, d)

## Dense real grass / plants: each entry placed n times, scaled to height h, no collision.
func _scatter_plants(sz: Vector2) -> void:
	# grass grows in a dozen thick patches (looks natural), keeping the centre battlefield clean
	var centers: Array = []
	var tries := 0
	while centers.size() < 12 and tries < 200:
		tries += 1
		var cx := _rng.randf_range(-sz.x / 2.0 + 6.0, sz.x / 2.0 - 6.0)
		var cz := _rng.randf_range(-sz.y / 2.0 + 6.0, sz.y / 2.0 - 6.0)
		if Vector2(cx, cz).length() < 14.0 or not _ground_under(Vector2(cx, cz)):
			continue
		var ok := true
		for c in centers:
			if Vector2(cx, cz).distance_to(c) < 9.0:
				ok = false
				break
		if ok:
			centers.append(Vector2(cx, cz))
	if centers.is_empty():
		return
	for e in _plants:
		var scene: PackedScene = e["scene"]
		var probe := scene.instantiate()
		var raw := _model_aabb(probe)
		var zup: bool = raw.size.z > raw.size.y * 1.5 and raw.size.z > raw.size.x
		probe.free()
		for i in int(e["n"]):
			var c: Vector2 = centers[_rng.randi() % centers.size()]
			var ang := _rng.randf_range(0.0, TAU)
			var rad := absf(_rng.randfn(0.0, 1.6))
			var x: float = c.x + cos(ang) * rad
			var z: float = c.y + sin(ang) * rad
			if not _ground_under(Vector2(x, z)):
				continue
			var inst := scene.instantiate()
			if zup:
				inst.rotation.x = -PI / 2.0
			var aa := _model_aabb(inst)
			var target: float = float(e["h"]) * _rng.randf_range(0.75, 1.3)
			var scl: float = target / maxf(aa.size.y, 0.05)
			inst.scale = Vector3(scl, scl, scl)
			inst.rotation.y = _rng.randf_range(0.0, TAU)
			aa = _model_aabb(inst)
			inst.position = Vector3(x, -aa.position.y, z)
			_fix_foliage(inst, layout.get("real_plant_tint", Color(0.82, 0.85, 0.62)))
			for mi in _all_mesh_instances(inst):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(inst)

func _real_tree_variant(p: Vector3) -> void:
	var v: Dictionary = _tree_variants[_rng.randi() % _tree_variants.size()]
	var inst := (v["scene"] as PackedScene).instantiate()
	var raw := _model_aabb(inst)
	var target: float = float(v["h"]) * _rng.randf_range(0.85, 1.15)
	var scl: float = target / maxf(raw.size.y, 0.1)
	inst.scale = Vector3(scl, scl, scl)
	inst.rotation.y = _rng.randf_range(0.0, TAU)
	raw = _model_aabb(inst)
	inst.position = p - Vector3(0, raw.position.y, 0)
	_fix_foliage(inst, Color(1.05, 1.08, 1.0), false)
	for mi in _all_mesh_instances(inst):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(inst)
	var fin := _model_aabb(inst)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = p
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = clampf(minf(fin.size.x, fin.size.z) * 0.12, 0.35, 1.0)
	cyl.height = target
	cs.shape = cyl
	cs.position = Vector3(0, target / 2.0, 0)
	body.add_child(cs)
	add_child(body)

func _real_tree(p: Vector3, scene: PackedScene = null) -> void:
	if not _tree_variants.is_empty():
		_real_tree_variant(p)
		return
	var inst := (scene if scene else _tree_scene).instantiate()
	# normalise every tree to a real height (~4.5-6.5 m) regardless of the model's native size
	var raw := _inst_aabb(inst)
	var native_h: float = maxf(raw.size.y, 0.5)
	var target := _rng.randf_range(4.5, 6.5)
	var scl := target / native_h
	inst.scale = Vector3(scl, scl * _rng.randf_range(0.95, 1.08), scl)
	inst.rotation.y = _rng.randf_range(0.0, TAU)
	inst.position = p
	for mi in _all_mesh_instances(inst):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(inst)
	# solid trunk collider sized from the model footprint, full height (no walking through)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = p
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = clampf(minf(raw.size.x, raw.size.z) * scl * 0.22, 0.45, 1.1)
	cyl.height = target
	cs.shape = cyl
	cs.position = Vector3(0, target / 2.0, 0)
	body.add_child(cs)
	add_child(body)

func _all_mesh_instances(n: Node, out := []) -> Array:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_all_mesh_instances(c, out)
	return out

func _scatter() -> void:
	var sz: Vector2 = layout["size"]
	if not _clutter.is_empty():
		_scatter_real(sz)
		return
	var rock := mat(_c("rock"), 0.95)
	var snowy := bool(theme.get("slippery", false))
	var count := int(sz.x * sz.y / 120.0)
	for i in count:
		var x := _rng.randf_range(-sz.x / 2.0 + 1.5, sz.x / 2.0 - 1.5)
		var z := _rng.randf_range(-sz.y / 2.0 + 1.5, sz.y / 2.0 - 1.5)
		if not _ground_under(Vector2(x, z)) or Vector2(x, z).length() < 5.0:
			continue
		if i % 3 == 0:
			var s := _visual(_sphere(1.0), Vector3(x, 0.0, z), rock)
			s.scale = Vector3(_rng.randf_range(0.3, 0.8), _rng.randf_range(0.2, 0.45), _rng.randf_range(0.3, 0.8))
		else:
			var tuft_col: Color = Color(0.9, 0.95, 1.0) if snowy else _c("grass").lightened(0.2)
			var t := _visual(_cyl(0.0, 0.13, 0.26), Vector3(x, 0.1, z), mat(tuft_col.darkened(0.15), 0.95, false))
			t.rotation = Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3))
			t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
