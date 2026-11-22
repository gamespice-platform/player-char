extends Node

## Writes one standalone Kenney avatar GLB for the TMC library: the body scaled to 1.8 m, one skin embedded, every clip of
## kenney_clips.res on it (Blender's FBX route only has Kenney's three own clips; the rest are baked by kenney_retarget.gd).
## godot --headless --path . res://tools/export_library_kenney.tscn -- <out.glb> [pack] [skin]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("export_library_kenney: pass an output .glb path")
		get_tree().quit(2)
		return
	var pack := StringName(args[1]) if args.size() > 1 else &"protagonists"
	var skin := StringName(args[2]) if args.size() > 2 else &"criminalMaleA"
	var body := GSKenneyCharacters.build(pack, skin)
	if body == null:
		get_tree().quit(1)
		return
	# The model file carries Kenney's own three clips in a player of its own: the baked library replaces them, so drop it (else idle2, run2, jump2).
	for own: AnimationPlayer in body.get_child(0).find_children("*", "AnimationPlayer", true, false):
		own.get_parent().remove_child(own)
		own.free()
	# The glTF exporter reads a mesh's own materials, not material_override: put the skin on the mesh.
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			mi.mesh.surface_set_material(s, mi.material_override)
		mi.material_override = null
	add_child(body)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(body, state)
	if err == OK:
		err = doc.write_to_filesystem(state, args[0])
	if err == OK:
		err = _strip_godot_extensions(args[0])
	print("export_library_kenney: %s -> %s" % [error_string(err), args[0]])
	get_tree().quit(0 if err == OK else 1)


## The site's wearable validator allows only the Khronos extensions: drop Godot's GODOT_single_root marker (it only says "one root node").
func _strip_godot_extensions(path: String) -> Error:
	var bytes := FileAccess.get_file_as_bytes(path)
	var json_len := bytes.decode_u32(12)
	var doc: Variant = JSON.parse_string(bytes.slice(20, 20 + json_len).get_string_from_utf8())
	if not doc is Dictionary:
		return ERR_PARSE_ERROR
	var used: Array = doc.get("extensionsUsed", [])
	used = used.filter(func(e: String) -> bool: return not e.begins_with("GODOT_"))
	if used.is_empty():
		doc.erase("extensionsUsed")
	else:
		doc["extensionsUsed"] = used
	for scene: Dictionary in doc.get("scenes", []):
		var ext: Dictionary = scene.get("extensions", {})
		for k in ext.keys():
			if String(k).begins_with("GODOT_"):
				ext.erase(k)
		if ext.is_empty():
			scene.erase("extensions")
	# JSON.stringify writes every integer as "3.0"; glTF indices must be integers, so take the ".0" off whole numbers.
	var re := RegEx.create_from_string("(?<=[0-9])\\.0(?=[,\\]}])")
	var text := re.sub(JSON.stringify(doc), "", true).to_utf8_buffer()
	while text.size() % 4 != 0:
		text.append(0x20)
	var out := PackedByteArray()
	out.resize(12)
	out.encode_u32(0, 0x46546C67)
	out.encode_u32(4, 2)
	var head := PackedByteArray()
	head.resize(8)
	head.encode_u32(0, text.size())
	head.encode_u32(4, 0x4E4F534A)
	out.append_array(head)
	out.append_array(text)
	out.append_array(bytes.slice(20 + json_len))
	out.encode_u32(8, out.size())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(out)
	return OK
