extends "gs_humanoid_figure_state.gd"

## [GSHumanoidFigure]'s clip choice, overlays, aim, support hand and swim lean, split out to keep each file small.

func _clip_for(p_state: StringName, speed: float) -> Array:
	var gun := hold == Hold.GUN
	if downed and propped:
		var named := StringName(downed_clips.get(&"propped", &""))
		if named == &"":
			named = GSHumanoidClips.IDLE_GUN if gun else GSHumanoidClips.IDLE
		return [named, 1.0]
	if downed:
		return [StringName(downed_clips.get(&"crawl", GSHumanoidClips.CRAWL)), clampf(speed / CRAWL_NATURAL, 0.0, 3.4)]
	if _action_full != &"":
		return [_action_full, 1.0]
	# A rider is carried: whatever speed the seat moves at, the legs stay sat.
	if seated and p_state != GSPlayerAnimState.DEAD:
		if driving and _anim != null and _anim.has_animation(GSHumanoidClips.DRIVE):
			return [GSHumanoidClips.DRIVE, 1.0]
		return [GSHumanoidClips.SIT, 1.0]
	# Running along a wall: the legs run in the air (the body is rolled onto the wall by the game).
	if bool(_motion.get("wall_running", false)) and p_state in [
			GSPlayerAnimState.JUMP, GSPlayerAnimState.FALL, GSPlayerAnimState.LAND]:
		return [GSHumanoidClips.RUN_GUN if gun else GSHumanoidClips.RUN, clampf(speed / 5.0, 0.7, 1.5)]
	# A slide on the ground: leant back, legs forward. The game's `sliding` key; in the air it is a fall.
	if bool(_motion.get("sliding", false)) and p_state in [
			GSPlayerAnimState.CROUCH_IDLE, GSPlayerAnimState.CROUCH_WALK, GSPlayerAnimState.RUN,
			GSPlayerAnimState.WALK, GSPlayerAnimState.IDLE] and _anim != null and _anim.has_animation(GSHumanoidClips.SLIDE):
		return [GSHumanoidClips.SLIDE, 1.0]
	if zombie_gait and not gun and _anim != null:
		var zombie := _zombie_clip_for(p_state, speed)
		if not zombie.is_empty():
			return zombie
	match p_state:
		GSPlayerAnimState.DEAD:
			return [GSHumanoidClips.DEATH, 1.0]
		GSPlayerAnimState.SWIM:
			return [GSHumanoidClips.SWIM, clampf(speed / 2.5, 0.45, 1.3)]
		GSPlayerAnimState.JUMP:
			return [GSHumanoidClips.JUMP, 1.0]
		GSPlayerAnimState.FALL:
			return [GSHumanoidClips.FALL, 1.0]
		GSPlayerAnimState.LAND:
			return [GSHumanoidClips.LAND, 1.4]
		GSPlayerAnimState.CROUCH_IDLE:
			return [GSHumanoidClips.CROUCH, 1.0]
		GSPlayerAnimState.CROUCH_WALK:
			return [GSHumanoidClips.CROUCH_WALK, clampf(speed / 1.6, 0.5, 1.6)]
		GSPlayerAnimState.WALK:
			# A game whose run threshold sits above its sprint speed would walk at a sprinter's pace.
			if sprint_speed > 0.0 and speed >= sprint_speed and _sprint_clip_for(speed):
				return [GSHumanoidClips.SPRINT, 1.0]
			return [GSHumanoidClips.WALK_GUN if gun else GSHumanoidClips.WALK, clampf(speed / WALK_NATURAL, 0.6, 1.8)]
		GSPlayerAnimState.RUN:
			if _sprint_clip_for(speed):
				return [GSHumanoidClips.SPRINT, 1.0]
			return [GSHumanoidClips.RUN_GUN if gun else GSHumanoidClips.RUN, clampf(speed / 5.0, 0.7, 1.5)]
		GSPlayerAnimState.CLIMB:
			return [GSHumanoidClips.CLIMB, clampf(absf(float(_motion.get("vertical", 0.0))) / 2.5, 0.0, 1.2)]
	return [GSHumanoidClips.IDLE_GUN if gun else GSHumanoidClips.IDLE, 1.0]


