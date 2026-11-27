extends Node3D

## [GSPlayerViewArms]'s constants, settings and state, split out to keep each file small.

## Bones shrunk to nothing; the arms hang off the chest, so they stay.
const HIDDEN_BONES: Array[String] = ["Head", "Neck", "UpperLeg.L", "UpperLeg.R"]
## The pack is part of the one skinned mesh, bound to the hips: its vertices are the hip-bound ones this far behind the body.
const PACK_BONE := "Hips"
## Bones whose own triangles are the trunk, dropped from the first-person mesh (the arms hang from the shoulders).
const TRUNK_BONES: Array[StringName] = [&"Torso", &"Abdomen", &"Hips"]
const PACK_BEHIND := -0.3
## The finger roots, all at the wrist: scaling them shrinks the hand about the wrist, so the forearm and the reach are untouched.
const FINGER_ROOTS: Array[String] = ["Pinky1", "Middle1", "Index1", "Thumb1"]
## The support arm, dropped from the mesh drawn while a weapon is held one-handed (a second copy of the mesh, swapped in:
## shrinking the bones instead pulled the sleeve into a flap at the screen's edge).
const LEFT_ARM_BONES: Array[String] = ["Shoulder.L"]
## A vertex carrying more than this weight on a dropped bone takes its triangles with it.
const TOUCH_WEIGHT := 0.01

## Extension point: `func(look: GSHumanoidLook, height: float) -> Node3D`. The node it returns is parented here and
## drawn as is, in place of the person; if it has `set_motion` and `animate` (a [GSHumanoidFigure]) they are driven.
## Fraction of the arm the lean aims to need, so the slide to reach never trims a hand the lean just brought in.
const LEAN_SLACK := 0.97
## How fast the drawn forearm scale follows a new [member forearm_scale], per second.
const FORE_RATE := 2.0
## How fast the drawn lean shrinks to the lean a grip needs, metres per second: a swap from a two-hand grip (the support
## hand far out) to a one-hand one moved the shoulder 0.27 m in one frame and the elbow with it, the hand still. A lean
## that has to grow is taken at once (a hand short of its grip is worse than a step).
const LEAN_RATE := 1.2
## Elbow turns tried about the shoulder-to-hand line (degrees) to take an arm out of the weapon's box, and how much
## of the forearm next to the hand may stay inside it (the hand is on the gun).
## The scan itself is [GSViewArmsClear], native when GameSpice Sim's "arms" module is loaded.
const CLEAR_ANGLES: Array[float] = GSViewArmsClear.ANGLES
const CLEAR_HAND_FREE := GSViewArmsClear.HAND_FREE

var arms_factory: Callable = Callable()
## Extension point: `func(bone: StringName, rest_position: Vector3) -> bool`, true for a vertex that is carried gear
## (a backpack) and must not show; triangles touching one are dropped. The default is the stock kit's pack.
var hide_vertex_fn: Callable = Callable()
## Where the camera sits relative to the crawling figure's head bone, in the figure's own frame (the clip lies the
## person along Z; the eye is measured from the posed head, not assumed, so a game's own figure fits too).
var eye_from_head: Vector3 = Vector3(0.0, 0.3, -0.4)
## The look drawn: [member own_look], or the server's [method set_look_override] while one is set.
var look: GSHumanoidLook = null
## The look [method build] was given: the player's own avatar, so each player's arms are their own.
var own_look: GSHumanoidLook = null
## The arms' close-up material ([GSViewArmsMaterial]: skin and cloth detail). Off: the crowd's flat palette.
var detailed: bool = true
## Vertical field of view the arms draw at in first person (the `viewmodel_fov` lens, [GSViewLens]); 0 is the camera's
## own. Needs [member detailed]. Only for arms whose held model is not lensed itself: a lensed weapon is scaled twice.
var hands_fov: float = 0.0:
	set(value):
		if not is_finite(value) or value < 0.0 or value >= 179.0:
			push_error("GSPlayerViewArms.hands_fov must be 0 (off) or under 179 degrees, got %s" % value)
			return
		hands_fov = value
## The lens scale at which the arms draw life size: [method GSViewLens.lens_scale] of the game's default camera and
## default [member hands_fov]. The arms draw at lens_scale(camera, hands_fov) over it, so the defaults change nothing.
var lens_neutral: float = 1.0:
	set(value):
		if not is_finite(value) or value <= 0.0:
			push_error("GSPlayerViewArms.lens_neutral must be above 0, got %s" % value)
			return
		lens_neutral = value
