extends RefCounted

## [member GSHumanoidFigure.central_tick]: one ticker node runs every figure's frame. A carried figure animates the
## same as on its own `_process`, a figure stopped before its first frame stays off the ticker, `set_ticking(false)`
## stops a central one, and turning the switch off hands each figure its own `_process` back.

var suite: Node


func _init(host: Node) -> void:
	suite = host


func run() -> void:
	suite._section("one ticker node runs every figure's frame (central_tick)")
	var was := GSHumanoidFigure.central_tick
	GSHumanoidFigure.central_tick = true
	var walker := _figure(4)
	walker.auto_animate = true
	var still := _figure(5)
	# Before its first frame: a posed-once portrait.
	still.set_process(false)
	var carried := 0.0
	while carried < 0.5:
		var dt := suite.get_process_delta_time()
		walker.position.x += 3.0 * dt
		carried += dt
		await suite.get_tree().process_frame
	var ticks: Node = GSHumanoidFigure.figure_ticks()
	suite._check(walker.is_central() and not walker.is_processing() and ticks != null and ticks.count() == 1,
		"a figure hands its frame to the ticker and stops its own _process (%d on the list)" % (ticks.count() if ticks != null else -1))
	suite._check(walker.clip in [GSHumanoidClips.WALK, GSHumanoidClips.RUN, GSHumanoidClips.SPRINT],
		"from the ticker, a carried figure still animates from how far it moved (%s)" % walker.clip)
	suite._check(not still.is_central() and not still.is_processing(), "a figure stopped before its first frame stays off the ticker")

	walker.set_ticking(false)
	var frame := walker._frame
	for i in 3:
		walker.position.x += 0.2
		await suite.get_tree().process_frame
	suite._check(walker._frame == frame and not walker.is_ticking(), "set_ticking(false) stops a central figure's frame")

	walker.set_ticking(true)
	GSHumanoidFigure.central_tick = false
	await suite.get_tree().process_frame
	await suite.get_tree().process_frame
	suite._check(not walker.is_central() and walker.is_processing() and ticks.count() == 0,
		"switched off, the figure gets its own _process back and leaves the list")
	GSHumanoidFigure.central_tick = was
	walker.free()
	still.free()
	await suite.get_tree().process_frame


func _figure(seed: int) -> GSHumanoidFigure:
	var f := GSHumanoidFigure.new()
	suite.add_child(f)
	f.build(GSHumanoidLook.stock(seed), 1.8)
	return f
