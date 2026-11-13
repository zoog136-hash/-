extends SceneTree
const LOOKUP = preload("res://scripts/catalog_item_lookup.gd")
const CASH = preload("res://scripts/shop/source523_cash_packages.gd")
const WORLD = preload("res://scripts/world.gd")
const CATALOG = preload("res://scripts/shop/source523_shop_catalog.gd")
var checks: int = 0
var failures: Array[String] = []
class GenericWorld extends RefCounted:
	var calls: int = 0
	func _find_catalog_item_record(_name: String) -> Dictionary:
		calls += 1
		return {"name":"callback"}
class CustomQuest extends RefCounted:
	func held_record(_name: String,_instances: Dictionary) -> Dictionary: return {}
class CustomCatalog extends CATALOG: pass
class CustomWorld extends WORLD: pass
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var a: Array = [{"name":"dup","v":1},{"name":"dup","v":2},7]
	var b: Array = [{"name":"dup","v":3},{"name":"second","v":4},{"name":"해독제","v":5}]
	var instances: Dictionary = {"one":{"name":"held","record":{"name":"held","nested":[1]}}}
	var scope := LOOKUP.CashInstallScope.new([a,b])
	for name: String in ["dup","second","held","absent","","해독제"]:
		check(var_to_bytes(scope.find_one([a,b],instances,name)) == var_to_bytes(LOOKUP.find_one([a,b],instances,name)),"first order/instance/miss parity "+name)
	check(is_same(scope.find_one([a,b],{},"dup"),a[0]),"catalog aliases and first duplicate retained")
	var held: Dictionary = scope.find_one([a,b],instances,"held");held.nested.append(2)
	check(instances.one.record.nested==[1],"held instance copied")
	a.append({"name":"new","v":5});scope.note_append(a)
	check(scope.find_one([a,b],{},"new").v==5,"tracked append visible")
	a.append({"name":"dup","v":9});scope.note_append(a)
	check(scope.find_one([a,b],{},"dup").v==1,"append cannot replace earlier duplicate")
	a[0].name="renamed"
	check(scope.find_one([a,b],{},"dup")==null and not scope.active,"changed hit name requests public fallback")
	check(LOOKUP.find_one([a,b],{},"dup").v==2,"public fallback finds next duplicate")
	scope=LOOKUP.CashInstallScope.new([a,b]);a.remove_at(0)
	check(scope.find_one([a,b],{},"missing")==null,"removal requests public fallback")
	scope=LOOKUP.CashInstallScope.new([a,b]);a.append({"name":"untracked"})
	check(scope.find_one([a,b],{},"untracked")==null,"untracked append requests fallback")
	scope=LOOKUP.CashInstallScope.new([a,b]);check(scope.find_one([a.duplicate(),b],{},"dup")==null,"array replacement requests fallback")
	scope=LOOKUP.CashInstallScope.new([a,b]);scope.close();check(scope.find_one([a,b],{},"dup")==null and scope.rows.is_empty(),"closed scope releases all references")
	var empty_first: Array=[{}, {"name":"","v":90}]
	var empty_second: Array=[{"name":"","v":91}]
	var empty_instances: Dictionary={"e":{"name":"","record":{"name":"","v":92}}}
	var empty_scope:=LOOKUP.CashInstallScope.new([empty_first,empty_second])
	check(is_same(empty_scope.find_one([empty_first,empty_second],empty_instances,""),LOOKUP.find_one([empty_first,empty_second],empty_instances,"")) and empty_scope.find_one([empty_first,empty_second],empty_instances,"").v==91,"empty first match skips later same-source duplicate and uses next source")
	empty_scope.close();empty_second.clear();empty_scope=LOOKUP.CashInstallScope.new([empty_first,empty_second])
	var empty_result: Dictionary=empty_scope.find_one([empty_first,empty_second],empty_instances,"")
	check(var_to_bytes(empty_result)==var_to_bytes(LOOKUP.find_one([empty_first,empty_second],empty_instances,"")) and empty_result.v==92 and not is_same(empty_result,empty_instances.e.record),"empty first match falls through to copied instance")
	empty_scope.close()
	var world := WORLD.new();world.catalog_db={"아이템":[{"name":"plain","sourceId":"fixture:1"}]};world.item_db=[{"name":"item-only"}];world.item_instances={"q":{"name":"[원본 보상] test","record":{"name":"[원본 보상] test","source_pending_use":true,"nested":[1]}}}
	var catalog := CATALOG.new();var live := CASH._install_lookup(world,catalog)
	check(live!=null,"exact production owners admitted")
	check(var_to_bytes(CASH._find_record(world,"plain","fixture:1",live))==var_to_bytes(world._find_catalog_item_record("plain","fixture:1")),"source ID path remains authoritative")
	for name: String in ["plain","item-only","[원본 보상] test","missing"]:
		check(var_to_bytes(CASH._find_record(world,name,"",live))==var_to_bytes(world._find_catalog_item_record(name)),"production held/quest/order parity "+name)
	var record: Dictionary={"name":"registered","nested":[1]};CASH._register(world,record,live)
	check(is_same(CASH._find_record(world,"registered","",live),record),"register append observed with original catalog alias")
	check(not is_same(world.item_db[-1],record),"item_db retains duplicate ownership")
	live.close();world.quest_auto=CustomQuest.new();check(CASH._install_lookup(world,catalog)==null,"custom quest callback excluded")
	world.quest_auto=null;check(CASH._install_lookup(world,CustomCatalog.new())==null,"catalog subclass excluded")
	var mastery = world.weapon_mastery;world.weapon_mastery=GenericWorld.new();check(CASH._install_lookup(world,catalog)==null,"custom mastery callback excluded");world.weapon_mastery=mastery
	var ticket = mastery.reset_ticket;mastery.reset_ticket=GenericWorld.new();check(CASH._install_lookup(world,catalog)==null,"custom reset ticket callback excluded");mastery.reset_ticket=ticket
	var fields = preload("res://scripts/loot/current523_native_fields.gd");var store = fields._store;fields.bind(preload("res://scripts/loot/current523_native_item_projection.gd").TemplateStore.new());var native_scope= CASH._install_lookup(world,catalog);check(native_scope!=null,"exact nested TemplateStore script admitted");native_scope.close();fields.bind(GenericWorld.new());check(CASH._install_lookup(world,catalog)==null,"custom template callback excluded");fields.bind(store)
	world.item_db=world.catalog_db["아이템"];check(CASH._install_lookup(world,catalog)==null,"aliased mutation sources excluded")
	var main: Node = load("res://Main.tscn").instantiate();main.catalog_db={"아이템":[]};main.item_db=[];var main_scope= CASH._install_lookup(main,catalog);check(main_scope!=null,"actual Main.tscn adapter admitted");main_scope.close();main.free()
	var custom := CustomWorld.new();check(CASH._install_lookup(custom,catalog)==null,"world subclass excluded")
	var generic := GenericWorld.new();check(CASH._install_lookup(generic,catalog)==null,"generic world excluded")
	check(CASH._find_record(generic,"name","",null).name=="callback" and generic.calls==1,"generic callback retains one-argument ABI")
	world.free();custom.free()
	print("CASH_INSTALL_LOOKUP_SCOPE_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
