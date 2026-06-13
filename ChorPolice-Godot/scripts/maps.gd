## Maps — the six arenas, with EXACT coordinates copied from the iOS Maps.swift
## layouts so iOS↔Android cross-play lines up on identical geometry.
## Coordinates are in "up-positive" space (like iOS): `top`/`y`/`floor` are
## heights above the bottom. game.gd converts to Godot's y-DOWN with godot_y = -y.
## grounds: Vector3(x0, x1, top)   platforms: Vector3(x, y, w)
class_name Maps
extends RefCounted

static func count() -> int:
	return 6

static func get_map(index: int) -> Dictionary:
	var i := ((index % 6) + 6) % 6
	match i:
		0: return _outpost()
		1: return _high_tower()
		2: return _subdivision()
		3: return _ice_box()
		4: return _crossfire()
		_: return _green_hills()

static func _c(r: float, g: float, b: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0)

static func _block(x: float, y: float, w: float, h: float, hang: bool) -> Dictionary:
	return {"x": x, "y": y, "w": w, "h": h, "hang": hang}

static func _struct(x: float, floor_y: float, kind: String) -> Dictionary:
	return {"x": x, "floor": floor_y, "kind": kind}

# MARK: 1 — Outpost (islands + 4 death pits + bunkers, dusk)

static func _outpost() -> Dictionary:
	return {
		"name": "Outpost", "short": "Outpost", "length": 7400.0,
		"theme": {
			"sky": [_c(30, 24, 38), _c(96, 58, 54), _c(196, 120, 66)],
			"rock": _c(97, 79, 59), "rock_edge": _c(59, 46, 33), "rock_dark": _c(69, 56, 41),
			"grass": _c(87, 128, 51), "grass_style": "grass",
			"hill": _c(51, 41, 43), "hill_style": "rocks",
			"props": ["kenney_bush", "kenney_mushroomBrown", "kenney_mushroomRed", "kenney_plant", "kenney_rock", "kenney_fence", "kenney_sign"],
			"weather": "embers", "slippery": false, "cloud_alpha": 0.7,
		},
		"grounds": [Vector3(0, 1150, 100), Vector3(1650, 2750, 120), Vector3(3250, 4250, 100), Vector3(4750, 5750, 140), Vector3(6250, 7400, 100)],
		"platforms": [
			Vector3(620, 300, 160), Vector3(980, 450, 140), Vector3(1430, 360, 150),
			Vector3(1950, 300, 170), Vector3(2430, 470, 150), Vector3(3000, 350, 150),
			Vector3(3500, 300, 150), Vector3(3870, 450, 150), Vector3(4180, 300, 140),
			Vector3(4520, 380, 150), Vector3(5050, 300, 160), Vector3(5480, 470, 150),
			Vector3(6020, 360, 150), Vector3(6520, 300, 160), Vector3(6900, 450, 150),
			Vector3(7220, 300, 150),
		],
		"blocks": [_block(2200, 520, 760, 80, true), _block(1900, 175, 60, 110, false), _block(2500, 360, 60, 130, false)],
		"structures": [_struct(300, 100, "bunker"), _struct(3700, 100, "bunker"), _struct(7250, 100, "tower")],
		"spawns": [Vector2(250, 170), Vector2(980, 520), Vector2(1950, 370), Vector2(3500, 370), Vector2(4180, 370), Vector2(5050, 370), Vector2(6520, 370), Vector2(7220, 370)],
		"pickups": [Vector2(620, 360), Vector2(1430, 420), Vector2(1950, 360), Vector2(2430, 530), Vector2(3000, 410), Vector2(3870, 510), Vector2(4520, 440), Vector2(5050, 360), Vector2(6020, 420), Vector2(6900, 510), Vector2(7220, 360)],
	}

# MARK: 2 — High Tower (central mega-tower over a huge pit)

static func _high_tower() -> Dictionary:
	return {
		"name": "High Tower", "short": "Tower", "length": 6000.0,
		"theme": {
			"sky": [_c(44, 52, 70), _c(110, 120, 140), _c(190, 190, 196)],
			"rock": _c(117, 117, 125), "rock_edge": _c(66, 66, 74), "rock_dark": _c(89, 89, 97),
			"grass": _c(97, 130, 64), "grass_style": "grass",
			"hill": _c(69, 74, 87), "hill_style": "mountains",
			"props": ["kenney_rock", "kenney_fenceBroken", "kenney_plantPurple", "kenney_plant"],
			"weather": "none", "slippery": false, "cloud_alpha": 0.9,
		},
		"grounds": [Vector3(0, 2350, 100), Vector3(3650, 6000, 100)],
		"platforms": [
			Vector3(560, 320, 170), Vector3(1050, 470, 150), Vector3(1550, 330, 150),
			Vector3(2000, 520, 150), Vector3(2300, 330, 130),
			Vector3(2680, 250, 120), Vector3(3320, 250, 120),
			Vector3(2720, 430, 120), Vector3(3280, 430, 120),
			Vector3(2680, 610, 120), Vector3(3320, 610, 120),
			Vector3(3000, 770, 280),
			Vector3(3700, 330, 130), Vector3(4000, 520, 150), Vector3(4450, 330, 150),
			Vector3(4950, 470, 150), Vector3(5440, 320, 170),
		],
		"blocks": [_block(3000, 270, 210, 800, false), _block(560, 240, 130, 280, false), _block(5440, 240, 130, 280, false)],
		"structures": [_struct(3000, 783, "tower"), _struct(560, 380, "bunker"), _struct(5440, 380, "bunker")],
		"spawns": [Vector2(300, 170), Vector2(1550, 400), Vector2(2000, 590), Vector2(2720, 500), Vector2(3280, 500), Vector2(3000, 845), Vector2(4450, 400), Vector2(5700, 170)],
		"pickups": [Vector2(360, 170), Vector2(1050, 540), Vector2(2000, 590), Vector2(2700, 320), Vector2(3300, 500), Vector2(3000, 850), Vector2(4000, 590), Vector2(4950, 540), Vector2(5640, 170)],
	}

