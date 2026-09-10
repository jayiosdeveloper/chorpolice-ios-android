## Fighter — an in-game 3D body (local player, bot or networked remote avatar):
## CharacterBody3D + HumanModel, acceleration-based movement with jump + jetpack,
## footsteps, health, hit / death / respawn, reload state, and a floating health bar +
## name. Units are metres, +Y up, forward = -Z.
class_name Fighter
extends CharacterBody3D

const SPEED := 6.2
const JUMP := 7.2
const THRUST := 6.8
const GRAVITY := 20.0
const MAX_FUEL := 100.0
const HEIGHT := 1.8
const ACCEL := 42.0
const DECEL := 55.0
const AIR_ACCEL := 14.0
const ICE_ACCEL := 9.0
const ICE_DECEL := 4.0

signal died
signal footstep

var team := "player"               # "player" | "enemy"
var is_bot := false
var use_meshy := false
var use_squad := false
var char_id := ""
var is_remote := false
var max_health := 100.0
var health := 100.0
var dead := false
var last_hit_wname := ""             # for the kill feed
var last_hit_by := ""
var current_weapon := 0
var name_text := ""
var slippery := false

var skin_jacket := Color(0, 0, 0, 0)
var skin_jacket2 := Color(0, 0, 0, 0)
var skin_accent := Color(0, 0, 0, 0)
var skin_helmet := Color(0, 0, 0, 0)
var skin_pants := Color(0, 0, 0, 0)
var skin_tone := Color(0, 0, 0, 0)
var jacket: Color
var accent: Color

var fuel := MAX_FUEL
var aim_yaw := 0.0                 # radians, 0 = facing -Z
var aim_pitch := 0.0
var jetting := false
var was_on_floor := true
var land_t := 0.0
var step_t := 0.0

# bot brain (driven by game.gd)
var think_t := 0.0
var fire_t := 1.0
var move_dir := Vector3.ZERO
var wants_dodge := false
var strafe_sign := 1.0
var jump_t := 0.0
var los := false

var model: HumanModel
var jet: CPUParticles3D
var _jet_light: OmniLight3D      # warm glow while thrusting
var hp_bar: MeshInstance3D
var hp_bg: MeshInstance3D
var name_label: Label3D
var overlay: Node3D
var _hit_t := 0.0
var _layer := 0

func _ready() -> void:
	_setup_colors()
	if is_remote:
		collision_layer = 8
		collision_mask = 0
		add_to_group("remote_player")
	elif is_bot or team == "enemy":
		collision_layer = 4
		collision_mask = 1 | 4
		add_to_group("bots")
	else:
		collision_layer = 2
		collision_mask = 1 | 4
		add_to_group("player")
	_layer = collision_layer
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.3

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = HEIGHT
	shape.shape = cap
	shape.position = Vector3(0, HEIGHT / 2.0, 0)
	add_child(shape)

	model = HumanModel.new()
	model.use_meshy = use_meshy
	model.use_squad = use_squad
	model.char_id = char_id
	model.jacket = jacket
	model.accent = accent
	add_child(model)

	_build_jet()
	_build_overlay()

func _setup_colors() -> void:
	if skin_jacket.a > 0.0:
		jacket = skin_jacket
		accent = skin_accent if skin_accent.a > 0.0 else jacket.lightened(0.45)
	elif team == "enemy" or is_bot:
		jacket = Color(0.90, 0.30, 0.32)
		accent = Color(1.0, 0.82, 0.40)
	else:
		jacket = Color(0.27, 0.55, 0.97)
		accent = Color(0.5, 0.95, 1.0)

func _build_jet() -> void:
	jet = CPUParticles3D.new()
	jet.emitting = false
	jet.amount = 90
	jet.lifetime = 0.42
	jet.local_coords = false
	jet.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	jet.emission_sphere_radius = 0.07
	jet.direction = Vector3(0, -1, 0)
	jet.spread = 11.0
	jet.initial_velocity_min = 6.0
	jet.initial_velocity_max = 9.5
	jet.gravity = Vector3(0, 2.0, 0)           # hot gas curls back up as it fades
	jet.angular_velocity_min = -180.0
	jet.angular_velocity_max = 180.0
	jet.scale_amount_min = 0.55
	jet.scale_amount_max = 1.0
	var sc := Curve.new()                       # flare out, then burn away
	sc.add_point(Vector2(0.0, 0.6)); sc.add_point(Vector2(0.25, 1.0)); sc.add_point(Vector2(1.0, 0.15))
	jet.scale_amount_curve = sc
	# real flame sprite on an additive billboard instead of shaded blobs
	var q := QuadMesh.new()
	q.size = Vector2(0.44, 0.44)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = load("res://assets/real/fx/flame_soft.png")
	q.material = mat
	jet.mesh = q
	jet.color_ramp = _ramp([Color(1.0, 0.98, 0.75, 1.0), Color(1.0, 0.72, 0.2, 1.0), Color(1.0, 0.35, 0.05, 0.7), Color(0.25, 0.22, 0.2, 0.0)])
	jet.position = Vector3(0, 1.05, 0.3)
	add_child(jet)
	# warm light thrown on the body / ground while thrusting
	_jet_light = OmniLight3D.new()
	_jet_light.light_color = Color(1.0, 0.6, 0.25)
	_jet_light.light_energy = 3.5
	_jet_light.omni_range = 4.0
	_jet_light.shadow_enabled = false
	_jet_light.visible = false
	_jet_light.position = Vector3(0, 0.75, 0.3)
	add_child(_jet_light)

