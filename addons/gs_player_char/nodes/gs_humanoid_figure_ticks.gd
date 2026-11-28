extends Node

## The one node that runs every [GSHumanoidFigure]'s frame when [member GSHumanoidFigure.central_tick] is on: a crowd
## of thirty-three costs one engine dispatch and one loop instead of a `_process` each. The figure makes it, hangs it at
## the end of the root and keeps it on the main loop's metadata. Each figure answers whether it stays on the list, so
## turning the switch off hands every figure its own `_process` back.

var _figures: Array = []


func join(figure: Node) -> void:
	_figures.append(figure)


## How many figures are on the list (one told to stop ticking stays on it). For a suite.
func count() -> int:
	return _figures.size()


func _process(delta: float) -> void:
	var frame := Engine.get_process_frames()
	var kept := 0
	for i in _figures.size():
		var figure: Variant = _figures[i]
		if is_instance_valid(figure) and figure._central_step(frame, delta):
			_figures[kept] = figure
			kept += 1
	_figures.resize(kept)
