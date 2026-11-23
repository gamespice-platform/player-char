class_name GSViewArmsSolid
extends RefCounted

## A weapon's mesh as a non-convex solid for the view arms' clearance: a voxel grid of how deep a point sits inside the weapon grown by the arm's thickness. Where a convex fit ([method GSViewArmsClear.dop_planes])
## closes over the notch behind an L-shaped gun's grip, where the wrist and forearm belong, this keeps the notch: a voxel is solid when the mesh's surface passes through it or when it cannot be reached from outside
## the grid (flood-filled), so air that opens to the outside stays air. Built once per weapon (cached by its points), read per frame with one array lookup.

## Voxel edge in metres. Grown (coarser) for a big mesh so the grid stays under [constant MAX_CELLS].
const VOXEL := 0.01
const MAX_CELLS := 400000

## The grid's box in the points' space (the weapon's surface grown by the radius): nothing outside it is inside the solid.
var box := AABB()
## The arm thickness the depths are grown by, metres.
var radius := 0.0
var voxel := VOXEL
var _origin := Vector3.ZERO
var _inv := 100.0
var _nx := 0
var _ny := 0
var _depth := PackedFloat32Array()

static var _cache: Dictionary = {}


## The solid for [param points] (triangle corners, three per triangle, as Mesh.get_faces gives), arm thickness [param p_radius]; cached by the points, so a weapon built twice is built once. Null for no triangles.
static func fit(points: PackedVector3Array, p_radius: float) -> GSViewArmsSolid:
	if points.size() < 3:
		return null
	var key := [hash(points), points.size(), snappedf(p_radius, 0.0001)]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 48:
		_cache.clear()
	var solid := GSViewArmsSolid.new()
	solid._build(points, maxf(p_radius, 0.0))
	_cache[key] = solid
	return solid


## How deep [param q] (the points' space) is inside the solid grown by the radius, metres: 0 clear of it, the radius at its surface, more inside the weapon.
func depth_at(q: Vector3) -> float:
	var f := (q - _origin) * _inv
	var ix := int(f.x)
	var iy := int(f.y)
	var iz := int(f.z)
	if f.x < 0.0 or f.y < 0.0 or f.z < 0.0 or ix >= _nx or iy >= _ny or iz >= _depth.size() / (_nx * _ny):
		return 0.0
	return _depth[ix + _nx * (iy + _ny * iz)]


func _build(points: PackedVector3Array, p_radius: float) -> void:
	radius = p_radius
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	var size := hi - lo
	voxel = VOXEL
	while (size.x / voxel + 8.0) * (size.y / voxel + 8.0) * (size.z / voxel + 8.0) > MAX_CELLS:
		voxel *= 1.25
	_inv = 1.0 / voxel
	var pad := int(ceil(radius * _inv)) + 2
	_origin = lo - Vector3.ONE * (pad * voxel)
	var dims := Vector3i((size * _inv).ceil()) + Vector3i.ONE * (2 * pad + 1)
	_nx = dims.x
	_ny = dims.y
	var nz := dims.z
	var count := _nx * _ny * nz
	box = AABB(_origin, Vector3(dims) * voxel)
	var surface := _rasterize(points, count)
	var outside := _flood_outside(surface, count, nz)
	_depth.resize(count)
	_depth.fill(0.0)
	var shell := PackedInt32Array()
	for i in count:
		if surface[i] == 1:
			shell.append(i)
	_grow(shell, radius)
	_fill_inside(surface, outside, shell)


## One byte per voxel: 1 where a triangle passes. Each triangle is sampled on a grid finer than a voxel, so the shell is 26-connected and a 6-connected flood cannot leak through it.
func _rasterize(points: PackedVector3Array, count: int) -> PackedByteArray:
	var surface := PackedByteArray()
	surface.resize(count)
	var limit := voxel * 0.6
	for t in range(0, points.size() - 2, 3):
		var a := points[t]
		var ab := points[t + 1] - a
		var ac := points[t + 2] - a
		var n := maxi(1, ceili(maxf(ab.length(), maxf(ac.length(), (ab - ac).length())) / limit))
		var step := 1.0 / n
		for i in n + 1:
			for j in n + 1 - i:
				surface[_index(a + ab * (i * step) + ac * (j * step))] = 1
	return surface


func _index(p: Vector3) -> int:
	var f := (p - _origin) * _inv
	return int(f.x) + _nx * (int(f.y) + _ny * int(f.z))


## 1 for every air voxel the flood from the grid's corner reaches through other air (6-connected). The grid's outermost layer is never shell, so it is walled off and no neighbour test needs a bounds check.
func _flood_outside(surface: PackedByteArray, count: int, nz: int) -> PackedByteArray:
	var seen := surface.duplicate()
	var sy := _nx
	var sz := _nx * _ny
	for z in nz:
		for y in _ny:
			for x in _nx:
				if x == 0 or y == 0 or z == 0 or x == _nx - 1 or y == _ny - 1 or z == nz - 1:
					seen[x + sy * y + sz * z] = 2
	var nbr := PackedInt32Array([-1, 1, -sy, sy, -sz, sz])
	var start := 1 + sy + sz
	var stack := PackedInt32Array([start])
	seen[start] = 3
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		for d in nbr:
			var j := i + d
			if seen[j] == 0:
				seen[j] = 3
				stack.append(j)
	for i in count:
		seen[i] = 1 if seen[i] >= 2 else 0
	return seen


## Depth of the air within [param r] of the shell: radius minus its distance to the nearest shell voxel. The grid's padding keeps every offset inside it.
func _grow(shell: PackedInt32Array, r: float) -> void:
	var reach := int(ceil(r * _inv))
	var offsets := PackedInt32Array()
	var gains := PackedFloat32Array()
	for dz in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var d := sqrt(float(dx * dx + dy * dy + dz * dz)) * voxel
				if d < r or (dx == 0 and dy == 0 and dz == 0):
					offsets.append(dx + _nx * (dy + _ny * dz))
					gains.append(r - d)
	for i in shell:
		for k in offsets.size():
			var j := i + offsets[k]
			if gains[k] > _depth[j]:
				_depth[j] = gains[k]


## The weapon's inside (voxels neither outside nor shell) is the radius plus its layers' distance from the shell, found by peeling inward from the shell.
func _fill_inside(surface: PackedByteArray, outside: PackedByteArray, shell: PackedInt32Array) -> void:
	var sy := _nx
	var sz := _nx * _ny
	var frontier := shell
	var layer := 0
	var nbr := PackedInt32Array([-1, 1, -sy, sy, -sz, sz])
	var done := surface.duplicate()
	while not frontier.is_empty():
		layer += 1
		var next := PackedInt32Array()
		for i in frontier:
			for n in nbr:
				var j := i + n
				if j >= 0 and j < done.size() and done[j] == 0 and outside[j] == 0:
					done[j] = 1
					_depth[j] = radius + layer * voxel
					next.append(j)
		frontier = next
