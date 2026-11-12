extends SceneTree
## Synthetic host-placement regression through the real NPC emitter, source
## selector, preview factory, pinned action bank and first frame decode/upload.
## Only the already-verified source table cache boundary is seeded with test rows;
## no original table admission, original pixels, GPU render or native M claim.
const SERVICE = preload("res://scripts/monsters/patch523_npc_combat.gd")
const SOURCE = preload("res://scripts/resources/current523_source_bank.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const SYNTHETIC = preload("res://tests/reference_sp2_load_memo_test.gd")
const ACTOR: int = 9001
const BUDGET: int = 64*1024*1024

class Pose:
	extends RefCounted
	var facing8: int = 2
class Actor:
	extends Node2D
	var motion := Pose.new()
class Player:
	extends Node2D
	var source_523_movement_blocked: bool = false
class World:
	extends Node2D
	var player := Player.new()

var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SOURCE_NPC_EFFECT_ANCHOR_FAIL ",label)

func write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
func write_json(path: String, value: Dictionary) -> String:
	write_bytes(path,JSON.stringify(value).to_utf8_buffer())
	return FileAccess.get_sha256(path)

func fixture(directory: String) -> Dictionary:
	var contract: Dictionary = {"format":"current523_identity_roles_v1","native_dispatch_verified":false,"selection":"explicit_source_actor_id_and_source_action_id","loop":"unknown_requires_explicit_caller_policy","timing":"source_explicit_fps_and_duration_ticks_only","frame_policy":"client_clamp_frame_null_missing_direction_or_empty_body"}
	var member: String = "Sprite/9001-0.sp2"
	var raw_path: String = directory.path_join("raw/"+member)
	write_bytes(raw_path,SYNTHETIC.make_sp2(255,false))
	var declaration: Dictionary = {"sprite_id":ACTOR,"source_file":"list_9.spr","source_line":10,"source_sha256":"a".repeat(64),"alias_target":null}
	var attribute: Dictionary = declaration.duplicate(true)
	attribute["literal_attribute_directives"] = []
	var layer: Dictionary = {"kind":"body","source_sprite_id":ACTOR}
	var directions: Array = []
	for direction: int in range(8):
		var selected: Dictionary = layer.duplicate()
		selected.merge({"member":member,"group_bit":direction,"frame_index":0})
		directions.append([{"duration_ticks":24,"layers":[selected]}])
	var track: Dictionary = {"source_action_id":0,"fps":24,"loop":null,"source_file":"list_9.spr","source_line":20,"directions":directions}
	var proof: Dictionary = {"code":0,"fps":24,"source_file":"list_9.spr","source_line":20,"source_sha256":"b".repeat(64),"tokens":[[0,0,24]],"declared_flag":1,"source_annotations":[]}
	var action: Dictionary = {"schema":1,"source_snapshot":"patch523","consumer_contract":contract,"action_key":"list_9.spr:B9001:A0","actor":{"source_sprite_id":ACTOR,"roles":{"source_action:0":track}},"source_proof":{"root_sprite_id":ACTOR,"body_sprite_id":ACTOR,"declarations":[{"kind":"body","declaration_path":[declaration]}],"roles":{"source_action:0":proof}},"compact_roles":{"source_action:0":{"source_action_id":0,"source_sprite_id":ACTOR,"fps":24,"loop":null,"tokens":[[0,0,24]],"declared_flag":1,"layers":[layer]}},"source_layer_declarations":[{"kind":"body","source_sprite_id":ACTOR,"declaration_path":[attribute]}],"independent_source_layers":[]}
	var action_path: String = "actors/9001/action-0.json"
	var action_sha: String = write_json(directory.path_join(action_path),action)
	var manifest: Dictionary = {"schema":1,"kind":"current523_reference_sp2_action_bank","source_snapshot":"patch523","consumer_contract":contract,"source_dummy_exclusion_policy":BANK.SOURCE_DUMMY_EXCLUSION_POLICY,"excluded_source_actors":{},"members":{member:{"member":member,"path":"raw/"+member,"sha256":FileAccess.get_sha256(raw_path),"bytes":FileAccess.get_size(raw_path)}},"actors":{"sprite:9001":{"0":{"path":action_path,"sha256":action_sha}}},"source_action_domains":{"sprite:9001":{"source_snapshot":"patch523","source_actor_id":ACTOR,"action_domain_basis":"all_effective_original_SPR_actions_not_only_compiled_entries","action_ids":[0]}}}
	var path: String = directory.path_join("manifest.json")
	var sha: String = write_json(path,manifest)
	var tables: String = directory.path_join("synthetic_verified_table_cache_boundary.txt")
	write_bytes(tables,"Synthetic test cache boundary. This is not an admitted original table ZIP.".to_utf8_buffer())
	return {"current523_source_bank":{"schema":1,"enabled":true,"source_snapshot":"patch523","tables_zip":tables,"manifest_path":path,"manifest_sha256":sha}}

func seed_test_table_cache(context: Dictionary, spell: Dictionary) -> void:
	# Isolate a previously verified reader boundary. The fixed original ZIP pin
	# is deliberately not claimed to match synthetic bytes; production code is
	# unchanged and this process exits after the host-placement test.
	var path: String = context.current523_source_bank.tables_zip
	SOURCE.shared_tables_enabled = false
	SOURCE._shared = false
	SOURCE._shared_tables.clear()
	SOURCE._rows.clear()
	SOURCE._by_id.clear()
	for table: String in SOURCE.TABLES:
		SOURCE._rows[table] = []
		SOURCE._by_id[table] = {}
	SOURCE._rows["SpellClass"] = [spell.duplicate(true)]
	SOURCE._by_id["SpellClass"] = {int(spell.ID):spell.duplicate(true)}
	SOURCE._table_path = path
	SOURCE._table_sha = SOURCE.TABLES_SHA
	SOURCE._table_stamp = "%d:%d" % [FileAccess.get_modified_time(path),FileAccess.get_size(path)]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data: String = "user://source_npc_anchor_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var context: Dictionary = fixture(data)
	var spell: Dictionary = {"ID":123,"Name":"synthetic NPC event","TestSpell":false,"EffectSpriteID":ACTOR,"EffectSpriteActionNo":0,"CasterEffectSpriteID":ACTOR,"SuccessEffectSpriteID":ACTOR}
	seed_test_table_cache(context,spell)
	var world := World.new()
	root.add_child(world)
	world.add_child(world.player)
	var actor := Actor.new()
	world.add_child(actor)
	actor.position = Vector2(100,200)
	actor.rotation = 0.6
	actor.scale = Vector2(2,0.5)
	actor.set_meta("current523_source_only_visual",{"required":true})
	actor.set_meta("current523_source_bank_selection",{"consumer":"npc","source_snapshot":"patch523","source_bank_context":context})
	var service := SERVICE.new()
	service.world = world
	var point := Vector2(350,-80)
	check(service.emit_effect(actor,spell,"EffectSpriteID",point),"real emitter selects and creates synthetic source event")
	check(service.effects.size() == 1,"existing owner tracks the emitted effect")
	if service.effects.is_empty():
		printerr(JSON.stringify(service.effect_status))
		world.free()
		finish()
		return
	var effect: Node2D = service.effects[0]
	var selected: Dictionary = service.effect_status["123:EffectSpriteID"].source_bank
	check(effect.get_parent() == actor and effect.is_set_as_top_level(),"NPC retains lifetime ownership while event snapshots world transform")
	check(effect.global_transform.is_equal_approx(Transform2D(0.0,point)),"initial transformed NPC does not distort event world point or basis")
	check(int(effect.get_meta("patch523_owner_id")) == actor.get_instance_id(),"existing owner identity metadata retained")
	check(int(effect.get_meta("patch523_frame_bytes")) == BUDGET and service.remaining_effect_bytes() == 0,"existing conservative texture budget remains reserved")
	check(selected.manifest_path == context.current523_source_bank.manifest_path and selected.manifest_sha256 == context.current523_source_bank.manifest_sha256,"NPC's selected bank path and pin preserved")
	check(selected.source_reference.row == spell and selected.source_reference.field == "EffectSpriteID" and selected.action_id == 0,"complete typed spell field and exact action preserved")
	check(effect._overlay_facing == 5 and effect.source_facing == 5 and is_zero_approx(effect._clock),"existing facing conversion and initial source clock preserved")
	check(effect._playback_tracks.idle.loop == false and effect._playback_tracks.idle.fps == 24,"source one-shot timing remains unchanged")
	var frame: Dictionary = effect.reference_source_frame_status()
	check(effect.last_source_frame == 0 and frame.get("selected_layers",[]).size() == 1 and effect._layers[0].texture != null,"production first frame decodes and assigns synthetic pixels")
	actor.position += Vector2(27,-43)
	actor.rotation = -0.8
	actor.scale = Vector2(0.75,3)
	check(effect.global_transform.is_equal_approx(Transform2D(0.0,point)),"event remains fixed as NPC moves rotates and scales")
	check(effect.advance_reference_source(0.25,"idle",5) and is_equal_approx(effect._clock,0.25),"existing source clock advances independently")
	check(effect.global_transform.is_equal_approx(Transform2D(0.0,point)),"advancing source animation retains world snapshot")
	check(not service.emit_effect(actor,spell,"SuccessEffectSpriteID",Vector2(12,34)) and service.effects.size() == 1,"budget rejection creates no extra node")
	service.forget(actor)
	check(service.effects.is_empty() and effect.is_queued_for_deletion(),"forget still retires actor-owned snapshot effect")
	check(service.remaining_effect_bytes() == BUDGET,"forget releases existing tracked budget")
	await process_frame
	check(not is_instance_valid(effect),"forgotten effect is freed")
	var changed: Dictionary = spell.duplicate(true)
	changed["Name"] = "different row"
	check(not service.emit_effect(actor,changed,"EffectSpriteID",point) and service.effects.is_empty(),"complete source-row disagreement still rejects")
	check(service.emit_effect(actor,spell,"CasterEffectSpriteID",point),"new event can be emitted after owner forget")
	var cleared: Node2D = service.effects[0]
	service.clear()
	check(service.effects.is_empty() and cleared.is_queued_for_deletion() and service.remaining_effect_bytes() == BUDGET,"service clear retains cleanup and budget release")
	await process_frame
	check(not is_instance_valid(cleared),"cleared source node is freed")
	check(service.emit_effect(actor,spell,"EffectSpriteID",point),"source event remains reusable after clear")
	var child: Node2D = service.effects[0]
	actor.free()
	check(not is_instance_valid(child) and service.remaining_effect_bytes() == BUDGET,"scene parent free still releases top-level child and budget")
	service.clear()
	world.free()
	finish()

func finish() -> void:
	SOURCE._rows.clear()
	SOURCE._by_id.clear()
	SOURCE._table_path = ""
	SOURCE._table_sha = ""
	SOURCE._table_stamp = ""
	SOURCE.shared_tables_enabled = true
	print("SOURCE_NPC_EFFECT_ANCHOR_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"synthetic_only":true,"table_cache_boundary_seeded":true,"original_admission_verified":false,"gpu_render_verified":false}))
	quit(0 if failures.is_empty() else 1)
