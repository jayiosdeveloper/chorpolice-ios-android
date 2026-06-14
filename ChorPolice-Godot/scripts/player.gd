## Player — procedural operative (helmet/visor/vest/two bracing arms/legs/jetpack)
## with combat: health, weapon swap (from Weapons), take_hit/die/respawn, plus a
## floating health bar + name. Bot extends this. Godot is y-DOWN (up = -y).
class_name Player
extends CharacterBody2D

const SPEED := 320.0
const THRUST := 330.0
const GRAVITY := 1100.0
const MAX_FUEL := 100.0
const GUN_SCALE := 1.35

signal died

var team := "player"           # "player" | "enemy" (Bot sets enemy in _init)
var max_health := 100.0
var health := 100.0
var dead := false
var current_weapon := 0
var muzzle_len := 54.0
var name_text := ""

var is_remote := false               # a networked avatar: no physics/collision, lerped
var skin_jacket := Color(0, 0, 0, 0) # alpha > 0 → use these instead of the team defaults
var skin_jacket2 := Color(0, 0, 0, 0) # gradient bottom (alpha 0 → flat = jacket)
var skin_accent := Color(0, 0, 0, 0)
var skin_helmet := Color(0, 0, 0, 0) # alpha 0 → derived from jacket
var skin_pants := Color(0, 0, 0, 0)
var skin_tone := Color(0, 0, 0, 0)

var fuel := MAX_FUEL
var facing := 1.0
var aim_angle := 0.0
var run_phase := 0.0

var body_group: Node2D
var arm_rig: Node2D
var left_leg: Node2D
var right_leg: Node2D
var jet: CPUParticles2D
var hp_bar: Polygon2D
var hp_bg: Polygon2D
var name_label: Label

var jacket: Color
var jacket2: Color
var jacket_dark: Color
var helmet: Color
var pants: Color
var accent: Color
var skin: Color
var gear: Color
var gear_dark: Color
var boot_col: Color

func _ready() -> void:
	_setup_colors()
	if is_remote:
		collision_layer = 8          # REMOTE: bullets visually stop on networked avatars…
		collision_mask = 0           # …but the avatar itself collides with nothing (owner is authoritative)
		add_to_group("remote_player")
	else:
		collision_layer = (4 if team == "enemy" else 2)
		collision_mask = 1
		add_to_group("bots" if team == "enemy" else "player")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 72)
	shape.shape = rect
	shape.position = Vector2(0, -36)
	add_child(shape)

	body_group = Node2D.new()
	add_child(body_group)
	arm_rig = Node2D.new()
	arm_rig.position = Vector2(2, -58)
	arm_rig.z_index = 5
	add_child(arm_rig)

	_build_body()
	set_weapon(0)
	_build_overlay()

func _setup_colors() -> void:
	if skin_jacket.a > 0.0:
		jacket = skin_jacket
		jacket2 = skin_jacket2 if skin_jacket2.a > 0.0 else jacket
		accent = skin_accent
		helmet = skin_helmet if skin_helmet.a > 0.0 else jacket
		pants = skin_pants if skin_pants.a > 0.0 else jacket.darkened(0.55)
		skin = skin_tone if skin_tone.a > 0.0 else Color(0.86, 0.66, 0.5)
	elif team == "enemy":
		jacket = Color(0.90, 0.30, 0.32)
		jacket2 = jacket
		accent = Color(1.0, 0.82, 0.40)
		helmet = jacket
		pants = Color(0.45, 0.13, 0.14)
		skin = Color(0.74, 0.52, 0.38)
	else:
		jacket = Color(0.27, 0.55, 0.97)
		jacket2 = jacket
		accent = Color(0.5, 0.95, 1.0)
		helmet = jacket
		pants = Color(0.13, 0.27, 0.5)
		skin = Color(0.86, 0.66, 0.5)
	jacket_dark = jacket.darkened(0.32)
	gear = Color(0.26, 0.28, 0.34)
	gear_dark = gear.darkened(0.3)
	boot_col = Color(0.16, 0.15, 0.18)

# MARK: drive

func control(move: Vector2, delta: float) -> void:
	velocity.x = move.x * SPEED
	var want_thrust := move.y < -0.15 and fuel > 0.0
	if want_thrust:
		velocity.y = -THRUST
		fuel = max(0.0, fuel - 40.0 * delta)
	else:
		velocity.y += GRAVITY * delta
		fuel = min(MAX_FUEL, fuel + 26.0 * delta)
	set_thrust(want_thrust)
	move_and_slide()
	animate(delta)

func set_thrust(on: bool) -> void:
	if jet:
		jet.emitting = on