## Turn the elbows so the arms do not pass through the weapon ([member GSViewGrip.bounds]); its radius in metres.
var keep_arms_clear: bool = true
var arm_radius: float = 0.03
## How deep each arm (firing, support) sat inside the weapon's box after the last solve, metres; 0 is clear.
var arm_depth_right: float = 0.0
var arm_depth_left: float = 0.0
## Run the elbow clearance scan in GameSpice Sim's native [code]GSSimViewArms[/code] when it is loaded (bit-identical to
## [GSViewArmsClear]); false keeps the script (the A/B baseline). Read once, on the first scan.
var native_clear: bool = true
var height: float = 1.8
var shown: bool = false
## Where the camera sits from the head bone when holding a weapon (upright figure, forward is -Z). A little behind it:
## further forward a near grip (a pump gun's) folds the elbow up beside the eye and the forearm fans across the view.
var held_eye_from_head: Vector3 = Vector3(0.0, 0.18, 0.06)
## Elbow directions in the arms' frame (right arm; the left is mirrored): out, down, a little back.
## Where the idle hand rests, from the arms node, out of the view, when the weapon is held with one hand.
const LEFT_REST := Vector3(-0.25, 0.9, 0.1)
var elbow_pole: Vector3 = Vector3(1.0, -1.2, 0.5)
## The support (left) elbow's direction in the same frame, as the left arm sees it; zero mirrors [member elbow_pole].
## Mirrored, the support elbow went out to the left and its forearm and sleeve crossed the view toward a handguard.
var support_elbow_pole: Vector3 = Vector3.ZERO
## The support forearm's girth on a two-hand grip, its length kept: it runs from the view's corner to the fore-end, near
## the eye, and at full girth its sleeve filled a quarter of the view (the sniper's). 1 draws it as built.
var support_forearm_girth: float = 1.0
## The held arms' size and how much wider apart the shoulders sit: slimmer arms leave the weapon visible.
var held_scale: float = 0.75
var held_spread: float = 1.25
## Draw the support forearm and hand as the firing ones mirrored, so one-sided forearm gear never crosses the view.
var mirror_support_forearm: bool = true
## How many times the arms' triangles are split and rounded (each level is four times the triangles, built once per
## body mesh): the kit's octagonal sleeves read as a staircase that close to the eye (FC judge D4). 0 draws them as built.
var sleeve_smooth_levels: int = 1
## Show the idle left arm in a one-hand grip. Off: it has no hand in view, only its sleeve at the screen edge.
var show_idle_left_arm: bool = false
## A sprint with one hand on the weapon (0 to 1, the host sets it each frame): the free arm pumps into view as a
## fist at [member run_left] (from this node), swinging by [member run_left_pump] against the stride, [member run_phase] (0 to 1).
var run: float = 0.0
var run_phase: float = 0.0
var run_left: Vector3 = Vector3(-0.2, -0.3, -0.32)
var run_left_pump: Vector3 = Vector3(0.0, 0.07, -0.1)
## How far below the view the pumping fist starts as [member run] eases in, so it rises into view, not pops.
const RUN_LEFT_DROP := Vector3(0.0, -0.3, 0.1)
## The hand's size with a weapon (1 is the kit's own mitts).
var hand_scale: float = 0.5
## The forearm's size with a weapon (1 is the kit's own); the hand keeps [member hand_scale]. A short grip close to the eye wants a slimmer, shorter forearm.
var forearm_scale: float = 1.0
## Where the wrist sits from the grip point, in the arms' frame (x out to the hand's side, y up, -z forward): just off
## the gun's centreline, so the hand wraps the grip's side instead of covering the sights or hanging below the grip.
var palm_offset: Vector3 = Vector3(0.015, -0.01, 0.02)
## How far the shoulders may lean toward a firing-hand target out of the arm's reach, metres; past it the hand stays short.
var max_lean: float = 0.4
## Draw [GSViewHand]s, five jointed fingers closed on the weapon with a [GSViewHandPoses] grip, in place of the
## kit's mitts while a weapon is held (false: the mitts and [member palm_offset], as before). Read by [method build].
var real_hands: bool = true
## The grips the real hands close into, by [member GSViewGrip.kind] ([method GSViewHandPoses.table]; edit or add kinds).
var hand_poses: Dictionary = GSViewHandPoses.table()
## The real hands' size against life size on the held arms (it follows [member held_scale] and [member hand_scale]
## over the kit's 0.5, so a game's per-weapon hand size still applies).
var hand_size: float = 1.0
## How far a knife hand has gone from its fist toward the throw's pinch ([constant GSViewHandPoses.KNIFE_THROW]),
## 0 to 1; the host sets it each frame from the throw's wind-back.
var throw_grip: float = 0.0
## How far the support hand has gone from its fore-end grip toward the throw's pinch, 0 to 1: a bolt handle is
## taken between finger and thumb. The host sets it each frame from the cycle.
var cycle_grip: float = 0.0
## How fast the fingers close into a new grip, per second; 0 closes them at once.
var finger_rate: float = 14.0
## Move the shoulder joint out toward a hand target the lean left out of the arm's reach (a long forend), so the hand
## lands on it instead of short; false leaves the hand short (the old slide toward the firing hand still applies).
var extend_reach: bool = true
## The most [member extend_reach] moves a shoulder, in the figure's own metres; 0 is no limit.
var reach_extend_max: float = 0.3
## Metres between the hand and its target after the last solve (firing hand, support hand); 0 when that hand is unused.
var hand_gap_right: float = 0.0
var hand_gap_left: float = 0.0
## The nearest a wrist target may come to the eye, metres along the view's forward: a hand the gun brings closer (a
## reload pulled to the chest, a gun pushed back by a wall) slides out along the forward to it, so its fingers stay past
## the camera's near plane. 0 is off (the old seat); a negative or non-finite value is refused with an error.
var hand_min_depth: float = 0.0:
	set(value):
		if value < 0.0 or not is_finite(value):
			push_error("GSPlayerViewArms.hand_min_depth must be 0 or more, got %s" % value)
			return
		hand_min_depth = value
