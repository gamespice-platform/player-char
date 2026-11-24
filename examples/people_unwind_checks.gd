extends RefCounted

## The suite's elbow-unwind section: a clear elbow turn is held rather than slewed back through the weapon (gs-player-char-right-1: after a
## reload the right forearm swept the receiver for ~15 frames). Reports through the suite's own `_section` and `_check`.

var suite: Node


func _init(host: Node) -> void:
	suite = host


func run() -> void:
	suite._section("the elbow does not unwind through the weapon")
	for start in [45.0, 80.0]:
		var free: float = await _unwind(false, start)
		var held: float = await _unwind(true, start)
		suite._check(free > 0.02, "without the hold an elbow turned %d degrees unwinds %.3f m into the receiver (the check can fail)" % [start, free])
		suite._check(held < 0.015, "with it the forearm stays out: %.3f m deep (turned %d degrees)" % [held, start])


## The deepest the right arm goes into a wide receiver while its elbow turn, left at [param start] degrees by a reload, eases back.
func _unwind(hold: bool, start: float) -> float:
	var size := Vector3(0.16, 0.22, 0.45)
	var weapon := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	weapon.mesh = box
	suite.add_child(weapon)
	weapon.position = Vector3(0.08, -0.2, -0.4)
	var arms := GSPlayerViewArms.new()
	arms.hold_clear_turn = hold
	suite.add_child(arms)
	arms.build(GSHumanoidLook.stock(3), 1.8)
	var held := GSViewGrip.two_hand(weapon, Vector3(0.0, -0.06, 0.12), Vector3(0.0, -0.06, -0.15))
	held.bounds = AABB(-size * 0.5, size)
	arms.set_held(held)
	for i in 30:
		arms.tick(0.0, 1.0 / 60.0)
		await suite.get_tree().process_frame
	arms._turn_right = start
	var worst := 0.0
	for i in 60:
		arms.tick(0.0, 1.0 / 60.0)
		await suite.get_tree().process_frame
		worst = maxf(worst, arms.arm_depth_right)
	arms.queue_free()
	weapon.queue_free()
	return worst
