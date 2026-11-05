extends SceneTree
## Actual published PR239 parser/ownership API; a contract test, not gameplay completion.
const Source=preload("res://scripts/expedition/source_catalog.gd")
const Bridge=preload("res://scripts/expedition/reward_bridge.gd")
const Cards=preload("res://scripts/expedition/reward_cards.gd")
class RegisteredHost extends Node:
	var records:Dictionary={}
	func _find_catalog_item_record(name:String)->Dictionary:return records.get(name,{})
var checks:int=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:
	var source=Source.new();var source_path:String="";var source_sha:String="";var equipment_path:String=""
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--expedition523-pack="):source_path=arg.trim_prefix("--expedition523-pack=")
		if arg.begins_with("--expedition523-sha256="):source_sha=arg.trim_prefix("--expedition523-sha256=")
		if arg.begins_with("--equipment523-reference="):equipment_path=arg.trim_prefix("--equipment523-reference=")
	if not ResourceLoader.exists("res://scripts/crafting/patch523_rules.gd") or equipment_path.is_empty():
		print("EXPEDITION523_RECIPIENT_CONTRACT_RESULT ",JSON.stringify({"checks":0,"failures":[],"skipped":"requires separately installed real PR239 code and existing v8 private input"}));quit();return
	check(source.install(source_path,source_sha),"unchanged source pack")
	var rules:RefCounted=load("res://scripts/crafting/patch523_rules.gd").new()
	check(rules.load_file(equipment_path,"b6b2589c15853b1998ecfc6484438a1fe0ef8e8e125d7d1d558e49c116f879ce"),"actual existing v8 parser and exact SHA")
	if not source.ready() or rules.data.is_empty():finish();return
	var completed:Dictionary={}
	for row:Dictionary in source.rows("MagicDollExpeditionCompleteRewardView"):completed[int(source.record("Reward",int(row.RewardID)).RewardClassID)]=true
	var host:=RegisteredHost.new();var found:int=0
	for item:Dictionary in source.rows("ItemClass"):
		var id:int=int(item.ID)
		if completed.has(id) or id in [75184,75194,95624,118992] or not Cards.fixed_target(source,id).is_empty():continue
		var entry:Dictionary=rules.data.items.get(str(id),{})
		if entry.is_empty():continue
		found+=1
		var record:Dictionary=rules.record(str(id))
		check(entry.item_class==item,"exact latest original item "+str(id))
		check(Bridge.recipient(host,record,item,{"patch523_equipment":rules})=="PR239 제작·가공","real recipient identity "+str(id))
		if not Bridge.protected_reason(item).is_empty():continue
		var material:Dictionary={"source_id":str(id),"item":str(record.name),"quantity":1,"physical":false,"level":0,"bless_code":1}
		if entry.has("currency_inventory_key"):material.inventory_key=entry.currency_inventory_key
		var key:String=rules.ownership_key(material)
		check(rules.available_material(material,{key:3},{record.name:record},{},{},{},false,0)==3,"actual recipient accepts its exact canonical key "+str(id))
		check(rules.available_material(material,{str(item.Name)+" (탐험 %d:1:0)"%id:3},{record.name:record},{},{},{},false,0)==0,"typed key cannot be silently treated as canonical "+str(id))
	check(found==83,"all105 items compared;83 definitions in current v8")
	var raw:Dictionary=source.record("ItemClass",3652).duplicate(true);raw.Cost+=1
	check(Bridge.recipient(host,rules.record("3652"),raw,{"patch523_equipment":rules}).is_empty(),"changed original definition cannot authorize handoff")
	var actual:Dictionary=source.record("ItemClass",3652)
	var record:Dictionary=rules.record("3652");host.records[record.name]=record
	check(Bridge.registered_material_target(host,actual,1,0,{"patch523_equipment":rules}).get("ok",false),"registered actual PR239 material works without PR238 effect engine")
	check(Bridge.registered_material_target(host,actual,2,0,{"patch523_equipment":rules}).is_empty(),"blessed source material cannot become normal stack")
	check(Bridge.registered_material_target(host,raw,1,0,{"patch523_equipment":rules}).is_empty(),"wrong original row cannot authorize registered material")
	host.records[record.name].source_is_storable=not bool(actual.IsStorable)
	check(Bridge.registered_material_target(host,actual,1,0,{"patch523_equipment":rules}).is_empty(),"source transfer restrictions cannot be weakened by registered metadata")
	host.free();finish()
func finish()->void:
	print("EXPEDITION523_RECIPIENT_CONTRACT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"contract_only_not_gameplay":true}))
	quit(0 if failures.is_empty() else 1)
