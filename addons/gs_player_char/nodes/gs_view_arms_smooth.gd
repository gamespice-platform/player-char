extends RefCounted

## Rounds the first-person arms' low-poly sleeves, split out of the arms mesh build. By path: no global name for a helper.
##
## The kit's arms are octagonal tubes with blocky shoulder and elbow joins. Seen from the eye an arm is the nearest thing in
## the frame, and its outline read as a staircase (FC judge D4). Each level splits every triangle in four, the new edge points
## on the curved PN-triangle edge through the corners' normals, so a tube rounds out and a join softens. Normals are welded by
## position first: a UV seam or a split normal would otherwise open a crack along it and keep the facets in the shading.


## [param arrays] (an indexed surface's) split [param levels] times. Skin weights, UVs, colour, tangent and the rest
## positions in CUSTOM0 are averaged along each edge. Zero levels, or no triangles, returns it as is.
static func subdivide(arrays: Array, levels: int) -> Array:
	var out := arrays
	for _l in levels:
		out = _split(out)
	return out


static func _split(arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var n := verts.size()
	if n == 0 or index.size() < 3:
		return arrays
	var smooth := _welded_normals(arrays)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
	var per := bones.size() / n if weights.size() == bones.size() else 0

	# One new vertex per edge, numbered after the old ones; the triangles split four ways round them.
	var mid: Dictionary = {}
	var edges: Array[Vector2i] = []
	var new_index := PackedInt32Array()
	new_index.resize(index.size() / 3 * 12)
	var w := 0
	for t in range(0, index.size() - 2, 3):
		var corner := [index[t], index[t + 1], index[t + 2]]
		var m := [0, 0, 0]
		for e in 3:
			var key := Vector2i(mini(corner[e], corner[(e + 1) % 3]), maxi(corner[e], corner[(e + 1) % 3]))
			if not mid.has(key):
				mid[key] = n + edges.size()
				edges.append(key)
			m[e] = mid[key]
		for v in [corner[0], m[0], m[2], m[0], corner[1], m[1], m[2], m[1], corner[2], m[0], m[1], m[2]]:
			new_index[w] = v
			w += 1

	var out := arrays.duplicate()
	var total := n + edges.size()
	var new_verts := verts.duplicate()
	var new_normals := smooth.duplicate()
	new_verts.resize(total)
	new_normals.resize(total)
	for i in edges.size():
		var a := edges[i].x
		var b := edges[i].y
		var pa := verts[a]
		var pb := verts[b]
		var na := smooth[a]
		var nb := smooth[b]
		# The cubic Bezier edge of a PN triangle at t = 0.5: (pa + 3 c1 + 3 c2 + pb) / 8.
		var c1 := (2.0 * pa + pb - (pb - pa).dot(na) * na) / 3.0
		var c2 := (2.0 * pb + pa - (pa - pb).dot(nb) * nb) / 3.0
		new_verts[n + i] = (pa + 3.0 * c1 + 3.0 * c2 + pb) / 8.0
		var nm := na + nb
		new_normals[n + i] = nm.normalized() if nm.length_squared() > 1e-12 else na
	out[Mesh.ARRAY_VERTEX] = new_verts
	out[Mesh.ARRAY_NORMAL] = new_normals
	out[Mesh.ARRAY_INDEX] = new_index
	if per > 0:
		out[Mesh.ARRAY_BONES] = _merged_bones(edges, n, per, bones, weights, true)
		out[Mesh.ARRAY_WEIGHTS] = _merged_bones(edges, n, per, bones, weights, false)
	for slot in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_CUSTOM0]:
		if arrays[slot] != null:
			out[slot] = _averaged(arrays[slot], edges, n)
	return out


## Each vertex's normal averaged (area-weighted) over every vertex at its position, so the two sides of a seam agree.
static func _welded_normals(arrays: Array) -> PackedVector3Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var given: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var at: Dictionary = {}
	var sums: Array[Vector3] = []
	var slot := PackedInt32Array()
	slot.resize(verts.size())
	for v in verts.size():
		var key := Vector3i((verts[v] * 10000.0).round())
		if not at.has(key):
			at[key] = sums.size()
			sums.append(Vector3.ZERO)
		slot[v] = at[key]
	for t in range(0, index.size() - 2, 3):
		var p0 := verts[index[t]]
		var face := (verts[index[t + 1]] - p0).cross(verts[index[t + 2]] - p0)
		for k in 3:
			sums[slot[index[t + k]]] += face
	var out := PackedVector3Array()
	out.resize(verts.size())
	for v in verts.size():
		var s := sums[slot[v]]
		var nm := s.normalized() if s.length_squared() > 1e-20 else (given[v] if v < given.size() else Vector3.UP)
		# The winding decides the cross's sign; the kit's own normal says which side is out.
		if v < given.size() and nm.dot(given[v]) < 0.0:
			nm = -nm
		out[v] = nm
	return out


## The bones (or, with [param want_bones] false, the weights) of the old vertices followed by each edge's: its corners'
## weights halved and merged, the strongest [param per] kept and renormalised.
static func _merged_bones(edges: Array[Vector2i], n: int, per: int, bones: PackedInt32Array, weights: PackedFloat32Array,
		want_bones: bool) -> Variant:
	var ob := bones.duplicate()
	var ow := weights.duplicate()
	ob.resize((n + edges.size()) * per)
	ow.resize((n + edges.size()) * per)
	for i in edges.size():
		var sum: Dictionary = {}
		for v in [edges[i].x, edges[i].y]:
			for k in per:
				var wt := weights[v * per + k]
				if wt > 0.0:
					sum[bones[v * per + k]] = float(sum.get(bones[v * per + k], 0.0)) + wt * 0.5
		var order: Array = sum.keys()
		# An even split breaks to the lower bone, not to whichever corner came first: a mirrored forearm's copies are
		# numbered after the rest, and the two sides would otherwise lean apart along the elbow.
		order.sort_custom(func(x: int, y: int) -> bool:
			var d := float(sum[x]) - float(sum[y])
			return d > 1e-5 or (absf(d) <= 1e-5 and x < y))
		var total := 0.0
		for k in mini(per, order.size()):
			total += float(sum[order[k]])
		for k in per:
			var at := (n + i) * per + k
			ob[at] = int(order[k]) if k < order.size() else 0
			ow[at] = float(sum[order[k]]) / total if k < order.size() and total > 0.0 else 0.0
	return ob if want_bones else ow


## A per-vertex array ([param arr]) followed by each edge's corners' average. A tangent and the CUSTOM0 rest position are
## four floats a vertex.
static func _averaged(arr: Variant, edges: Array[Vector2i], n: int) -> Variant:
	if arr is PackedVector2Array:
		var v2: PackedVector2Array = arr.duplicate()
		v2.resize(n + edges.size())
		for i in edges.size():
			v2[n + i] = (v2[edges[i].x] + v2[edges[i].y]) * 0.5
		return v2
	if arr is PackedColorArray:
		var col: PackedColorArray = arr.duplicate()
		col.resize(n + edges.size())
		for i in edges.size():
			col[n + i] = col[edges[i].x].lerp(col[edges[i].y], 0.5)
		return col
	if arr is PackedFloat32Array:
		var f: PackedFloat32Array = arr.duplicate()
		f.resize((n + edges.size()) * 4)
		for i in edges.size():
			for k in 4:
				f[(n + i) * 4 + k] = (f[edges[i].x * 4 + k] + f[edges[i].y * 4 + k]) * 0.5
		return f
	return arr