## The zombie gait's clip and rate for a ground state, or empty. The rates are the clips' own ground speeds (metres a second).
func _zombie_clip_for(p_state: StringName, speed: float) -> Array:
	match p_state:
		GSPlayerAnimState.IDLE:
			if _anim.has_animation(GSHumanoidClips.ZOMBIE_IDLE):
				return [GSHumanoidClips.ZOMBIE_IDLE, 1.0]
		GSPlayerAnimState.WALK:
			if _anim.has_animation(GSHumanoidClips.ZOMBIE_WALK):
				return [GSHumanoidClips.ZOMBIE_WALK, clampf(speed / ZOMBIE_WALK_NATURAL, 0.6, 1.8)]
		GSPlayerAnimState.RUN:
			if _anim.has_animation(GSHumanoidClips.SPRINT):
				return [GSHumanoidClips.SPRINT, clampf(speed / ZOMBIE_SPRINT_NATURAL, 0.7, 1.5)]
	return []


## Whether a runner at [param speed] plays the sprint clip: the game's `sprinting` key when it sends one, else the speed, with a gap so it does not flicker.
func _sprint_clip_for(speed: float) -> bool:
	if _anim == null or not _anim.has_animation(GSHumanoidClips.SPRINT):
		return false
	var from := sprint_speed if sprint_speed > 0.0 else _machine.run_speed * 1.6
	# The run clip hovers (both feet up) above its own pace, whoever says sprinting; the sprint clip stays grounded.
	# That pace is a 1.8 m body's: a smaller one strides shorter, so the same ground speed is a faster run for it.
	var body := height / 1.8
	from = minf(from, RUN_CLIP_MAX_SPEED * body)
	var fast := speed >= from - (SPRINT_EXIT * body if _sprint_clip else 0.0)
	_sprint_clip = (sprinting or fast) if _motion.has("sprinting") else fast
	return _sprint_clip


## The rate that moves the lower foot back exactly as far as the body goes this step (negative walking backward), or NAN when the
## clip is not a stride. The clips have no root motion and sweep the planted foot back unevenly, so
## any constant rate skates it; the rate is read off the clip's distance table instead.
func _matched_rate(speed: float, dt: float) -> float:
	if dt <= 0.0 or not state in STRIDE_STATES:
		return NAN
	if not clip in STRIDE_CLIPS or _current_clip() != clip:
		return NAN
	var table := _stride_for(clip)
	if table.size() < 2 or table[-1] <= 0.0:
		return NAN
	var length := _clip_length()
	var phase := fposmod(_clip_position(), length) / length
	var back := -1.0 if legs.backward else 1.0
	var want := GSHumanoidStride.distance_at(table, phase) + back * speed * dt
	var laps := floorf(want / table[-1])
	var to := GSHumanoidStride.phase_at(table, want - laps * table[-1]) + laps
	var most := stride_max_rate if stride_max_rate > 0.0 else INF
	# Where the table says the foot hardly moves the matched rate races the clip, and a leg swings through in a frame or two.
	if stride_rate_span > 0.0:
		most = minf(most, speed * length / table[-1] * stride_rate_span)
	return clampf((to - phase) * length / dt * back, 0.0, most) * back


func _stride_for(clip_id: StringName) -> PackedFloat32Array:
	if not _strides.has(clip_id):
		_strides[clip_id] = GSHumanoidStride.table_for(_anim.get_animation(clip_id), _skeleton, _model, _to_figure())
	return _strides[clip_id]


