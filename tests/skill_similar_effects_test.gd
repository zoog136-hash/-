extends SceneTree

const BRIDGE = preload("res://scripts/skills/skill_similar_bridge.gd")
const VFX = preload("res://scripts/skills/skill_vfx.gd")
var errors: Array[String] = []
func check(ok: bool, note: String) -> void:
	if not ok: errors.append(note); push_error(note)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var bridge = BRIDGE.new()
	if bridge.effects.is_empty():
		push_error("SIMILAR_EFFECTS_FAIL: tracked SPR pack absent")
		quit(1)
		return
	var catalog: Dictionary = bridge.resource_catalog()
	check(catalog.size() == 96, "91 original plus five reviewed cast resources registered")
	check(bridge.cache.is_empty(), "catalog listing must not preload textures")
	var checked_frames: int = 0
	for key: String in catalog:
		var spec: Dictionary = catalog[key]
		var resource: SpriteFrames = bridge.frames_for_resource(key)
		check(resource != null, "unbound resource must load: " + key)
		if resource != null:
			check(resource.get_frame_count(&"source") == int(spec.count), "source frame count preserved")
			for frame: int in range(resource.get_frame_count(&"source")):
				var pixels: Image = resource.get_frame_texture(&"source", frame).get_image()
				var digest := HashingContext.new()
				digest.start(HashingContext.HASH_SHA256)
				digest.update(pixels.get_data())
				check(digest.finish().hex_encode() == str(spec.frame_rgba_sha256[frame]), "decoded source pixels preserved: " + key)
				checked_frames += 1
		bridge.release(key)
		bridge.trim()
		check(bridge.cache.is_empty(), "catalog resource releases without resident texture")
	print("SIMILAR_RESOURCE_CATALOG resources=", catalog.size(), " frames=", checked_frames)
	var master: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/master.json"))
	var mapped := 0
	for row: Dictionary in master.records:
		var entry: Dictionary = bridge.binding_for(str(row.id))
		check(not entry.is_empty(), "missing stable skill ID " + str(row.id))
		for phase: String in entry.get("phases", {}):
			var frames: SpriteFrames = bridge.frames_for(str(row.id), phase)
			check(frames != null, str(row.name) + " / " + phase + " missing real source frames")
			if frames != null:
				check(not frames.get_animation_loop(&"source"), "source must be one shot")
				check(frames.get_frame_count(&"source") > 0, "empty animation")
			bridge.release(str(entry.phases[phase]))
		check(bridge.resident_bytes() <= bridge.MAX_RGBA_BYTES, "cache budget exceeded")
		mapped += 1
	check(bridge.frames_for("lm_missing", "impact") == null, "unknown IDs must fall back")
	bridge.trim()
	var pins: Array[String] = []
	var denied := 0
	for row: Dictionary in master.records:
		var entry: Dictionary = bridge.binding_for(str(row.id))
		for phase: String in entry.get("phases", {}):
			if bridge.frames_for(str(row.id), phase) == null: denied += 1
			else: pins.append(str(entry.phases[phase]))
			check(bridge.resident_bytes() <= bridge.MAX_RGBA_BYTES, "pinned cache exceeded budget")
	check(denied > 0, "cache saturation must reject visuals")
	for key: String in pins: bridge.release(key)
	bridge.trim()
	check(bridge.cache.is_empty(), "released atlas pins leaked")
	bridge.bindings["cycle_a"] = {"inherits_visual":"cycle_b"}
	bridge.bindings["cycle_b"] = {"inherits_visual":"cycle_a"}
	check(bridge.binding_for("cycle_a").is_empty(), "inheritance cycle must terminate")
	var vfx = VFX.new()
	root.add_child(vfx)
	await process_frame
	vfx.emit_skill("lm_0f78dd70d9994d34", "impact", Vector2(100,100))
	check(vfx.live.size() == 1 and not str(vfx.live[0].get("similar_key", "")).is_empty(), "real visual event not routed")
	vfx.clear()
	check(vfx.live.is_empty() and vfx.similar_bridge.cache.is_empty(), "clear leaks pinned art")
	vfx.queue_free()
	await process_frame
	print("SIMILAR_EFFECTS_RESULT skills=%d errors=%d" % [mapped, errors.size()])
	quit(0 if errors.is_empty() else 1)
