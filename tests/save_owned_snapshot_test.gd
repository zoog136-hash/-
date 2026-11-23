extends SceneTree
const SNAP = preload("res://scripts/save/owned_snapshot.gd")
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	var live: Dictionary = {"nested":[{"count":1}],"typed":[1,1.0],"bytes":PackedByteArray([1,2])}
	var exported: Dictionary = live.duplicate(true)
	var data: Dictionary = {"exported":exported,"live":live,"unknown":{"nested":[2]},"array":[live],"number":1,"packed":PackedByteArray([3,4])}
	var expected: Dictionary = data.duplicate(true)
	var frozen: Dictionary = SNAP.freeze(data,{"exported":exported})
	check(var_to_bytes(frozen)==var_to_bytes(expected),"exact typed snapshot equals prior deep-copy path")
	check(is_same(frozen.exported,exported),"fresh isolated export transferred")
	check(not is_same(frozen.live,live),"live root copied")
	check(not is_same(frozen.live.nested,live.nested),"nested live state copied")
	live.nested[0].count=9;live.bytes[0]=9;data.unknown.nested[0]=9;data.packed[0]=9
	check(var_to_bytes(frozen)==var_to_bytes(expected),"live and unknown nested edits cannot alter snapshot")
	var replaced: Dictionary = {"exported":{"nested":[{"count":3}]}}
	var second: Dictionary = SNAP.freeze(replaced,{"exported":exported})
	replaced.exported.nested[0].count=7
	check(second.exported.nested[0].count==3,"trimmed or transaction replacement conservatively copied")
	var none: Dictionary = SNAP.freeze(data,{})
	check(var_to_bytes(none)==var_to_bytes(data.duplicate(true)),"caller with no owned roots retains old contract")
	print("SAVE_OWNED_SNAPSHOT_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