func _play(wanted: StringName, rate: float) -> void:
	if _anim == null:
		return
	# An action uploaded after the clips were baked: this figure goes back to its mixer.
	if _clips != null and _anim.has_animation(wanted) and not bool(_clips.call(&"has_animation", wanted)):
		_drop_native_clips()
	if not _anim.has_animation(wanted):
		wanted = GSHumanoidClips.IDLE
		if not _anim.has_animation(wanted):
			return
	_set_clip_rate(rate)
	if clip == wanted:
		return
	var from := _stride_fraction()
	var low_from := clip == GSHumanoidClips.SLIDE or clip == GSHumanoidClips.CROUCH or clip == GSHumanoidClips.CROUCH_WALK
	var low_to := wanted == GSHumanoidClips.SLIDE or wanted == GSHumanoidClips.CROUCH or wanted == GSHumanoidClips.CROUCH_WALK
	# Into or out of a crouched or sliding clip: the stance's own time, not a stride's, so the head does not pop up or down.
	var stance := low_from != low_to
	var blend := SLIDE_BLEND if wanted == GSHumanoidClips.SLIDE or clip == GSHumanoidClips.SLIDE else (CROUCH_BLEND if stance else 0.15)
	clip = wanted
	var cross := from >= 0.0 and wanted in STRIDE_CLIPS
	# A stride cut keeps the feet planted but would snap the arms, and the gun in the hand with them.
	if cross:
		_ease.begin(_skeleton, _upper, HAND_BONE, blend if stance else GSHumanoidBlend.SECONDS)
	var feet := GSHumanoidStride.feet_now(_skeleton, _to_figure()) if cross else PackedVector3Array()
	_play_clip(wanted, 0.0 if cross else blend)
	if cross and not feet.is_empty():
		_seek_clip(GSHumanoidStride.matching_time(_anim.get_animation(wanted), _skeleton, _model, _to_figure(), feet))


## How far through its stride the playing clip's planted foot is, 0 to 1, or -1 when it is not a stride clip. A clip entered at this fraction keeps the foot it stands on travelling with the ground.
func _stride_fraction() -> float:
	if not clip in STRIDE_CLIPS or _current_clip() != clip:
		return -1.0
	var table := _stride_for(clip)
	if table.size() < 2 or table[-1] <= 0.0:
		return -1.0
	var length := _clip_length()
	return GSHumanoidStride.distance_at(table, fposmod(_clip_position(), length) / length) / table[-1]


## Ends a looping or full-body action when the player leaves the spot: a pose is for standing.
func _end_action_if_moved() -> void:
	if action == &"" and not _overlay_loop:
		return
	var still := state == GSPlayerAnimState.IDLE or state == GSPlayerAnimState.CROUCH_IDLE
	if _action_full != &"" and not still:
		stop_action()
	elif _overlay_loop and (downed or state in [GSPlayerAnimState.DEAD, GSPlayerAnimState.SWIM,
			GSPlayerAnimState.CLIMB, GSPlayerAnimState.JUMP, GSPlayerAnimState.FALL, GSPlayerAnimState.RUN]):
		stop_action()


func _start_overlay(which: StringName, rate: float) -> void:
	if _anim == null or not _anim.has_animation(which):
		return
	_overlay_loop = false
	_overlay_stopping = false
	_stop_time = 0.0
	_overlay_blend = BLEND_IN
	action = &""
	overlay = which
	_overlay_time = 0.0
	_overlay_rate = rate
	_overlay_gain = 1.0


## Bends the waist and chest by [member aim_pitch] after the clip and the overlays, so what the arms
## do points up or down with the view; not while down, dead, swimming or climbing, and only on a
## bone the playing clip keys (see [GSHumanoidAim]).
func _apply_aim() -> void:
	var plan: Variant = _aim_plan()
	if plan == null:
		return
	if _pose_n != null:
		_pose_n.call(&"aim", _skeleton, plan, _to_figure(), aim_pitch, -SPRINT_DROP * sprint_blend)
		return
	GSHumanoidAim.apply_plan(_skeleton, plan, _to_figure(), aim_pitch, sprint_blend)


## The plan [method _apply_aim] bends by this frame (flat for GameSpice Sim), or null when it bends nothing.
func _aim_plan() -> Variant:
	if _skeleton == null or (is_zero_approx(aim_pitch) and sprint_blend <= 0.0) or downed:
		return null
	if state == GSPlayerAnimState.DEAD or state == GSPlayerAnimState.SWIM or state == GSPlayerAnimState.CLIMB:
		return null
	var animation := _anim.get_animation(clip)
	if animation == null:
		return null
	var arm := 1 if hold != Hold.NONE else 0
	var plans: Variant = _aim_plans.get(animation)
	if plans == null:
		plans = [null, null]
	if plans[arm] == null:
		plans[arm] = GSHumanoidAim.plan(_skeleton, _model, animation, arm == 1)
		if _pose_n != null:
			plans[arm] = _flat_plan(plans[arm])
		_aim_plans[animation] = plans
	return plans[arm]


