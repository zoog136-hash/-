extends SceneTree
## Pure adapter reducer and explicitly injected synthetic service boundary.
## Never writes D._data, installs a supplier, or claims normal acquisition.
const Native = preload("res://scripts/equipment523/native_catalog.gd")
const Service = preload("res://scripts/equipment523/service.gd")
const C = preload("res://scripts/equipment523/common.gd")
var checks: int = 0
var failures: Array[String] = []
var original_cache_negative_checked: bool = false
var original_native_api_checked: bool = false

class KernelService extends Service:
	var fixtures: Dictionary = {}
	func _native_identity(record: Dictionary) -> Dictionary:
		var key: String = str(record.get("sourceId",""))+"|"+str(record.get("source_bless_raw",0))
		var fixture: Dictionary = fixtures.get(key,{})
		if fixture.is_empty(): return {}
		return Native.validate_identity(store.pack,record,fixture.definition,fixture.expected,fixture.identity,bool(fixture.equipment))

class World extends Node:
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var equipped_items: Dictionary = {}
	var catalog_db: Dictionary = {"아이템":[]}
	var item_db: Array = []
	func _item_locked(_name: String, _id: String) -> bool: return false
	func _enhancement_kind_for_record(record: Dictionary) -> String:
		return "armor" if record.get("slot") == "body" else ""

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	_test_reducer()
	_test_service()
	_test_unavailable_owner()
	_test_original_owner_api()
	print("EQUIPMENT523_NATIVE_CATALOG_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"original_cache_negative_checked":original_cache_negative_checked,"original_native_api_checked":original_native_api_checked,"scope":"SYNTHETIC_IDENTITY_REDUCER_AND_SERVICE_KERNEL; OPTIONAL_ORIGINAL_NATIVE_OWNER_REGISTRATION_API; EXPLICIT_OWNERSHIP_FIXTURE_NOT_NORMAL_ACQUISITION"}))
	quit(0 if failures.is_empty() else 1)

func _pack() -> Dictionary:
	return {"source_sha256":C.SOURCE_SHA,"tables":{},"bonuses":{},"bindings":{"legacy:3":{"name":"legacy","source_id":3}},"items":{
		"1":{"raw":{"ID":1,"Name":"Kernel material","TestItem":false,"CategoryID":10},"names":["Kernel material"],"name":"Kernel material"},
		"2":{"raw":{"ID":2,"Name":"Kernel gear","TestItem":false,"CategoryID":2},"names":["Kernel gear"],"name":"Kernel gear"},
		"3":{"raw":{"ID":3,"Name":"legacy","TestItem":false},"names":["legacy"],"name":"legacy"}}}

func _fixture(pack: Dictionary, id: int, bless: int, gear: bool = false) -> Dictionary:
	var raw: Dictionary = pack.items[str(id)].raw.duplicate(true)
	var record: Dictionary = {"source_m_native_item":true,"source_item_class_id":id,"source_snapshot":"patch523","source":"lineagem_patch523","sourceUrl":"synthetic fixture","source_bless_raw":bless,"name":str(raw.Name),"source_display_name":str(raw.Name),"sourceId":"m523:item:"+str(id),"slot":"body" if gear else "material","type":"synthetic","grade":"일반"}
	if not gear and bless != 1:
		record.name += " · "+("축복" if bless == 2 else "저주")
		record.sourceId += ":bless:"+str(bless)
	return {"expected":record,"definition":{"original_item":raw,"native_record":record.duplicate(true)},"identity":{"schema":3,"source_snapshot":"patch523","sha256":"a".repeat(64)},"equipment":gear}

func _validated(pack: Dictionary, record: Dictionary, fixture: Dictionary) -> Dictionary:
	return Native.validate_identity(pack,record,fixture.definition,fixture.expected,fixture.identity,fixture.equipment)

func _test_reducer() -> void:
	var pack: Dictionary = _pack()
	for bless: int in [1,2,3]:
		var fixture: Dictionary = _fixture(pack,1,bless)
		var result: Dictionary = _validated(pack,fixture.expected,fixture)
		_check(int(result.get("source_id",0)) == 1 and int(result.get("bless_code",0)) == bless,"pure reducer preserves exact native blessing identity "+str(bless))
		_check(Native.processing_bless(fixture.expected,{},result) == (bless if bless != 3 else 0),"processing keeps its existing normal/blessed domain and refuses cursed "+str(bless))
	var normal: Dictionary = _fixture(pack,1,1)
	for field: String in ["name","sourceId","source","source_snapshot","source_item_class_id","source_bless_raw","slot","grade"]:
		var changed: Dictionary = normal.expected.duplicate(true)
		changed[field] = 99 if field in ["source_item_class_id","source_bless_raw"] else "changed"
		_check(_validated(pack,changed,normal).is_empty(),"identity reducer refuses changed canonical field "+field)
	for value: Variant in [true,"2",2.5,NAN,INF,0,-1]:
		var changed: Dictionary = normal.expected.duplicate(true)
		changed.source_bless_raw = value
		_check(_validated(pack,changed,normal).is_empty(),"raw blessing is a finite whole source code: "+str(value))
	var wrong: Dictionary = normal.duplicate(true)
	wrong.definition.original_item.CategoryID = 20
	_check(_validated(pack,normal.expected,wrong).is_empty(),"every ItemClass field retained by the processing cache must match")
	wrong = normal.duplicate(true)
	wrong.definition.original_item.TestItem = true
	_check(_validated(pack,normal.expected,wrong).is_empty(),"a test original cannot pass native identity validation")
	wrong = normal.duplicate(true)
	wrong.identity = {}
	_check(_validated(pack,normal.expected,wrong).is_empty(),"no active verified full catalog identity means no native identity")
	var blessed: Dictionary = _fixture(pack,1,2)
	var identity: Dictionary = _validated(pack,blessed.expected,blessed)
	_check(Native.processing_bless(blessed.expected,{"source_bless_code":1},identity) == 0,"a stack cannot flatten its native blessed suffix into a normal code")
	_check(Native.processing_bless(blessed.expected,{"blessed":false},identity) == 0,"a stack's physical normal flag cannot contradict its blessed source identity")
	_check(Native.processing_bless(blessed.expected,{"bless_state":"blessed","blessed":true},identity) == 2,"consistent physical stack flags preserve the native blessing")
	var gear: Dictionary = _fixture(pack,2,1,true)
	identity = _validated(pack,gear.expected,gear)
	_check(Native.processing_bless(gear.expected,{"source_bless_code":1,"blessed":true},identity) == 2,"existing live gear blessing supersedes a historical normal raw gear code")
	gear = _fixture(pack,2,2,true)
	identity = _validated(pack,gear.expected,gear)
	_check(Native.processing_bless(gear.expected,{"source_bless_code":2,"blessed":false,"bless_state":"normal"},identity) == 1,"existing live gear blessing removal supersedes a historical blessed raw gear code")
	_check(Native.processing_bless(gear.expected,{"blessed":false,"bless_state":"blessed"},identity) == 0,"contradictory physical gear flags are refused")

func _test_service() -> void:
	var world := World.new()
	var service := KernelService.new()
	service.store.pack = _pack()
	for bless: int in [1,2,3]:
		var fixture: Dictionary = _fixture(service.store.pack,1,bless)
		var record: Dictionary = fixture.expected
		service.fixtures[str(record.sourceId)+"|"+str(bless)] = fixture
		world.catalog_db["아이템"].append(record)
		world.inventory[str(record.name)] = {1:10,2:7,3:2}[bless]
	var entries: Array = service._entries(world)
	_check(entries.size() == 2,"synthetic service boundary lists normal and blessed stacks separately and excludes cursed")
	var by_id: Dictionary = {}
	for entry: Dictionary in entries: by_id[str(entry.instance_id)] = entry
	_check(by_id.has("stack:1") and int(by_id["stack:1"].quantity) == 10 and int(by_id["stack:1"].bless_code) == 1,"normal stack keeps its historical physical selection ID")
	_check(by_id.has("stack:1:bless:2") and int(by_id["stack:1:bless:2"].quantity) == 7 and int(by_id["stack:1:bless:2"].bless_code) == 2,"blessed stack has its exact distinct owner ID and quantity")
	var normal: Dictionary = world.catalog_db["아이템"][0]
	var blessed: Dictionary = world.catalog_db["아이템"][1]
	world.item_instances["selected"] = {"name":blessed.name,"record":blessed.duplicate(true),"source_reward_quantity":3}
	entries = service._entries(world)
	by_id.clear()
	for entry: Dictionary in entries: by_id[str(entry.instance_id)] = entry
	_check(int(by_id.get("selected",{}).get("quantity",0)) == 3 and int(by_id.get("stack:1:bless:2",{}).get("quantity",0)) == 4,"physical and virtual quantities remain separate within their exact blessed inventory key")
	world.item_instances.selected["blessed"] = false
	_check(service._info(world,"selected",world.item_instances.selected).is_empty(),"physical native stack identity conflict cannot become a processing material")
	world.item_instances.selected.erase("blessed")
	var catalog: Dictionary = service._output_catalog(world)
	_check(service._output_record(world,1,catalog,1) == normal and service._output_record(world,1,catalog,2) == blessed,"output lookup selects exact registered normal/blessed records by the result's source blessing")
	world.catalog_db["아이템"].erase(blessed)
	catalog = service._output_catalog(world)
	var pending: Dictionary = service._output_record(world,1,catalog,2)
	_check(pending.get("source_original_item") == true and not pending.get("source_m_native_item",false) and pending.sourceId == "m523:item:1","absent blessed native output stays pending instead of reconstructing a native name or suffix")
	world.catalog_db["아이템"].append({"name":"legacy","sourceId":"legacy:3","slot":"consumable"})
	_check(service._source(world.catalog_db["아이템"].back()) == 3 and service._output_record(world,3,{},2).name == "legacy","existing exact legacy binding and its output blessing behavior are preserved")
	var alias: Dictionary = service.fixtures["m523:item:1|1"].duplicate(true)
	alias.expected.name = "Kernel approved alias"
	alias.expected.sourceId = "kernel:alias:1"
	alias.expected.source_legacy_catalog_alias = true
	service.fixtures["kernel:alias:1|1"] = alias
	world.catalog_db["아이템"].append(alias.expected)
	world.inventory[alias.expected.name] = 8
	entries = service._entries(world)
	var ambiguous_normal: bool = false
	for entry: Dictionary in entries:
		if entry.get("virtual_stack",false) and int(entry.source_id) == 1 and int(entry.bless_code) == 1: ambiguous_normal = true
	_check(not ambiguous_normal,"two legal catalog keys for one source variant are blocked rather than merging inventory names")
	world.inventory.erase(str(alias.expected.name))
	entries = service._entries(world)
	ambiguous_normal = false
	for entry: Dictionary in entries:
		if entry.get("virtual_stack",false) and int(entry.source_id) == 1 and int(entry.bless_code) == 1: ambiguous_normal = true
	_check(not ambiguous_normal,"an unowned registered alias retains the existing source-variant ambiguity guard")
	world.free()

func _test_unavailable_owner() -> void:
	var service = Service.new()
	service.store.pack = _pack()
	var record: Dictionary = _fixture(service.store.pack,1,1).expected
	# An unverified synthetic native marker must not be rescued by an otherwise
	# matching legacy binding, even if a real owner/cache happens to be present.
	service.store.pack.bindings[record.sourceId] = {"name":record.name,"source_id":1}
	_check(service._source(record) == 0,"an unavailable or unverified native identity cannot use a legacy/name fallback")
	var path: String = OS.get_environment("EQUIPMENT523_RULES_FILE")
	if path.is_empty(): return
	_check(FileAccess.file_exists(path) and FileAccess.get_sha256(path) == "e2a51dce910799ee31c7943b84a6b44d3c84dfb964b25fe8962f39522cafd700","optional original-cache negative uses the existing exact byte-verified processing rules")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != "e2a51dce910799ee31c7943b84a6b44d3c84dfb964b25fe8962f39522cafd700": return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return
	service.store.pack = parsed
	var item: Dictionary = service.store.pack.items.get("223762",{})
	var partial: Dictionary = {"name":str(item.get("name","")),"sourceId":"m523:item:223762","source_item_class_id":223762,"source_m_native_item":true,"source_snapshot":"patch523","source":"lineagem_patch523","source_bless_raw":1}
	_check(service._source(partial) == 0,"an actual source item row alone cannot invent the missing verified native supplier record")
	original_cache_negative_checked = true

func _test_original_owner_api() -> void:
	var requested: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-drop-root="): requested = true
	if not requested: return
	var path: String = OS.get_environment("EQUIPMENT523_RULES_FILE")
	_check(not path.is_empty() and FileAccess.file_exists(path),"original native API test requires the existing verified processing cache")
	if path.is_empty() or not FileAccess.file_exists(path): return
	_check(FileAccess.get_sha256(path) == "e2a51dce910799ee31c7943b84a6b44d3c84dfb964b25fe8962f39522cafd700","original native API joins the exact immutable processing rules bytes")
	if FileAccess.get_sha256(path) != "e2a51dce910799ee31c7943b84a6b44d3c84dfb964b25fe8962f39522cafd700": return
	if not ResourceLoader.exists(Native.OWNER_PATH):
		_check(false,"the published native owner must exist for its optional positive API test")
		return
	var owner: Variant = load(Native.OWNER_PATH)
	var identity: Dictionary = owner.pack_identity()
	_check(identity.get("sha256") == "38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27","the existing public loader verifies the regenerated original native cache pin")
	if identity.get("sha256") != "38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27": return
	var service = Service.new()
	service.store.pack = JSON.parse_string(FileAccess.get_file_as_string(path))
	var world := World.new()
	owner.register_catalog(owner.data(),world.catalog_db)
	var registered: Dictionary = {}
	for record: Dictionary in world.catalog_db["아이템"]: registered[str(record.get("sourceId",""))] = record
	var records: Array = []
	for spec: Array in [[223762,1,3],[223762,2,7],[289162,1,5],[372058,2,2]]:
		var definition: Dictionary = owner.definition_id(str(spec[0]))
		var expected: Dictionary = owner.variant_item(definition.get("native_record",{}),int(spec[1]))
		var record: Dictionary = registered.get(str(expected.get("sourceId","")),{})
		_check(not record.is_empty() and owner.matches(record,expected),"the actual public catalog registered the exact original source variant "+str(spec[0])+":"+str(spec[1]))
		if record.is_empty(): continue
		var actual: Dictionary = service._native_identity(record)
		_check(int(actual.get("source_id",0)) == int(spec[0]) and int(actual.get("bless_code",0)) == int(spec[1]),"public item_definition and processing ItemClass fields join without native reconstruction "+str(spec[0])+":"+str(spec[1]))
		records.append(record)
		world.inventory[str(record.name)] = int(spec[2])
	# Focus the already registered records. Quantities are an explicit test
	# ownership fixture, not an NPC drop, craft execution or new reward grant.
	world.catalog_db["아이템"] = records
	var entries: Array = service._entries(world)
	_check(entries.size() == 4,"real catalog variants remain four separate processing stack selections")
	var by_id: Dictionary = {}
	for entry: Dictionary in entries: by_id[str(entry.instance_id)] = entry
	_check(int(by_id.get("stack:223762",{}).get("quantity",0)) == 3 and int(by_id.get("stack:223762:bless:2",{}).get("quantity",0)) == 7,"real normal and blessed scroll names keep independent quantities")
	_check(int(by_id.get("stack:372058:bless:2",{}).get("bless_code",0)) == 2,"real blessed core raw code is never flattened to normal")
	if by_id.has("stack:372058:bless:2"):
		var selected: Dictionary = by_id["stack:372058:bless:2"]
		world.item_instances["real-api-fixture"] = {"name":selected.name,"record":selected.record.duplicate(true),"source_reward_quantity":1}
		_check(int(service._info(world,"real-api-fixture",world.item_instances["real-api-fixture"]).get("bless_code",0)) == 2,"real registered native physical core keeps the same exact blessing identity")
	original_native_api_checked = true
	world.free()
