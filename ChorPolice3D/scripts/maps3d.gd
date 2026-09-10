## Maps3D — six large, hand-designed arenas (metres, +Y up, centred on the origin). Each
## has its own theme *and* its own layout idea:
##   1 Outpost      — desert military base: container compound, watchtowers, helipad, sandbags
##   2 High Tower   — vertical: a 4-tier tower on an island ringed by a pit, 4 bridges, outer ring
##   3 Subdivision  — suburban town: two rows of houses, main street with cars, plaza, alleys
##   4 Ice Box      — frozen: slippery lake, ice pillars, igloo bunkers, pine forest, containers
##   5 Crossfire    — canyon: two raised fortresses across a chasm, 3 bridges (low/low/high)
##   6 Green Hills  — meadow: mounds (hills), farm (house + barn + silo), pond, stone walls, forest
## Names/themes (sky, rock, grass colours, weather) come from Maps (maps.gd).
## Layout keys: size, grounds [Rect2], blocks [{pos,size,kind}], platforms [{pos,size}],
## ramps [{pos,size,yaw}], structures [{pos,kind,yaw}], trees [Vector3], spawns, pickups, bases.
class_name Maps3D
extends RefCounted

static func get_layout(index: int) -> Dictionary:
	var i: int = Maps.ORDER[((index % Maps.ORDER.size()) + Maps.ORDER.size()) % Maps.ORDER.size()]
	var l: Dictionary
	match i:
		0: l = _outpost()
		1: l = _high_tower()
		2: l = _subdivision()
		3: l = _ice_box()
		4: l = _crossfire()
		_: l = _green_hills()
	var m := Maps.get_map(i)
	l["name"] = m["name"]
	l["theme"] = m["theme"]
	return l

static func _b(x: float, y: float, z: float, w: float, h: float, d: float, kind := "crate") -> Dictionary:
	return {"pos": Vector3(x, y + h / 2.0, z), "size": Vector3(w, h, d), "kind": kind}

static func _p(x: float, y: float, z: float, w: float, d: float) -> Dictionary:
	return {"pos": Vector3(x, y, z), "size": Vector2(w, d)}

static func _r(x: float, y: float, z: float, w: float, h: float, len: float, yaw: float) -> Dictionary:
	return {"pos": Vector3(x, y, z), "size": Vector3(w, h, len), "yaw": yaw}

static func _s(x: float, y: float, z: float, kind: String, yaw := 0.0) -> Dictionary:
	return {"pos": Vector3(x, y, z), "kind": kind, "yaw": yaw}

static func _v(x: float, z: float, y := 0.0) -> Vector3:
	return Vector3(x, y, z)

## A hill mound: platform top with four ramps.
static func _mound(x: float, z: float, top: float, w: float, out: Dictionary) -> void:
	out["platforms"].append(_p(x, top, z, w, w))
	var len := top * 2.4
	out["ramps"].append(_r(x, 0, z + w / 2.0 + len / 2.0 - 0.3, w * 0.8, top, len, 0.0))
	out["ramps"].append(_r(x, 0, z - w / 2.0 - len / 2.0 + 0.3, w * 0.8, top, len, PI))
	out["ramps"].append(_r(x + w / 2.0 + len / 2.0 - 0.3, 0, z, w * 0.8, top, len, -PI / 2.0))
	out["ramps"].append(_r(x - w / 2.0 - len / 2.0 + 0.3, 0, z, w * 0.8, top, len, PI / 2.0))

## Row of trees along a line.
static func _treeline(out: Array, from: Vector3, to: Vector3, n: int, jitter := 1.2) -> void:
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1))
		var p := from.lerp(to, t)
		var j := sin(float(i) * 12.9898) * jitter
		out.append(Vector3(p.x + j, 0, p.z + cos(float(i) * 7.3) * jitter))

# MARK: 1 — Outpost (96 x 72): desert military base

