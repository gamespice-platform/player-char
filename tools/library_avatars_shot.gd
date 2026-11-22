extends SceneTree

## A line-up of the library avatars (library/avatars/*.glb), each loaded as a bare GLB the way the site's viewer does, standing in its idle clip.
## Rendered, so not headless: tools/library_avatars_shot.sh [out.png]

const DIR := "res://library/avatars/"
const OUT_DEFAULT := "res://out/library_avatars.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else OUT_DEFAULT
	root.size = Vector2i(1280, 640)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.4, 0.45)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var files := DirAccess.get_files_at(DIR)
	files.sort()
	var x := 0.0
	var n := 0
	var per_row := 6
	for f in files:
		if not f.ends_with(".glb"):
			continue
		var state := GLTFState.new()
		var doc := GLTFDocument.new()
		if doc.append_from_file(ProjectSettings.globalize_path(DIR + f), state) != OK:
			printerr("did not load " + f)
			continue
		var node := doc.generate_scene(state)
		node.position = Vector3(1.6 * (n % per_row), -2.3 * (n / per_row), 0)
		n += 1
		root.add_child(node)
		for player: AnimationPlayer in node.find_children("*", "AnimationPlayer", true, false):
			if player.has_animation("idle"):
				player.play("idle")
		print("LIBRARY ", f, " clips=", node.find_children("*", "AnimationPlayer", true, false).map(func(p: AnimationPlayer) -> int: return p.get_animation_list().size()))
	var camera := Camera3D.new()
	camera.position = Vector3(1.6 * (per_row - 1) / 2.0, -0.2, 7.2)
	camera.fov = 45
	root.add_child(camera)
	for i in 20:
		await process_frame
	var path := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_texture().get_image().save_png(path)
	print("LIBRARY shot ", path)
	quit(0)
