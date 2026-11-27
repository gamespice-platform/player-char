class_name GSHumanoidCrawl
extends RefCounted

## A crawling body's feet: planted until the leg is stretched to [constant FAR] of its length,
## then swung in [constant SWING_S] to where it is bent to [constant NEAR], one at a time.

const FAR := 0.9
const NEAR := 0.35
const SWING_S := 0.16
const LIFT_M := 0.1
const BLEND_S := 0.15
const LEGS := [["UpperLeg.L", "LowerLeg.L", "Foot.L"], ["UpperLeg.R", "LowerLeg.R", "Foot.R"]]

var at: Array[Vector3] = []
var swing: Array[float] = []
var weight: float = 0.0

# Per-frame scratch, sized once: the bone ids for the skeleton last seen and each leg's measures.
var _legs: Array[PackedInt32Array] = []
var _legs_for: int = 0
var _legs_bones: int = -1
var _hips: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _ankles: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _lands: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _reach: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])
var _stretch: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])


## The clip's feet scrape the ground at a pace of their own, so a crawling body's feet are held
## still in the world and stepped by IK when the leg runs out of reach. A phase-timed plant
## ([GSFootPlant]) overreaches here: the legs are short and the clip surges the hips.
func step(figure: Node3D, skeleton: Skeleton3D, active: bool, speed: float, dt: float) -> void:
	weight = move_toward(weight, 1.0 if speed >= 0.1 else 0.0, dt / BLEND_S)
	if not active or weight <= 0.0:
		at.clear()
		weight = 0.0
		return
	var legs := _leg_ids(skeleton)
	if legs.is_empty():
		return
	# In the world, about the figure's own upright frame: the model may still be tilting out of a pose.
	var to_world := skeleton.global_transform
	var to_skel := to_world.affine_inverse()
	var sized := to_world.basis.get_scale().y
	var back := Vector3(figure.global_transform.basis.z.x, 0.0, figure.global_transform.basis.z.z).normalized()
	var right := Vector3(figure.global_transform.basis.x.x, 0.0, figure.global_transform.basis.x.z).normalized()
	var hips := _hips
	var ankles := _ankles
	var lands := _lands
	var reach := _reach
	for i in legs.size():
		var leg := legs[i]
		var knee := GSHumanoidIk.global_pose(skeleton, leg[1])
		var end_local := skeleton.get_bone_global_rest(leg[1]).affine_inverse() * skeleton.get_bone_global_rest(leg[2]).origin
		var hip := to_world * GSHumanoidIk.global_pose(skeleton, leg[0]).origin
		var ankle := to_world * (knee * end_local)
		var length := (GSHumanoidIk.global_pose(skeleton, leg[0]).origin.distance_to(knee.origin) + end_local.length()) * sized
		# On the floor at the standing ankle's height, beside the hip as the clip has it, bent to NEAR.
		var floor_y := figure.global_position.y + skeleton.get_bone_global_rest(leg[2]).origin.y * sized
		var side := (ankle - hip).dot(right)
		var flat := Vector2(side, hip.y - floor_y).length()
		var land := hip + right * side + back * sqrt(maxf(pow(length * NEAR, 2.0) - flat * flat, 0.0001))
		land.y = floor_y
		hips[i] = hip
		ankles[i] = ankle
		reach[i] = length
		lands[i] = land
	if at.size() != 2:
		at = [Vector3(ankles[0].x, lands[0].y, ankles[0].z), Vector3(ankles[1].x, lands[1].y, ankles[1].z)]  # perf-lint: allow alloc once on entering a crawl
		swing = [-1.0, -1.0]  # perf-lint: allow alloc once on entering a crawl
	var stretch := _stretch
	for k in 2:
		stretch[k] = hips[k].distance_to(at[k]) / reach[k]
	# One foot at a time, the more stretched first; a leg at full length steps regardless, or it drags.
	var first := 0 if stretch[0] >= stretch[1] else 1
	for j in 2:
		var k := first if j == 0 else 1 - first
		var other_down := swing[1 - k] < 0.0
		if swing[k] < 0.0 and (stretch[k] > FAR and other_down or stretch[k] > 0.98):
			swing[k] = 0.0
	var w := smoothstep(0.0, 1.0, weight)
	for k in 2:
		var leg := legs[k]
		var target := at[k]
		if swing[k] >= 0.0:
			swing[k] = minf(swing[k] + dt / SWING_S, 1.0)
			var s := swing[k]
			target = at[k].lerp(lands[k], smoothstep(0.0, 1.0, s)) + Vector3.UP * LIFT_M * sin(PI * s)
			if s >= 1.0:
				at[k] = lands[k]
				swing[k] = -1.0
		var end_local := skeleton.get_bone_global_rest(leg[1]).affine_inverse() * skeleton.get_bone_global_rest(leg[2]).origin
		# Knees out to the side, as a body crawling flat pushes: the clip's leg is too straight to steer
		# by (its bend flips from frame to frame), and a knee pointed at the floor would go through it.
		var hip_x := GSHumanoidIk.global_pose(skeleton, leg[0]).origin.x
		var pole := Vector3(signf(hip_x) if hip_x != 0.0 else 1.0, -0.3, 0.0)
		var ankle := GSHumanoidIk.two_bone_to(skeleton, leg[0], leg[1], end_local, to_skel * ankles[k].lerp(target, w), pole, 1.0)
		var parent := skeleton.get_bone_parent(leg[2])
		skeleton.set_bone_pose_position(leg[2], ankle if parent < 0 else GSHumanoidIk.global_pose(skeleton, parent).affine_inverse() * ankle)


# The legs' bone ids, looked up by name only when the skeleton changes; empty when one is missing.
func _leg_ids(skeleton: Skeleton3D) -> Array[PackedInt32Array]:
	var id := skeleton.get_instance_id()
	var bones := skeleton.get_bone_count()
	if id == _legs_for and bones == _legs_bones:
		return _legs
	_legs_for = id
	_legs_bones = bones
	_legs.clear()
	for names: Array in LEGS:
		var ids := PackedInt32Array([skeleton.find_bone(names[0]), skeleton.find_bone(names[1]), skeleton.find_bone(names[2])])  # perf-lint: allow alloc only when the skeleton changes
		if ids.has(-1):
			_legs.clear()
			return _legs
		_legs.append(ids)
	return _legs