static func _outpost() -> Dictionary:
	var l := {
		"size": Vector2(96, 72),
		"grounds": [Rect2(-48, -36, 96, 72)],
		"blocks": [], "platforms": [], "ramps": [], "structures": [], "trees": [],
		"spawns": [], "pickups": [], "bases": [Vector3(-42, 0, 0), Vector3(42, 0, 0)],
		"real": true, "real_sky": "day_clear", "real_tree": "quiver_tree_01",
		"real_trees": [
			{"model": "maple_tree", "h": 6.5}, {"model": "maple_tree", "h": 5.5},
			{"model": "realistic_hd_bamboo_palm_930", "h": 4.5},
			{"model": "realistic_hd_cabbage_tree_950", "h": 4.0},
			{"model": "realistic_hd_royal_poinciana_1940", "h": 7.0},
		],
		"real_props": ["dead_tree_trunk", "dead_tree_trunk_02", "tree_stump_02", "shrub_02", "shrub_04",
			"Barrel_01", "Barrel_02", "barrel_03", "ammo_box", "old_military_crate", "wooden_crate_01",
			"plastic_crate_02", "metal_jerrycan_green", "plastic_jerrycan", "propane_tank",
			"moon_rock_02", "moon_rock_04", "moon_rock_06"],
		"real_surfaces": {"ground": "desert_sand", "rock": "rock", "wall": "concrete",
			"concrete": "concrete", "metal": "metal_rusted", "wood": "wood_planks",
			"sandbag": "sandbag_fabric", "brick": "brick", "roof": "roof_tiles"},
		"real_place": [
			{"model": "brick_home", "pos": Vector3(-34, 0, 20), "yaw": 0.5, "len": 15.0, "collide": "trimesh"},
			{"model": "container_home", "pos": Vector3(34, 0, -20), "yaw": -2.2, "len": 17.0, "collide": "trimesh", "sink": 2.6},
			{"model": "brick_home", "pos": Vector3(2, 0, -28), "yaw": 0.1, "len": 14.0, "collide": "trimesh"},
			{"model": "shipping_containers", "pos": Vector3(-10, 0, -9), "yaw": 0.0, "scale": 0.7, "collide": "trimesh"},
			{"model": "shipping_containers", "pos": Vector3(11, 0, 9), "yaw": PI, "scale": 0.7, "collide": "trimesh"},
			{"model": "shipping_containers", "pos": Vector3(14, 0, -8), "yaw": 1.57, "scale": 0.7, "collide": "trimesh"},
			{"model": "shipping_containers", "pos": Vector3(-28, 0, -22), "yaw": 0.4, "scale": 0.75, "collide": "trimesh"},
			{"model": "shipping_containers", "pos": Vector3(30, 0, 22), "yaw": -2.0, "scale": 0.75, "collide": "trimesh"},
		],
	}
	var b: Array = l["blocks"]
	# central container compound (courtyard 20 x 16) — walls made of containers, two stacked corners
	for i in 3:
		b.append(_b(-12 + i * 12, 0, -10, 6.0, 2.6, 2.4, "container"))
		b.append(_b(-12 + i * 12, 0, 10, 6.0, 2.6, 2.4, "container"))
	b.append(_b(-16, 0, 0, 2.4, 2.6, 6.0, "container"))
	b.append(_b(16, 0, 0, 2.4, 2.6, 6.0, "container"))
	b.append(_b(-12, 2.6, -10, 6.0, 2.6, 2.4, "container"))     # stacked corners
	b.append(_b(12, 2.6, 10, 6.0, 2.6, 2.4, "container"))
	# sandbag nests inside + centre crates
	b.append(_b(0, 0, 0, 2.4, 1.0, 2.4, "barrier"))
	b.append(_b(-6, 0, 4, 3.0, 1.0, 1.0, "barrier"))
	b.append(_b(6, 0, -4, 3.0, 1.0, 1.0, "barrier"))
	b.append(_b(-4, 0, -4, 1.4, 1.4, 1.4))
	b.append(_b(4, 0, 4, 1.4, 1.4, 1.4))
	# flanking crate yards
	for i in 4:
		b.append(_b(-34 + (i % 2) * 3, 0, -22 + int(i / 2) * 3, 2.2, 2.2, 2.2))
		b.append(_b(34 - (i % 2) * 3, 0, 22 - int(i / 2) * 3, 2.2, 2.2, 2.2))
	b.append(_b(-31, 2.2, -19, 1.6, 1.6, 1.6))
	b.append(_b(31, 2.2, 19, 1.6, 1.6, 1.6))
	# jersey barrier lines on the approach roads
	for i in 4:
		b.append(_b(-26 + i * 4, 0, -30, 3.2, 1.0, 0.8, "barrier"))
		b.append(_b(26 - i * 4, 0, 30, 3.2, 1.0, 0.8, "barrier"))
	# fuel tanks + generator (metal)
	b.append(_b(-38, 0, 24, 3.0, 2.4, 3.0, "metal"))
	b.append(_b(-34, 0, 24, 3.0, 2.4, 3.0, "metal"))
	b.append(_b(38, 0, -24, 4.0, 1.6, 2.0, "metal"))
	# perimeter boulders
	b.append(_b(-40, 0, -30, 4, 2.6, 4, "rock"))
	b.append(_b(40, 0, 30, 4, 2.6, 4, "rock"))
	b.append(_b(0, 0, -32, 5, 2.2, 3, "rock"))
	b.append(_b(0, 0, 32, 5, 2.2, 3, "rock"))
	# helipad (raised deck) + a sniper deck over the compound
	l["platforms"] = [_p(-30, 1.0, 12, 12, 12), _p(0, 5.6, 0, 8, 6), _p(30, 3.0, -12, 6, 6)]
	l["ramps"] = [_r(-30, 0, 20.5, 4, 1.0, 5, 0.0), _r(-16, 2.6, -3.5, 2.2, 3.0, 7.0, PI), _r(30, 0, -4.5, 3, 3.0, 8, 0.0)]
	l["structures"] = [_s(-42, 0, -26, "tower"), _s(42, 0, 26, "tower"), _s(-42, 0, 26, "tower"), _s(42, 0, -26, "tower"),
		_s(-30, 0, -8, "bunker", PI / 2), _s(30, 0, 8, "bunker", -PI / 2), _s(20, 0, -28, "bunker", 0.0), _s(-20, 0, 28, "bunker", PI)]
	var t: Array = l["trees"]
	_treeline(t, Vector3(-46, 0, -34), Vector3(46, 0, -34), 9, 2.2)
	_treeline(t, Vector3(-46, 0, 34), Vector3(46, 0, 34), 9, 2.2)
	_treeline(t, Vector3(-46, 0, -30), Vector3(-46, 0, 30), 6, 2.0)
	_treeline(t, Vector3(46, 0, -30), Vector3(46, 0, 30), 6, 2.0)
	for pp in [Vector3(-30, 0, -6), Vector3(30, 0, 6), Vector3(-6, 0, 26), Vector3(8, 0, -24), Vector3(-20, 0, 20), Vector3(20, 0, -20), Vector3(-34, 0, 6), Vector3(34, 0, -6), Vector3(12, 0, 22), Vector3(-12, 0, -22)]:
		t.append(pp)
	l["spawns"] = [_v(-42, -10), _v(42, 10), _v(-42, 12), _v(42, -12), _v(-10, -26), _v(10, 26), _v(-24, 2), _v(24, -2), _v(0, -22), _v(0, 22)]
	l["pickups"] = [_v(0, 0, 5.9), _v(-30, 12, 1.3), _v(30, -12, 3.3), _v(-12, -10, 5.5), _v(12, 10, 5.5),
		_v(0, -16, 0.3), _v(0, 16, 0.3), _v(-36, 0, 0.3), _v(36, 0, 0.3), _v(-22, -26, 0.3), _v(22, 26, 0.3), _v(-8, 0, 0.3), _v(8, 0, 0.3)]
	return l

