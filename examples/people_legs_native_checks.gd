extends RefCounted

## The people suite's native legs section: two figures of one look run the same motion script, one
## posing its legs and capping its limbs' turn in script and one in GameSpice Sim's
## [code]GSSimLegs[/code] and [code]GSSimTurnLimit[/code] ([GSHumanoidNativeLegs]), and every bone's
## pose is compared each frame (within [constant TOLERANCE]), then each path's cost per
## [method GSHumanoidFigure.animate]. With no library it says the native half was skipped and passes;
## [code]GS_SIM_REQUIRE_NATIVE=1[/code] (CI) fails instead. Always three checks.

const Motion := preload("people_native_motion.gd")
## The native kernels do the script's f32 vector maths in its order; a float step of slack keeps a
## compiler's fused multiply-add from failing the suite.
const TOLERANCE := 1e-5

var suite: Node


func _init(host: Node) -> void:
	suite = host


func run() -> void:
	suite._section("native legs and turn limit pose a figure like the scripts")
	var native := GSHumanoidNativeLegs.available()
	var required := OS.get_environment("GS_SIM_REQUIRE_NATIVE") == "1"
	if not native:
		suite._line("  gs-sim's figure module is not loaded: the native half is skipped")
	var world := Node3D.new()
	suite.add_child(world)
	var was := GSHumanoidNativeLegs.native
	GSHumanoidNativeLegs.native = false
	var by_script := Motion.figure(world)
	GSHumanoidNativeLegs.native = true
	var by_native := Motion.figure(world)
	GSHumanoidNativeLegs.native = was
	var on_native: bool = by_native.legs._n != null and by_native._turn_limit._n != null
	var worst := 0.0
	var differ := 0
	var legs_posed := 0
	var held := 0
	var limited := 0
	var walled := 0
	for i in Motion.FRAMES:
		var motion := Motion.motion(i)
		for f: GSHumanoidFigure in [by_script, by_native]:
			f.position += (motion["velocity"] as Vector3) / 60.0
			Motion.on_wall(motion, i, f.position)
			f.aim(sin(i * 0.07) * 0.5)
			f.set_motion(motion)
			f.animate(Motion.speed(i), 1.0 / 60.0)
		var d := Motion.gap(by_script.skeleton(), by_native.skeleton())
		worst = maxf(worst, d)
		if d > TOLERANCE:
			differ += 1
		if not by_script.legs._saved.is_empty():
			legs_posed += 1
		if by_script.legs.holding():
			held += 1
		if by_script._turn_limit.turned() or by_script._stride_limit.turned():
			limited += 1
		if by_script.legs.wall_weight > 0.0:
			walled += 1
	suite._check((native and on_native and differ == 0 and legs_posed > Motion.FRAMES / 4 and held > 0 and walled > 0)
		or (not native and not required),
		"%d frames of stand, walk, sprint, crouch, jump and wall run, aiming, match the scripts: worst bone gap %s (%d frames over %s; legs posed %d, feet held %d, limbs held back %d, on a wall %d)%s"
		% [Motion.FRAMES, String.num_scientific(worst), differ, String.num_scientific(TOLERANCE), legs_posed, held, limited, walled,
			"" if native else "; skipped, no library"])
	suite._check(by_script.legs._n == null and by_script._turn_limit._n == null and by_script._pose_n == null,
		"native off keeps the scripts posing the legs, aim and support hand")
	var script_us := Motion.cost(by_script)
	var native_us := Motion.cost(by_native) if on_native else 0.0
	suite._line("  per figure: animate with script legs %.2f us, native legs %.2f us" % [script_us, native_us])
	suite._check(not native or on_native, "native on gives a figure GameSpice Sim's legs and turn limits")
	world.queue_free()
	await suite.get_tree().process_frame
