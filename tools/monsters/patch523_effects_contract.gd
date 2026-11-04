extends SceneTree
const EFFECTS = preload("res://scripts/monsters/patch523_effect_frames.gd")
const SERVICE = preload("res://scripts/monsters/patch523_npc_combat.gd")
var count: int = 0
var failed: bool = false
func check(value: bool, label: String) -> void:
	count += 1
	if not value: failed = true; push_error(label)
func _init() -> void: call_deferred("run")
func run() -> void:
	var service = SERVICE.new(); service.configure(root)
	var catalog = service.source_effects
	check(catalog.error.is_empty() and catalog.records.size() == 17,"actual pinned current M effect pack")
	check(not EFFECTS.new().load_pack(service.effect_manifest,"0".repeat(64)),"wrong manifest pin rejected")
	var malformed: Dictionary = catalog.records["2232"].duplicate(true)
	malformed.frames[0].path = "frames/..\\outside.png"
	check(not catalog.valid_row(malformed,"2232"),"portable frame path traversal rejected")
	malformed = catalog.records["2232"].duplicate(true); malformed.source_fps = INF
	check(not catalog.valid_row(malformed,"2232"),"nonfinite source clock rejected")
	catalog.enabled = true; catalog.compose_children = true; catalog.fallback_fps = 30; catalog.opacity = .6; catalog.visual_scale = 1.25; catalog.additive = false
	check(catalog.make_effect(2232,0,1) == null,"global remaining texture budget rejects before allocation")
	var path: String = "user://effect_settings_contract_%d.cfg" % Time.get_ticks_usec()
	catalog.settings_path = path
	check(catalog.save_settings() == OK,"visual preferences write separate config")
	var restored = EFFECTS.new(); restored.settings_path = path; restored.load_settings()
	check(restored.enabled and restored.fallback_fps == 30 and is_equal_approx(restored.opacity,.6) and restored.visual_scale == 1.25 and not restored.additive and restored.compose_children,"all UI preferences survive reload")
	DirAccess.remove_absolute(path)
	for id: String in catalog.records:
		var row: Dictionary = catalog.records[id]
		var effect: Node2D = catalog.make_effect(int(id)); check(effect != null,"real PNG bytes accepted for "+id)
		if effect == null: continue
		root.add_child(effect)
		var expected: float = 0
		for frame: Dictionary in row.frames: expected += float(frame.source_ticks)/30.0
		check(is_equal_approx(effect.own_total,expected) and effect.timing_origin == "host_estimated_configurable_FPS","SPR ticks and explicit fallback separation "+id)
		check(effect.sprite.texture != null and effect.textures.size() == row.frames.size(),"every selected source token loads texture "+id)
		check(effect.layer_effects.size() == row.children.size(),"all required child layers load together "+id)
		effect.clear(); effect.free()
		check(not row.frames.is_empty(),"cleanup cannot mutate reusable manifest "+id)
		var second = catalog.make_effect(int(id)); check(second != null,"effect can be emitted repeatedly "+id)
		if second != null: second.free()
	catalog.compose_children = false
	check(catalog.make_effect(6530) == null,"disabled composition cannot show a partial substitute")
	catalog.compose_children = true
	var actor := Node2D.new(); root.add_child(actor)
	var spell: Dictionary = service.catalog.row("SpellClass",47873)
	check(service.emit_effect(actor,spell,"EffectSpriteID",Vector2(10,20)),"actual source spell47873 emits exact2232")
	check(service.effects.size() == 1 and service.effects[0].global_position == Vector2(10,20),"source effect reaches live scene point")
	service.forget(actor)
	check(service.effects.is_empty(),"actor lifecycle removes source effects")
	catalog.enabled = false
	check(not service.emit_effect(actor,spell,"EffectSpriteID",Vector2.ZERO),"disabled visual preference emits no substitute")
	actor.free(); service.clear(); await process_frame
	print("PATCH523_EFFECTS_RESULT checks=",count," failures=",failed," actual_M_source_frames=true; native_runtime_equivalence=false")
	quit(1 if failed else 0)
