class_name GSHumanoidNativeClips
extends RefCounted

## [GSHumanoidFigure]'s clip playback in GameSpice Sim: `GSSimClipPlayer` plays, seeks, advances
## and cross-fades the clips the way the figure's [AnimationPlayer] does and writes the posed bones
## straight into the skeleton, so the figure's mixer stays inactive (kept only for its library).
## Without the extension, with [member native] off, or with a clip the native player does not do
## (scale tracks, eased or cubic keys), the figure keeps its [AnimationPlayer]: the fallback the web
## build always runs. Reached through [ClassDB] by name, so nothing needs the extension.

const SET_CLASS := &"GSSimClipSet"
const PLAYER_CLASS := &"GSSimClipPlayer"
## The clips' skeleton path from the player's root, as their tracks name it ([GSHumanoidFigure] renames other exporters' to it).
const SKELETON_PATH := "CharacterArmature/Skeleton3D"

## Play the clips in GameSpice Sim when it is loaded (the same pose as the mixer); off keeps the
## [AnimationPlayer]. Read when a body is built.
static var native := true
static var _known := -1
## Baked sets by library and skeleton size, shared by every figure of a body: [code]{key: GSSimClipSet or null}[/code].
static var _sets := {}


## Whether the gs_sim extension provides the clip player; asked once.
static func available() -> bool:
	if _known < 0:
		_known = 1 if ClassDB.class_exists(SET_CLASS) and ClassDB.class_exists(PLAYER_CLASS) else 0
	return _known == 1


## A clip player for [param anim]'s library on [param skeleton], or null for the [AnimationPlayer]
## path. Plays nothing yet.
static func player_for(anim: AnimationPlayer, skeleton: Skeleton3D) -> RefCounted:
	if not native or anim == null or skeleton == null or not available():
		return null
	if not anim.has_animation_library(&""):
		return null
	var library := anim.get_animation_library(&"")
	var key := "%d:%d:%d" % [library.get_instance_id(), skeleton.get_bone_count(), library.get_animation_list().size()]
	if not _sets.has(key):
		var made: RefCounted = ClassDB.instantiate(SET_CLASS)
		var baked: bool = made.call(&"bake", library, skeleton, SKELETON_PATH)
		if not baked:
			GSLog.info("figure", "clips stay on the AnimationPlayer", {"why": String(made.call(&"failure"))})
		_sets[key] = made if baked else null
	var set_for: RefCounted = _sets[key]
	if set_for == null:
		return null
	var player: RefCounted = ClassDB.instantiate(PLAYER_CLASS)
	var ok: bool = player.call(&"setup", set_for, skeleton)
	return player if ok else null


## Forgets the baked sets (a test that rebuilds libraries).
static func clear() -> void:
	_sets.clear()
