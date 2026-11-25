class_name GSViewHandPoses
extends RefCounted

## How each hand holds each kind of weapon in first person: the grips [GSPlayerViewArms] closes its [GSViewHand]s
## into. A kind ([member GSViewGrip.kind]) has a `firing` hand (the right) and, for a two-hand weapon, a `support`
## one (the left).
##
## A hand is a Dictionary:
## - `fingers`, `palm`: where the fingers point and the palm faces, in the weapon's frame as Vector3(right, up,
##   forward); the thumb follows from the two and the hand's side;
## - `centre`: the point of the hand, in its own frame (metres at life size: +Y to the fingers, +Z out of the palm,
##   x toward the thumb on a right hand), that sits on the grip point; the wrist is placed from it;
## - `thumb`, `index`, `middle`, `ring`, `pinky`: each finger's three joint curls toward the palm (degrees);
## - `spread`: how far the fingers fan out (degrees);
## - `size`: the hand's size against the arms' (optional, 1): a knife's fist is drawn smaller so its short handle fills it.
##
## A game edits [member GSPlayerViewArms.hand_poses] (a fresh [method table]) to adjust one, or adds kinds.

const RIFLE: StringName = &"rifle"
const PISTOL: StringName = &"pistol"
const SHOTGUN: StringName = &"shotgun"
const LAUNCHER: StringName = &"launcher"
const SNIPER: StringName = &"sniper"
const GRENADE: StringName = &"grenade"
const KNIFE: StringName = &"knife"
const FISTS: StringName = &"fists"
## What a knife hand blends to as a throw winds up ([member GSPlayerViewArms.throw_grip]): the blade pinched between
## the thumb and the first two fingers, the others tucked.
const KNIFE_THROW: StringName = &"knife_throw"
## Melee and missile kinds, each on a weapon whose forward runs along its handle toward the head or blade (or, for
## a bow, up its handle, and for a crossbow, down its stock to the muzzle) and whose up is the side away from the
## blade's edge (toward the holder):
## a one-hand sword, dagger or mace: a fist round the handle, thumb toward the blade.
const SWORD: StringName = &"sword"
## A two-hand haft (axe, spear, longsword, a mace held in both): the right fist on it and the left fist below it.
const HAFT: StringName = &"haft"
## A shield on the left arm: the left fist on its handle; the right hand a relaxed fist at the grip point (a game
## moves it each frame to wherever the free hand rests).
const SHIELD: StringName = &"shield"
## A bow held in the left fist; the right hand's first three fingers hook the string (the grip point, moved each
## frame as the string is drawn).
const BOW: StringName = &"bow"
## A crossbow: the right hand on its grip, the index on the trigger, the left under the stock ahead of it.
const CROSSBOW: StringName = &"crossbow"
## The fingers a hand pose curls, in [GSViewHand]'s order.
const FINGERS: Array[StringName] = [&"thumb", &"index", &"middle", &"ring", &"pinky"]


