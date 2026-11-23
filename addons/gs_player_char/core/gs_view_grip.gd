class_name GSViewGrip
extends RefCounted

## Where the hands go on a first-person weapon: points in [member anchor]'s local space, read each frame so the hands follow the weapon wherever the host moves it. Hand one, or both.

## The weapon mesh's node (or a marker child of it); the points below are in its space.
var anchor: Node3D = null
## Where the firing hand's palm sits.
var grip: Vector3 = Vector3.ZERO
## Where the support hand sits; [constant Vector3.INF] holds the weapon with one hand.
var support: Vector3 = Vector3.INF
## The weapon's box in [member anchor]'s space, which the arms keep their elbows and forearms out of. Left empty, it
## is measured once from the visible meshes at and under the anchor (not particles or lights); a marker anchor with no mesh under it gets no clearance.
var bounds: AABB = AABB()
## What kind of weapon it is, the key into [member GSPlayerViewArms.hand_poses] ([GSViewHandPoses]: rifle, pistol,
## shotgun, launcher, sniper, grenade, knife, fists); an unknown kind is held as a rifle.
var kind: StringName = &"rifle"
## The weapon's forward (toward the muzzle) and up in [member anchor]'s space, which the hands close round.
var forward: Vector3 = Vector3.FORWARD
var up: Vector3 = Vector3.UP
var _measured := false
## Points on the weapon's surface in the frame [member bounds] is in, for a host that sets [member bounds] itself
## (a bare marker anchor has no mesh to measure). The arms then keep out of the convex fit of these points, not the box.
var hull_points := PackedVector3Array()
var _hull := PackedFloat32Array()
var _hull_measured := false
var _host_box := false


## A one-hand weapon (a pistol, a knife).
static func one_hand(p_anchor: Node3D, p_grip: Vector3) -> GSViewGrip:
	var g := GSViewGrip.new()
	g.anchor = p_anchor
	g.grip = p_grip
	return g


## A two-hand weapon: the support hand on the foregrip.
static func two_hand(p_anchor: Node3D, p_grip: Vector3, p_support: Vector3) -> GSViewGrip:
	var g := one_hand(p_anchor, p_grip)
	g.support = p_support
	return g


func is_two_hand() -> bool:
	return support.is_finite()


## False when the anchor is gone or outside the tree, so the arms rest instead of reaching for nothing.
func is_valid() -> bool:
	return anchor != null and is_instance_valid(anchor) and anchor.is_inside_tree() and grip.is_finite()


func grip_world() -> Vector3:
	return anchor.global_transform * grip


func support_world() -> Vector3:
	return anchor.global_transform * support


func forward_world() -> Vector3:
	return (anchor.global_transform.basis * forward).normalized()


func up_world() -> Vector3:
	return (anchor.global_transform.basis * up).normalized()


## [member bounds], measured on first use when the host did not set it; empty when there is nothing to measure.
func bounds_local() -> AABB:
	if bounds.has_volume() or _measured or not is_valid():
		_host_box = _host_box or (bounds.has_volume() and not _measured)
		return bounds
	_measured = true
	bounds = _measure(anchor, Transform3D.IDENTITY, AABB())
	return bounds


static func _measure(node: Node, to_anchor: Transform3D, box: AABB) -> AABB:
	if node is MeshInstance3D and (node as MeshInstance3D).visible and (node as MeshInstance3D).get_aabb().has_volume():
		var own := to_anchor * (node as MeshInstance3D).get_aabb()
		box = own if not box.has_volume() else box.merge(own)
	for child in node.get_children():
		if child is Node3D:
			box = _measure(child, to_anchor * (child as Node3D).transform, box)
	return box


## A tight convex fit to the visible meshes' vertices in [member anchor]'s space ([method GSViewArmsClear.dop_planes]), so the arms clear the weapon itself
## and not the empty corners of its box. Measured once; empty when the host set [member bounds] itself (its box is then the whole answer) or there is no mesh.
func hull_planes() -> PackedFloat32Array:
	if _hull_measured or not is_valid():
		return _hull
	_hull_measured = true
	var points := hull_points
	if points.is_empty():
		if _host_box:
			return _hull
		_collect(anchor, Transform3D.IDENTITY, points)
	_hull = GSViewArmsClear.dop_planes(points)
	return _hull


static func _collect(node: Node, to_anchor: Transform3D, points: PackedVector3Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).visible and (node as MeshInstance3D).mesh != null:
		for p in (node as MeshInstance3D).mesh.get_faces():
			points.append(to_anchor * p)
	for child in node.get_children():
		if child is Node3D:
			_collect(child, to_anchor * (child as Node3D).transform, points)
