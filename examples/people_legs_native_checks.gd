extends RefCounted

## The people suite's native legs section: two figures of one look run the same motion script, one
## posing its legs and capping its limbs' turn in script and one in GameSpice Sim's
## [code]GSSimLegs[/code] and [code]GSSimTurnLimit[/code] ([GSHumanoidNativeLegs]), and every bone's
## pose is compared each frame (within [constant TOLERANCE]), then each path's cost per
## [method GSHumanoidFigure.animate]. With no library it says the native half was skipped and passes;
## [code]GS_SIM_REQUIRE_NATIVE=1[/code] (CI) fails instead. A third figure makes one native call per
## step ([member GSHumanoidNativeLegs.fused] off) and must pose to the bit like the fused one, and two more are stepped together
## through [GSHumanoidFigureBatch] (one native call a step for both) and must pose to the bit like it too. Always five checks.

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
	var by_steps := Motion.figure(world)
	var batched: Array[GSHumanoidFigure] = [Motion.figure(world), Motion.figure(world)]
	GSHumanoidNativeLegs.native = was
	var on_native: bool = by_native.legs._n != null and by_native._turn_limit._n != null
	var worst := 0.0
	var differ := 0
	var legs_posed := 0
	var held := 0
	var limited := 0
	var walled := 0
	var carried := 0
	var supported := 0
	var split := 0.0
	var apart := 0.0
	# A sniper, chosen by the game: the carry gives the other hand the foregrip, and its shots work the bolt.
	for f: GSHumanoidFigure in [by_script, by_native, by_steps] + batched:
		f.carry.set_class(&"sniper")
	for i in Motion.FRAMES:
		var motion := Motion.motion(i)
		for f: GSHumanoidFigure in [by_script, by_native, by_steps] + batched:
			GSHumanoidNativeLegs.fused = f != by_steps
			_carry_script(f.carry, i)
			f.position += (motion["velocity"] as Vector3) / 60.0
			Motion.on_wall(motion, i, f.position)
			f.aim(sin(i * 0.07) * 0.5)
			f.set_motion(motion)
			if not batched.has(f):
				f.animate(Motion.speed(i), 1.0 / 60.0)
		GSHumanoidNativeLegs.fused = true
		apart = maxf(apart, _batch_gap(by_native, batched, Motion.speed(i)))
		split = maxf(split, Motion.gap(by_native.skeleton(), by_steps.skeleton()))
		var d := Motion.gap(by_script.skeleton(), by_native.skeleton())
		var grip_a := by_script.carry.support_grip
		var grip_b := by_native.carry.support_grip
		if grip_a.is_finite() or grip_b.is_finite():
			var g := (grip_a - grip_b).abs()
			d = maxf(d, maxf(g.x, maxf(g.y, g.z)) if grip_a.is_finite() and grip_b.is_finite() else INF)
			supported += 1
		if by_script.carry.weight > 0.001:
			carried += 1
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
	suite._check((native and on_native and differ == 0 and legs_posed > Motion.FRAMES / 4 and held > 0 and walled > 0
		and carried > Motion.FRAMES / 2 and supported > 0 and (by_native._carry_n != null) == GSHumanoidNativeLegs.carries())
		or (not native and not required),
		"%d frames of stand, walk, sprint, crouch, jump and wall run, aiming, firing and reloading a carried sniper, match the scripts: worst bone gap %s (%d frames over %s; legs posed %d, feet held %d, limbs held back %d, on a wall %d, gun carried %d, foregrip held %d, carry native %s)%s"
		% [Motion.FRAMES, String.num_scientific(worst), differ, String.num_scientific(TOLERANCE), legs_posed, held, limited, walled,
			carried, supported, by_native._carry_n != null,
			"" if native else "; skipped, no library"])
	suite._check(by_script.legs._n == null and by_script._turn_limit._n == null and by_script._pose_n == null and by_script._carry_n == null,
		"native off keeps the scripts posing the legs, aim and support hand")
	var script_us := Motion.cost(by_script)
	var native_us := Motion.cost(by_native) if on_native else 0.0
	suite._line("  per figure: animate with script legs %.2f us, native legs %.2f us" % [script_us, native_us])
	suite._check(not native or on_native, "native on gives a figure GameSpice Sim's legs and turn limits")
	_check_split(native, split, apart)
	world.queue_free()
	await suite.get_tree().process_frame


func _check_split(native: bool, split: float, apart: float) -> void:
	suite._check(split == 0.0 or not native, "one native call per step poses like the fused calls (restore %s, wall and stride %s, upper body %s, legs below %s): gap %s"
		% [GSHumanoidNativeLegs.restores(), GSHumanoidNativeLegs.fuses(), GSHumanoidNativeLegs.chains(), GSHumanoidNativeLegs.lowers(),
			String.num_scientific(split)])
	suite._check(apart == 0.0,
		"two figures stepped together through GSHumanoidFigureBatch (one native call a step for both: %s) pose like one stepped alone: gap %s"
		% [GSHumanoidNativeLegs.batches(), String.num_scientific(apart)])


## Steps [param batched] together at [param speed], then the worst bone gap between [param alone] and each, or INF when a
## support grip differs.
static func _batch_gap(alone: GSHumanoidFigure, batched: Array[GSHumanoidFigure], speed: float) -> float:
	GSHumanoidFigureBatch.animate_all(batched, PackedFloat64Array([speed, speed]), PackedFloat64Array([1.0 / 60.0, 1.0 / 60.0]))
	var worst := 0.0
	for f in batched:
		worst = maxf(worst, Motion.gap(alone.skeleton(), f.skeleton()))
		var a := alone.carry.support_grip
		var b := f.carry.support_grip
		if a != b and (a.is_finite() or b.is_finite()):
			worst = INF
	return worst


## The game's side of the carry on frame [param i]: raised a while, shots (the kick and the bolt), a whole reload
## path over the wall run and a weapon change at the end.
static func _carry_script(carry: GSHumanoidCarryPose, i: int) -> void:
	carry.raised = i >= 30 and i < 60
	if i == 45 or i == 120 or i == 190:
		carry.fired()
	carry.reloading = i >= 160 and i < 232
	carry.switching = i >= 234
