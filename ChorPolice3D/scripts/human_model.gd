## HumanModel — the real human soldier character (Mixamo "Vanguard", via the three.js
## examples, see CREDITS.md): a rigged + skinned mesh with Idle / Walk / Run clips, a
## procedural layer (AimRig) for aim pitch / air pose / flinch, two-arm IK holding a
## GunModel in front of the chest, reload + recoil animations, death fall, and a team /
## skin tint. Same public surface as the old RobotModel so Fighter / Player use it as-is.
class_name HumanModel
extends Node3D

const SCENE: PackedScene = preload("res://assets/models/human/soldier.glb")
const MESHY_PATH := "res://assets/real/chars/hero2/hero2.glb"
var use_meshy := false
var use_squad := false
var char_path := ""                    # explicit model override (Mixamo-rigged); shares squad anims
var char_tex := ""                     # optional albedo texture for the chosen character
var char_id := ""                      # picks a model from CHAR_MODELS
var _char_is_squad := true
var _use_mesh_scale := false
var _hide_meshes: Array = []           # mesh-name substrings to hide (e.g. a model's built-in gun)

# Selectable Mixamo-rigged characters (all share the black_squad animation set).
const CHAR_MODELS := {
	"bravo": {"path": SQUAD_PATH, "tex": ""},
	"striker": {"path": "res://assets/real/chars/hero_new/hero_new.fbx", "tex": "res://assets/real/chars/hero_new/hero_new_albedo.png"},
	"nova": {"path": "res://assets/real/chars/hero_f/hero_f.fbx", "tex": "res://assets/real/chars/hero_f/hero_f_albedo.png"},
}
const SQUAD_PATH := "res://assets/real/chars/black_squad/black_squad.fbx"
var SQUAD_GUN_POS := Vector3(0.0, 0.0, 0.14)
var SQUAD_GUN_ROT := Vector3(90, 0, 180)
var _fire_t := 0.0
var _lhand_bone: BoneAttachment3D
const SQUAD_ANIMS := {
	"idle": "Rifle Idle", "walk": "Rifle Walk To Stop", "run": "Rifle Run (1)",
	"jump": "Jump Up", "fall": "Jump Loop", "land": "Jump Down",
	"death": "Rifle Run To Dying", "fire": "Firing Rifle",
}
var _clip_idle := "Idle"
var _clip_walk := "Walk"
var _clip_run := "Run"
var _death_tw: Tween
var _gun_mount: Node3D
var _hand_bone: BoneAttachment3D
var _base_pos := Vector3.ZERO
const MODEL_YAW := 0.0
const BLEND := 0.2
const HEIGHT := 1.83

var jacket := Color(0.27, 0.55, 0.97)
var accent := Color(0.5, 0.95, 1.0)

var anim: AnimationPlayer
var skeleton: Skeleton3D
var rig: AimRig
var gun: GunModel
var gun_hold: Node3D               # chest-attached pivot the gun hangs from (pitches with the aim)
var gun_type := -1
var muzzle: Marker3D               # kept for API compatibility (gun.muzzle is used)
var body_mat: StandardMaterial3D
var visor_mat: StandardMaterial3D
var state := ""
var reloading := false
var dead := false
var _inst: Node3D
var _ik_r: SkeletonIK3D
var _ik_l: SkeletonIK3D
var _hand_r: Node3D
var _hand_l: Node3D
var _hold_home := Vector3(0.12, 0.02, -0.28)
var _pitch := 0.0
var _ads := 0.0
var ads := false
var _reload_tw: Tween
var _chest: BoneAttachment3D
var aim_dir := Vector3.ZERO             # world direction the gun must point (set by the game each frame)

## Point the gun along a world direction (muzzle -> crosshair target). Zero = body forward + pitch.
func set_aim_dir(d: Vector3) -> void:
	aim_dir = d