# MARK: 2 — High Tower (80 x 80): tiered tower on an island over a pit

static func _high_tower() -> Dictionary:
	var l := {
		"size": Vector2(80, 80),
		# outer ring (width 16) + central island 26 x 26; the gap between is a death pit
		"grounds": [Rect2(-40, -40, 80, 16), Rect2(-40, 24, 80, 16), Rect2(-40, -24, 16, 48), Rect2(24, -24, 16, 48), Rect2(-13, -13, 26, 26)],
		"blocks": [], "platforms": [], "ramps": [], "structures": [], "trees": [],
		"spawns": [], "pickups": [], "bases": [Vector3(-34, 0, 0), Vector3(34, 0, 0)],
		"real": true, "real_sky": "day_clear", "real_platform": "diamond_plate", "real_tree": "island_tree_02",
		"real_tints": {"ground": Color(0.52, 0.53, 0.55), "wall": Color(0.55, 0.6, 0.66),
			"concrete": Color(0.72, 0.72, 0.74), "rock": Color(0.7, 0.68, 0.66),
			"metal": Color(0.58, 0.6, 0.63)},
		"real_surfaces": {"ground": "paving_stone", "rock": "cliff_rock", "wall": "steel_wall",
			"concrete": "concrete_worn", "metal": "diamond_plate", "wood": "wood_planks",
			"sandbag": "sandbag_fabric", "brick": "brick", "roof": "roof_tiles"},
		"real_fence": true,
		"real_props": ["modular_industrial_pipes_01", "modular_airduct_circular_01", "modular_airduct_rectangular_01",
			"modular_metal_gutter", "small_lpg_tank", "industrial_pipe_lamp", "modular_chainlink_fence",
			"shrub_02", "shrub_04", "moon_rock_02", "moon_rock_04",
			"street_lamp_01", "portable_searchlight", "security_light", "propane_tank",
			"old_military_crate", "wooden_crate_01", "metal_jerrycan_green", "plastic_jerrycan",
			"ladder_sectioned_01", "metal_tool_chest", "Barrel_01", "barrel_03", "ammo_box",
			"moon_rock_02", "moon_rock_04"],
	}
	var b: Array = l["blocks"]
	# the tower core (solid, rises through the tiers)
	b.append(_b(0, 0, 0, 7, 4, 7, "wall"))
	b.append(_b(0, 4, 0, 5, 4, 5, "wall"))
	b.append(_b(0, 8, 0, 3.5, 4, 3.5, "wall"))
	b.append(_b(0, 12, 0, 2.4, 4, 2.4, "pillar"))
	# island cover
	b.append(_b(-9, 0, -9, 1.6, 1.6, 1.6))
	b.append(_b(9, 0, 9, 1.6, 1.6, 1.6))
	b.append(_b(-9, 0, 9, 2.6, 1.0, 1.0, "barrier"))
	b.append(_b(9, 0, -9, 2.6, 1.0, 1.0, "barrier"))
	# outer ring cover + corner boulders
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.append(_b(sx * 33, 0, sz * 33, 3.2, 2.6, 3.2, "rock"))
			b.append(_b(sx * 32, 0, sz * 14, 2.0, 2.0, 2.0))
			b.append(_b(sx * 14, 0, sz * 32, 2.0, 2.0, 2.0))
	# tiers (walkable rings around the core) + crown
	l["platforms"] = [_p(0, 4.0, 0, 12, 12), _p(0, 8.0, 0, 9, 9), _p(0, 12.0, 0, 6.5, 6.5), _p(0, 16.0, 0, 4, 4),
		# four bridges over the pit (no ground under → legless decks)
		_p(-18.5, 0.3, 0, 11, 4), _p(18.5, 0.3, 0, 11, 4), _p(0, 0.3, -18.5, 4, 11), _p(0, 0.3, 18.5, 4, 11),
		# outer ring lookouts
		_p(-32, 3.2, -24, 5, 5), _p(32, 3.2, 24, 5, 5)]
	# spiral of ramps: island → tier1 (south), tier1 → tier2 (east), tier2 → tier3 (north), tier3 → crown (west)
	l["ramps"] = [_r(3.5, 0, 10.5, 2.6, 4.0, 9.0, 0.0), _r(9.0, 4.0, -3.0, 2.2, 4.0, 8.5, -PI / 2.0),
		_r(-2.5, 8.0, -8.0, 2.0, 4.0, 7.5, PI), _r(-7.0, 12.0, 1.5, 1.8, 4.0, 7.0, PI / 2.0),
		_r(-32, 0, -19.0, 3.0, 3.2, 6.5, PI), _r(32, 0, 19.0, 3.0, 3.2, 6.5, 0.0)]
	l["structures"] = [_s(-32, 0, 30, "bunker", PI / 2), _s(32, 0, -30, "bunker", -PI / 2), _s(0, 0, -32, "tower"), _s(0, 0, 32, "tower")]
	var t: Array = l["trees"]
	for sx: float in [-1.0, 1.0]:
		_treeline(t, Vector3(sx * 37, 0, -34), Vector3(sx * 37, 0, 34), 6, 1.2)
		_treeline(t, Vector3(-34, 0, sx * 37), Vector3(34, 0, sx * 37), 6, 1.2)
	l["spawns"] = [_v(-34, -8), _v(34, 8), _v(-34, 8), _v(34, -8), _v(-14, -34), _v(14, 34), _v(14, -34), _v(-14, 34), _v(0, 16.3), _v(-8, 0)]
	l["pickups"] = [_v(0, 0, 16.3), _v(3, 3, 12.3), _v(-3, -3, 8.3), _v(4, -4, 4.3), _v(-18.5, 0, 0.6), _v(18.5, 0, 0.6), _v(0, -18.5, 0.6), _v(0, 18.5, 0.6),
		_v(-32, -24, 3.5), _v(32, 24, 3.5), _v(-33, 0, 0.3), _v(33, 0, 0.3), _v(0, -33, 0.3), _v(0, 33, 0.3)]
	return l