# MARK: 3 — Subdivision (two roofed interior complexes, night)

static func _subdivision() -> Dictionary:
	return {
		"name": "Subdivision", "short": "Subdiv", "length": 7000.0,
		"theme": {
			"sky": [_c(10, 12, 20), _c(28, 34, 44), _c(60, 72, 80)],
			"rock": _c(74, 82, 79), "rock_edge": _c(41, 46, 43), "rock_dark": _c(56, 61, 59),
			"grass": _c(69, 97, 56), "grass_style": "grass",
			"hill": _c(23, 31, 33), "hill_style": "buildings",
			"props": ["kenney_box", "kenney_boxWarning", "kenney_fenceBroken", "kenney_rock"],
			"weather": "embers", "slippery": false, "cloud_alpha": 0.15,
		},
		"grounds": [Vector3(0, 3150, 100), Vector3(3850, 7000, 100)],
		"platforms": [
			Vector3(470, 320, 150),
			Vector3(1150, 200, 150), Vector3(1750, 200, 150), Vector3(2350, 200, 150),
			Vector3(1450, 360, 150), Vector3(2050, 360, 150),
			Vector3(3500, 250, 180), Vector3(3500, 470, 160),
			Vector3(4650, 200, 150), Vector3(5250, 200, 150), Vector3(5850, 200, 150),
			Vector3(4950, 360, 150), Vector3(5550, 360, 150),
			Vector3(6530, 320, 150),
		],
		"blocks": [
			_block(1750, 540, 1820, 64, true), _block(900, 200, 56, 200, false), _block(2600, 200, 56, 200, false),
			_block(5250, 540, 1820, 64, true), _block(4400, 200, 56, 200, false), _block(6100, 200, 56, 200, false),
		],
		"structures": [_struct(1750, 572, "house"), _struct(5250, 572, "house")],
		"spawns": [Vector2(300, 170), Vector2(1150, 270), Vector2(2350, 270), Vector2(1750, 620), Vector2(3500, 320), Vector2(4650, 270), Vector2(5850, 270), Vector2(6700, 170)],
		"pickups": [Vector2(470, 390), Vector2(1450, 270), Vector2(1750, 270), Vector2(2350, 430), Vector2(3500, 320), Vector2(3500, 540), Vector2(4650, 270), Vector2(5250, 270), Vector2(5850, 430), Vector2(6530, 390)],
	}

# MARK: 4 — Ice Box (enclosed, slippery, hanging shelves + corner towers)

static func _ice_box() -> Dictionary:
	return {
		"name": "Ice Box", "short": "Ice", "length": 6600.0,
		"theme": {
			"sky": [_c(10, 14, 44), _c(34, 58, 118), _c(150, 196, 228)],
			"rock": _c(168, 196, 222), "rock_edge": _c(107, 140, 179), "rock_dark": _c(140, 168, 199),
			"grass": _c(240, 247, 255), "grass_style": "snow",
			"hill": _c(41, 61, 110), "hill_style": "mountains",
			"props": ["kenney_deadTree", "kenney_igloo", "kenney_pineSapling", "kenney_rockIce", "kenney_snowBall", "kenney_plantSnow"],
			"weather": "snow", "slippery": true, "cloud_alpha": 0.85,
		},
		"grounds": [Vector3(0, 6600, 95)],
		"platforms": [
			Vector3(560, 300, 170), Vector3(980, 470, 150), Vector3(1430, 320, 160),
			Vector3(1850, 250, 150), Vector3(1850, 470, 150),
			Vector3(2400, 360, 170), Vector3(2850, 560, 160),
			Vector3(3300, 320, 200), Vector3(3300, 560, 170),
			Vector3(3750, 400, 150),
			Vector3(4200, 250, 150), Vector3(4200, 470, 150),
			Vector3(4750, 360, 170), Vector3(5200, 560, 160),
			Vector3(5650, 320, 170), Vector3(6080, 470, 150),
		],
		"blocks": [
			_block(1430, 560, 900, 80, true), _block(5200, 560, 900, 80, true),
			_block(2650, 200, 80, 210, false), _block(3950, 200, 80, 210, false),
		],
		"structures": [_struct(360, 95, "tower"), _struct(6240, 95, "tower")],
		"spawns": [Vector2(300, 165), Vector2(1100, 165), Vector2(2400, 430), Vector2(3300, 390), Vector2(3750, 470), Vector2(4200, 540), Vector2(5500, 165), Vector2(6300, 165)],
		"pickups": [Vector2(560, 370), Vector2(1430, 390), Vector2(1850, 320), Vector2(2400, 430), Vector2(3300, 390), Vector2(3300, 630), Vector2(4200, 320), Vector2(4750, 430), Vector2(5650, 390), Vector2(6080, 540)],
	}