func _ready() -> void:
	var scene: PackedScene = SCENE
	if use_squad:
		# character model path: explicit char_path, else CHAR_MODELS[char_id], else CP_CHARPATH env,
		# else black_squad. All are Mixamo-rigged (mixamorig_ bones) so they share the squad anim set.
		var cp := char_path
		if char_id == "":
			char_id = OS.get_environment("CP_CHARID")
		if cp == "" and char_id != "" and CHAR_MODELS.has(char_id):
			cp = String(CHAR_MODELS[char_id]["path"])
			char_tex = String(CHAR_MODELS[char_id].get("tex", ""))
			_use_mesh_scale = bool(CHAR_MODELS[char_id].get("mesh_scale", false))
			_hide_meshes = CHAR_MODELS[char_id].get("hide", [])
		if cp == "":
			cp = OS.get_environment("CP_CHARPATH")
			if char_tex == "":
				char_tex = OS.get_environment("CP_CHARTEX")
			if OS.get_environment("CP_MESHSCALE") == "1":
				_use_mesh_scale = true
		if cp == "" or not ResourceLoader.exists(cp):
			cp = SQUAD_PATH
			char_tex = ""
		_char_is_squad = (cp == SQUAD_PATH)
		if ResourceLoader.exists(cp):
			scene = load(cp)
	elif use_meshy and ResourceLoader.exists(MESHY_PATH):
		scene = load(MESHY_PATH)
	_inst = scene.instantiate()
	# safety: if a chosen character FBX has no mesh (e.g. an anim-only "Without Skin"
	# export), fall back to the default soldier so nothing renders invisible.
	if use_squad and _find_type(_inst, "MeshInstance3D") == null and ResourceLoader.exists(SQUAD_PATH):
		_inst.free()
		_inst = load(SQUAD_PATH).instantiate()
		char_tex = ""
		_char_is_squad = true
	_inst.rotation.y = PI if (use_meshy or use_squad) else MODEL_YAW
	if use_meshy:
		_inst.scale = Vector3(1.18, 1.18, 1.18)
	add_child(_inst)
	if not _hide_meshes.is_empty():
		_apply_hide(_inst)
	_base_pos = _inst.position
	anim = _find_type(_inst, "AnimationPlayer") as AnimationPlayer
	skeleton = _find_type(_inst, "Skeleton3D") as Skeleton3D
	_resolve_clips()
	if use_squad:
		_scale_to_height(1.85)
		_merge_squad_anims()
	_setup_materials(_inst)
	_setup_rig()
	set_weapon(0)
	play("idle")