# MARK: 3 — Subdivision (104 x 64): suburban town

static func _subdivision() -> Dictionary:
	var l := {
		"size": Vector2(104, 64),
		"grounds": [Rect2(-52, -32, 104, 64)],
		"blocks": [], "platforms": [], "ramps": [], "structures": [], "trees": [],
		"spawns": [], "pickups": [], "bases": [Vector3(-46, 0, 0), Vector3(46, 0, 0)],
	}
	var b: Array = l["blocks"]
	var st: Array = l["structures"]
	# two rows of houses along the main street (z = 0), facing the street
	for i in 3:
		var x := -32.0 + i * 32.0
		st.append(_s(x, 0, -16, "house", 0.0))
		st.append(_s(x, 0, 16, "house", PI))
		# yard fences (low walls) + a car parked in the drive
		b.append(_b(x - 6, 0, -12, 0.4, 1.1, 8, "wall"))
		b.append(_b(x + 6, 0, 12, 0.4, 1.1, 8, "wall"))
		b.append(_b(x + 5.5, 0, -9, 2.0, 1.4, 4.2, "metal"))
		b.append(_b(x - 5.5, 0, 9, 2.0, 1.4, 4.2, "metal"))
		# hedges behind the houses
		b.append(_b(x, 0, -24, 10, 1.2, 1.0, "rock"))
		b.append(_b(x, 0, 24, 10, 1.2, 1.0, "rock"))
	# main street furniture: barriers + cars in the middle lane
	for i in 5:
		b.append(_b(-40 + i * 20, 0, 0, 2.0, 1.4, 4.4, "metal"))
	b.append(_b(-16, 0, -3, 3.2, 1.0, 0.8, "barrier"))
	b.append(_b(16, 0, 3, 3.2, 1.0, 0.8, "barrier"))
	# cross street + plaza in the centre with a fountain and benches
	b.append(_b(0, 0, 0, 2.4, 2.4, 2.4, "pillar"))
	b.append(_b(-4, 0, -4, 2.2, 0.5, 0.7))
	b.append(_b(4, 0, 4, 2.2, 0.5, 0.7))
	# back alleys with containers + crates
	b.append(_b(-48, 0, -28, 6, 2.6, 2.4, "container"))
	b.append(_b(48, 0, 28, 6, 2.6, 2.4, "container"))
	b.append(_b(-16, 0, 28, 2.2, 2.2, 2.2))
	b.append(_b(16, 0, -28, 2.2, 2.2, 2.2))
	b.append(_b(-14, 2.2, 28, 1.4, 1.4, 1.4))
	# corner shop (a bigger box) with a roof deck you can jump onto
	b.append(_b(-46, 0, 6, 10, 4.0, 8, "wall"))
	b.append(_b(46, 0, -6, 10, 4.0, 8, "wall"))
	l["platforms"] = [_p(0, 0.35, 0, 14, 14), _p(-46, 4.2, 6, 10.4, 8.4), _p(46, 4.2, -6, 10.4, 8.4)]
	l["ramps"] = [_r(-46, 0, 14.5, 3, 4.2, 9, 0.0), _r(46, 0, -14.5, 3, 4.2, 9, PI)]
	var t: Array = l["trees"]
	for i in 3:
		var x := -32.0 + i * 32.0
		t.append(Vector3(x - 10, 0, -7)); t.append(Vector3(x + 10, 0, 7))
	_treeline(t, Vector3(-50, 0, -30), Vector3(50, 0, -30), 9, 1.5)
	_treeline(t, Vector3(-50, 0, 30), Vector3(50, 0, 30), 9, 1.5)
	l["spawns"] = [_v(-46, -12), _v(46, 12), _v(-46, 18), _v(46, -18), _v(-16, -28), _v(16, 28), _v(-8, 10), _v(8, -10), _v(-30, 4), _v(30, -4)]
	l["pickups"] = [_v(0, 0, 0.7), _v(-46, 6, 4.5), _v(46, -6, 4.5), _v(-16, 0, 0.3), _v(16, 0, 0.3), _v(-32, -8, 0.3), _v(32, 8, 0.3), _v(0, -26, 0.3), _v(0, 26, 0.3), _v(-48, 28, 0.3), _v(48, -28, 0.3)]
	return l

