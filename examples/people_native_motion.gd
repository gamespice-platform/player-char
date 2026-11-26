extends RefCounted

## The people suite's native sections' shared motion script: one look's figure, the stand, walk,
## sprint, crouch and jump each native section runs on a script-posed and a native-posed figure,
## the worst bone gap between two skeletons and a figure's cost per [method GSHumanoidFigure.animate].

const FRAMES := 240
const BENCH_FRAMES := 600


static func figure(world: Node3D) -> GSHumanoidFigure:
	var f := GSHumanoidFigure.new()
	world.add_child(f)
	f.build(GSHumanoidLook.stock(21), 1.8)
	f.set_hold(GSHumanoidFigure.Hold.GUN)
	return f


static func motion(i: int) -> Dictionary:
	var airborne := i >= 150 and i < 175
	return {"on_floor": not airborne, "vertical": 3.0 - (i - 150) * 0.25 if airborne else 0.0,
		"velocity": Vector3(sin(i * 0.05), 0.0, -cos(i * 0.05)) * speed(i), "sprinting": i >= 70 and i < 100,
		"crouched": i >= 100 and i < 140}


static func speed(i: int) -> float:
	if i < 30:
		return 0.0
	if i < 70:
		return 2.2
	if i < 100:
		return 6.0
	if i < 140:
		return 1.5
	return 4.0 if i < 200 else 0.0


static func gap(a: Skeleton3D, b: Skeleton3D) -> float:
	var worst := 0.0
	for i in a.get_bone_count():
		var qa := a.get_bone_pose_rotation(i)
		var qb := b.get_bone_pose_rotation(i)
		worst = maxf(worst, maxf(maxf(absf(qa.x - qb.x), absf(qa.y - qb.y)), maxf(absf(qa.z - qb.z), absf(qa.w - qb.w))))
		var pa := a.get_bone_pose_position(i)
		var pb := b.get_bone_pose_position(i)
		worst = maxf(worst, maxf(maxf(absf(pa.x - pb.x), absf(pa.y - pb.y)), absf(pa.z - pb.z)))
	return worst


static func cost(f: GSHumanoidFigure) -> float:
	var t0 := Time.get_ticks_usec()
	for i in BENCH_FRAMES:
		f.set_motion(motion(i % FRAMES))
		f.animate(speed(i % FRAMES), 1.0 / 60.0)
	return float(Time.get_ticks_usec() - t0) / BENCH_FRAMES
