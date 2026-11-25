extends SceneTree
## Synthetic codec output isolates the deterministic per-refresh reuse policy.
## Does not substitute pixels or certify the original source delivery.
const COORDS = preload("res://scripts/maps/source_coordinates.gd")
var checks: int = 0
var failures: Array[String] = []

class CodecProbe extends "res://scripts/maps/current523_static_spr.gd":
	var calls: Dictionary = {}
	var frame_image: Image
	func _source(sprite_id: int, _selector: int = 0, _declared_child: bool = false) -> Dictionary:
		return {"stored_frame0": false, "member":str(sprite_id), "stored_group_bit":0,
			"declaration":_declarations[sprite_id], "sha256":"a".repeat(64), "source_bytes":1, "dispatch":"synthetic"}
	func _render_static_frame(source_info: Dictionary, _frame: int) -> Dictionary:
		var id: int = int(source_info.member)
		calls[id] = int(calls.get(id, 0)) + 1
		if id == 201: return {"ok":true, "empty":true}
		if id == 202: return {"ok":false}
		return {"ok":true, "image":frame_image, "bounds":Rect2i(2, 3, 4, 4)}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func attr(body: String) -> Dictionary:
	return {"code":104,"name":"attr","raw_body":body,"raw":"104.attr("+body+")"}

func blend_runs() -> void:
	var probe := CodecProbe.new()
	probe.options = probe.DEFAULTS.duplicate(true)
	probe.coordinates = COORDS.new()
	check(probe.coordinates.configure([0,0],[64,64],{"basis_x":[24,-12],"basis_y":[24,12],"translation":[0,768]}),"blend projection ready")
	probe.frame_image = Image.create_empty(4,4,false,Image.FORMAT_RGBA8)
	probe.frame_image.fill(Color.CADET_BLUE)
	var mods: Array = [[], [attr("128")], [attr("128"),attr("8")], [attr("7"),attr(" 640 ")], [attr("bad"),attr("128")]]
	var records: Array[Dictionary] = []
	for id: int in mods.size():
		var definition: Dictionary = {"action_id":3,"sequence":[{"frame":0,"duration":1}],
			"own_ordered_references":[],"unresolved_modifiers":mods[id]}
		definition["own_source_blend"] = probe._own_source_blend(definition)
		probe._declarations[id+401] = definition
		records.append({"sprite_id":id+401,"raw_x":1,"raw_y":1})
	probe.refresh(records) # Source-settings preview stages a detached node first.
	check(probe._blend_runs.is_empty(),"staged settings have not allocated detached canvas RIDs")
	root.add_child(probe)
	var draws: Array[Dictionary] = probe.displayed_records()
	var modes: Array[int] = []
	for draw: Dictionary in draws:modes.append(int(draw.get("source_blend_mode",probe.MIX_BLEND)))
	check(modes==[probe.MIX_BLEND,probe.MULTIPLY_BLEND,probe.MIX_BLEND,probe.MULTIPLY_BLEND,probe.MIX_BLEND],
		"literal 128/last own104 resolve to MUL, intervening normals and malformed declarations remain MIX in source order")
	check(probe._blend_runs.size()==5 and int(probe.metrics().get("source_own104_multiply_records"))==2,
		"interleaved materials do not reorder by blend; all five drawing runs were submitted")
	check(draws[1].ignored_modifiers.is_empty() and draws[2].ignored_modifiers.size()==2,
		"own104 used by multiply is no longer reported ignored, unsupported variants are still diagnostic")
	var original_rids: Array[RID] = probe._blend_runs.duplicate()
	probe.refresh(records)
	check(probe._blend_runs==original_rids,"unchanged runs reuse existing canvas RIDs")
	var normal_only: Array[Dictionary] = [records[0],records[2],records[4]]
	probe.refresh(normal_only)
	check(probe._blend_runs.is_empty() and probe.displayed_records().size()==3,
		"normal-only field returns to the unchanged parent batch and frees alternate runs")
	probe.refresh(records)
	root.remove_child(probe)
	check(probe._blend_runs.is_empty(),"leaving the map frees all blend draw runs")
	root.add_child(probe)
	check(probe._blend_runs.size()==5,"reattaching the staged map restores its retained draw list")
	probe.options.unresolved_modifier_policy="DISABLED"
	probe.refresh(records)
	check(probe.displayed_records().size()==1 and probe._blend_runs.is_empty(),"explicit old no-modifiers gate remains unchanged")
	probe.queue_free()

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var probe := CodecProbe.new()
	root.add_child(probe)
	probe.options = probe.DEFAULTS.duplicate(true)
	probe.coordinates = COORDS.new()
	check(probe.coordinates.configure([0,0], [64,64], {"basis_x":[24,-12],"basis_y":[24,12],"translation":[0,768]}), "projection ready")
	probe.frame_image = Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	probe.frame_image.fill(Color.CADET_BLUE)
	var records: Array[Dictionary] = []
	var expected: Array[int] = []
	for id: int in range(1,130):
		probe._declarations[id] = {"action_id":0, "sequence":[{"frame":0,"duration":1}], "own_ordered_references":[]}
		records.append({"sprite_id":id,"raw_x":id % 20,"raw_y":1})
		expected.append(id)
	for id: int in [1,201,202,201,202,1]:
		probe._declarations[id] = {"action_id":0, "sequence":[{"frame":0,"duration":1}], "own_ordered_references":[]}
		records.append({"sprite_id":id,"raw_x":7,"raw_y":2})
		if id == 1: expected.append(id)
	probe.refresh(records)
	var draws: Array[Dictionary] = probe.displayed_records()
	var actual: Array[int] = []
	for draw: Dictionary in draws: actual.append(draw.drawn_sprite_id)
	check(actual == expected, "visible placement draw order and multiplicity retained across LRU eviction")
	check(not probe._textures.has("1:0:0") and probe._textures.size() == 128, "visible reuse does not increase global cache")
	check(probe.calls.get(1) == 1 and probe.calls.get(201) == 1 and probe.calls.get(202) == 1, "one codec call per deterministic frame in the refresh")
	check(draws.size() == expected.size() and draws[0].texture == draws[129].texture and draws[129].texture == draws[130].texture, "draws use same live texture, not just restated order")
	check(int(probe.metrics().get("empty_frames")) == 2 and int(probe.metrics().get("unresolved_records")) == 2, "per-placement diagnostics unchanged for repeated failures")
	probe.refresh(records)
	check(probe.calls.get(201) == 2 and probe.calls.get(202) == 2, "negative results not retained between refreshes")
	blend_runs()
	print("CURRENT523_STATIC_FRAME_CACHE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"synthetic":true}))
	probe.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