# MARK: 4 — Ice Box (84 x 68): frozen lake + igloos + ice pillars (slippery)

static func _ice_box() -> Dictionary:
	var l := {
		"size": Vector2(84, 68),
		"grounds": [Rect2(-42, -34, 84, 68)],
		"blocks": [], "platforms": [], "ramps": [], "structures": [], "trees": [],
		"spawns": [], "pickups": [], "bases": [Vector3(-38, 0, 0), Vector3(38, 0, 0)],
	}
	var b: Array = l["blocks"]
	# the frozen lake (visual ice slab) with a ring of ice pillars
	b.append(_b(0, 0, 0, 34, 0.12, 26, "ice"))
	for i in 8:
		var a := float(i) / 8.0 * TAU
		b.append(_b(cos(a) * 15.0, 0, sin(a) * 11.0, 1.8, 3.0 + (i % 3) * 1.2, 1.8, "pillar"))
	b.append(_b(0, 0, 0, 3.0, 6.0, 3.0, "pillar"))
	# frozen containers + crates on the shores
	b.append(_b(-28, 0, -20, 6, 2.6, 2.4, "container"))
	b.append(_b(28, 0, 20, 6, 2.6, 2.4, "container"))
	b.append(_b(-28, 2.6, -20, 6, 2.6, 2.4, "container"))
	b.append(_b(24, 0, -24, 2.2, 2.2, 2.2)); b.append(_b(-24, 0, 24, 2.2, 2.2, 2.2))
	b.append(_b(26, 0, -21, 1.4, 1.4, 1.4)); b.append(_b(-26, 0, 21, 1.4, 1.4, 1.4))
	# ice boulders
	b.append(_b(-36, 0, 10, 4, 2.6, 3, "rock")); b.append(_b(36, 0, -10, 4, 2.6, 3, "rock"))
	b.append(_b(-10, 0, 28, 3, 2.0, 3, "rock")); b.append(_b(10, 0, -28, 3, 2.0, 3, "rock"))
	b.append(_b(0, 0, -26, 6, 1.0, 1.0, "barrier")); b.append(_b(0, 0, 26, 6, 1.0, 1.0, "barrier"))
	# ice shelves (platforms) reached by ramps + a high central deck on the pillar
	l["platforms"] = [_p(0, 6.2, 0, 6, 6), _p(-20, 3.4, 12, 6, 6), _p(20, 3.4, -12, 6, 6), _p(-20, 3.4, -12, 5, 5), _p(20, 3.4, 12, 5, 5)]
	l["ramps"] = [_r(-20, 0, 19.0, 3.0, 3.4, 8, 0.0), _r(20, 0, -19.0, 3.0, 3.4, 8, PI), _r(-20, 0, -19.0, 3.0, 3.4, 8, PI), _r(20, 0, 19.0, 3.0, 3.4, 8, 0.0)]
	l["structures"] = [_s(-36, 0, -26, "bunker", PI / 2), _s(36, 0, 26, "bunker", -PI / 2), _s(-36, 0, 26, "tower"), _s(36, 0, -26, "tower"), _s(0, 0, -30, "house", 0.0), _s(0, 0, 30, "house", PI)]
	var t: Array = l["trees"]
	_treeline(t, Vector3(-40, 0, -32), Vector3(40, 0, -32), 10, 1.6)
	_treeline(t, Vector3(-40, 0, 32), Vector3(40, 0, 32), 10, 1.6)
	_treeline(t, Vector3(-40, 0, -28), Vector3(-40, 0, 28), 6, 1.4)
	_treeline(t, Vector3(40, 0, -28), Vector3(40, 0, 28), 6, 1.4)
	l["spawns"] = [_v(-36, -8), _v(36, 8), _v(-36, 8), _v(36, -8), _v(-10, -30), _v(10, 30), _v(-30, 4), _v(30, -4), _v(0, 6.5), _v(-20, 0)]
	l["pickups"] = [_v(0, 0, 6.5), _v(-20, 12, 3.7), _v(20, -12, 3.7), _v(-20, -12, 3.7), _v(20, 12, 3.7), _v(0, -12, 0.3), _v(0, 12, 0.3), _v(-30, 0, 0.3), _v(30, 0, 0.3), _v(-28, -20, 5.5), _v(28, 20, 2.9)]
	return l