## [param plan] (index, parent, share, arm flag per bone) as numbers for `GSSimFigurePose.aim`.
static func _flat_plan(plan: Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(plan.size())
	for k in plan.size():
		var v: Variant = plan[k]
		out[k] = (1.0 if v else 0.0) if v is bool else float(v)
	return out


## Where the support hand goes: the weapon's foregrip, [constant Vector3.INF] when the gun is held with one
## hand or none. In world space; called every frame by the held weapon, since it moves with the gun.
func set_support_grip(point: Vector3) -> void:
	support_point = point


## Two-bone IK on the left arm toward [member support_point], blended by the support weight, after the clip,
## the overlays and the aim so it lands on the gun wherever they put it. Only on bones the clip keys (a bone no
## track writes keeps last frame's pose, and the turn would add up).
func _apply_support() -> void:
	if _skeleton == null or _support_weight <= 0.0 or downed:
		return
	var target := _support_target()
	if not target.is_finite():
		return
	var bones := _support_bones_for(clip)
	if bones.is_empty():
		return
	var chain := _support_chain(bones)
	if _pose_n != null:
		_pose_n.call(&"support", _skeleton, PackedInt32Array(bones), chain, target,
			_to_figure().basis.inverse() * SUPPORT_POLE, _support_weight)
		return
	GSHumanoidIk.two_bone_under(_skeleton, bones, GSHumanoidIk.chain_pose(_skeleton, chain), target,
		_to_figure().basis.inverse() * SUPPORT_POLE, _support_weight)


## Where the support hand goes in skeleton space: the held weapon's foregrip, else the carry's.
func _support_target() -> Vector3:
	return _skeleton.global_transform.affine_inverse() * support_point if support_point.is_finite() else carry.support_grip


## The bones from the root down to the support arm's parent, cached per arm.
func _support_chain(bones: Array[int]) -> PackedInt32Array:
	var chain: Variant = _support_chains.get(bones[0])
	if chain == null:
		chain = GSHumanoidIk.chain_to(_skeleton, _skeleton.get_bone_parent(bones[0]))
		_support_chains[bones[0]] = chain
	return chain


## [method _apply_aim], the legs' turn, [method _apply_carry] and [method _apply_support] as one `GSSimFigurePose.upper`
## call (the same pose), with what each works out handed over; false leaves them to the four steps: without
## [method GSHumanoidNativeLegs.chains], a native leg or carry, or while a stride ease runs between the aim and the legs.
## Given a [param batch] list, the call is appended there and [method _upper_done] is left to its caller.
func _apply_upper(seen: bool, far: float, up: Vector3, batch: Variant = null) -> bool:
	if _skeleton == null or _pose_n == null or _carry_n == null or legs._n == null or _ease.left > 0.0 \
			or not GSHumanoidNativeLegs.chains():
		return false
	var plan: Variant = _aim_plan() if seen else null
	var turn := legs.fused_twist(up)
	var to := _to_figure()
	var held: Array = []
	if seen and far <= ANIM_FAR:
		held = _carry_args()
	var bones: Array[int] = []
	var from_carry := 0.0
	var target := Vector3.INF
	if seen and far <= SUPPORT_RANGE and _support_weight > 0.0 and not downed:
		target = _support_target()
		from_carry = 1.0 if not held.is_empty() and not support_point.is_finite() else 0.0
		if from_carry > 0.0 or target.is_finite():
			bones = _support_bones_for(clip)
	var none := PackedInt32Array()
	var pole := to.basis.inverse() * SUPPORT_POLE
	var aim_plan: Variant = plan if plan != null else PackedFloat64Array()
	var values := PackedFloat64Array([aim_pitch, -SPRINT_DROP * sprint_blend, legs.twist, up.x, up.y, up.z, target.x, target.y,
		target.z, pole.x, pole.y, pole.z, _support_weight, from_carry])
	_st_held = not held.is_empty()
	var arm: Variant = held[0] if _st_held else none
	var keyed: Variant = held[1] if _st_held else PackedByteArray()
	var frame: Variant = held[2] if _st_held else PackedFloat64Array()
	var chain: Variant = _support_chain(bones) if not bones.is_empty() else none
	if batch is Array:
		batch.append_array([_pose_n, _skeleton, turn, to, aim_plan, values, arm, keyed, frame, PackedInt32Array(bones), chain])
	else:
		_upper_done(_pose_n.call(&"upper", _skeleton, turn, to, aim_plan, values, arm, keyed, frame, PackedInt32Array(bones), chain))
	return true


## [method _apply_upper]'s call answered with the support hand's grip, kept when the figure carries.
func _upper_done(grip: Vector3) -> void:
	if _st_held:
		carry.support_grip = grip


## [method _apply_carry]'s arm as `GSSimFigurePose` arguments ([method GSHumanoidCarryPose.native_args]), or empty.
func _carry_args() -> Array:
	if clip == GSHumanoidClips.DEATH or clip == GSHumanoidClips.SWIM:
		carry.support_grip = Vector3.INF
		return []
	return carry.native_args(_carry_n, _skeleton, _model, _anim, _to_figure(), _anim.get_animation(clip), _stride_fraction(),
		aim_pitch, height / 1.8, _sprint, _speed, _overlay_weight)


func _apply_carry() -> void:
	if _skeleton == null or clip == GSHumanoidClips.DEATH or clip == GSHumanoidClips.SWIM:
		carry.support_grip = Vector3.INF
		return
	carry.apply(_skeleton, _model, _anim, _to_figure(), _anim.get_animation(clip), _stride_fraction(), aim_pitch,
		height / 1.8, _sprint, _speed, _overlay_weight, _carry_n)


## The support arm's bone indices if [param clip_id] keys them (a bone no track writes keeps last frame's pose), else empty; cached per clip.
func _support_bones_for(clip_id: StringName) -> Array[int]:
	if _support_cache.has(clip_id):
		return _support_cache[clip_id]
	var bones := GSHumanoidIk.keyed_bones(_skeleton, _model, _anim.get_animation(clip_id), SUPPORT_BONES)
	_support_cache[clip_id] = bones
	return bones


## Swimming lays the whole body forward, about the hips, and eases back out of it. The swim clip
## is drawn upright ([method GSHumanoidClips._swimming]); this is what makes it horizontal.
func _apply_swim(delta: float) -> void:
	if _model == null:
		return
	var wanted := SWIM_LEAN if state == GSPlayerAnimState.SWIM and not downed else 0.0
	var before := _swim_pitch + _prop_pitch + _slide_lift + _own_back
	var sliding := state != GSPlayerAnimState.SWIM and clip == GSHumanoidClips.SLIDE
	_slide_lift = move_toward(_slide_lift, SLIDE_LIFT * height / 1.8 if sliding else 0.0, delta * 0.6)
	_swim_pitch = move_toward(_swim_pitch, wanted, delta * 3.0)
	_prop_pitch = move_toward(_prop_pitch, -PROP_LEAN if downed and propped else 0.0, delta * 3.0)
	_own_back = _own.back_for(_view_pitch) * height / 1.8
	var total := _swim_pitch + _prop_pitch
	if is_equal_approx(before, total + _slide_lift + _own_back) and total == 0.0 and _slide_lift == 0.0 and _own_back == 0.0:
		return
	_model.transform = _model_transform()
	_frame_tf_ok = false


## The model under the figure: laid forward or back about the hips, raised by a slide and onto the floor, set back for its own view.
func _model_transform() -> Transform3D:
	var hips := Vector3(0.0, height * 0.55, 0.0)
	var tilt := Transform3D(Basis(Vector3.RIGHT, -(_swim_pitch + _prop_pitch)), Vector3.ZERO)
	var about := Transform3D(Basis.IDENTITY, hips) * tilt * Transform3D(Basis.IDENTITY, -hips)
	return Transform3D(Basis.IDENTITY, Vector3(0.0, _slide_lift + floor_lift, _own_back)) * about * Transform3D(_model_basis, _model_origin)


## Ends the playing action, easing out.
func stop_action() -> void:
	_action_full = &""
	if overlay != &"" and _overlay_loop and not _overlay_stopping:
		_overlay_stopping = true
		_stop_time = 0.0
	action = &""


## Skeleton space to the figure's frame: the skeleton's own transform under the model, then the
## model's turn and scale.
func _to_figure() -> Transform3D:
	if _frame_tf_ok:
		return _frame_tf
	var skel_to_model := _model.global_transform.affine_inverse() * _skeleton.global_transform if _model.is_inside_tree() and absf(_model.global_basis.determinant()) > 1e-9 else Transform3D.IDENTITY
	var out := Transform3D(_model_basis, _model_origin) * skel_to_model
	if _frame_tf_on:
		_frame_tf = out
		_frame_tf_ok = true
	return out


## Plays the clips in GameSpice Sim when it can ([GSHumanoidNativeClips]), leaving the mixer inactive.
func _start_native_clips() -> void:
	_clips = GSHumanoidNativeClips.player_for(_anim, _skeleton)
	_clips_far = false
	_anim.active = _clips == null


## Past [constant ANIM_FAR] the native clips stop posing the fingers (under a pixel there): fewer
## bones sampled and written. The [AnimationPlayer] fallback always poses every bone.
func _set_clip_detail(far: bool) -> void:
	if _clips == null or far == _clips_far:
		return
	_clips_far = far
	var skip := PackedByteArray()
	if far:
		skip.resize(_skeleton.get_bone_count())
		for i in skip.size():
			var bone_name := _skeleton.get_bone_name(i)
			for root: String in FAR_SKIPPED_BONES:
				if bone_name.begins_with(root):
					skip[i] = 1
					break
	_clips.call(&"set_skip", skip)


## Back to the [AnimationPlayer], on the clip playing now.
func _drop_native_clips() -> void:
	var was := _current_clip()
	var at := _clip_position()
	var rate := _clip_rate()
	_clips = null
	_anim.active = true
	_anim.speed_scale = rate
	if was != &"":
		_anim.play(was, 0.0)
		_anim.seek(at, true)


# The playback calls of [member _anim], or of [member _clips] when the clips play natively.
func _play_clip(wanted: StringName, blend: float) -> void:
	if _clips != null:
		_clips.call(&"play", wanted, blend)
	else:
		_anim.play(wanted, blend)


func _seek_clip(time: float) -> void:
	if _clips != null:
		_clips.call(&"seek", time, true)
	else:
		_anim.seek(time, true)


func _advance_clip(delta: float) -> void:
	if _clips != null:
		_clips.call(&"advance", delta)
	else:
		_anim.advance(delta)


## The mixer's speed scale is kept too: what reads the figure's clip rate reads it there.
func _set_clip_rate(rate: float) -> void:
	_anim.speed_scale = rate
	if _clips != null:
		_clips.call(&"set_speed_scale", rate)


func _clip_rate() -> float:
	return float(_clips.call(&"get_speed_scale")) if _clips != null else _anim.speed_scale


## The playing clip, empty when none plays (a one-shot clip that ended).
func _current_clip() -> StringName:
	return StringName(_clips.call(&"current_animation")) if _clips != null else StringName(_anim.current_animation)


func _clip_position() -> float:
	return float(_clips.call(&"current_animation_position")) if _clips != null else _anim.current_animation_position


func _clip_length() -> float:
	return float(_clips.call(&"current_animation_length")) if _clips != null else _anim.current_animation_length


## Undoes last frame's limits and legs in the reverse of the order they were written: the turn limit last, so first.
func _step_restore(batch: Variant) -> void:
	if legs._n != null and _turn_limit._n != null and _stride_limit._n != null and GSHumanoidNativeLegs.restores():
		if batch is Array:
			batch.append_array([legs._n, _skeleton, _turn_limit._n, _stride_limit._n])
		else:
			legs._n.call(&"restore_with", _skeleton, _turn_limit._n, _stride_limit._n)
		return
	_turn_limit.restore(_skeleton)
	legs.restore(_skeleton)
	_stride_limit.restore(_skeleton)


func _step_close() -> void:
	_own.cap_colour = look.top
	_own.apply(_skeleton, _mesh)


func _step_shut() -> void:
	_frame_tf_on = false
	_frame_tf_ok = false


## [method _lower_native]'s call answered: whether the feet's hold still holds.
func _lower_done(holding: bool) -> void:
	if _st_plan & 3 == 2:
		_landing = _landing and holding


func _skeleton_up() -> Vector3:
	return (_to_figure().basis.inverse() * Vector3.UP).normalized()


func _apply_crawl_feet(speed: float, dt: float) -> void:
	var id := StringName(downed_clips.get(&"crawl", GSHumanoidClips.CRAWL))
	_crawl.step(self, _skeleton, downed and not propped and clip == id and _current_clip() == id, speed, dt)
