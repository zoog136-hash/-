extends SceneTree
## Same exact original input through the production NPC admission API. Default
## fixtures also check duplicates, unkeyed, malformed and excluded rows.
const P=preload("res://scripts/monsters/current523_npc_input_projection.gd")
const C=preload("res://scripts/monsters/patch523_npc_catalog.gd")
const S=preload("res://scripts/resources/current523_definition_rows.gd")
class Baseline extends P:
	func _keep_fixed_enum(table: String, all: Array[Dictionary]) -> bool:
		var order := PackedInt32Array()
		order.resize(all.size())
		for i: int in all.size(): order[i]=i
		for row: Dictionary in all:
			if not _excluded(table,row) and not _keep(table,row,_positions_in(table,row,order,all)):return false
		return true
var failures: Array[String]=[]
var checks: int=0
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: failures.append(why);printerr("NPC_ENUM_POS_FAIL ",why)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for fixture: Array in [
		[{"ID":0},{"ID":1.0},{"ID":7}],
		[{"ID":7},{"ID":7.0}],
		[{"ID":7,"V":1},{"ID":7,"V":2}],
		[{"ID":null},{"ID":7}],
		[{"V":5},{"V":6},{"V":5}],
		[{"ID":7,"Name":"[더미] skip"},{"ID":7,"Name":"keep"}],
		[{"ID":1},{"ID":1},{"ID":1}]]:
		var rows: Array[Dictionary]=[]
		rows.assign(fixture)
		var reference:=Baseline.new()
		var actual:=P.new()
		var expected: bool=reference._keep_fixed_enum("BuffGroup",rows)
		var got: bool=actual._keep_fixed_enum("BuffGroup",rows)
		check(got==expected and actual.problem==reference.problem,"same admission and reason")
		check(var_to_bytes([actual._selected,actual.exclusions])==var_to_bytes([reference._selected,reference.exclusions]),"same source positions/order/content/exclusions")
	var evidence: Dictionary={}
	if OS.get_environment("TWILIGHT_VERIFY_NPC73681")=="1":
		var src: Dictionary=S.row("NpcClass",73681)
		if src.get("Sprite")!=4576:check(false,"exact original #73681/4576 source installed")
		else:
			var host: Dictionary={"source_m_npc_id":73681,"source_m_original":{"ID":73681,"Sprite":4576,"DescId":src.DescId},"source_m_spawn_npc_level":19,"drop":[]}
			var expected: PackedByteArray
			var times: Dictionary={"legacy":[],"linear":[]}
			for arm: int in [-1,0,1,1,0,1,0,0,1,0,1,1,0]:
				var c=C.new()
				if arm==0:c._original_input=Baseline.new()
				var start: int=Time.get_ticks_usec()
				var out: Dictionary=c.project_actor_record(host)
				var elapsed: int=Time.get_ticks_usec()-start
				var bytes: PackedByteArray=var_to_bytes([out,c.content,c.source_model_sha256,c.admitted_source_identities])
				if arm<0:expected=bytes
				else:times["legacy" if arm==0 else "linear"].append(elapsed)
				check(out.get("source_m_definition_snapshot")=="patch523" and bytes==expected,"same full real NPC and registry bytes")
			evidence={"npc":73681,"sprite":4576,"first_actor_existing_definition_caches_us":times,"source_sha":C.SOURCE_SHA}
	print("CURRENT523_NPC_ENUM_POSITION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