## The stock grips, a fresh copy each call.
static func table() -> Dictionary:
	# The firing hand on a pistol grip raked back about 20 degrees, the index finger along the trigger guard.
	var trigger := {&"fingers": Vector3(0.0, -0.34, 0.94), &"palm": Vector3(-1.0, 0.0, 0.0), &"centre": Vector3(0.0, 0.066, 0.026),
		&"thumb": Vector3(18.0, 22.0, 12.0), &"index": Vector3(22.0, 48.0, 18.0), &"middle": Vector3(72.0, 92.0, 52.0),
		&"ring": Vector3(76.0, 94.0, 54.0), &"pinky": Vector3(80.0, 92.0, 52.0), &"spread": 0.0}
	var out := {}
	out[RIFLE] = {
		&"firing": trigger.duplicate(),
		# Under the handguard, palm up, the fingers closed round its right side, the thumb along the left.
		&"support": {&"fingers": Vector3(0.85, 0.1, 0.5), &"palm": Vector3(-0.15, 1.0, 0.0), &"centre": Vector3(0.0, 0.07, 0.022),
			&"thumb": Vector3(16.0, 22.0, 12.0), &"index": Vector3(66.0, 80.0, 46.0), &"middle": Vector3(70.0, 84.0, 48.0),
			&"ring": Vector3(72.0, 84.0, 48.0), &"pinky": Vector3(74.0, 82.0, 46.0), &"spread": 1.0},
	}
	out[SNIPER] = {
		&"firing": trigger.duplicate(),
		# The long handguard held from its left side, palm in and a little under it, the fingers forward and up, closing
		# over its top; a palm-up hand under it showed its whole palm and sleeve over the gun.
		&"support": {&"fingers": Vector3(-0.2, 0.4, 0.9), &"palm": Vector3(0.85, 0.5, 0.0), &"centre": Vector3(0.0, 0.065, 0.022),
			&"thumb": Vector3(14.0, 20.0, 12.0), &"index": Vector3(64.0, 78.0, 46.0), &"middle": Vector3(68.0, 82.0, 48.0),
			&"ring": Vector3(70.0, 82.0, 48.0), &"pinky": Vector3(72.0, 80.0, 46.0), &"spread": 1.0},
	}
	out[SHOTGUN] = {
		&"firing": trigger.duplicate(),
		# Round the pump: the fingers close up its right side.
		&"support": {&"fingers": Vector3(0.95, 0.15, 0.3), &"palm": Vector3(-0.2, 1.0, 0.0), &"centre": Vector3(0.0, 0.07, 0.026),
			&"thumb": Vector3(16.0, 22.0, 12.0), &"index": Vector3(68.0, 80.0, 46.0), &"middle": Vector3(70.0, 84.0, 48.0),
			&"ring": Vector3(72.0, 84.0, 48.0), &"pinky": Vector3(74.0, 82.0, 46.0), &"spread": 0.0},
	}
	out[LAUNCHER] = {
		&"firing": trigger.duplicate(),
		# A vertical fore grip, palm in from the left, thumb up.
		&"support": {&"fingers": Vector3(0.0, -0.25, 1.0), &"palm": Vector3(1.0, 0.0, 0.0), &"centre": Vector3(0.0, 0.066, 0.026),
			&"thumb": Vector3(16.0, 20.0, 12.0), &"index": Vector3(70.0, 88.0, 50.0), &"middle": Vector3(72.0, 92.0, 52.0),
			&"ring": Vector3(76.0, 94.0, 54.0), &"pinky": Vector3(80.0, 92.0, 52.0), &"spread": 0.0},
	}
	var pistol: Dictionary = trigger.duplicate()
	pistol[&"fingers"] = Vector3(0.0, -0.24, 0.97)
	out[PISTOL] = {
		&"firing": pistol,
		# Thumbs forward: the support hand wraps the firing fingers from the left, palm in.
		&"support": {&"fingers": Vector3(0.25, -0.75, 0.6), &"palm": Vector3(1.0, -0.1, 0.25), &"centre": Vector3(0.0, 0.06, 0.03),
			&"thumb": Vector3(10.0, 12.0, 8.0), &"index": Vector3(58.0, 70.0, 40.0), &"middle": Vector3(62.0, 74.0, 44.0),
			&"ring": Vector3(66.0, 76.0, 44.0), &"pinky": Vector3(70.0, 74.0, 44.0), &"spread": 0.0},
	}
	# A ball in the fingers, the hand under and behind it.
	out[GRENADE] = {&"firing": {&"fingers": Vector3(-0.25, 0.55, 0.8), &"palm": Vector3(-0.55, 0.55, -0.35), &"centre": Vector3(0.0, 0.088, 0.036),
		&"thumb": Vector3(26.0, 26.0, 16.0), &"index": Vector3(40.0, 46.0, 30.0), &"middle": Vector3(42.0, 48.0, 32.0),
		&"ring": Vector3(44.0, 48.0, 32.0), &"pinky": Vector3(46.0, 46.0, 30.0), &"spread": 10.0}}
	# A fist round the handle, which runs along the thumb's line to the blade: fingers down, palm in, thumb forward.
	out[KNIFE] = {&"firing": {&"fingers": Vector3(0.0, -1.0, 0.25), &"palm": Vector3(-1.0, 0.0, 0.0), &"centre": Vector3(0.0, 0.07, 0.024),
		&"thumb": Vector3(26.0, 30.0, 16.0), &"index": Vector3(78.0, 96.0, 56.0), &"middle": Vector3(80.0, 98.0, 58.0),
		&"ring": Vector3(82.0, 98.0, 58.0), &"pinky": Vector3(84.0, 96.0, 56.0), &"spread": 0.0, &"size": 0.8}}
	out[KNIFE_THROW] = {&"firing": {&"fingers": Vector3(0.0, -1.0, 0.25), &"palm": Vector3(-1.0, 0.0, 0.0), &"centre": Vector3(0.0, 0.105, 0.018),
		&"thumb": Vector3(8.0, 18.0, 14.0), &"index": Vector3(30.0, 34.0, 18.0), &"middle": Vector3(36.0, 40.0, 22.0),
		&"ring": Vector3(80.0, 96.0, 56.0), &"pinky": Vector3(84.0, 94.0, 54.0), &"spread": 2.0}}
	out[FISTS] = {&"firing": {&"fingers": Vector3(0.0, 0.0, 1.0), &"palm": Vector3(-1.0, 0.0, 0.0), &"centre": Vector3(0.0, 0.07, 0.02),
		&"thumb": Vector3(32.0, 40.0, 26.0), &"index": Vector3(86.0, 100.0, 62.0), &"middle": Vector3(88.0, 102.0, 62.0),
		&"ring": Vector3(88.0, 102.0, 62.0), &"pinky": Vector3(88.0, 100.0, 60.0), &"spread": 0.0}}
	_add_melee(out)
	return out