## How many times further off than the arms the held weapon is drawn: a game that draws its gun beyond life size and
## brings it to life size about the eye for the arms (a hands frame) sets it, and the arms' close-up material
## ([GSViewArmsMaterial]) writes their depth as if grown by it about the eye. The pixels stay put, but the depth test
## then sees the arms where the gun is: fingers wrap behind a grip, the gun covers the forearm under it, instead of the
## whole arm drawing over the gun from a third of its distance. 1 is off; below 1 or non-finite is refused with an error.
var draw_depth: float = 1.0:
	set(value):
		if value < 1.0 or not is_finite(value):
			push_error("GSPlayerViewArms.draw_depth must be 1 or more, got %s" % value)
			return
		draw_depth = value
## Draws the grip sockets, hand targets and arm bone axes over the view ([GSViewArmsPoseDebug]).
var debug_pose: bool = false:
	set(value):
		debug_pose = value
		if not value and _pose_debug != null:
			_pose_debug.queue_free()
			_pose_debug = null
var _pose_debug: GSViewArmsPoseDebug = null
## Idle breathing and walk bob, metres: [method sway] is what the host adds to its weapon mount.
var breath_amplitude: float = 0.003
var bob_amplitude: float = 0.012

var _arms: Node3D = null
var _bones: Array[int] = []
var _fingers: Array[int] = []
## Keeps the arms undrawn from a change of mode until they are fitted and have been posed for [constant FIT_TICKS] ticks
## (a refit seats the head bone where the clip's first frames are still settling, so the arms swing into place). Off by default:
## a host that drives `arms().visible` itself leaves it off.
var hide_until_fitted: bool = false
const FIT_TICKS := 3
var _fitted := false
var _ticks := 0
var _head: int = -1
var _downed := false
var _grip: GSViewGrip = null
var _phase := 0.0
var _sway := Vector3.ZERO
var _base := Vector3.ZERO
var _right: Array[int] = []
var _left: Array[int] = []
var _override: GSHumanoidLook = null
var _detail_on := false
## [method _grip_hands] read once per tick ([member _hands_tick] while one runs).
var _hands_tick := false
var _hands_for: GSViewGrip = null
var _hands_memo: Array = []
## Reused per tick so the arms allocate nothing for their hands: the [firing, support] pair of
## [method _grip_hands_now], the two wrist targets, and the mirrored fist with the pose it was built from.
var _hands_pair: Array[Dictionary] = [{}, {}]
var _wrists: Array[Vector3] = [Vector3.INF, Vector3.INF]
var _mirror_from: Dictionary = {}  # perf-lint: allow untyped_array a hand pose row
var _mirror_out: Dictionary = {}  # perf-lint: allow untyped_array a hand pose row
## Bone indices of the arm scale pass, looked up once per skeleton (find_bone by name is a string search per call).
var _arm_skeleton: Skeleton3D = null
var _arm_left: Array[int] = []
var _arm_upper_r := -1
var _arm_lower_r := -1
## Last values written to the draw-depth instance uniforms, so an unchanged set is not re-sent.
var _depth_sent := Vector4(NAN, 0.0, 0.0, 0.0)
var _lens_sent := 1.0
var _depth_meshes: Array[GeometryInstance3D] = []
var _turn_right := 0.0
var _turn_left := 0.0
## GameSpice Sim's GSSimViewArms, made on the first scan when [member native_clear] and the class exists; reached by name
## (never typed) so this addon loads without the extension. [member _native_tried] keeps it to one probe.
var _native: Object = null
var _native_tried := false
## The forearm scale drawn, eased toward [member forearm_scale] (or 1 without a weapon) at [constant FORE_RATE].
var _fore := 1.0
## The lean drawn, eased toward the one the grip needs at [constant LEAN_RATE]; [member _delta] is this tick's step.
var _leaned := Vector3.ZERO
var _delta := 1.0 / 60.0
var _was_holding := false
## The real hands, firing (right) then support (left); empty with [member real_hands] off or a factory's arms.
var _hands: Array[GSViewHand] = []
## Upper-arm bones [method _extend] moved this tick, put back to their rest the next.
var _extended: Array[int] = []
## How far each shoulder was moved out last tick (firing, support), figure metres.
var reach_extended_right: float = 0.0
var reach_extended_left: float = 0.0
## The figure's mesh with both arms and with the support arm dropped ([constant LEFT_ARM_BONES]).
var _two_arm_mesh: Mesh = null
var _one_arm_mesh: Mesh = null