# MARK: 5 — Crossfire (108 x 52): two raised fortresses across a chasm

static func _crossfire() -> Dictionary:
	var l := {
		"size": Vector2(108, 52),
		# west plateau, east plateau, a small island in the middle; the rest is the chasm
		"grounds": [Rect2(-54, -26, 40, 52), Rect2(14, -26, 40, 52), Rect2(-5, -5, 10, 10)],
		"blocks": [], "platforms": [], "ramps": [], "structures": [], "trees": [],
		"spawns": [], "pickups": [], "bases": [Vector3(-46, 3.6, 0), Vector3(46, 3.6, 0)],
		"real": true, "real_sky": "day_clear", "real_tree": "quiver_tree_01",
		"real_props": ["dead_tree_trunk", "dead_tree_trunk_02", "tree_stump_02", "shrub_02", "shrub_04", "Barrel_01", "Barrel_02", "ammo_box", "plastic_crate_02", "moon_rock_02", "moon_rock_04", "moon_rock_06"],
		"real_surfaces": {"ground": "dirt_cracked", "rock": "cliff_rock", "wall": "cliff_rock",
			"concrete": "concrete", "metal": "metal_rusted", "wood": "wood_planks",
			"sandbag": "sandbag_fabric"},
		"real_tints": {"ground": Color(0.95, 0.72, 0.5), "rock": Color(0.85, 0.55, 0.36),
			"wall": Color(0.88, 0.6, 0.42), "concrete": Color(0.95, 0.82, 0.68)},
	}
	var b: Array = l["blocks"]
	var pl: Array = l["platforms"]
	var rp: Array = l["ramps"]
	var st: Array = l["structures"]
	for sx: float in [-1.0, 1.0]:
		# fortress: a raised keep (big wall block) with a walkable top + battlements
		b.append(_b(sx * 44, 0, 0, 14, 3.6, 22, "wall"))
		for i in 5:
			b.append(_b(sx * 50.5, 3.6, -10 + i * 5, 0.8, 1.2, 1.6, "wall"))
		b.append(_b(sx * 44, 3.6, 11.4, 14, 1.2, 0.8, "wall"))
		b.append(_b(sx * 44, 3.6, -11.4, 14, 1.2, 0.8, "wall"))
		# stairs up to the keep from the plateau (two ramps)
		rp.append(_r(sx * 33.0, 0, 6, 3.0, 3.6, 8.0, -sx * PI / 2.0))
		rp.append(_r(sx * 33.0, 0, -6, 3.0, 3.6, 8.0, -sx * PI / 2.0))
		# towers on the keep + bunkers on the plateau
		st.append(_s(sx * 46, 3.6, -8, "tower"))
		st.append(_s(sx * 46, 3.6, 8, "tower"))
		st.append(_s(sx * 24, 0, -18, "bunker", -sx * PI / 2.0))
		st.append(_s(sx * 24, 0, 18, "bunker", -sx * PI / 2.0))
		# plateau cover
		b.append(_b(sx * 22, 0, 0, 2.2, 2.2, 2.2))
		b.append(_b(sx * 28, 0, 8, 2.6, 1.0, 1.0, "barrier"))
		b.append(_b(sx * 28, 0, -8, 2.6, 1.0, 1.0, "barrier"))
		b.append(_b(sx * 18, 0, -12, 4, 2.4, 3, "rock"))
		b.append(_b(sx * 18, 0, 12, 4, 2.4, 3, "rock"))
		b.append(_b(sx * 40, 0, 22, 3, 2.0, 3, "rock"))
		b.append(_b(sx * 40, 0, -22, 3, 2.0, 3, "rock"))
	# three bridges: two low ones (north / south) and a high one keep-to-keep
	pl.append(_p(0, 0.3, -18, 28, 4))
	pl.append(_p(0, 0.3, 18, 28, 4))
	pl.append(_p(0, 5.4, 0, 30, 3))
	pl.append(_p(-24, 5.4, 0, 6, 3))
	pl.append(_p(24, 5.4, 0, 6, 3))
	rp.append(_r(-31.5, 3.6, 0, 3, 1.8, 4.0, PI / 2.0))       # keep top → high bridge (small step)
	rp.append(_r(31.5, 3.6, 0, 3, 1.8, 4.0, -PI / 2.0))
	# centre island
	b.append(_b(0, 0, 0, 2.4, 1.0, 2.4, "barrier"))
	var t: Array = l["trees"]
	_treeline(t, Vector3(-52, 0, -24), Vector3(-16, 0, -24), 5, 1.2)
	_treeline(t, Vector3(16, 0, 24), Vector3(52, 0, 24), 5, 1.2)
	l["spawns"] = [_v(-46, 0, 3.6), _v(46, 0, 3.6), _v(-30, -20), _v(30, 20), _v(-30, 20), _v(30, -20), _v(-22, 4), _v(22, -4), _v(-40, 14), _v(40, -14)]
	l["pickups"] = [_v(0, 0, 5.7), _v(0, 0, 0.3), _v(0, -18, 0.6), _v(0, 18, 0.6), _v(-24, 0, 5.7), _v(24, 0, 5.7), _v(-44, 0, 3.9), _v(44, 0, 3.9), _v(-24, -8, 0.3), _v(24, 8, 0.3), _v(-30, 22, 0.3), _v(30, -22, 0.3)]
	return l