## The sword, haft, shield, bow and crossbow grips. A left (support) hand is written for the left: its palm +x
## faces right, its thumb follows mirrored.
static func _add_melee(out: Dictionary) -> void:
	# A fist round a handle that runs along the weapon's forward: fingers down and a little forward, palm in.
	var fist := {&"fingers": Vector3(0.0, -1.0, 0.2), &"palm": Vector3(-1.0, 0.0, 0.0), &"centre": Vector3(0.0, 0.072, 0.026),
		&"thumb": Vector3(28.0, 32.0, 18.0), &"index": Vector3(78.0, 96.0, 56.0), &"middle": Vector3(80.0, 98.0, 58.0),
		&"ring": Vector3(82.0, 98.0, 58.0), &"pinky": Vector3(84.0, 96.0, 56.0), &"spread": 0.0, &"size": 0.95}
	var left_fist: Dictionary = fist.duplicate()
	left_fist[&"palm"] = Vector3(1.0, 0.0, 0.0)
	out[SWORD] = {&"firing": fist.duplicate()}
	out[HAFT] = {&"firing": fist.duplicate(), &"support": left_fist.duplicate()}
	# The free right hand by the hip, loosely closed: the grip point is the middle of its curled fingers.
	var loose := {&"fingers": Vector3(0.0, -1.0, 0.1), &"palm": Vector3(-1.0, 0.0, 0.0), &"centre": Vector3(0.0, 0.07, 0.03),
		&"thumb": Vector3(14.0, 18.0, 10.0), &"index": Vector3(36.0, 44.0, 26.0), &"middle": Vector3(40.0, 48.0, 28.0),
		&"ring": Vector3(44.0, 50.0, 30.0), &"pinky": Vector3(48.0, 50.0, 30.0), &"spread": 4.0}
	out[SHIELD] = {&"firing": loose, &"support": left_fist.duplicate()}
	# The string on the first joints of three fingers, the thumb tucked under, the pinky folded.
	var draw := {&"fingers": Vector3(0.0, 0.2, 1.0), &"palm": Vector3(-1.0, 0.0, 0.0), &"centre": Vector3(0.0, 0.088, 0.03),
		&"thumb": Vector3(40.0, 44.0, 26.0), &"index": Vector3(18.0, 64.0, 34.0), &"middle": Vector3(16.0, 70.0, 38.0),
		&"ring": Vector3(18.0, 66.0, 36.0), &"pinky": Vector3(80.0, 94.0, 54.0), &"spread": 0.0}
	out[BOW] = {&"firing": draw, &"support": left_fist.duplicate()}
	# The right hand on the grip behind the trigger; the left under the fore-stock, palm up, fingers round its right.
	out[CROSSBOW] = {
		&"firing": {&"fingers": Vector3(0.0, -0.5, 0.86), &"palm": Vector3(-1.0, 0.0, 0.0), &"centre": Vector3(0.0, 0.066, 0.026),
			&"thumb": Vector3(18.0, 22.0, 12.0), &"index": Vector3(22.0, 48.0, 18.0), &"middle": Vector3(72.0, 92.0, 52.0),
			&"ring": Vector3(76.0, 94.0, 54.0), &"pinky": Vector3(80.0, 92.0, 52.0), &"spread": 0.0},
		&"support": {&"fingers": Vector3(0.8, 0.1, 0.55), &"palm": Vector3(-0.1, 1.0, 0.0), &"centre": Vector3(0.0, 0.07, 0.024),
			&"thumb": Vector3(16.0, 22.0, 12.0), &"index": Vector3(64.0, 78.0, 44.0), &"middle": Vector3(68.0, 82.0, 46.0),
			&"ring": Vector3(70.0, 82.0, 46.0), &"pinky": Vector3(72.0, 80.0, 44.0), &"spread": 1.0},
	}


