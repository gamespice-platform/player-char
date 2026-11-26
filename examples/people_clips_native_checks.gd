extends RefCounted

## The people suite's native clip section: two figures of one look run the same motion script, one
## on its [AnimationPlayer] and one on GameSpice Sim's [code]GSSimClipPlayer[/code]
## ([GSHumanoidNativeClips]), and every bone's pose position and rotation is compared each frame
## (within [constant TOLERANCE]), then each path's cost per [method GSHumanoidFigure.animate].
## With no library it says the native half was skipped and passes;
## [code]GS_SIM_REQUIRE_NATIVE=1[/code] (CI) fails instead. Always three checks.

const Motion := preload("people_native_motion.gd")
## The mixer adds each clip's weighted pose to the rest in its own order; the native player sums in
## the same order, so the poses should agree to the bit. A float step of slack keeps a compiler's
## fused multiply-add from failing the suite.
const TOLERANCE := 1e-5

var suite: Node


func _init(host: Node) -> void:
	suite = host


func run() -> void:
	suite._section("native clip playback poses a figure like its AnimationPlayer")
	var native := GSHumanoidNativeClips.available()
	var required := OS.get_environment("GS_SIM_REQUIRE_NATIVE") == "1"
	if not native:
		suite._line("  gs-sim's clip module is not loaded: the native half is skipped")
	var world := Node3D.new()
	suite.add_child(world)
	var was := GSHumanoidNativeClips.native
	GSHumanoidNativeClips.native = false
	var by_mixer := Motion.figure(world)
	GSHumanoidNativeClips.native = true
	var by_native := Motion.figure(world)
	GSHumanoidNativeClips.native = was
	var on_native: bool = by_native._clips != null
	var worst := 0.0
	var differ := 0
	var moved := 0
	for i in Motion.FRAMES:
		var motion := Motion.motion(i)
		for f: GSHumanoidFigure in [by_mixer, by_native]:
			f.set_motion(motion)
			f.animate(Motion.speed(i), 1.0 / 60.0)
		var d := Motion.gap(by_mixer.skeleton(), by_native.skeleton())
		worst = maxf(worst, d)
		if d > TOLERANCE:
			differ += 1
		if by_mixer.skeleton().get_bone_pose_rotation(5) != by_mixer.skeleton().get_bone_rest(5).basis.get_rotation_quaternion():
			moved += 1
	suite._check((native and on_native and differ == 0 and moved > Motion.FRAMES / 2) or (not native and not required),
		"%d frames of stand, walk, sprint, crouch and jump match the mixer: worst bone gap %s (%d frames over %s)%s"
		% [Motion.FRAMES, String.num_scientific(worst), differ, String.num_scientific(TOLERANCE), "" if native else "; skipped, no library"])
	suite._check(by_mixer._clips == null and by_mixer._anim.active, "native off keeps the AnimationPlayer active")
	var mixer_us := Motion.cost(by_mixer)
	var native_us := Motion.cost(by_native) if on_native else 0.0
	var mixer_clip_us := _clip_cost(by_mixer)
	var native_clip_us := _clip_cost(by_native) if on_native else 0.0
	suite._line("  per figure: animate mixer %.2f us, native %.2f us; the clip step alone mixer %.2f us, native %.2f us (%d bones)"
		% [mixer_us, native_us, mixer_clip_us, native_clip_us, by_native.skeleton().get_bone_count()])
	suite._check(not on_native or not by_native._anim.active, "native clips leave the mixer inactive")
	world.queue_free()
	await suite.get_tree().process_frame


## The clip step alone ([method GSHumanoidFigure._advance_clip]): sampling, blending and the bone writes.
func _clip_cost(f: GSHumanoidFigure) -> float:
	var t0 := Time.get_ticks_usec()
	for i in Motion.BENCH_FRAMES:
		f._advance_clip(1.0 / 60.0)
	return float(Time.get_ticks_usec() - t0) / Motion.BENCH_FRAMES
