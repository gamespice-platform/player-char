extends "gs_player_view_arms_mesh.gd"

## The elbow-pole half of [GSPlayerViewArms]: keeping each elbow off the shoulder-to-hand line, slewing it smoothly and turning it clear of the weapon.



## The share of the unit pole that must lie across the shoulder-to-hand line before [method _steady_pole] leaves it alone.
const POLE_SIDE_MIN := 0.6


## [param pole] kept off the shoulder-to-[param target] line. A hand reaching across the body (ADS, a reload) lines the shoulder-to-hand line up with the sideways pole, the part of the pole across
## that line shrinks to nothing and flips, and the elbow jumped 0.4 m in a frame; below [constant POLE_SIDE_MIN] of the pole across the line, down is mixed in, so the elbow swings down and round instead.
func _steady_pole(skeleton: Skeleton3D, bones: Array[int], target: Vector3, pole: Vector3) -> Vector3:
	var line := target - GSHumanoidIk.global_pose(skeleton, bones[0]).origin
	if line.length() < 0.0001:
		return pole
	var dir := line.normalized()
	var unit := pole.normalized()
	var side := sqrt(maxf(1.0 - unit.dot(dir) * unit.dot(dir), 0.0))
	if side >= POLE_SIDE_MIN:
		return pole
	var down := skeleton.global_transform.basis.inverse() * (global_transform.basis * Vector3.DOWN)
	return unit + down.normalized() * (2.0 * (POLE_SIDE_MIN - side) / POLE_SIDE_MIN)


## The most the elbow turn may change in one frame, degrees.
const MAX_TURN_STEP := 4.0

## Degrees per frame the elbow turns while crossing the weapon (its turn changing sign).
const CROSS_STEP := 40.0

## How deep (metres) into the weapon's box an elbow turn may be and still be held by [member hold_clear_turn]; a turn buried more is free to move.
const HOLD_DEPTH := 0.02

## Keep the elbow turn it had when the next step would take a clear arm into the weapon (an unwind after a reload). Off only to measure what it prevents.
var hold_clear_turn := true

## The most the elbow direction (the pole across the shoulder-to-hand line) may swing in one frame, degrees. The turn cap above only
## bounds the clearance scan; a hand crossing the shoulder line (an aim-out finishing, a reload) can spin the sideways pole 180 degrees
## in a frame whatever the scan does, and the forearm jumped 0.3 m for one frame, or lay straight out (a T-pose flash).
const MAX_POLE_STEP := 25.0

## How much the elbow's swing speed may change in one frame, degrees a frame. A speed cap alone still lets the elbow start at full speed from
## rest (the smg reload's forearm went 0.015, 0.096, 0.080, 0.019 m a frame), so the swing speeds up and brakes in steps of this and the
## elbow's path is continuous in speed as well as in place.
const POLE_ACCEL := 3.0

var _last_pole_right := Vector3.ZERO
var _last_pole_left := Vector3.ZERO
## The signed swing (radians a frame about the shoulder-to-hand line) each elbow made last frame.
var _pole_speed_right := 0.0
var _pole_speed_left := 0.0
## The swing the last [method _slew_pole] made.
var _slewed_speed := 0.0


## [param pole] turned about [param line] toward [param last] by a swing whose speed (last frame's [param speed]) changes by no more than
## [constant POLE_ACCEL] a frame and never passes [constant MAX_POLE_STEP], braking so it settles on the pole instead of overshooting.
## Returns the unit sideways part (across [param line]) so [param last] next frame holds what the elbow used: a raw pole lying nearly along
## the line has a tiny sideways part that swings a long way for a small move of the line (the elbow jumped 0.24 m the frame the aim-in finished).
func _slew_pole(last: Vector3, line: Vector3, pole: Vector3, speed: float) -> Vector3:
	_slewed_speed = 0.0
	if line.length() < 0.0001 or last == Vector3.ZERO:
		return pole
	var dir := line.normalized()
	var was := last - dir * last.dot(dir)
	var now := pole - dir * pole.dot(dir)
	if was.length() < 0.0001 or now.length() < 0.0001:
		return pole
	var swing := was.signed_angle_to(now, dir)
	# A swing near half a turn could go either way: keep going the way the elbow was already moving.
	if absf(swing) > PI * 0.9 and absf(speed) > 0.0001 and signf(swing) != signf(speed):
		swing -= signf(swing) * TAU
	var accel := deg_to_rad(POLE_ACCEL)
	# The fastest speed from which the remaining swing can still be braked to a stop at accel a frame.
	var brake := accel * (sqrt(1.0 + 8.0 * absf(swing) / accel) - 1.0) * 0.5
	var stepped := clampf(signf(swing) * minf(deg_to_rad(MAX_POLE_STEP), brake), speed - accel, speed + accel)
	if absf(swing) <= absf(stepped) or absf(swing) < accel * 0.5:
		stepped = swing
	_slewed_speed = stepped
	return was.normalized().rotated(dir, stepped)