## [param a] blended toward [param b] by [param t] (0 to 1): curls, centre and directions.
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	if not (t > 0.0) or b.is_empty():
		return a
	if t >= 1.0:
		return b
	var out := a.duplicate()
	for key in b:
		if a.has(key) and a[key] is Vector3:
			out[key] = (a[key] as Vector3).lerp(b[key], t)
		elif a.has(key) and (a[key] is float or a[key] is int):
			out[key] = lerpf(float(a[key]), float(b[key]), t)
	return out


## The hand's frame (orthonormal, before its size) for [param hand] on a weapon whose forward and up are
## [param forward] and [param up] (world): x = y cross z, so a right hand's thumb is +x and a mirrored left one's -x.
static func frame(hand: Dictionary, forward: Vector3, up: Vector3) -> Basis:
	var f := forward.normalized()
	var u := up.normalized() - f * up.normalized().dot(f)
	# An up along the forward (a grenade's art forward is its own up) has no side to close round: what is left of it
	# is noise, which flipped the hand 0.13 m frame to frame. The world's up then, or its back for a forward along it.
	if u.length() < 0.1:
		var ref := Vector3.UP if absf(f.y) < 0.9 else Vector3.BACK
		u = ref - f * ref.dot(f)
	u = u.normalized()
	if not f.is_normalized() or not u.is_normalized():
		return Basis.IDENTITY
	var r := f.cross(u)
	var p: Vector3 = hand.get(&"palm", Vector3(-1.0, 0.0, 0.0))
	var palm := (r * p.x + u * p.y + f * p.z).normalized()
	var g: Vector3 = hand.get(&"fingers", Vector3(0.0, 0.0, 1.0))
	var along := r * g.x + u * g.y + f * g.z
	var fingers := (along - palm * along.dot(palm)).normalized()
	if not fingers.is_normalized():
		fingers = (f - palm * f.dot(palm)).normalized()
	return Basis(fingers.cross(palm), fingers, palm)
