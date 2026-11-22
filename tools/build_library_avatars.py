"""Builds library-ready avatar GLBs (textured, with the clip set) from the shipped people and Kenney bodies.

    blender -b --factory-startup --python tools/build_library_avatars.py -- <people dir> <out dir>

The shipped people GLBs are texture-less and clip-less on purpose (GSHumanoidPalette recolours them through the
shared 512 px swatch atlas, and matt alone carries the clips, retargeted onto the others at run time). The TMC
avatar library and Nightly's Assets audit judge a GLB on its own, so this writes standalone copies:
- the swatch atlas, enlarged to 1024 px, embedded and on the material (nearest filtering: flat swatches stay flat);
- matt's clips, renamed idle/walk/run/..., on every person (the four bodies share one 43-bone skeleton).
The tri counts are the kit's decimated ones (build_people.py RATIO): matt and lis stay under the audit's 3000
floor until the Quaternius kit is re-downloaded and rebuilt; this tool does not subdivide to fake it.
Outputs go outside the shipped addon: the game keeps using the lean files.
"""
import bpy, os, sys

people, out = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(out, exist_ok=True)
BODIES = ["matt", "lis", "sam", "shaun"]


def fresh():
	bpy.ops.wm.read_factory_settings(use_empty=True)


def load(path):
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=path)
	return set(bpy.data.objects) - before


def clip_name(n):
	return n.replace("_CharacterArmature", "")


def textured(image_path, size):
	img = bpy.data.images.load(image_path)
	if img.size[0] != size:
		img.scale(size, size)
	img.pack()
	return img


def apply_texture(img):
	for m in bpy.data.materials:
		m.use_nodes = True
		nt = m.node_tree
		bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
		tex = nt.nodes.new("ShaderNodeTexImage")
		tex.image = img
		tex.interpolation = "Closest"
		nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])


def export(path, objs):
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
		export_image_format="AUTO", export_animation_mode="ACTIONS", export_force_sampling=True,
		export_optimize_animation_size=True, export_apply=False, export_yup=True)
	print("BUILT", path, os.path.getsize(path))


def with_clips(arm, actions):
	ad = arm.animation_data_create()
	for a in actions:
		track = ad.nla_tracks.new()
		track.name = a.name
		track.strips.new(a.name, 1, a)


# Matt's clips are the family set.
fresh()
load(os.path.join(people, "people_matt.glb"))
clips = {}
for a in bpy.data.actions:
	a.name = clip_name(a.name)
	a.use_fake_user = True
	clips[a.name] = a
for need in ("idle", "walk", "run"):
	if need not in clips:
		raise SystemExit("matt lacks clip " + need)
with_clips(next(o for o in bpy.data.objects if o.type == "ARMATURE"), [clips[k] for k in sorted(clips)])
apply_texture(textured(os.path.join(people, "atlas_people.png"), 1024))
export(os.path.join(out, "gs-people-matt.glb"), list(bpy.data.objects))
matt_path = os.path.join(out, "_matt_clips.blend")
bpy.ops.wm.save_as_mainfile(filepath=matt_path)

for body in BODIES[1:]:
	fresh()
	with bpy.data.libraries.load(matt_path) as (src, dst):
		dst.actions = list(src.actions)
	objs = load(os.path.join(people, "people_%s.glb" % body))
	arm = next(o for o in objs if o.type == "ARMATURE")
	for a in dst.actions:
		a.use_fake_user = True
	with_clips(arm, sorted(dst.actions, key=lambda a: a.name))
	apply_texture(textured(os.path.join(people, "atlas_people.png"), 1024))
	export(os.path.join(out, "gs-people-%s.glb" % body), list(objs))
os.remove(matt_path)
