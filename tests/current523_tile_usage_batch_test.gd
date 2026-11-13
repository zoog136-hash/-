extends SceneTree
const BATCH=preload("res://scripts/maps/current523_tile_usage_batch.gd")
class Pack extends RefCounted:
	var calls: Array[int]=[]
	var revision: String="a"
	func source_usage_identity(tile_id: int) -> Dictionary:
		calls.append(tile_id)
		return {} if tile_id==9 else {"member":"Tile/%d.ti2"%tile_id,"bytes":42,"sha256":revision.repeat(64)}
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok:failures.append(why)
func _initialize() -> void:
	var pack:=Pack.new()
	var refs: Dictionary={}
	for tile: int in [3,9,4]:
		for subimage: int in range(256):refs[(tile<<8)|subimage]=true
	var before: Dictionary=refs.duplicate(true)
	var identities: Dictionary=BATCH.identities(pack,refs)
	check(pack.calls==[3,9,4],"768 subimages read exactly three identities, including misses")
	check(refs==before,"observation units and order input retained")
	check(identities.keys()==[3,9,4],"first-seen identity order retained")
	var units: Array[String]=[]
	for ref: int in refs:
		var source: Dictionary=identities[ref>>8]
		if not source.is_empty():units.append(str(source.member)+":subimage:"+str(ref&255))
	check(units.size()==512,"all valid subimage observations retained")
	check(units[0]=="Tile/3.ti2:subimage:0" and units[511]=="Tile/4.ti2:subimage:255","output order unchanged")
	pack.revision="b"
	var refreshed: Dictionary=BATCH.identities(pack,refs)
	check(pack.calls.size()==6,"next draw rereads identities")
	check(refreshed[3].sha256=="b".repeat(64) and identities[3].sha256=="a".repeat(64),"changed identity observed without stale cross-draw cache")
	var replacement:=Pack.new()
	check(BATCH.identities(replacement,refs).size()==3 and replacement.calls.size()==3,"replacement pack owns its reads")
	check(BATCH.identities(pack,{}).is_empty() and pack.calls.size()==6,"empty draw has no reads")
	print("CURRENT523_TILE_USAGE_BATCH_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"synthetic_refs":768,"identity_reads":3}))
	quit(0 if failures.is_empty() else 1)
