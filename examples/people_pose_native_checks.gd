class_name GSPeoplePoseNativeChecks
extends RefCounted

## The people suite's native pose-blend section: GameSpice Sim's [code]GSSimPoseBlend[/code] against [method GSHumanoidPoseRecord.apply_script] on two figures,
## every bone rotation (within one float step), root position and the model transform (to the bit), and what each costs per call. With no library it says the native half was skipped
## and passes; [code]GS_SIM_REQUIRE_NATIVE=1[/code] (CI) fails instead. Always two checks, so the suite's count holds either way.

const BENCH_CALLS := 3000
## The engine's Quaternion.normalized carries more precision than a float length gives, so a rotation can land one float step (about 1.2e-7) off the script's; the model transform and the root positions are to the bit.
const ROT_TOLERANCE := 4e-7
const ALPHAS := [0.0, 0.13, 0.5, 0.77, 1.0]

var suite: Node


func _init(host: Node) -> void:
	suite = host


func run() -> void:
	suite._section("the native pose blend is the script's, to the bit")
	var native := GSHumanoidPoseRecord.native_available()
	var required := OS.get_environment("GS_SIM_REQUIRE_NATIVE") == "1"
	if not native:
		suite._line("  gs-sim's pose module is not loaded: the native half is skipped")
	var world := Node3D.new()
	suite.add_child(world)
	var live := GSHumanoidFigure.new()
	var by_script := GSHumanoidFigure.new()
	var by_native := GSHumanoidFigure.new()
	for f: GSHumanoidFigure in [live, by_script, by_native]:
		world.add_child(f)
		f.build(GSHumanoidLook.stock(21), 1.8)
		f.set_hold(GSHumanoidFigure.Hold.GUN)
	var rows: Array[PackedFloat32Array] = []
	for i in 40:
		live.set_motion({"on_floor": true, "aim": 0.3 * sin(i * 0.4), "crouched": i > 25})
		live.animate(4.6 if i < 25 else 1.2, 1.0 / 60.0)
		live.rotate_y(0.05)
		rows.append(live.pose_record())
	var compared := 0
	var differ := 0
	var moved := 0
	if native:
		var poser: RefCounted = ClassDB.instantiate(GSHumanoidPoseRecord.NATIVE_CLASS)
		for i in rows.size() - 1:
			for alpha: float in ALPHAS:
				var ok_s := GSHumanoidPoseRecord.apply_script(by_script.skeleton(), by_script.body_node(), rows[i], rows[i + 1], alpha)
				var ok_n: bool = poser.apply(by_native.skeleton(), by_native.body_node(), rows[i], rows[i + 1], alpha, GSHumanoidPoseRecord._root_bones(by_native.skeleton()))
				compared += 1
				if not (ok_s and ok_n and _same(by_script, by_native)):
					differ += 1
				if by_script.skeleton().get_bone_pose_rotation(1) != Quaternion.IDENTITY:
					moved += 1
	suite._check((native and compared >= 150 and differ == 0 and moved == compared) or (not native and not required),
		"%d blends of a figure's pose match the script: rotations within a float step, model and root positions to the bit (%d differ)%s" % [compared, differ, "" if native else "; skipped, no library"])
	var native_us := 0.0
	var script_us := 0.0
	if native:
		var t0 := Time.get_ticks_usec()
		for i in BENCH_CALLS:
			GSHumanoidPoseRecord.apply(by_native.skeleton(), by_native.body_node(), rows[i % 39], rows[i % 39 + 1], 0.37)
		native_us = float(Time.get_ticks_usec() - t0) / BENCH_CALLS
	var t1 := Time.get_ticks_usec()
	for i in BENCH_CALLS:
		GSHumanoidPoseRecord.apply_script(by_script.skeleton(), by_script.body_node(), rows[i % 39], rows[i % 39 + 1], 0.37)
	script_us = float(Time.get_ticks_usec() - t1) / BENCH_CALLS
	suite._line("  pose blend per call: script %.2f us, native %.2f us (%d bones)" % [script_us, native_us, by_script.skeleton().get_bone_count()])
	# The switch: off keeps the script and still draws.
	var was := GSHumanoidPoseRecord.native
	GSHumanoidPoseRecord.native = false
	var drawn := GSHumanoidPoseRecord.apply(by_script.skeleton(), by_script.body_node(), rows[0], rows[1], 0.5)
	GSHumanoidPoseRecord.native = was
	suite._check(drawn, "native off draws through the script")
	world.queue_free()
	await suite.get_tree().process_frame


func _same(a: GSHumanoidFigure, b: GSHumanoidFigure) -> bool:
	var ta := a.body_node().transform
	var tb := b.body_node().transform
	if ta.basis.x != tb.basis.x or ta.basis.y != tb.basis.y or ta.basis.z != tb.basis.z or ta.origin != tb.origin:
		return false
	var sa := a.skeleton()
	var sb := b.skeleton()
	for i in sa.get_bone_count():
		var qa := sa.get_bone_pose_rotation(i)
		var qb := sb.get_bone_pose_rotation(i)
		if absf(qa.x - qb.x) > ROT_TOLERANCE or absf(qa.y - qb.y) > ROT_TOLERANCE or absf(qa.z - qb.z) > ROT_TOLERANCE or absf(qa.w - qb.w) > ROT_TOLERANCE:
			return false
		if sa.get_bone_pose_position(i) != sb.get_bone_pose_position(i):
			return false
	return true

