class_name GSHumanoidNativeLegs
extends RefCounted

## [GSHumanoidLegs]' and [GSHumanoidTurnLimit]'s bone work in GameSpice Sim: `GSSimLegs` turns the
## root and hips, lifts the ankles off the floor, holds and steps the feet, sets them on a climbed wall,
## `GSSimTurnLimit` caps the limbs' turn, and `GSSimFigurePose` bends the aim and puts the support hand
## on the foregrip, writing the same rotations into the skeleton as the scripts. The scripts keep their
## fields and decisions and hand the native side what it needs as arguments. Without the extension or
## with [member native] off, the scripts pose the bones themselves: the fallback the web build always
## runs. Reached through [ClassDB] by name, so nothing needs the extension.

const LEGS_CLASS := &"GSSimLegs"
const TURN_CLASS := &"GSSimTurnLimit"
const POSE_CLASS := &"GSSimFigurePose"
const BATCH_CLASS := &"GSSimFigureBatch"

## Pose the legs and cap the turn in GameSpice Sim when it is loaded (the same pose as the scripts);
## off keeps the scripts. Read when a [GSHumanoidLegs] or [GSHumanoidTurnLimit] is made.
static var native := true
## With [member native], hand a figure's back-to-back bone steps to GameSpice Sim as one call each
## (`restore_with`, `on_wall_with`, `upper`, `lower`: the same pose); off makes one call per step, the fallback.
static var fused := true
## With [member fused], [GSHumanoidFigureBatch] makes each of those calls once a frame for all its figures
## (`GSSimFigureBatch`: the same pose); off steps the figures one by one, the fallback.
static var batched := true
static var _known := -1
static var _carries := -1
static var _restores := -1
static var _fuses := -1
static var _chains := -1
static var _lowers := -1
static var _batches := -1


## Whether the gs_sim extension provides all three classes (an older library without the pose class
## runs the scripts throughout); asked once.
static func available() -> bool:
	if _known < 0:
		var all := ClassDB.class_exists(LEGS_CLASS) and ClassDB.class_exists(TURN_CLASS) and ClassDB.class_exists(POSE_CLASS)
		_known = 1 if all else 0
	return _known == 1


## A `GSSimLegs` for one [GSHumanoidLegs], or null for the script path.
static func legs() -> RefCounted:
	if not native or not available():
		return null
	return ClassDB.instantiate(LEGS_CLASS)


## A `GSSimTurnLimit` over [param names] (those in [param arm_names] at the arm rate), or null for the script path.
static func turn_limit(names: Array[String], arm_names: Array[String]) -> RefCounted:
	if not native or not available():
		return null
	var made: RefCounted = ClassDB.instantiate(TURN_CLASS)
	made.call(&"setup", PackedStringArray(names), PackedStringArray(arm_names))
	return made


## Whether the loaded `GSSimFigurePose` also draws the carry ([GSHumanoidCarryPose]); an older library
## leaves the gun arm to the script. Off with [member native].
static func carries() -> bool:
	if _carries < 0:
		_carries = 1 if available() and ClassDB.class_has_method(POSE_CLASS, &"carry") else 0
	return native and _carries == 1


## A `GSSimFigurePose` for one [GSHumanoidFigure]'s aim and support hand, or null for the script path.
static func pose() -> RefCounted:
	if not native or not available():
		return null
	return ClassDB.instantiate(POSE_CLASS)


## Whether the loaded `GSSimLegs` undoes a figure's turn limit, legs and stride limit in one call
## (`restore_with`); an older library takes the three calls. Off with [member native] or [member fused].
static func restores() -> bool:
	if _restores < 0:
		_restores = 1 if available() and ClassDB.class_has_method(LEGS_CLASS, &"restore_with") else 0
	return native and fused and _restores == 1


## Whether the loaded `GSSimLegs` sets the feet on a wall and steps the stride limit in one call
## (`on_wall_with`); an older library takes the two calls. Off with [member native] or [member fused].
static func fuses() -> bool:
	if _fuses < 0:
		_fuses = 1 if available() and ClassDB.class_has_method(LEGS_CLASS, &"on_wall_with") else 0
	return native and fused and _fuses == 1


## Whether the loaded `GSSimFigurePose` makes a figure's aim, leg turn, carry and support hand in one call
## (`upper`); an older library takes the four. Off with [member native] or [member fused].
static func chains() -> bool:
	if _chains < 0:
		_chains = 1 if available() and ClassDB.class_has_method(POSE_CLASS, &"upper") else 0
	return native and fused and _chains == 1


## Whether, with [member fused], a figure's legs after the upper body (wall, stride limit, floor, feet's hold, turn limit and
## resettle) are one call (`GSSimLegs.lower`); an older library makes them one by one.
static func lowers() -> bool:
	if _lowers < 0:
		_lowers = 1 if available() and ClassDB.class_has_method(LEGS_CLASS, &"lower") else 0
	return native and fused and _lowers == 1


## Whether, with [member fused] and [member batched], [GSHumanoidFigureBatch] makes a frame's restore, upper and lower calls
## once for all its figures (`GSSimFigureBatch`); an older library steps them one by one.
static func batches() -> bool:
	if _batches < 0:
		_batches = 1 if available() and ClassDB.class_exists(BATCH_CLASS) else 0
	return native and fused and batched and _batches == 1


## A `GSSimFigureBatch` for one frame's figures, or null for the figure-by-figure path.
static func batch() -> RefCounted:
	if not batches():
		return null
	return ClassDB.instantiate(BATCH_CLASS)
