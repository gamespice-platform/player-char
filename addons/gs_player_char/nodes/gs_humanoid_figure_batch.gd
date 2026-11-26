class_name GSHumanoidFigureBatch
extends RefCounted

## Steps many [GSHumanoidFigure]s in one frame with each native bone step made once for all of them: every figure's script
## runs up to its restore, then one `GSSimFigureBatch` call restores them all, and the same for the upper body and the legs.
## Each figure's own steps keep their order, so the pose is the one [method GSHumanoidFigure.animate] makes figure by
## figure; what it saves is the engine's dispatch of a native call per figure and step. Without
## [method GSHumanoidNativeLegs.batches] it is that loop. One thread: a figure's nodes stay on the caller's.


## [method GSHumanoidFigure.animate] for each of [param figures] at its entry of [param speeds] over its entry of
## [param deltas] (a figure posed through [method GSHumanoidFigure.pose] takes [method GSHumanoidFigure.frame_delta]).
static func animate_all(figures: Array, speeds: PackedFloat64Array, deltas: PackedFloat64Array) -> void:
	var batch := GSHumanoidNativeLegs.batch()
	if batch == null:
		for i in figures.size():
			(figures[i] as GSHumanoidFigure).animate(speeds[i], deltas[i])
		return
	var live: Array[GSHumanoidFigure] = []
	for i in figures.size():
		var f: GSHumanoidFigure = figures[i]
		f._frame_tf_on = true
		if f._step_open(speeds[i], deltas[i]):
			live.append(f)
		else:
			f._step_shut()
	if live.is_empty():
		return
	var calls: Array = []
	for f in live:
		f._step_restore(calls)
	if not calls.is_empty():
		batch.call(&"restore", calls)
	_upper(batch, live)
	_lower(batch, live)
	for f in live:
		f._step_close()
		f._step_shut()


static func _upper(batch: RefCounted, live: Array[GSHumanoidFigure]) -> void:
	var calls: Array = []
	var queued: Array[GSHumanoidFigure] = []
	for f in live:
		var at := calls.size()
		f._step_upper(calls)
		if calls.size() > at:
			queued.append(f)
	if queued.is_empty():
		return
	var grips: PackedVector3Array = batch.call(&"upper", calls)
	for i in queued.size():
		queued[i]._upper_done(grips[i])


static func _lower(batch: RefCounted, live: Array[GSHumanoidFigure]) -> void:
	var calls: Array = []
	var queued: Array[GSHumanoidFigure] = []
	for f in live:
		var at := calls.size()
		f._step_lower(calls)
		if calls.size() > at:
			queued.append(f)
	if queued.is_empty():
		return
	var held: PackedByteArray = batch.call(&"lower", calls)
	for i in queued.size():
		queued[i]._lower_done(held[i] != 0)