## The elbow direction (skeleton space) for an arm reaching [param target]: [param pole], turned about the
## shoulder-to-hand line to the least-buried of [constant CLEAR_ANGLES] when the arm would pass through the weapon.
## Eased part way each frame, so the elbow swings across rather than snapping.
func _clear_pole(skeleton: Skeleton3D, bones: Array[int], target: Vector3, pole: Vector3, right: bool) -> Vector3:
	var box := _grip.bounds_local().grow(arm_radius) if keep_arms_clear and _grip.bounds_local().has_volume() else AABB()
	var shoulder := GSHumanoidIk.global_pose(skeleton, bones[0]).origin
	var dir := (target - shoulder).normalized()
	if not box.has_volume() or not dir.is_normalized():
		return pole
	var lengths := _arm_lengths(skeleton, bones)
	var to_anchor := _grip.anchor.global_transform.affine_inverse() * skeleton.global_transform
	var up := skeleton.global_transform.basis.inverse() * (global_transform.basis * Vector3.UP)
	if not _native_tried:
		_native_tried = true
		if native_clear and ClassDB.class_exists(&"GSSimViewArms"):
			_native = ClassDB.instantiate(&"GSSimViewArms")
	var prev := _turn_right if right else _turn_left
	var r: PackedFloat64Array
	if _native != null:
		r = _native.clear_pole(shoulder, target, lengths, pole, dir, to_anchor, box, up, prev)
	else:
		r = GSViewArmsClear.scan(shoulder, target, lengths, pole, dir, to_anchor, box, up, prev)
	var turned := Vector3(r[0], r[1], r[2])
	var turn := r[3]
	var depth := r[4]
	# The scan eases a fraction of the gap, a big swing when the best angle flips by 60 degrees; cap the step so the forearm slews rather than jumps.
	# Crossing the weapon (the turn changing sign) is the one place a slow slew hurts: the forearm drags through the receiver, so the elbow crosses the middle band faster.
	var step := MAX_TURN_STEP
	var want := turn
	if turn * prev < 0.0:
		step = CROSS_STEP
		want = prev + (turn - prev) / GSViewArmsClear.EASE
	if absf(want - prev) > step:
		turn = prev + signf(want - prev) * step
		turned = pole.rotated(dir, deg_to_rad(turn))
		depth = GSViewArmsClear.arm_depth(to_anchor, box, shoulder, GSViewArmsClear.elbow_for(shoulder, target, lengths, turned), target)
	elif want != turn:
		turn = want
		turned = pole.rotated(dir, deg_to_rad(turn))
		depth = GSViewArmsClear.arm_depth(to_anchor, box, shoulder, GSViewArmsClear.elbow_for(shoulder, target, lengths, turned), target)
	# A turn that was clear must not unwind through the weapon: after a reload the elbow slewed back toward its natural side and swept the forearm
	# through the receiver for ~15 frames. A step that lands deeper than the turn it had, while that turn is within HOLD_DEPTH, is not taken; the scan keeps asking.
	if hold_clear_turn and depth > 0.0 and turn != prev:
		var was_depth := GSViewArmsClear.arm_depth(to_anchor, box, shoulder, GSViewArmsClear.elbow_for(shoulder, target, lengths, pole.rotated(dir, deg_to_rad(prev))), target)
		if was_depth <= HOLD_DEPTH and depth > was_depth:
			turn = prev
			turned = pole.rotated(dir, deg_to_rad(turn))
			depth = was_depth
	if right:
		_turn_right = turn
		arm_depth_right = depth
	else:
		_turn_left = turn
		arm_depth_left = depth
	return turned


func _arm_lengths(skeleton: Skeleton3D, bones: Array[int]) -> Vector2:
	var upper_pose := GSHumanoidIk.global_pose(skeleton, bones[0])
	var lower_pose := GSHumanoidIk.global_pose_below(skeleton, bones[0], upper_pose, bones[1])
	var wrist := GSHumanoidIk.global_pose_below(skeleton, bones[1], lower_pose, bones[2]).origin
	return Vector2((lower_pose.origin - upper_pose.origin).length(), (wrist - lower_pose.origin).length())