# MARK: 6 — Green Hills (96 x 76): meadow with mounds, a farm, a pond, stone walls, forest

static func _green_hills() -> Dictionary:
	var l := {
		"size": Vector2(96, 76),
		"grounds": [Rect2(-48, -38, 96, 76)],
		"blocks": [], "platforms": [], "ramps": [], "structures": [], "trees": [],
		"spawns": [], "pickups": [], "bases": [Vector3(-42, 0, 0), Vector3(42, 0, 0)],
		"real": true, "real_sky": "valley", 
		"real_trees": [{"model": "birch_tree", "h": 9.0}, {"model": "tree_gn", "h": 9.5}, {"model": "birch_tree", "h": 7.0},
			{"model": "realistic_hd_sour_orange_1630", "h": 4.5}],
				"real_place": [
			{"model": "free_london_kinnaird_house", "pos": Vector3(0, 0, -26), "yaw": 0.0, "len": 24.0, "collide": "trimesh"},
			{"model": "school_house_7_bedford_nh__kendall_shoe_1847", "pos": Vector3(-34, 0, 16), "yaw": 1.3, "len": 18.0, "collide": "trimesh", "sink": 5.0},
			{"model": "gta_6_prison_tower__guard_tower__watchtower", "pos": Vector3(14, 0, 6), "yaw": 0.6, "scale": 1.6, "collide": "trimesh"},
		],
		"real_props": ["rock_07", "rock_09", "namaqualand_boulder_03", "namaqualand_boulder_04",
			"wooden_crate_01", "Barrel_01"],
		"real_surfaces": {"ground": "forest_grass", "rock": "rock", "wall": "brick",
			"concrete": "concrete", "metal": "metal_rusted", "wood": "wood_planks",
			"brick": "brick", "roof": "roof_tiles"},
		"real_tints": {"ground": Color(0.82, 0.9, 0.7)},
	}
	var b: Array = l["blocks"]
	# three hills (mounds) of different heights
	# the farm in the NE corner: house + barn + silo, fenced with stone walls
	l["structures"] = []
	b.append(_b(30, 0, 14, 28, 0.9, 0.6, "wall"))
	b.append(_b(14, 0, 25, 0.6, 0.9, 22, "wall"))
	for i in 4:
		b.append(_b(24 + i * 1.5, 0, 20, 1.2, 0.9, 1.2, "crate"))         # hay bales
	# pond in the SW quarter
	b.append(_b(-15, 0, -12, 3, 1.4, 3, "rock")); b.append(_b(-37, 0, -24, 3, 1.6, 3, "rock"))
	# stone walls crossing the meadow + boulder clusters
	b.append(_b(-8, 0, 22, 0.6, 1.0, 26, "wall"))
	b.append(_b(8, 0, -22, 0.6, 1.0, 26, "wall"))
	b.append(_b(-30, 0, 2, 5, 3.0, 4, "rock")); b.append(_b(-34, 0, 5, 3, 1.8, 3, "rock"))
	b.append(_b(30, 0, -2, 5, 3.0, 4, "rock")); b.append(_b(34, 0, -5, 3, 1.8, 3, "rock"))
	b.append(_b(0, 0, -28, 4, 2.2, 3, "rock")); b.append(_b(0, 0, 28, 4, 2.2, 3, "rock"))
	# ruined cottage in the SE
	b.append(_b(-30, 0, -32, 2.2, 2.2, 2.2)); b.append(_b(-27, 0, -32, 1.4, 1.4, 1.4))
	# forest border + copses
	var t: Array = l["trees"]
	_treeline(t, Vector3(-46, 0, -36), Vector3(46, 0, -36), 12, 1.8)
	_treeline(t, Vector3(-46, 0, 36), Vector3(46, 0, 36), 12, 1.8)
	_treeline(t, Vector3(-46, 0, -30), Vector3(-46, 0, 30), 8, 1.6)
	_treeline(t, Vector3(46, 0, -30), Vector3(46, 0, 30), 8, 1.6)
	for p in [Vector3(-14, 0, 10), Vector3(-12, 0, 13), Vector3(14, 0, -10), Vector3(12, 0, -13), Vector3(-20, 0, -30), Vector3(20, 0, 8)]:
		t.append(p)
	l["spawns"] = [_v(-42, -8), _v(42, 8), _v(-42, 12), _v(42, -12), _v(-12, -32), _v(12, 32), _v(-20, 30), _v(20, -30), _v(0, 4.3), _v(-8, 0)]
	l["pickups"] = [_v(0, 0, 4.3), _v(-26, 18, 2.9), _v(26, -18, 3.5), _v(-42, 30, 3.3), _v(-26, -18, 0.3), _v(32, 30, 0.3), _v(0, -18, 0.3), _v(0, 18, 0.3), _v(-36, 0, 0.3), _v(36, 0, 0.3), _v(-30, -30, 0.3), _v(30, -24, 0.3)]
	l["platforms"] = []
	l["ramps"] = []
	return l