func _find_type(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find_type(c, cls)
		if r:
			return r
	return null

# MARK: materials

func _setup_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				if use_squad and m is StandardMaterial3D:
					var ds := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					ds.metallic = 0.0
					ds.roughness = clampf(ds.roughness, 0.6, 1.0)
					if char_tex != "" and ResourceLoader.exists(char_tex):
						ds.albedo_texture = load(char_tex)     # real Meshy colour texture
						ds.albedo_color = Color(1.08, 1.08, 1.08)
					elif _char_is_squad:
						ds.albedo_color = Color(1.35, 1.35, 1.35)   # lift the dark tactical gear
					else:
						ds.albedo_color = Color(1.05, 1.05, 1.05)
					mi.set_surface_override_material(s, ds)
					continue
				if m is StandardMaterial3D:
					var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					if String(d.resource_name).to_lower().contains("visor"):
						visor_mat = d
					else:
						body_mat = d
					mi.set_surface_override_material(s, d)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in n.get_children():
		_setup_materials(c)
	if body_mat and visor_mat:
		set_colors(jacket, accent)

static func _tint(c: Color) -> Color:
	# keep the suit readable: 55 % toward the team colour, lifted so dark colours don't go black
	return Color(0.45 + c.r * 0.75, 0.45 + c.g * 0.75, 0.45 + c.b * 0.75)

func set_colors(j: Color, a: Color) -> void:
	jacket = j
	accent = a
	if body_mat:
		body_mat.albedo_color = _tint(j)
	if visor_mat:
		visor_mat.albedo_color = a
		visor_mat.emission_enabled = true
		visor_mat.emission = a
		visor_mat.emission_energy_multiplier = 1.6
		visor_mat.metallic = 0.6
		visor_mat.roughness = 0.2

func flash() -> void:
	if not body_mat:
		return
	var tw := create_tween()
	tw.tween_property(body_mat, "albedo_color", Color(1.8, 1.4, 1.4), 0.04)
	tw.tween_property(body_mat, "albedo_color", _tint(jacket), 0.16)
	if rig:
		rig.flinch = 1.0
		var tw2 := create_tween()
		tw2.tween_property(rig, "flinch", 0.0, 0.35)

# MARK: rig (chest pivot + arm IK)

static func _norm(x: String) -> String:
	return x.to_lower().replace("0", "")

func _bone(suffix: String) -> String:
	var want := _norm(suffix)
	for i in skeleton.get_bone_count():
		if _norm(skeleton.get_bone_name(i)).ends_with(want):
			return skeleton.get_bone_name(i)
	return ""

## Find the actual clip names for idle/walk/run (works for soldier + meshy + others).
func _resolve_clips() -> void:
	if not anim:
		return
	var list := anim.get_animation_list()
	_clip_idle = ""; _clip_walk = ""; _clip_run = ""
	for c in list:
		var lc := String(c).to_lower()
		if _clip_run == "" and lc.contains("run"): _clip_run = c
		elif _clip_walk == "" and lc.contains("walk"): _clip_walk = c
		elif _clip_idle == "" and (lc.contains("idle") or lc.contains("base")): _clip_idle = c
	if _clip_idle == "": _clip_idle = list[0] if list.size() > 0 else ""
	if _clip_walk == "": _clip_walk = _clip_run if _clip_run != "" else _clip_idle
	if _clip_run == "": _clip_run = _clip_walk

## Normalise a skinned FBX to a target height (its AABB is only known once posed).
func _scale_to_height(h: float) -> void:
	# Some FBX nest the skeleton under a scaled Armature, so bone-local rests lie about
	# size — those characters set mesh_scale to measure the real mesh bounds instead.
	if _use_mesh_scale:
		# skinned-mesh world bounds are only valid once the node is in-tree and posed;
		# wait a frame so get_aabb()/global_transform return real values (not identity).
		if is_inside_tree():
			await get_tree().process_frame
		var mh := _mesh_world_height()
		if mh > 0.001:
			_inst.scale *= (h / mh)
		_inst.position.y -= _mesh_world_bottom()   # ground the feet to y=0
		return
	if not skeleton:
		return
	var lo := 1e20; var hi := -1e20
	for i in skeleton.get_bone_count():
		var y := skeleton.get_bone_global_rest(i).origin.y
		lo = minf(lo, y); hi = maxf(hi, y)
	var span := maxf(hi - lo, 0.01)
	var cur := span * _inst.scale.y
	if cur > 0.001:
		_inst.scale *= (h / cur)

func _mesh_world_height() -> float:
	var lo := 1e20; var hi := -1e20
	var found := false
	var stack: Array = [_inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is VisualInstance3D:
			var a: AABB = (n as Node3D).global_transform * (n as VisualInstance3D).get_aabb()
			if a.size.y > 0.0001:
				lo = minf(lo, a.position.y); hi = maxf(hi, a.position.y + a.size.y); found = true
		for c in n.get_children():
			stack.append(c)
	return (hi - lo) if found else 0.0

## Hide mesh parts whose name contains any of the _hide_meshes substrings (built-in gun etc.).
func _apply_hide(n: Node) -> void:
	if n is MeshInstance3D:
		var nm := n.name.to_lower()
		for p in _hide_meshes:
			if nm.contains(String(p)):
				(n as MeshInstance3D).visible = false
				break
	for c in n.get_children():
		_apply_hide(c)

## Lowest mesh point in world Y (to sit the feet on the ground).
func _mesh_world_bottom() -> float:
	var lo := 1e20
	var stack: Array = [_inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is VisualInstance3D:
			var a: AABB = (n as Node3D).global_transform * (n as VisualInstance3D).get_aabb()
			if a.size.y > 0.0001:
				lo = minf(lo, a.position.y)
		for c in n.get_children():
			stack.append(c)
	return 0.0 if lo > 1e19 else lo

## Loads each Mixamo animation FBX and copies its single clip into our AnimationPlayer.
func _merge_squad_anims() -> void:
	if not anim:
		return
	var lib := AnimationLibrary.new()
	for state in SQUAD_ANIMS:
		var fp: String = "res://assets/real/chars/black_squad/anims/%s.fbx" % SQUAD_ANIMS[state]
		if not ResourceLoader.exists(fp):
			continue
		var ai := (load(fp) as PackedScene).instantiate()
		var ap := _find_type(ai, "AnimationPlayer") as AnimationPlayer
		if ap:
			for cn in ap.get_animation_list():
				var a := ap.get_animation(cn)
				if a:
					var dup: Animation = a.duplicate()
					_make_in_place(dup)
					_retarget(dup)   # remap node path + bone names onto THIS rig (Mixamo/Meshy/GLB nesting)
					if state in ["idle", "walk", "run", "fall"]:
						dup.loop_mode = Animation.LOOP_LINEAR
					lib.add_animation(state, dup)
					break
		ai.queue_free()
	if anim.has_animation_library(""):
		anim.remove_animation_library("")
	anim.add_animation_library("", lib)
	_clip_idle = "idle"; _clip_walk = "walk"; _clip_run = "run"

## Bone-name key that ignores rig-specific naming (mixamorig_ prefix, underscores, the
## Spine1 vs Spine01 style, case) so a Mixamo clip retargets onto any humanoid skeleton.
static func _bnorm(s: String) -> String:
	return s.to_lower().replace("mixamorig_", "").replace("mixamorig:", "").replace("_", "").replace("0", "")

## Rewrite each animation track to point at THIS character's skeleton + bone names, so
## the shared Mixamo clips drive the loaded rig regardless of its bone naming (Mixamo,
## Meshy, etc.) and node nesting (Skeleton3D vs Armature/Skeleton3D).
func _retarget(a: Animation) -> void:
	if not skeleton or not anim:
		return
	var base: Node = anim.get_node_or_null(anim.root_node)
	if base == null:
		base = anim.get_parent()
	var rel := String(base.get_path_to(skeleton))
	var bmap := {}
	for i in skeleton.get_bone_count():
		bmap[_bnorm(skeleton.get_bone_name(i))] = skeleton.get_bone_name(i)
	for ti in a.get_track_count():
		var p := String(a.track_get_path(ti))
		var colon := p.rfind(":")
		if colon < 0:
			continue
		var key := _bnorm(p.substr(colon + 1))
		if bmap.has(key):
			a.track_set_path(ti, NodePath(rel + ":" + String(bmap[key])))

## Removes the root (Hips) horizontal drift from a clip so it animates in place
## (Mixamo clips downloaded without "In Place" otherwise slide forward then snap back).
func _make_in_place(a: Animation) -> void:
	# Remove the Hips POSITION track entirely. Mixamo clips store hip translation in the
	# SOURCE character's scale; keeping it breaks other Mixamo characters (huge offset →
	# model flies off screen). Dropping it leaves a pure-rotation clip that retargets onto
	# ANY Mixamo skeleton at any scale, staying grounded at its own rest hip position.
	var to_remove: Array[int] = []
	for ti in a.get_track_count():
		if a.track_get_type(ti) != Animation.TYPE_POSITION_3D:
			continue
		if String(a.track_get_path(ti)).to_lower().contains("hips"):
			to_remove.append(ti)
	to_remove.reverse()
	for ti in to_remove:
		a.remove_track(ti)

func _setup_rig() -> void:
	rig = AimRig.new()
	skeleton.add_child(rig)
	if use_squad:
		# The gun hangs from a chest pivot that is pointed along the AIM direction every
		# frame (so the barrel goes where the crosshair is), and both hands are IK-pulled
		# onto the gun's grip / foregrip markers — the rifle clips only drive body + legs.
		_chest = BoneAttachment3D.new()
		_chest.bone_name = _bone("Spine2")
		skeleton.add_child(_chest)
		gun_hold = Node3D.new()
		gun_hold.top_level = true
		add_child(gun_hold)
		_gun_mount = Node3D.new()
		gun_hold.add_child(_gun_mount)
		_hand_r = Node3D.new()
		_hand_l = Node3D.new()
		add_child(_hand_r); add_child(_hand_l)
		_hand_r.top_level = true; _hand_l.top_level = true
		_ik_r = _make_ik("RightArm", "RightHand", _hand_r, Vector3(60, -35, 110))
		_ik_l = _make_ik("LeftArm", "LeftHand", _hand_l, Vector3(-60, -35, 110))
		# keep the clip's natural hand orientation (only the wrist is pulled to the gun)
		_ik_r.override_tip_basis = false
		_ik_l.override_tip_basis = false
		_ik_r.stop(); _ik_l.stop()
		return

	_chest = BoneAttachment3D.new()
	_chest.bone_name = _bone("Spine2")
	skeleton.add_child(_chest)
	gun_hold = Node3D.new()
	_chest.add_child(gun_hold)
	gun_hold.top_level = true

	_hand_r = Node3D.new()
	_hand_l = Node3D.new()
	add_child(_hand_r); add_child(_hand_l)
	_hand_r.top_level = true; _hand_l.top_level = true
	_ik_r = _make_ik("RightArm", "RightHand", _hand_r, Vector3(60, -35, 110))
	_ik_l = _make_ik("LeftArm", "LeftHand", _hand_l, Vector3(-60, -35, 110))

func _make_ik(root_suffix: String, tip_suffix: String, target: Node3D, magnet: Vector3) -> SkeletonIK3D:
	var ik := SkeletonIK3D.new()
	ik.root_bone = _bone(root_suffix)
	ik.tip_bone = _bone(tip_suffix)
	ik.override_tip_basis = true
	ik.use_magnet = true
	ik.magnet = magnet
	ik.interpolation = 1.0
	ik.max_iterations = 12
	ik.min_distance = 0.002
	skeleton.add_child(ik)
	ik.target_node = ik.get_path_to(target)
	ik.start()
	return ik

func _process(_delta: float) -> void:
	if use_squad:
		_ads = move_toward(_ads, 1.0 if ads else 0.0, _delta * 5.0)
		_fire_t = maxf(0.0, _fire_t - _delta)
		var have_gun := gun_hold != null and _chest != null and gun != null and not dead
		if have_gun:
			# squad models are yawed 180°, so their forward / right are the node's -Z / -X
			var fwd := (-global_transform.basis.z).normalized()
			var rgt := (-global_transform.basis.x).normalized()
			var dir := aim_dir
			if dir.length_squared() < 0.5:
				dir = Basis(rgt, _pitch) * fwd            # no explicit aim: body forward, pitched
			dir = dir.normalized()
			var hh := _hold_home.lerp(_hold_home + Vector3(-0.07, 0.13, 0.06), _ads)
			var base := _chest.global_transform.origin + rgt * hh.x + Vector3.UP * hh.y + fwd * -hh.z
			var z := -dir                                 # gun space: barrel along -Z
			var x := Vector3.UP.cross(z)
			if x.length_squared() < 0.001:
				x = rgt
			x = x.normalized()
			var y := z.cross(x).normalized()
			gun_hold.global_transform = Transform3D(Basis(x, y, z), base)
			_gun_mount.transform = Transform3D.IDENTITY
			if gun.grip and gun.foregrip:
				# markers sit at the palm; the IK tip is the wrist bone, so step back along the fingers
				var gr := gun.grip.global_transform
				var fg := gun.foregrip.global_transform
				_hand_r.global_transform = Transform3D(gr.basis, gr.origin - gr.basis.y * 0.06)
				_hand_l.global_transform = Transform3D(fg.basis, fg.origin - fg.basis.y * 0.06)
				if _ik_r and not _ik_r.is_running(): _ik_r.start()
				if _ik_l and not _ik_l.is_running(): _ik_l.start()
		else:
			if _ik_r and _ik_r.is_running(): _ik_r.stop()
			if _ik_l and _ik_l.is_running(): _ik_l.stop()
		return
	if not gun or dead:
		return
	# the gun pivot: re-express in world space so it is upright + pitched, positioned off the chest
	_ads = move_toward(_ads, 1.0 if ads else 0.0, _delta * 5.0)
	var chest := _chest.global_transform
	var sgn := -1.0 if use_meshy else 1.0
	var fwd := (global_transform.basis.z * sgn).normalized()
	var rgt := (global_transform.basis.x * sgn).normalized()
	var up := Vector3.UP
	var hh := _hold_home.lerp(_hold_home + Vector3(-0.07, 0.13, 0.06), _ads)
	var base := chest.origin + rgt * hh.x + up * hh.y + fwd * -hh.z
	var pitched := Basis(rgt, _pitch)
	var b := Basis(rgt, pitched * up, -(pitched * fwd))
	gun_hold.global_transform = Transform3D(b.orthonormalized(), base)
	if gun.grip and gun.foregrip:
		_hand_r.global_transform = gun.grip.global_transform
		_hand_l.global_transform = gun.foregrip.global_transform

func set_ads(on: bool) -> void:
	ads = on

func set_pitch(p: float) -> void:
	_pitch = clampf(p, -1.0, 1.0)
	if rig:
		rig.pitch = _pitch

func set_lean(l: float) -> void:
	if rig:
		rig.lean = l

# MARK: weapons

func set_weapon(t: int) -> void:
	if t < 0:                       # no weapon (empty-handed showcase / lobby stance)
		gun_type = -1
		if gun:
			gun.queue_free()
		gun = null
		muzzle = null
		return
	if use_squad:
		gun_type = t
		if gun:
			gun.queue_free()
		gun = GunModel.build(t)
		if _gun_mount:
			_gun_mount.add_child(gun)
		muzzle = gun.muzzle
		return
	if t == gun_type and gun:
		return
	gun_type = t
	if gun:
		gun.queue_free()
	gun = GunModel.build(t)
	gun_hold.add_child(gun)
	match t:
		Weapons.MAGNUM: _hold_home = Vector3(0.10, 0.08, -0.26)
		Weapons.UZI: _hold_home = Vector3(0.12, 0.04, -0.26)
		Weapons.ROCKET: _hold_home = Vector3(0.16, 0.10, -0.12)
		Weapons.SNIPER, Weapons.SHOTGUN: _hold_home = Vector3(0.12, 0.0, -0.22)
		_: _hold_home = Vector3(0.12, 0.02, -0.24)
	muzzle = gun.muzzle

func muzzle_global() -> Vector3:
	if gun and gun.muzzle:
		return gun.muzzle.global_position
	return global_position + Vector3(0, 1.3, 0) - global_transform.basis.z * 0.6

## Recoil kick on the gun pivot + bolt cycle + a brass casing.
func recoil(strength := 1.0) -> void:
	if not gun:
		return
	gun.cycle_bolt()
	var tw := create_tween()
	tw.tween_property(gun, "position", Vector3(0, 0.01 * strength, 0.05 * strength), 0.03)
	tw.tween_property(gun, "position", Vector3.ZERO, 0.09)
	tw.parallel().tween_property(gun, "rotation:x", 0.0, 0.09).from(0.08 * strength)
	_eject_casing()

func _eject_casing() -> void:
	if not gun or not gun.eject or gun_type == Weapons.ROCKET or gun_type == Weapons.FLAMER:
		return
	var c := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.004
	m.bottom_radius = 0.004
	m.height = 0.02
	m.radial_segments = 5
	m.rings = 1
	m.material = GunModel.mat("brass")
	c.mesh = m
	c.top_level = true
	add_child(c)
	var pos := gun.eject.global_position
	c.global_position = pos
	var vel := global_transform.basis.x * randf_range(1.2, 1.8) + Vector3.UP * randf_range(1.8, 2.4) + global_transform.basis.z * 0.4
	var t := 0.0
	var tw := create_tween()
	tw.tween_method(func(tt: float) -> void:
		if not is_instance_valid(c):
			return
		var dt := tt - t
		t = tt
		vel += Vector3(0, -9.8, 0) * dt
		pos += vel * dt
		c.global_position = pos
		c.rotation += Vector3(0.4, 0.3, 0.1), 0.0, 0.8, 0.8)
	tw.tween_callback(c.queue_free)

## Reload: left hand goes to the magazine, mag drops, hand returns from the belt with a
## fresh one. `dur` seconds total. Fires `on_done` when finished.
func reload(dur: float, on_done: Callable = Callable()) -> void:
	if use_squad:
		if reloading or not gun:
			return
		reloading = true
		var tw := create_tween()
		tw.tween_property(_gun_mount, "rotation_degrees", SQUAD_GUN_ROT + Vector3(35, 0, 0), dur * 0.3)
		tw.tween_interval(dur * 0.4)
		tw.tween_property(_gun_mount, "rotation_degrees", SQUAD_GUN_ROT, dur * 0.3)
		tw.tween_callback(func() -> void:
			reloading = false
			if on_done.is_valid(): on_done.call())
		return
	if not gun or reloading:
		return
	reloading = true
	if _reload_tw:
		_reload_tw.kill()
	var has_mag := gun.mag != null and gun.mag.get_child_count() > 0 and gun_type != Weapons.ROCKET and gun_type != Weapons.FLAMER
	var mag_home := gun.mag.position if gun.mag else Vector3.ZERO
	var fore_home := gun.foregrip.position
	var fore_basis := gun.foregrip.basis
	var mag_pos := (gun.mag.position if gun.mag else fore_home) + Vector3(0, -0.06, 0)
	var belt := Vector3(-0.05, -0.55, 0.15)              # gun-local: down-left near the hip
	_reload_tw = create_tween()
	_reload_tw.tween_property(rig, "reload_amt", 1.0, 0.15)
	_reload_tw.parallel().tween_property(gun.foregrip, "position", mag_pos, dur * 0.18)
	_reload_tw.parallel().tween_property(gun, "rotation", Vector3(0.12, 0.0, 0.3), dur * 0.18)
	if has_mag:
		_reload_tw.tween_callback(_drop_mag)
		_reload_tw.tween_property(gun.mag, "position", mag_pos, dur * 0.06)
	_reload_tw.tween_property(gun.foregrip, "position", belt, dur * 0.22)
	if has_mag:
		_reload_tw.tween_callback(func() -> void: gun.mag.visible = true)
		_reload_tw.tween_property(gun.foregrip, "position", mag_pos, dur * 0.22)
		_reload_tw.parallel().tween_property(gun.mag, "position", mag_pos, dur * 0.22).from(belt)
		_reload_tw.tween_property(gun.mag, "position", mag_home, dur * 0.1)
	else:
		_reload_tw.tween_property(gun.foregrip, "position", mag_pos, dur * 0.22)
		_reload_tw.tween_interval(dur * 0.1)
	_reload_tw.tween_property(gun.foregrip, "position", fore_home, dur * 0.18)
	_reload_tw.parallel().tween_property(gun, "rotation", Vector3.ZERO, dur * 0.18)
	_reload_tw.parallel().tween_property(rig, "reload_amt", 0.0, dur * 0.18)
	_reload_tw.tween_callback(func() -> void:
		gun.foregrip.basis = fore_basis
		reloading = false
		if on_done.is_valid():
			on_done.call())

func _drop_mag() -> void:
	if not gun or not gun.mag:
		return
	gun.mag.visible = false
	# a falling copy of the magazine
	var d := gun.mag.duplicate() as Node3D
	d.visible = true
	d.top_level = true
	add_child(d)
	d.global_transform = gun.mag.global_transform
	var vel := Vector3(randf_range(-0.3, 0.3), 0.4, randf_range(-0.3, 0.3))
	var pos := d.global_position
	var t := 0.0
	var tw := create_tween()
	tw.tween_method(func(tt: float) -> void:
		if not is_instance_valid(d):
			return
		var dt := tt - t
		t = tt
		vel += Vector3(0, -9.8, 0) * dt
		pos += vel * dt
		if pos.y < global_position.y + 0.02:
			pos.y = global_position.y + 0.02
			vel = Vector3.ZERO
		d.global_position = pos
		d.rotation.x += dt * 4.0, 0.0, 1.4, 1.4)
	tw.tween_callback(d.queue_free)

func cancel_reload() -> void:
	if _reload_tw:
		_reload_tw.kill()
	reloading = false
	if rig:
		rig.reload_amt = 0.0
	if gun:
		gun.rotation = Vector3.ZERO
		if gun.mag:
			gun.mag.visible = true

# MARK: death

## Play the firing-rifle clip briefly (upper-body recoil) — called on each shot.
func fire_pose() -> void:
	if not use_squad or not anim or dead or not anim.has_animation("fire"):
		return
	_fire_t = 0.28
	if state != "fire":
		state = "fire"
		anim.play("fire", 0.05)

func die() -> void:
	dead = true
	cancel_reload()
	if use_squad and anim and anim.has_animation("death"):
		if _ik_r: _ik_r.stop()
		if _ik_l: _ik_l.stop()
		anim.play("death", 0.15)
		var clip := anim.get_animation("death")
		if clip and clip.length > 2.0:
			anim.seek(0.45, true)             # skip the run-up frames, go straight into the fall
		# Shared clips are pure-rotation (hip translation stripped), so the body would pivot
		# around a hip fixed at standing height and end up floating. Lower the pivot to the
		# ground over the fall so the character actually lies on the floor.
		var hip_h := _hip_height()
		if _death_tw: _death_tw.kill()
		_death_tw = create_tween()
		_death_tw.tween_property(_inst, "position:y", _base_pos.y - hip_h + 0.10, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		return
	if _ik_r: _ik_r.stop()
	if _ik_l: _ik_l.stop()
	if anim:
		anim.pause()
	if _death_tw: _death_tw.kill()
	_death_tw = create_tween()
	_death_tw.set_parallel(true)
	_death_tw.tween_property(_inst, "rotation:x", -PI / 2.0 + 0.08, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_death_tw.tween_property(_inst, "position:y", 0.12, 0.5)
	_death_tw.tween_property(_inst, "rotation:z", randf_range(-0.25, 0.25), 0.5)

## Height of the hips bone above the model origin (world units) — grounds the death fall.
func _hip_height() -> float:
	if not skeleton:
		return 0.9
	var idx := skeleton.find_bone(_bone("Hips"))
	if idx < 0:
		return 0.9
	var hip_y := (skeleton.global_transform * skeleton.get_bone_global_pose(idx).origin).y
	return maxf(hip_y - global_position.y, 0.3)

func revive() -> void:
	dead = false
	if _death_tw: _death_tw.kill()
	_inst.rotation = Vector3(0, PI if (use_meshy or use_squad) else MODEL_YAW, 0)
	_inst.position = _base_pos
	if _ik_r: _ik_r.start()
	if _ik_l: _ik_l.start()
	state = ""
	play("idle")

# MARK: animation states

func play(new_state: String, speed := 1.0) -> void:
	if dead or not anim:
		return
	if new_state == state and anim.is_playing():
		anim.speed_scale = speed
		_apply_state_extras(new_state)
		return
	state = new_state
	var clip := _clip_idle
	if use_squad:
		if _fire_t > 0.0 and new_state in ["idle", "hit", "land"]:
			if state != "fire":
				state = "fire"
				anim.play("fire", 0.05)
			_apply_state_extras(new_state)
			return
		match new_state:
			"run", "strafe_l", "strafe_r": clip = "run"
			"back":
				clip = "run"; speed = -absf(speed) if speed != 0.0 else -1.0
			"walk": clip = "walk"
			"jump": clip = "jump"
			"fall": clip = "fall"
			"land": clip = "land"
			_: clip = "idle"
		if new_state == "back": speed = -absf(speed)
	else:
		match new_state:
			"run", "strafe_l", "strafe_r":
				clip = _clip_run
			"walk":
				clip = _clip_walk
			"back":
				clip = _clip_run
				speed = -absf(speed)
			"jump", "fall", "land", "idle", "hit":
				clip = _clip_idle
	if clip == "":
		return
	anim.speed_scale = speed
	anim.play(clip, BLEND)
	_apply_state_extras(new_state)

func _apply_state_extras(s: String) -> void:
	if not rig:
		return
	var target_air := 1.0 if (s == "jump" or s == "fall") else 0.0
	rig.air = lerpf(rig.air, target_air, 0.25)
	rig.lean = 0.35 if s == "strafe_r" else (-0.35 if s == "strafe_l" else 0.0)
