extends RefCounted

## The suite's elbow-continuity section: the elbow direction speeds up and brakes smoothly instead of starting at full speed
## (arm-ik-elbow-spikes-1: the smg reload's forearm went 0.015, 0.096, 0.080, 0.019 m a frame). Reports through the suite's `_section` and `_check`.

var suite: Node


func _init(host: Node) -> void:
	suite = host


func run() -> void:
	suite._section("the elbow direction changes speed gradually")
	var arms := GSPlayerViewArms.new()
	var line := Vector3(0.0, 0.0, -1.0)
	for target_deg in [30.0, 100.0, 170.0, -120.0]:
		var target := Vector3.RIGHT.rotated(line, deg_to_rad(target_deg))
		var last := Vector3.RIGHT
		var speed := 0.0
		var worst_jump := 0.0
		var worst_step := 0.0
		var frames := 0
		var closer := true
		var gap := last.angle_to(target)
		for i in 120:
			var next := arms._slew_pole(last, line, target, speed)
			var now: float = arms._slewed_speed
			worst_jump = maxf(worst_jump, absf(now - speed))
			worst_step = maxf(worst_step, absf(now))
			speed = now
			last = next
			frames += 1
			closer = closer and next.angle_to(target) <= gap + 0.0001
			gap = next.angle_to(target)
			if absf(speed) < 0.0001 and next.angle_to(target) < 0.001:
				break
		suite._check(worst_jump <= deg_to_rad(GSPlayerViewArms.POLE_ACCEL) * 1.25, "a %d degree elbow swing never changes speed by more than a quarter over %.1f degrees a frame (%.2f)" % [target_deg, GSPlayerViewArms.POLE_ACCEL, rad_to_deg(worst_jump)])
		suite._check(worst_step <= deg_to_rad(GSPlayerViewArms.MAX_POLE_STEP) + 0.0001 and last.angle_to(target) < 0.001 and closer, "and settles on the pole within %d frames without overshoot (%.1f degrees off)" % [frames, rad_to_deg(last.angle_to(target))])
	arms.free()