func set_aim(angle: float) -> void:
	aim_angle = angle
	facing = 1.0 if cos(angle) >= 0.0 else -1.0
	body_group.scale.x = facing
	arm_rig.rotation = angle
	arm_rig.scale.y = facing

func animate(delta: float, grounded := true, hspeed := 0.0, use_physics := true) -> void:
	var on_floor := is_on_floor() if use_physics else grounded
	var sp := absf(velocity.x) if use_physics else hspeed
	if not on_floor:
		left_leg.rotation = lerpf(left_leg.rotation, 0.4, 0.2)
		right_leg.rotation = lerpf(right_leg.rotation, -0.3, 0.2)
	elif sp > 12.0:
		run_phase += delta * (sp / 34.0)
		var swing := sin(run_phase) * 0.6
		left_leg.rotation = swing
		right_leg.rotation = -swing
	else:
		left_leg.rotation = lerpf(left_leg.rotation, 0.0, 0.25)
		right_leg.rotation = lerpf(right_leg.rotation, 0.0, 0.25)

func muzzle_position() -> Vector2:
	return arm_rig.to_global(Vector2(muzzle_len * GUN_SCALE, 0))

# MARK: combat

func take_hit(dmg: float) -> bool:
	if dead:
		return false
	health = maxf(0.0, health - dmg)
	_update_hp()
	_flash()
	if health <= 0.0:
		dead = true
		body_group.visible = false
		arm_rig.visible = false
		_overlay_visible(false)
		died.emit()
		return true
	return false

func heal(amount: float) -> void:
	if dead:
		return
	health = minf(max_health, health + amount)
	_update_hp()

func respawn(pos: Vector2) -> void:
	position = pos
	health = max_health
	dead = false
	fuel = MAX_FUEL
	velocity = Vector2.ZERO
	body_group.visible = true
	arm_rig.visible = true
	_overlay_visible(true)
	_update_hp()

func _overlay_visible(v: bool) -> void:
	hp_bar.visible = v
	name_label.visible = v
	if hp_bg:
		hp_bg.visible = v

func _flash() -> void:
	var tw := create_tween()
	tw.tween_property(body_group, "modulate:a", 0.35, 0.05)
	tw.tween_property(body_group, "modulate:a", 1.0, 0.12)

# MARK: overlay (health bar + name) — child of Player so it never flips

func _build_overlay() -> void:
	hp_bg = Shapes.rrect(Vector2(48, 7), 3, Color(0, 0, 0, 0.5))
	hp_bg.position = Vector2(0, -118)
	hp_bg.z_index = 20
	add_child(hp_bg)
	hp_bar = Polygon2D.new()
	hp_bar.color = Color(0.3, 0.85, 0.4)
	hp_bar.z_index = 21
	add_child(hp_bar)
	_update_hp()

	name_label = Label.new()
	name_label.text = name_text
	name_label.position = Vector2(-60, -142)
	name_label.size = Vector2(120, 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.z_index = 21
	add_child(name_label)

func set_name_text(s: String) -> void:
	name_text = s
	if name_label:
		name_label.text = s

func _update_hp() -> void:
	var frac := clampf(health / max_health, 0.0, 1.0)
	var w := 48.0 * frac
	hp_bar.polygon = PackedVector2Array([
		Vector2(-24, -3.5), Vector2(-24 + w, -3.5), Vector2(-24 + w, 3.5), Vector2(-24, 3.5)])
	hp_bar.position = Vector2(0, -118)

# MARK: build (character)

func _add(part: Node2D, x: float, up: float, z: int) -> void:
	part.position = Vector2(x, -up)
	part.z_index = z
	body_group.add_child(part)

func _build_body() -> void:
	var shadow := Shapes.circ(1, Color(0, 0, 0, 0.22))
	shadow.scale = Vector2(24, 6)
	shadow.position = Vector2(2, -1)
	shadow.z_index = -6
	body_group.add_child(shadow)

	_add(Shapes.rrect(Vector2(18, 32), 6, gear), -16, 58, -3)
	_add(Shapes.rrect(Vector2(12, 8), 3, gear_dark), -16, 42, -3)

	left_leg = _make_leg(-8.0)
	right_leg = _make_leg(8.0)

	var torso := Shapes.rrect(Vector2(37, 36), 11, jacket)
	_grad_poly(torso, jacket, jacket2)        # vertical gradient when jacket2 differs
	_add(torso, 0, 55, 0)
	_add(Shapes.rrect(Vector2(37, 8), 3, pants), 0, 40, 1)
	_add(Shapes.circ(4, accent), -4, 58, 2)
	_add(Shapes.rrect(Vector2(18, 14), 6, jacket), -16, 70, 3)
	_add(Shapes.rrect(Vector2(18, 14), 6, jacket), 16, 70, 3)

	_add(Shapes.rrect(Vector2(30, 28), 11, skin), 3, 84, 4)
	_add(Shapes.rrect(Vector2(34, 22), 11, helmet), 3, 94, 6)
	_add(Shapes.rrect(Vector2(21, 8), 4, accent), 6, 88, 7)
	_add(Shapes.rrect(Vector2(3, 12), 1, jacket_dark), -10, 104, 5)
	_add(Shapes.circ(3, accent), -10, 111, 5)

	# jetpack exhaust (behind the body; streams down while thrusting)
	jet = CPUParticles2D.new()
	jet.position = Vector2(-15, -38)
	jet.z_index = -4
	jet.emitting = false
	jet.local_coords = false
	jet.amount = 22
	jet.lifetime = 0.36
	jet.direction = Vector2(0, 1)
	jet.spread = 12.0
	jet.gravity = Vector2(0, 320)
	jet.initial_velocity_min = 150.0
	jet.initial_velocity_max = 230.0
	jet.scale_amount_min = 3.0
	jet.scale_amount_max = 6.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 0.7, 0.95), Color(1, 0.6, 0.2, 0.7), Color(1, 0.3, 0.1, 0.0)])
	jet.color_ramp = ramp
	body_group.add_child(jet)

