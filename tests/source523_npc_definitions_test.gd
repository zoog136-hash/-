extends SceneTree
const Catalog=preload("res://scripts/shop/source523_shop_catalog.gd")
const Definitions=preload("res://scripts/shop/source523_npc_definitions.gd")
var checks: int=0
var failures: int=0
func _init() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var source=Catalog.session()
	check(source.available(),"actual existing shop pack selected")
	if not source.available():quit(1);return
	var npc=Definitions.new()
	npc.configure(source)
	check(not npc.loaded_sha256.is_empty(),"actual separate NPC pack byte checked")
	if npc.loaded_sha256.is_empty():quit(1);return
	var result: Dictionary=npc.context(13,1952)
	check(result.ok and result.currency_id==1 and str(result.origin).contains("TWILIGHT"),"Serin source identity plus labelled local availability")
	check(npc.currency_for(91)==21,"clan currency remains distinct from Adena")
	check(not npc.context(28,433).ok,"numeric EarthObject ID collision cannot authorize another merchant")
	check(not npc.context(372,37738).ok,"event merchant with no configured source spawn remains inactive")
	check(not npc.context(13,433).ok,"another merchant goods ID cannot use Serin's availability")
	var original: Dictionary=npc.rules.duplicate(true)
	var serin_hash: String=npc.rule_hash(13)
	npc.rules.merchants.append({"merchant_id":52,"earth_object_id":28,"spawn_id":5,"label":"테르"})
	check(npc.rule_hash(13)==serin_hash,"adding another independent NPC does not change Serin's saved rule")
	check(npc.context(52,int(npc.records["52"].goods_ids[0])).ok,"another explicit source NPC can be configured independently")
	npc.rules=original.duplicate(true)
	npc.rules.zero_hours_are_open="true"
	check(not Definitions.validate_rules(npc.rules).is_empty(),"local rule flags require real booleans")
	npc.rules=original.duplicate(true)
	npc.rules.merchants[0].spawn_id=1333
	check(not npc.context(13,1952).ok,"inner-castle spawn cannot replace Serin")
	npc.rules=original.duplicate(true)
	npc.rules.enabled=false
	check(not npc.context(13,1952).ok,"local NPC availability can be disabled")
	npc.rules=original
	var hash_before: String=npc.rule_hash()
	npc.rules.zero_hours_are_open=false
	check(npc.rule_hash()!=hash_before,"local time policy has a distinct durable identity")
	check(not npc.load_pack("user://missing-npc.json","f".repeat(64),source.loaded_sha256) and not npc.records.is_empty(),"invalid replacement preserves source definitions and reports failure")
	check(not npc.context(13,1952).ok,"failed replacement cannot activate stale definitions")
	print("SOURCE523_NPC_DEFINITIONS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if failures else 0)