static func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	for i in cols.size():
		offs.append(float(i) / float(cols.size() - 1))
	g.offsets = offs
	g.colors = PackedColorArray(cols)
	return g

# MARK: drive

## move: world-space horizontal vector (length ≤ 1). jet: hold to fly (burns fuel).
## jump: rising edge → hop from the floor.
func control(move: Vector3, want_jet: bool, jump: bool, delta: float) -> void:
	var on_floor := is_on_floor()
	var target := Vector3(move.x, 0, move.z) * SPEED
	var cur := Vector3(velocity.x, 0, velocity.z)
	var accel: float
	if on_floor:
		if slippery:
			accel = ICE_ACCEL if target.length() > 0.1 else ICE_DECEL
		else:
			accel = ACCEL if target.length() > 0.1 else DECEL
	else:
		accel = AIR_ACCEL
	cur = cur.move_toward(target, accel * delta)
	velocity.x = cur.x
	velocity.z = cur.z
	if jump and on_floor:
		velocity.y = JUMP
		on_floor = false
	var thrusting := want_jet and fuel > 0.0 and not on_floor
	if thrusting:
		velocity.y = minf(velocity.y + 30.0 * delta, THRUST)
		if velocity.y < 1.0:
			velocity.y = 1.0
		fuel = maxf(0.0, fuel - 40.0 * delta)
	else:
		velocity.y -= GRAVITY * delta
		fuel = minf(MAX_FUEL, fuel + (30.0 if on_floor else 8.0) * delta)
	set_thrust(thrusting)
	move_and_slide()
	animate(delta)
	# footsteps
	if is_on_floor() and cur.length() > 1.5:
		step_t -= delta * cur.length() / SPEED
		if step_t <= 0.0:
			step_t = 0.36
			footstep.emit()
	else:
		step_t = 0.1

func set_thrust(on: bool) -> void:
	jetting = on
	if jet:
		jet.emitting = on
		if _jet_light:
			_jet_light.visible = on

func set_aim(yaw: float, pitch := 0.0) -> void:
	aim_yaw = yaw
	aim_pitch = clampf(pitch, -1.2, 1.2)
	if model:
		model.rotation.y = yaw
		model.set_pitch(aim_pitch)

func aim_dir() -> Vector3:
	var c := cos(aim_pitch)
	return Vector3(-sin(aim_yaw) * c, sin(aim_pitch), -cos(aim_yaw) * c)

func forward() -> Vector3:
	return Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))

func right() -> Vector3:
	return Vector3(cos(aim_yaw), 0.0, -sin(aim_yaw))

func muzzle_position() -> Vector3:
	if model and model.gun:
		return model.muzzle_global()
	return global_position + Vector3(0, 1.3, 0) + forward() * 0.6

func eye_position() -> Vector3:
	return global_position + Vector3(0, 1.55, 0)

func set_weapon(t: int) -> void:
	current_weapon = t
	if model:
		model.set_weapon(t)

func is_reloading() -> bool:
	return model != null and model.reloading

## Picks the animation from the current motion. Remotes pass their synced values.
func animate(delta: float, grounded := true, hspeed := -1.0) -> void:
	if not model or dead:
		return
	var on_floor := is_on_floor() if not is_remote else grounded
	var h := Vector2(velocity.x, velocity.z).length() if hspeed < 0.0 else hspeed
	if _hit_t > 0.0:
		_hit_t -= delta
	if not on_floor:
		model.play("jump" if (velocity.y > 1.0 or jetting) else "fall")
		was_on_floor = false
		return
	if not was_on_floor:
		was_on_floor = true
		land_t = 0.18
		footstep.emit()                     # landing thump + dust
	if land_t > 0.0:
		land_t -= delta
		model.play("land")
		return
	if h > 0.6:
		var fwd := forward()
		var rgt := right()
		var v := Vector3(velocity.x, 0, velocity.z).normalized()
		var f := v.dot(fwd)
		var s := v.dot(rgt)
		var sp := clampf(h / SPEED, 0.5, 1.4)
		if f < -0.5:
			model.play("back", sp)
		elif s > 0.7:
			model.play("strafe_r", sp)
		elif s < -0.7:
			model.play("strafe_l", sp)
		elif h < 2.6:
			model.play("walk", clampf(h / 2.4, 0.6, 1.3))
		else:
			model.play("run", sp)
	else:
		model.play("idle")