func set_weapon(t: int) -> void:
	current_weapon = t
	var d := Weapons.data(t)
	muzzle_len = d["muzzle"]
	for c in arm_rig.get_children():
		c.queue_free()
	var grips: Array = d["grips"]
	var back_x := float(grips[0]) * GUN_SCALE
	var front_x := float(grips[1]) * GUN_SCALE

	arm_rig.add_child(_z(Shapes.limb(Vector2.ZERO, Vector2(back_x * 0.45, 15), 12, jacket_dark), 0))
	arm_rig.add_child(_z(Shapes.limb(Vector2(back_x * 0.45, 15), Vector2(back_x, 0), 11, jacket_dark), 0))

	var gun := Weapons.art(t)
	gun.scale = Vector2(GUN_SCALE, GUN_SCALE)
	gun.z_index = 2
	arm_rig.add_child(gun)

	var bh := _make_hand()
	bh.position = Vector2(back_x, 0)
	bh.z_index = 3
	arm_rig.add_child(bh)

	if not is_equal_approx(front_x, back_x):
		arm_rig.add_child(_z(Shapes.limb(Vector2.ZERO, Vector2(front_x * 0.5, 16), 12, jacket), 4))
		arm_rig.add_child(_z(Shapes.limb(Vector2(front_x * 0.5, 16), Vector2(front_x, 0), 11, jacket), 4))
		var fh := _make_hand()
		fh.position = Vector2(front_x, 0)
		fh.z_index = 5
		arm_rig.add_child(fh)

func _make_leg(x: float) -> Node2D:
	var leg := Node2D.new()
	leg.position = Vector2(x, -40)
	leg.z_index = -1
	var thigh := Shapes.rrect(Vector2(15, 40), 6, pants)
	thigh.position = Vector2(0, 20)
	leg.add_child(thigh)
	var b := Shapes.rrect(Vector2(17, 11), 4, boot_col)
	b.position = Vector2(3, 40)
	leg.add_child(b)
	body_group.add_child(leg)
	return leg

func _make_hand() -> Node2D:
	var n := Node2D.new()
	n.add_child(Shapes.rrect(Vector2(12, 15), 5, skin))
	for i in 3:
		var crease := Shapes.rrect(Vector2(12, 1.6), 0.8, skin.darkened(0.3))
		crease.position = Vector2(0, -4.5 + float(i) * 4.0)
		n.add_child(crease)
	var thumb := Shapes.rrect(Vector2(4.6, 7.5), 2.2, skin)
	thumb.position = Vector2(-5, -4)
	thumb.rotation = 0.35
	n.add_child(thumb)
	return n

func _z(node: Node2D, z: int) -> Node2D:
	node.z_index = z
	return node

func _grad_poly(p: Polygon2D, top_c: Color, bot_c: Color) -> void:
	if top_c == bot_c:
		return
	var pts := p.polygon
	if pts.is_empty():
		return
	var ymin := pts[0].y
	var ymax := pts[0].y
	for v in pts:
		ymin = minf(ymin, v.y)
		ymax = maxf(ymax, v.y)
	var span := maxf(0.001, ymax - ymin)
	var cols := PackedColorArray()
	for v in pts:
		cols.append(top_c.lerp(bot_c, (v.y - ymin) / span))
	p.vertex_colors = cols
