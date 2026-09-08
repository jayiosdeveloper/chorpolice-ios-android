## AimRig — a SkeletonModifier3D (runs after the AnimationPlayer, before skinning) that
## layers procedural motion on top of the Mixamo clips: torso pitch toward the aim,
## a mid-air leg tuck, a flinch, and a head turn. Child of the Skeleton3D.
class_name AimRig
extends SkeletonModifier3D

var pitch := 0.0            # radians, + = looking up
var air := 0.0              # 0..1 how "in the air" the body is (leg tuck)
var flinch := 0.0           # 0..1, decays
var lean := 0.0             # -1..1 sideways lean while strafing
var reload_amt := 0.0       # 0..1 — extra torso dip during reloads

var _b := {}

static func _norm(x: String) -> String:
	return x.to_lower().replace("0", "")

func _find(sk: Skeleton3D, suffix: String) -> int:
	var want := _norm(suffix)
	for i in sk.get_bone_count():
		if _norm(sk.get_bone_name(i)).ends_with(want):
			return i
	return -1

func _process_modification() -> void:
	var sk := get_skeleton()
	if not sk:
		return
	if _b.is_empty():
		for n in ["Spine", "Spine1", "Spine2", "Neck", "Head", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm"]:
			_b[n] = _find(sk, n)
	# torso pitch — split across the three spine bones (bone-local X is the side axis)
	var p := clampf(pitch, -0.9, 0.9)
	var per := p * 0.17 - reload_amt * 0.1
	for n in ["Spine", "Spine1", "Spine2"]:
		_rot(sk, _b[n], Vector3(1, 0, 0), per)
	_rot(sk, _b["Neck"], Vector3(1, 0, 0), p * 0.22)
	# lean into strafes
	if absf(lean) > 0.01:
		_rot(sk, _b["Spine1"], Vector3(0, 0, 1), -lean * 0.14)
	# leg tuck in the air
	if air > 0.01:
		_rot(sk, _b["LeftUpLeg"], Vector3(1, 0, 0), -0.55 * air)
		_rot(sk, _b["RightUpLeg"], Vector3(1, 0, 0), -0.35 * air)
		_rot(sk, _b["LeftLeg"], Vector3(1, 0, 0), 0.9 * air)
		_rot(sk, _b["RightLeg"], Vector3(1, 0, 0), 0.6 * air)
	# flinch: shoulders in, head down
	if flinch > 0.01:
		_rot(sk, _b["Spine2"], Vector3(1, 0, 0), 0.25 * flinch)
		_rot(sk, _b["Head"], Vector3(1, 0, 0), 0.3 * flinch)
		_rot(sk, _b["Spine1"], Vector3(0, 1, 0), 0.2 * flinch)

func _rot(sk: Skeleton3D, idx: int, axis: Vector3, angle: float) -> void:
	if idx < 0 or absf(angle) < 0.0001:
		return
	var q := sk.get_bone_pose_rotation(idx)
	sk.set_bone_pose_rotation(idx, q * Quaternion(axis, angle))