# MARK: 5 — Crossfire (desert canyon + bridge + base towers + cave)

static func _crossfire() -> Dictionary:
	return {
		"name": "Crossfire", "short": "Cross", "length": 7400.0,
		"theme": {
			"sky": [_c(40, 22, 40), _c(140, 70, 50), _c(232, 150, 80)],
			"rock": _c(140, 105, 69), "rock_edge": _c(87, 61, 38), "rock_dark": _c(112, 84, 56),
			"grass": _c(150, 128, 61), "grass_style": "grass",
			"hill": _c(89, 61, 51), "hill_style": "rocks",
			"props": ["kenney_cactus", "kenney_rock", "kenney_sign", "kenney_fence"],
			"weather": "embers", "slippery": false, "cloud_alpha": 0.55,
		},
		"grounds": [Vector3(0, 2600, 110), Vector3(3450, 3950, 150), Vector3(4800, 7400, 110)],
		"platforms": [
			Vector3(520, 340, 170), Vector3(1080, 300, 160), Vector3(1650, 430, 160), Vector3(2150, 320, 150),
			Vector3(2950, 360, 170),
			Vector3(3700, 540, 200),
			Vector3(3700, 260, 160),
			Vector3(4450, 360, 170),
			Vector3(5250, 320, 150), Vector3(5750, 430, 160), Vector3(6320, 300, 160), Vector3(6880, 340, 170),
		],
		"blocks": [
			_block(2680, 280, 150, 360, false), _block(4720, 280, 150, 360, false),
			_block(520, 245, 120, 250, false), _block(6880, 245, 120, 250, false),
			_block(3700, 150, 760, 70, true),
		],
		"structures": [_struct(520, 425, "bunker"), _struct(6880, 425, "bunker"), _struct(3700, 640, "tower")],
		"spawns": [Vector2(300, 180), Vector2(1080, 370), Vector2(2150, 390), Vector2(3700, 610), Vector2(4450, 430), Vector2(5250, 390), Vector2(6880, 410), Vector2(7100, 180)],
		"pickups": [Vector2(820, 180), Vector2(1080, 370), Vector2(1650, 500), Vector2(3700, 610), Vector2(3700, 330), Vector2(2950, 430), Vector2(4450, 430), Vector2(5750, 500), Vector2(6580, 180)],
	}

# MARK: 6 — Green Hills (bright day, rolling hills + gaps)

static func _green_hills() -> Dictionary:
	return {
		"name": "Green Hills", "short": "Hills", "length": 7200.0,
		"theme": {
			"sky": [_c(96, 160, 230), _c(150, 200, 245), _c(208, 236, 255)],
			"rock": _c(115, 82, 51), "rock_edge": _c(72, 51, 31), "rock_dark": _c(92, 66, 41),
			"grass": _c(115, 178, 66), "grass_style": "grass",
			"hill": _c(61, 115, 61), "hill_style": "trees",
			"props": ["kenney_bush", "kenney_mushroomBrown", "kenney_mushroomRed", "kenney_plant", "kenney_rock", "kenney_fence", "kenney_sign"],
			"weather": "none", "slippery": false, "cloud_alpha": 1.0,
		},
		"grounds": [Vector3(0, 1500, 100), Vector3(1850, 2900, 200), Vector3(3250, 4200, 130), Vector3(4550, 5400, 250), Vector3(5750, 7200, 110)],
		"platforms": [
			Vector3(560, 300, 210), Vector3(1120, 440, 210),
			Vector3(1650, 320, 140),
			Vector3(2350, 430, 210), Vector3(2880, 560, 210),
			Vector3(3060, 320, 140),
			Vector3(3650, 380, 210), Vector3(4080, 520, 210),
			Vector3(4380, 360, 140),
			Vector3(4950, 480, 210),
			Vector3(5550, 360, 140),
			Vector3(6050, 320, 210), Vector3(6550, 460, 210), Vector3(6950, 320, 210),
		],
		"blocks": [],
		"structures": [],
		"spawns": [Vector2(350, 170), Vector2(1120, 510), Vector2(2300, 270), Vector2(3650, 450), Vector2(4900, 320), Vector2(5550, 430), Vector2(6050, 390), Vector2(6950, 390)],
		"pickups": [Vector2(700, 170), Vector2(1120, 510), Vector2(2350, 270), Vector2(2880, 630), Vector2(3650, 450), Vector2(4080, 590), Vector2(4950, 550), Vector2(6050, 390), Vector2(6550, 530)],
	}
