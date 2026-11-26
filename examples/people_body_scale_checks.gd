extends RefCounted

## A body that is not 1.8 m tall against GSClipMetrics, whose height limits are body-relative: the run clip's
## flight hovers above its own pace, and that pace scales with the body, so a small runner at the same ground
## speed is on the grounded sprint clip and keeps a foot on the floor (Airdrift's 1.37 m runner at 4.76 m/s).

const FPS := 15.0
const RAMP := 0.3
const SECONDS := 3.0
## A game's filmstrip limits (Airdrift, g2gfast, FC): float_m and plant_height_m are read at 1x body size.
const LIMITS := {"plant_height_m": 0.12, "slide_window_s": 0.05, "float_m": 0.20, "pop_deg": 135.0}
var suite: Node


func _init(host: Node) -> void:
	suite = host


func run() -> void:
	suite._section("a small or tall body picks the run clip by its own stride")
	var small := _ramp(1.3716, 4.7625)
	suite._check(small["scale"] < 1.0 and small["clip"] == GSHumanoidClips.SPRINT and small["pass"],
		"a 1.37 m runner (skeleton scale %.2f) at 4.76 m/s: %s, floor_contact %.3f (limit 0.25)" % [small["scale"], small["clip"], small["hover"]])
	var stock := _ramp(1.8, 4.7625)
	suite._check(stock["clip"] == GSHumanoidClips.RUN, "a 1.8 m runner at the same pace keeps the run clip (%s)" % stock["clip"])
	var tall := _ramp(2.7, 6.0)
	suite._check(tall["scale"] > 1.5 and tall["clip"] == GSHumanoidClips.RUN,
		"a 2.7 m runner at 6 m/s is under its run clip's pace: the run clip (%s, scale %.2f)" % [tall["clip"], tall["scale"]])


## Ramps a figure [param height] metres tall up to [param pace] at the filmstrip's 15 fps; returns its clip, skeleton scale and floor row.
func _ramp(height: float, pace: float) -> Dictionary:
	var f := GSHumanoidFigure.new()
	suite.add_child(f)
	f.build(GSHumanoidLook.stock(9), height)
	var m := GSClipMetrics.new()
	var dt := 1.0 / FPS
	var v := 0.0
	for i in int(SECONDS * FPS):
		v = minf(pace, v + pace / RAMP * dt)
		f.position.z -= v * dt
		f.set_motion({"on_floor": true, "vertical": 0.0, "crouched": false, "aim": 0.0})
		f.animate(v, dt)
		f.skeleton().force_update_all_bone_transforms()
		m.add(m.pose_sample(float(i) * dt, f.skeleton(), f.global_position, true))
	var out := {"clip": f.clip, "scale": f.skeleton().global_transform.basis.get_scale().y, "pass": false, "hover": NAN}
	for row in m.evaluate(LIMITS):
		if row["check"] == "floor_contact":
			out["pass"] = row["pass"]
			out["hover"] = float(row["value"])
	f.queue_free()
	return out
