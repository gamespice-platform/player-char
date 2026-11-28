extends "gs_humanoid_figure_clips.gd"

## [GSHumanoidFigure]'s ticking, split out to keep each file small: whether a figure runs its own `_process` or is one
## of the figures [code]gs_humanoid_figure_ticks.gd[/code] runs in one loop. The frame itself is [method _tick], which
## [GSHumanoidFigure] defines.

## One ticker node runs every figure's frame (the follow-the-floor lift between steps, an [member auto_animate] body's
## measure and pose) instead of each figure's own `_process`. Off by default; a game maps its own cvar onto it. Same
## steps, same order within a figure, later in the frame than the figure's own place in the tree (after whatever posed
## it). A game that stops a figure's frame calls [method set_ticking], which works either way; `set_process(false)`
## before the figure's first frame keeps it off the ticker too. Turned off at run time, every figure gets its own
## `_process` back on its next frame.
static var central_tick := false

const FigureTicks := preload("gs_humanoid_figure_ticks.gd")
const TICKS_META := &"gs_player_char_figure_ticks"

## Whether this figure should tick (see [method set_ticking]), whether the ticker holds it, the process frame it last
## ticked in (a stamp against a double tick), and a suite's way of keeping one figure on its own `_process`.
var _tick_wanted := true
var _central := false
var _ticked_frame := -1
var _own_tick := false


## Starts or stops this figure's frame: `set_process` when it ticks itself, the ticker's skip when it is central.
func set_ticking(on: bool) -> void:
	_tick_wanted = on
	if not _central:
		set_process(on)


## Whether this figure's frame runs, by [method set_ticking] or by `set_process` while it ticks itself.
func is_ticking() -> bool:
	return _tick_wanted if _central else is_processing()


## Whether the tree's ticker runs this figure's frame. For a suite.
func is_central() -> bool:
	return _central


func _ready() -> void:
	# Always: between calls to [method GSHumanoidFigure.animate] (a far body's skipped frames) the drawn origin still
	# moves, and the lift follows it.
	set_process(true)


func _process(delta: float) -> void:
	_ticked_frame = Engine.get_process_frames()
	_tick(delta)
	if central_tick and not _own_tick and not Engine.is_editor_hint():
		_join_central()


## The frame: [GSHumanoidFigure] defines it.
func _tick(_delta: float) -> void:
	pass


## Hands this figure to the tree's ticker and stops its own `_process`. A later `set_process(true)` brings it back
## here for a frame; the stamp stops a double tick.
func _join_central() -> void:
	var ticks := _figure_ticks()
	if ticks == null:
		return
	_tick_wanted = true
	set_process(false)
	if not _central:
		_central = true
		ticks.join(self)


## The ticker's call, once a frame: false drops this figure from its list.
func _central_step(frame: int, delta: float) -> bool:
	if not central_tick or not _central:
		_central = false
		set_process(_tick_wanted)
		return false
	if not _tick_wanted or _ticked_frame == frame or not is_inside_tree() or not can_process():
		return true
	_ticked_frame = frame
	_tick(delta)
	return true


## The tree's ticker, made and parented at the end of the root on first use.
static func _figure_ticks() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	if loop.has_meta(TICKS_META):
		var held: Variant = loop.get_meta(TICKS_META)
		if is_instance_valid(held):
			return held
	var made := FigureTicks.new()
	made.name = "GSHumanoidFigureTicks"
	made.process_mode = Node.PROCESS_MODE_ALWAYS
	loop.root.add_child.call_deferred(made)
	loop.set_meta(TICKS_META, made)
	return made


## The ticker, or null before any figure joined it. For a suite.
static func figure_ticks() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or not loop.has_meta(TICKS_META):
		return null
	var held: Variant = loop.get_meta(TICKS_META)
	return held if is_instance_valid(held) else null
