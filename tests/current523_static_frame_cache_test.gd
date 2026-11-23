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
	print("CURRENT523_STATIC_FRAME_CACHE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"synthetic":true}))
	probe.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
