class_name GSHumanoidNativeLegs
extends RefCounted

## [GSHumanoidLegs]' and [GSHumanoidTurnLimit]'s bone work in GameSpice Sim: `GSSimLegs` turns the
## root and hips, lifts the ankles off the floor, holds and steps the feet, and `GSSimTurnLimit` caps
## the limbs' turn, writing the same rotations into the skeleton as the scripts. The scripts keep their
## fields and decisions and hand the native side what it needs as arguments. Without the extension or
## with [member native] off, the scripts pose the bones themselves: the fallback the web build always
## runs. Reached through [ClassDB] by name, so nothing needs the extension.

const LEGS_CLASS := &"GSSimLegs"
const TURN_CLASS := &"GSSimTurnLimit"

## Pose the legs and cap the turn in GameSpice Sim when it is loaded (the same pose as the scripts);
## off keeps the scripts. Read when a [GSHumanoidLegs] or [GSHumanoidTurnLimit] is made.
static var native := true
static var _known := -1


## Whether the gs_sim extension provides both classes; asked once.
static func available() -> bool:
	if _known < 0:
		_known = 1 if ClassDB.class_exists(LEGS_CLASS) and ClassDB.class_exists(TURN_CLASS) else 0
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
