## Weapons — the 9 guns ported from iOS (stats + vector art).
## type ints match iOS rawValues: 0 rifle/M4, 1 uzi, 2 shotgun, 3 sniper/M14,
## 4 magnum, 5 mp5, 6 ak47, 7 flamer, 8 rocket/SMAW.
class_name Weapons
extends RefCounted

const RIFLE := 0
const UZI := 1
const SHOTGUN := 2
const SNIPER := 3
const MAGNUM := 4
const MP5 := 5
const AK47 := 6
const FLAMER := 7
const ROCKET := 8

static func data(t: int) -> Dictionary:
	match t:
		UZI:     return {"name": "UZI", "interval": 0.07, "dmg": 7.0, "speed": 900.0, "pellets": 1, "spread": 0.05, "life": 1.5, "ammo": 40, "muzzle": 46.0, "special": "bullet", "grips": [22.0, 33.0]}
		SHOTGUN: return {"name": "SHOTGUN", "interval": 0.6, "dmg": 9.0, "speed": 800.0, "pellets": 5, "spread": 0.18, "life": 1.5, "ammo": 12, "muzzle": 54.0, "special": "bullet", "grips": [15.0, 31.0]}
		SNIPER:  return {"name": "M14", "interval": 0.95, "dmg": 45.0, "speed": 1450.0, "pellets": 1, "spread": 0.0, "life": 1.5, "ammo": 8, "muzzle": 64.0, "special": "bullet", "grips": [13.0, 33.0]}
		MAGNUM:  return {"name": "MAGNUM", "interval": 0.45, "dmg": 28.0, "speed": 1150.0, "pellets": 1, "spread": 0.01, "life": 1.5, "ammo": 12, "muzzle": 44.0, "special": "bullet", "grips": [13.0, 13.0]}
		MP5:     return {"name": "MP5", "interval": 0.085, "dmg": 8.0, "speed": 920.0, "pellets": 1, "spread": 0.04, "life": 1.5, "ammo": 45, "muzzle": 47.0, "special": "bullet", "grips": [20.0, 37.0]}
		AK47:    return {"name": "AK-47", "interval": 0.16, "dmg": 14.0, "speed": 950.0, "pellets": 1, "spread": 0.03, "life": 1.5, "ammo": 35, "muzzle": 56.0, "special": "bullet", "grips": [20.0, 38.0]}
		FLAMER:  return {"name": "FLAMER", "interval": 0.05, "dmg": 3.0, "speed": 520.0, "pellets": 1, "spread": 0.12, "life": 0.30, "ammo": 90, "muzzle": 50.0, "special": "flame", "grips": [19.0, 39.0]}
		ROCKET:  return {"name": "SMAW", "interval": 1.3, "dmg": 62.0, "speed": 470.0, "pellets": 1, "spread": 0.0, "life": 4.0, "ammo": 4, "muzzle": 58.0, "special": "rocket", "grips": [24.0, 35.0]}
		_:       return {"name": "M4", "interval": 0.14, "dmg": 11.0, "speed": 940.0, "pellets": 1, "spread": 0.015, "life": 1.5, "ammo": -1, "muzzle": 54.0, "special": "bullet", "grips": [24.0, 42.0]}

## Vector gun model (parented inside the arm rig; +x = barrel, y+ = down).
static func art(t: int) -> Node2D:
	var n := Node2D.new()
	var metal := Color(0.17, 0.18, 0.21)
	var dark := Color(0.09, 0.10, 0.14)
	var wood := Color(0.36, 0.24, 0.13)
	match t:
		UZI:
			_p(n, 8, 0, 10, 5, dark); _p(n, 24, 0, 22, 9, metal)
			_p(n, 22, 10, 6, 12, dark, 0.2); _p(n, 40, 0, 12, 4, dark)
		SHOTGUN:
			_p(n, 4, 0, 12, 8, wood); _p(n, 16, 0, 12, 8, metal)
			_p(n, 34, 1, 34, 5, dark); _p(n, 31, 5, 14, 5, wood); _p(n, 52, -4, 3, 4, dark)
		SNIPER:
			_p(n, 6, 0, 28, 8, wood); _p(n, 28, 0, 12, 6, metal)
			_p(n, 30, -7, 16, 5, metal); _p(n, 24, -4, 3, 5, dark); _p(n, 38, -4, 3, 5, dark)
			_p(n, 48, 0, 34, 4, dark); _p(n, 64, -4, 2.5, 5, dark)
		MAGNUM:
			_p(n, 20, 0, 16, 6, metal); _p(n, 34, 0, 14, 4, dark)
			_p(n, 21, 0, 8, 8, dark); _p(n, 13, 7, 6, 11, wood, 0.3); _p(n, 41, -4, 2, 4, dark)
		MP5:
			_p(n, 9, 0, 10, 5, metal); _p(n, 25, 0, 22, 9, metal)
			_p(n, 27, 10, 6, 12, dark, 0.3); _p(n, 20, 8, 5, 8, dark); _p(n, 42, 0, 10, 4, dark)
		AK47:
			_p(n, 6, 0, 12, 7, wood); _p(n, 22, 0, 20, 8, metal)
			_p(n, 38, 0, 11, 5, wood); _p(n, 48, 0, 12, 3, dark)
			_p(n, 25, 10, 7, 13, dark, 0.45); _p(n, 54, -5, 2, 5, dark)
		FLAMER:
			_p(n, 13, 9, 12, 8, Color(0.62, 0.20, 0.15)); _p(n, 24, 0, 22, 9, metal)
			_p(n, 42, 0, 14, 5, dark); _p(n, 50, 0, 4, 7, dark); _p(n, 19, 8, 5, 7, dark)
		ROCKET:
			_p(n, 30, 0, 46, 10, dark); _p(n, 55, 0, 7, 7, Color(0.78, 0.25, 0.20))
			_p(n, 24, 8, 5, 8, metal); _p(n, 30, -8, 9, 4, metal)
		_:  # M4
			_p(n, 7, 0, 14, 7, metal); _p(n, 27, 0, 20, 8, metal); _p(n, 28, -6, 12, 3, dark)
			_p(n, 27, 9, 7, 13, dark, 0.25); _p(n, 46, 0, 16, 4, dark); _p(n, 54, -4, 2.5, 6, dark)
	return n

static func _p(parent: Node2D, x: float, y: float, w: float, h: float, col: Color, rot := 0.0) -> void:
	var s := Shapes.rrect(Vector2(w, h), minf(w, h) * 0.3, col)
	s.position = Vector2(x, y)
	s.rotation = rot
	parent.add_child(s)
