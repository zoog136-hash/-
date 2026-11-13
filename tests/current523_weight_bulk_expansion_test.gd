extends SceneTree
const OPTIONS = preload("res://scripts/item_options.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const NATIVE = preload("res://scripts/loot/current523_native_item_projection.gd")
var checks: int=0
var failures: Array[String]=[]
class Generic extends RefCounted:
	var calls: int=0
	func record(_id: String) -> Dictionary:
		calls+=1
		return {"source_weight_unit":"unverified_source_units","source_weight":0,"source_original_item":{"ID":7,"TestItem":false,"Weight":0}}
class OverrideStore extends NATIVE.TemplateStore:
	var calls: int=0
	func record(_id: String) -> Dictionary:
		calls+=1
		return {"source_weight_unit":"unverified_source_units","source_weight":0,"source_original_item":{"ID":7,"TestItem":false,"Weight":0}}
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var path: String="user://weight-bulk-fixture.bin"
	var writer:=FileAccess.open(path,FileAccess.WRITE)
	var light: Dictionary={"source_item_class_id":7,"source_weight_unit":"unverified_source_units"}
	var nested: Dictionary={"ID":7,"TestItem":false,"Weight":0,"nested":[{"v":[1]}]}
	writer.store_var(light); writer.store_var({"keys":["source_item_class_id","source_weight_unit","source_weight","source_original_item"],"fields":{"source_weight":0,"source_original_item":nested}}); writer.close()
	var store:=NATIVE.TemplateStore.new();store.file=FileAccess.open(path,FileAccess.READ);store.offsets={"7":0};store.interning=false
	var own: Dictionary={FIELDS.MARK:true,"source":"lineagem_patch523","source_snapshot":"patch523","source_m_native_item":true,"source_test_item":false,"source_projection":"current523_original_typed_game_dto_v1","source_item_class_id":7,"source_bless_raw":1,"sourceId":"m523:item:7","slot":"material"}
	FIELDS.bind(store)
	var before: Dictionary=OPTIONS.current_source_weight_input(own,{})
	check(FIELDS._cache.has("7"),"public weight API still populates original cache")
	FIELDS.bind(store)
	var after: Dictionary=OPTIONS._bulk_source_weight_input(own,{})
	check(var_to_bytes(before)==var_to_bytes(after),"bulk and public values equal for uninstalled identity")
	check(not FIELDS._cache.has("7"),"eligible fresh native bulk expansion does not populate public cache")
	check(nested.nested[0].v==[1] and not own.has("source_original_item"),"bulk input aliases remain unchanged")
	FIELDS.bind(store);OPTIONS.current_source_weight_input(own,{})
	store.file=null
	check(var_to_bytes(OPTIONS._bulk_source_weight_input(own,{}))==var_to_bytes(before),"bulk keeps authoritative cached template without touching file")
	store.file=FileAccess.open(path,FileAccess.READ)
	var missing: Dictionary=own.duplicate(true);missing.source_item_class_id=404;missing.sourceId="m523:item:404"
	FIELDS.bind(store);OPTIONS.current_source_weight_input(missing,{})
	store.offsets["404"]=0;store.file=null
	check(OPTIONS._bulk_source_weight_input(missing,{})=={"applicable":false},"cached empty miss remains authoritative")
	store.offsets.erase("404");store.file=FileAccess.open(path,FileAccess.READ)
	var generic:=Generic.new();FIELDS.bind(generic)
	check(OPTIONS._bulk_source_weight_input(own,{})==before and generic.calls==1 and FIELDS._cache.has("7"),"generic provider retains one cached public full read")
	var override_store:=OverrideStore.new();override_store.interning=false;override_store.file=store.file;override_store.offsets=store.offsets;FIELDS.bind(override_store)
	check(OPTIONS._bulk_source_weight_input(own,{})==before and override_store.calls==1,"subclass record override is never bypassed")
	store.interning=true;store.strings.clear();FIELDS.bind(store)
	check(OPTIONS._bulk_source_weight_input(own,{})==before and FIELDS._cache.has("7") and not store.strings.is_empty(),"interning side effects retain original path")
	var ordinary: Dictionary=own.duplicate(true);ordinary.erase(FIELDS.MARK);ordinary.source_weight_unit="unverified_source_units"
	FIELDS.bind(null)
	check(OPTIONS._bulk_source_weight_input(ordinary,{})==OPTIONS.current_source_weight_input(ordinary,{}),"ordinary unmarked input retains exact public validation")
	for changed: Dictionary in [{"source_m_native_item":"true"},{"source_projection":"wrong"},{"source_test_item":true}]:
		var invalid: Dictionary=own.duplicate(true);invalid.merge(changed,true);FIELDS.bind(generic);var calls: int=generic.calls
		check(OPTIONS._bulk_source_weight_input(invalid,{})=={"applicable":false} and generic.calls==calls,"malformed admission fails before expansion "+str(changed))
	FIELDS.bind(null);store.file.close();DirAccess.remove_absolute(path)
	print("WEIGHT_BULK_EXPANSION_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
