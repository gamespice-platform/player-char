class_name GSViewArmsMaterial
extends RefCounted

## The first-person arms' material: the crowd's palette swap ([GSHumanoidAssets]) plus close-up detail, since your own
## arms fill a quarter of the screen where a flat swatch reads as white plastic. Skin gets mottling, a soft sheen and
## light through it; clothing gets a woven bump. The pattern follows each vertex's rest position, so it does not swim.

## Stored per vertex by [GSPlayerViewArms] in CUSTOM0 (rest position, w = 1): where the detail pattern is read.
const REST_FORMAT := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT

const DETAIL := """
// Detail over the swapped colour. Skin swaps come first in the swap list (skin_swaps of them).
uniform int skin_swaps = 0;
uniform float weave_scale = 900.0;
uniform float weave_depth = 0.0004;
uniform float detail = 1.0;
varying vec3 rest;
// GSPlayerViewArms.draw_depth: the clip position of the view point grown by it about the eye (same pixel, further depth).
// Only from draw_eye's own view: a shadow pass renders from the light, where the growth would move the shadow.
instance uniform float draw_depth = 1.0;
instance uniform vec3 draw_eye = vec3(0.0);
// GSPlayerViewArms.lens(): view-space X and Y scaled by it about the eye, as GSViewLens scales a held model.
instance uniform float draw_lens = 1.0;

float gs_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float gs_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(gs_hash(i), gs_hash(i + vec3(1, 0, 0)), f.x), mix(gs_hash(i + vec3(0, 1, 0)), gs_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(gs_hash(i + vec3(0, 0, 1)), gs_hash(i + vec3(1, 0, 1)), f.x), mix(gs_hash(i + vec3(0, 1, 1)), gs_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	rest = CUSTOM0.xyz;
	// POSITION is written on every path: a shader that writes it on some leaves it undefined on the rest (no arms).
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (distance(INV_VIEW_MATRIX[3].xyz, draw_eye) < 0.01) {
		v.xy *= draw_lens;
		v.xyz *= draw_depth;
	}
	POSITION = PROJECTION_MATRIX * v;
}
"""

const FRAGMENT := """
void fragment() {
	vec3 c = texture(atlas, UV).rgb;
	int hit = -1;
	for (int i = 0; i < swaps; i++) {
		vec3 d = c - from_colour[i].rgb;
		if (dot(d, d) < tolerance) {
			c = to_colour[i].rgb;
			hit = i;
			break;
		}
		vec3 e = c - from_linear[i].rgb;
		if (dot(e, e) < tolerance * 0.25) {
			c = to_linear[i].rgb;
			hit = i;
			break;
		}
	}
	float h;
	if (hit >= 0 && hit < skin_swaps) {
		// Skin: blotches a few centimetres across, pores below that, warmer where it is thin.
		float blotch = gs_noise(rest * 28.0);
		float pores = gs_noise(rest * 160.0);
		c *= mix(vec3(1.0), vec3(1.06, 0.93, 0.9), blotch * 0.5 * detail) * (1.0 - 0.07 * pores * detail);
		h = pores * 0.00015;
		ROUGHNESS = 0.55;
		SPECULAR = 0.3;
		BACKLIGHT = c * 0.35 * detail;
	} else {
		// Cloth: a twill weave a few millimetres across, and wear patches.
		vec3 p = rest * weave_scale;
		float weave = sin(p.x + p.z) * sin(p.y * 1.3 - p.z) * 0.5 + 0.5;
		float wear = gs_noise(rest * 22.0);
		c *= (0.9 + 0.12 * weave * detail) * (1.0 - 0.1 * wear * detail);
		h = weave * weave_depth;
		ROUGHNESS = 0.95;
		SPECULAR = 0.1;
	}
	// Bump from the screen-space slope of h (no tangents needed: the kit has none).
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h * detail) * r1 + dFdy(h * detail) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
	ALBEDO = c;
	EMISSION = vec3(flash * 0.35, flash * 0.05, flash * 0.03);
}
"""

static var _shader: Shader = null
static var _materials: Dictionary = {}


## The arms' material for [param look]: [GSHumanoidAssets]' swap for it, with the detail on top. One per look.
static func for_look(look: GSHumanoidLook) -> ShaderMaterial:
	# A registered body brings its own painted texture: there are no swatches for the detail to read.
	if GSHumanoidLook.registered.has(look.body):
		return GSHumanoidAssets.material_for(look)
	var key := look.key()
	if _materials.has(key):
		return _materials[key]
	var base := GSHumanoidAssets.material_for(look)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = shader_code()
	var material := ShaderMaterial.new()
	material.shader = _shader
	for uniform in [&"atlas", &"from_colour", &"to_colour", &"from_linear", &"to_linear", &"swaps"]:
		material.set_shader_parameter(uniform, base.get_shader_parameter(uniform))
	material.set_shader_parameter(&"skin_swaps", skin_swaps(look))
	_materials[key] = material
	return material


## The crowd shader with its fragment replaced by the detailed one and specular turned on.
static func shader_code() -> String:
	var crowd := GSHumanoidAssets.SHADER
	var head := crowd.substr(0, crowd.find("void fragment()")).replace("specular_disabled", "specular_schlick_ggx")
	return head + DETAIL + FRAGMENT


## How many of [param look]'s swaps are skin colours: [method GSHumanoidAssets.material_for] lists them first.
static func skin_swaps(look: GSHumanoidLook) -> int:
	var wears: Dictionary = GSHumanoidAssets.WEARS.get(look.body, {})
	return mini((wears.get("skin", []) as Array).size(), GSHumanoidAssets.SWAPS)


static func clear_cache() -> void:
	_materials.clear()
	_shader = null
