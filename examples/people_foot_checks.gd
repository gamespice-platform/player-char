class_name GSPeopleFootChecks
extends RefCounted

## The suite's foot-hold section: the hold's reach on a strafe, the pin at touchdown, a stop keeping the feet, and the sprint
## clip from 3.5 m/s. Each fails if its constant regresses. Reports through the suite's `_section` and `_check`.

const DT := 1.0 / 60.0

var suite: Node


func _init(host: Node) -> void:
	suite = host


func run() -> void:
	suite._section("feet hold: strafe reach, landing pin, stop, sprint clip")
	_check_constants()
	await _check_strafe()
	await _check_landing()
	await _check_stop()
	await _check_sprint_clip()


func _figure(reach: float = GSHumanoidFigure.FOOT_HOLD_REACH) -> GSHumanoidFigure:
	var g := GSHumanoidFigure.new()
	suite.add_child(g)
	g.build(GSHumanoidLook.stock(9), 1.8)
	g.foot_hold_reach = reach
	return g


func _check_constants() -> void:
	var fresh := GSHumanoidFigure.new()
	suite._check(is_equal_approx(GSHumanoidFigure.FOOT_HOLD_REACH, 0.25) and is_equal_approx(fresh.foot_hold_reach, 0.25),
		"the foot hold reaches 0.25 m by default (strafe's residual skate)")
	fresh.free()
	suite._check(is_equal_approx(GSHumanoidFigure.LAND_PIN, 0.5) and is_equal_approx(GSHumanoidFigure.RUN_CLIP_MAX_SPEED, 3.5),
		"the landing pin lasts 0.5 s and the run clip tops out at 3.5 m/s")


## Strafing at a run: the planted foot is held in the world, and the hold's reach is the default one (the clip's sideways drift is within it).
func _check_strafe() -> void:
	var held := {}
	for reach: float in [0.0, GSHumanoidFigure.FOOT_HOLD_REACH]:
		var g := _figure(reach)
		var v := Vector3(3.0, 0, 0)
		for i in 100:
			g.position += v * DT
			g.set_motion({"on_floor": true, "velocity": v})
			g.animate(v.length(), DT)
		held[reach] = g.legs.is_holding()
		g.queue_free()
		await suite.get_tree().process_frame
	suite._check(held[GSHumanoidFigure.FOOT_HOLD_REACH] and not held[0.0], "strafing at 3 m/s holds the planted foot (%s) and holds none with no reach (%s)" % [held[GSHumanoidFigure.FOOT_HOLD_REACH], held[0.0]])


## A run, a jump and a landing at a standstill: touchdown starts the pin, the feet are held while it lasts, and it runs down.
func _check_landing() -> void:
	var held := {}
	var pin_at := -1.0
	var pin_end := -1.0
	for reach: float in [0.0, GSHumanoidFigure.FOOT_HOLD_REACH]:
		var g := _figure(reach)
		var v := Vector3(0, 0, -2.5)
		for i in 60:
			g.position += v * DT
			g.set_motion({"on_floor": true, "velocity": v})
			g.animate(v.length(), DT)
		for i in 30:
			g.set_motion({"on_floor": false, "velocity": Vector3(0, 3.0 - i * 0.2, 0)})
			g.animate(0.0, DT)
		g.legs.let_go()
		for i in 41:
			g.set_motion({"on_floor": true, "velocity": Vector3.ZERO})
			g.animate(0.0, DT)
			if i == 1:
				pin_at = g._landing
				held[reach] = g.legs.is_holding()
			if i == 40:
				pin_end = g._landing
		g.queue_free()
		await suite.get_tree().process_frame
	suite._check(absf(pin_at - GSHumanoidFigure.LAND_PIN) < 3.0 * DT and pin_end < 0.15, "touchdown starts the pin at %.2f s and it runs down (%.2f s 40 frames on)" % [pin_at, pin_end])
	suite._check(held[GSHumanoidFigure.FOOT_HOLD_REACH] and not held[0.0], "after a landing the feet are held by the pin (%s), and not with no reach (%s)" % [held[GSHumanoidFigure.FOOT_HOLD_REACH], held[0.0]])


## Walking then stopping: the feet stay held where the stride set them down instead of being dragged back by the idle blend.
func _check_stop() -> void:
	var held := {}
	for reach: float in [0.0, GSHumanoidFigure.FOOT_HOLD_REACH]:
		var g := _figure(reach)
		var v := Vector3(0, 0, -1.6)
		for i in 90:
			g.position += v * DT
			g.set_motion({"on_floor": true, "velocity": v})
			g.animate(v.length(), DT)
		for i in 10:
			g.set_motion({"on_floor": true, "velocity": Vector3.ZERO})
			g.animate(0.0, DT)
		held[reach] = g.legs.is_holding()
		g.queue_free()
		await suite.get_tree().process_frame
	suite._check(held[GSHumanoidFigure.FOOT_HOLD_REACH] and not held[0.0], "a stop keeps the feet held (%s), and not with no reach (%s)" % [held[GSHumanoidFigure.FOOT_HOLD_REACH], held[0.0]])


## A runner plays the grounded sprint clip above RUN_CLIP_MAX_SPEED, whatever the run speed above it is set; below it, the run clip.
func _check_sprint_clip() -> void:
	var clips := {}
	for pace: float in [3.3, 3.8, 4.5]:
		var g := _figure()
		g.set_run_speeds(3.0, 2.6)
		for i in 60:
			g.position.z -= pace * DT
			g.set_motion({"on_floor": true, "velocity": Vector3(0, 0, -pace)})
			g.animate(pace, DT)
		clips[pace] = g.clip
		g.queue_free()
		await suite.get_tree().process_frame
	suite._check(clips[3.3] != GSHumanoidClips.SPRINT and clips[3.8] == GSHumanoidClips.SPRINT and clips[4.5] == GSHumanoidClips.SPRINT,
		"run speed uses %s above 3.5 m/s and not below (3.3: %s, 3.8: %s, 4.5: %s)" % [GSHumanoidClips.SPRINT, clips[3.3], clips[3.8], clips[4.5]])
