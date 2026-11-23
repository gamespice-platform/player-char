class_name GSViewArmsClear
extends RefCounted

## The view arms' elbow clearance scan, free of nodes: which turn of the elbow pole about the shoulder-to-hand line keeps the arm out of the weapon. [GSPlayerViewArms] runs it per arm per frame; GameSpice Sim's [code]GSSimViewArms[/code]
## ("arms" module) is the native twin, bit-identical (GameSpice Sim's selftest compares the two on seeded inputs), and this script is the fallback where the extension is not loaded (web, a build without it).

## Turns tried, degrees; ties go to the earlier (smaller) one.
const ANGLES: Array[float] = [0.0, 15.0, -15.0, 30.0, -30.0, 45.0, -45.0, 60.0, -60.0, 80.0, -80.0]
## The share of the forearm, from the hand end, left out of the depth (a hand on the grip is meant to touch it).
const HAND_FREE := 0.35
## How far each frame's turn eases toward the best angle.
const EASE := 0.35


## The eased turn for an arm: [param pole] turned about [param dir] (the unit shoulder-to-[param target] line) part way from [param prev_turn] toward the least-buried angle of [constant ANGLES], scored by depth into [param box]
## (anchor space, through [param to_anchor]; or into the convex [param planes] when given, see [method dop_planes]), a small cost per degree, and a cost for an elbow above the shoulder along [param up]. All points in skeleton space; [param lengths] are the upper arm and forearm.
## Returns [turned.x, turned.y, turned.z, turn (degrees), depth of the turned arm (metres)].
static func scan(shoulder: Vector3, target: Vector3, lengths: Vector2, pole: Vector3, dir: Vector3, to_anchor: Transform3D,
		box: AABB, up: Vector3, prev_turn: float, planes := PackedFloat32Array()) -> PackedFloat64Array:
	var best := 0.0
	var best_score := INF
	for angle in ANGLES:
		var elbow := elbow_for(shoulder, target, lengths, pole.rotated(dir, deg_to_rad(angle)))
		# Ties go to the smaller turn; an elbow raised above the shoulder crosses the view, so it scores worse.
		var score := arm_depth(to_anchor, box, shoulder, elbow, target, planes) + absf(angle) * 0.00005 + (0.05 if (elbow - shoulder).dot(up) > 0.0 else 0.0)
		if score < best_score - 0.002:
			best_score = score
			best = angle
	var turn := lerpf(prev_turn, best, EASE)
	var turned := pole.rotated(dir, deg_to_rad(turn))
	var depth := arm_depth(to_anchor, box, shoulder, elbow_for(shoulder, target, lengths, turned), target, planes)
	return PackedFloat64Array([turned.x, turned.y, turned.z, turn, depth])


## Where [method GSHumanoidIk.two_bone] puts the elbow for this target and pole, without posing anything.
static func elbow_for(shoulder: Vector3, target: Vector3, lengths: Vector2, pole: Vector3) -> Vector3:
	var la := lengths.x
	var lb := lengths.y
	var to_target := target - shoulder
	if la < 0.0001 or lb < 0.0001 or to_target.length() < 0.0001:
		return shoulder
	var reach := clampf(to_target.length(), absf(la - lb) + 0.001, la + lb - 0.001)
	var dir := to_target.normalized()
	var along := (la * la - lb * lb + reach * reach) / (2.0 * reach)
	var side := pole - dir * pole.dot(dir)
	side = side.normalized() if side.length_squared() > 0.000001 else Vector3.UP
	return shoulder + dir * along + side * sqrt(maxf(la * la - along * along, 0.0))


## How deep the upper arm and the forearm (all but its hand end) go into [param box], or the convex [param planes] inside it (anchor space), metres.
static func arm_depth(to_anchor: Transform3D, box: AABB, shoulder: Vector3, elbow: Vector3, target: Vector3, planes := PackedFloat32Array()) -> float:
	var s := to_anchor * shoulder
	var e := to_anchor * elbow
	var h := to_anchor * target.lerp(elbow, HAND_FREE)
	# Most elbows miss the weapon: two native segment tests rule that out before the eighteen samples.
	if box.intersects_segment(s, e) == null and box.intersects_segment(e, h) == null:
		return 0.0
	var deepest := 0.0
	var hull := not planes.is_empty()
	for i in 9:
		var t := i / 8.0
		if hull:
			deepest = maxf(deepest, maxf(depth_in_hull(planes, s.lerp(e, t)), depth_in_hull(planes, e.lerp(h, t))))
		else:
			deepest = maxf(deepest, maxf(depth_in(box, s.lerp(e, t)), depth_in(box, e.lerp(h, t))))
	return deepest


## How far [param q] is inside [param box] from its nearest face, or 0 outside.
static func depth_in(box: AABB, q: Vector3) -> float:
	if not box.has_point(q):
		return 0.0
	var low := q - box.position
	var high := box.end - q
	return minf(minf(minf(low.x, high.x), minf(low.y, high.y)), minf(low.z, high.z))


## How far [param q] is inside the convex solid [param planes] ([method dop_planes]: nx, ny, nz, d per plane, inside is n.q <= d) from its nearest face, or 0 outside.
## The dot product is spelled in doubles, left to right, so the native twin reproduces it to the bit.
static func depth_in_hull(planes: PackedFloat32Array, q: Vector3) -> float:
	var deepest := INF
	for i in range(0, planes.size(), 4):
		var gap: float = planes[i + 3] - (planes[i] * q.x + planes[i + 1] * q.y + planes[i + 2] * q.z)
		if gap < 0.0:
			return 0.0
		deepest = minf(deepest, gap)
	return 0.0 if deepest == INF else deepest


static var _dirs: Array[Vector3] = []


## The 26 directions of the discrete oriented polytope: the faces, edges and corners of a cube.
static func dop_dirs() -> Array[Vector3]:
	if _dirs.is_empty():
		for x in [-1, 0, 1]:
			for y in [-1, 0, 1]:
				for z in [-1, 0, 1]:
					if x != 0 or y != 0 or z != 0:
						_dirs.append(Vector3(x, y, z).normalized())
	return _dirs


## A convex solid hugging [param points] (a weapon's mesh vertices): for each of [method dop_dirs] the plane just touching the farthest point, packed nx, ny, nz, d
## (a 26-sided polytope, a much closer fit to a gun than its box, which is its six axis planes). Empty for no points.
static func dop_planes(points: PackedVector3Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if points.is_empty():
		return out
	for n in dop_dirs():
		var far := -INF
		for p in points:
			far = maxf(far, n.dot(p))
		out.append_array(PackedFloat32Array([n.x, n.y, n.z, far]))
	return out


## [param planes] pushed out by [param radius] (the arm's thickness) along every normal.
static func grown(planes: PackedFloat32Array, radius: float) -> PackedFloat32Array:
	var out := planes.duplicate()
	for i in range(3, out.size(), 4):
		out[i] += radius
	return out