# MARK: combat

func take_hit(dmg: float) -> bool:
	if dead:
		return false
	health = maxf(0.0, health - dmg)
	_update_hp()
	_flash()
	if health <= 0.0:
		dead = true
		_set_body_visible(false)
		died.emit()
		return true
	_hit_t = 0.25
	return false

func heal(amount: float) -> void:
	if dead:
		return
	health = minf(max_health, health + amount)
	_update_hp()

func respawn(pos: Vector3) -> void:
	global_position = pos
	health = max_health
	dead = false
	fuel = MAX_FUEL
	velocity = Vector3.ZERO
	_set_body_visible(true)
	_update_hp()

## Dead bodies stay visible (fallen) for a moment; the overlay + collision go away.
func _set_body_visible(v: bool) -> void:
	collision_layer = _layer if v else 0
	_overlay_visible(v)
	if model:
		if v:
			model.visible = true
			model.revive()
		else:
			model.die()
			# once the fall has settled, leave a corpse behind (stays ~8 s, then fades) and
			# hide the live model so this fighter can respawn / be freed
			var tw := create_tween()
			tw.tween_interval(1.4)
			tw.tween_callback(func() -> void:
				if dead and is_instance_valid(model):
					_leave_corpse()
					model.visible = false)
	if not v:
		set_thrust(false)

## Duplicate the posed skinned mesh as a static corpse in the scene (no anim / IK / rig),
## keep it for a while, then fade it out.
func _leave_corpse() -> void:
	if not model or not model._inst or not get_tree().current_scene:
		return
	var src: Node3D = model._inst
	var c: Node3D = src.duplicate()
	var strip: Array = []
	var st: Array = [c]
	while not st.is_empty():
		var n: Node = st.pop_back()
		if n is AnimationPlayer or n is SkeletonIK3D or n is AimRig:
			strip.append(n)
		for ch in n.get_children():
			st.append(ch)
	for n in strip:
		n.get_parent().remove_child(n)
		n.queue_free()
	get_tree().current_scene.add_child(c)
	c.global_transform = src.global_transform
	var tw := c.create_tween()
	tw.tween_interval(8.0)
	tw.tween_callback(func() -> void:
		var mats: Array = []
		var s2: Array = [c]
		while not s2.is_empty():
			var n: Node = s2.pop_back()
			if n is MeshInstance3D and (n as MeshInstance3D).mesh:
				var mi := n as MeshInstance3D
				for si in mi.mesh.get_surface_count():
					var m := mi.get_active_material(si)
					if m is BaseMaterial3D:
						var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
						d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						mi.set_surface_override_material(si, d)
						mats.append(d)
			for ch in n.get_children():
				s2.append(ch)
		var ft := c.create_tween()
		ft.set_parallel(true)
		for d in mats:
			ft.tween_property(d, "albedo_color:a", 0.0, 1.5)
		ft.chain().tween_callback(c.queue_free))

func _overlay_visible(v: bool) -> void:
	if overlay:
		overlay.visible = v

func _flash() -> void:
	if model:
		model.flash()

# MARK: overlay (health bar + name)

func _build_overlay() -> void:
	overlay = Node3D.new()
	overlay.position = Vector3(0, HEIGHT + 0.42, 0)
	add_child(overlay)

	hp_bg = _quad(Vector2(0.9, 0.1), Color(0, 0, 0, 0.55))
	overlay.add_child(hp_bg)
	hp_bar = _quad(Vector2(0.9, 0.1), Color(0.3, 0.85, 0.4))
	hp_bar.position.z = 0.001
	overlay.add_child(hp_bar)

	name_label = Label3D.new()
	name_label.text = name_text
	name_label.font_size = 40
	name_label.pixel_size = 0.006
	name_label.outline_size = 8
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.position = Vector3(0, 0.22, 0)
	name_label.modulate = Color(1, 1, 1, 0.95)
	overlay.add_child(name_label)
	_update_hp()

func _quad(size: Vector2, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.render_priority = 2
	q.material = m
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func set_name_text(s: String) -> void:
	name_text = s
	if name_label:
		name_label.text = s

func _update_hp() -> void:
	if not hp_bar:
		return
	var frac := clampf(health / max_health, 0.0, 1.0)
	hp_bar.scale.x = maxf(frac, 0.001)
	hp_bar.position.x = -0.45 * (1.0 - frac)
	var m := hp_bar.mesh.surface_get_material(0) as StandardMaterial3D
	if m:
		m.albedo_color = Color(0.3, 0.85, 0.4) if frac > 0.5 else (Color(0.95, 0.75, 0.2) if frac > 0.25 else Color(0.95, 0.3, 0.25))
