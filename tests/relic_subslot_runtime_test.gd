extends SceneTree
const Runtime=preload("res://scripts/cards/option_awakening_runtime.gd")
const Slot=preload("res://scripts/cards/native_relic_subslot.gd")
const Unlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
const Registry=preload("res://scripts/lineagem_base508.gd")
const Fixture=preload("res://tests/native_option_awakening_test.gd")
class Host extends Fixture.Host:
	var level: int=1
	var active_skill_buffs: Dictionary={}
	var inventory: Dictionary={}
	var item_instances: Dictionary={}
	var locks: Dictionary={}
	var saved: Dictionary={}
	func _item_locked(name_value: String,id: String="") -> bool:return bool(locks.get(name_value+("@@@"+id if not id.is_empty() else ""),false))
	func _save_game(_quiet: bool,override: Dictionary={}) -> Error:
		if save_error==OK:saved=override.duplicate(true)
		return save_error
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var host=Host.new();root.add_child(host);host.catalog_db=Registry.apply_catalog({});host.card_draw_fusion.configure(host.catalog_db)
	var service=Runtime.new();check(service.configure(host),"runtime configures")
	var chosen: String="source:m508:98:20548";host.card_draw_fusion.owned["성물"][chosen]=true
	check(service.select_relic_subslot(chosen).code=="relic_subslot_locked","locked slot rejects selection")
	var record: Dictionary=Unlock.record();host.inventory={record.name:1};host.item_instances={"unlock":{"name":record.name,"record":record}}
	host.locks={record.name:true}
	check(not service.use_relic_unlock_item(record.name).ok and host.inventory[record.name]==1,"name lock preserves item")
	host.locks={record.name+"@@@unlock":true}
	check(not service.use_relic_unlock_item(record.name).ok and host.item_instances.has("unlock"),"physical lock preserves item")
	host.locks={};host.save_error=ERR_FILE_CANT_WRITE
	var before: int=hash([service.export_state(),host.inventory,host.item_instances,host.gold])
	check(service.use_relic_unlock_item(record.name).code=="save_failed" and hash([service.export_state(),host.inventory,host.item_instances,host.gold])==before,"failed unlock saves no item or flag mutation")
	host.save_error=OK
	check(service.use_relic_unlock_item(record.name).ok and host.inventory.is_empty() and host.item_instances.is_empty() and Unlock.unlocked(service.progress),"exact one item atomically unlocks at explicit source use conditions")
	check(host.saved.card_option_awakening[Unlock.FIELD]==Unlock.marker(),"unlock marker and debit share save")
	check(not service.use_relic_unlock_item(record.name).ok,"duplicate unlock cannot consume again")
	host.save_error=ERR_FILE_CANT_WRITE;before=hash(service.progress)
	check(service.select_relic_subslot(chosen).code=="save_failed" and hash(service.progress)==before,"failed slot save preserves choice")
	host.save_error=OK
	check(service.select_relic_subslot(chosen).ok and service.relic_subslot_view().active,"owned unlocked additional relic works with empty main")
	var records: Array=service.bonus_records().filter(func(row: Dictionary) -> bool:return row.origin=="relic_subslot11:"+chosen)
	check(records.size()==1 and records[0].meleeHit==1 and is_equal_approx(float(records[0].hpPct),0.01),"actual bonus records receive one-percent secondary HP in consumer fraction units")
	check(service.bonus_records()==service.bonus_records(),"repeated refresh does not stack")
	var saved: Dictionary=service.export_state();check(service.accept_load({Runtime.SAVE_KEY:saved,"card_draw_fusion":host.card_draw_fusion.export_state()}) and service.relic_subslot_view().active,"existing writer load restores unlock and selected slot")
	check(service.select_relic_subslot("").ok and not service.relic_subslot_view().active and service.bonus_records().all(func(row: Dictionary) -> bool:return not str(row.origin).begins_with("relic_subslot11:")),"release persists and removes secondary effects")
	var bad: Dictionary=service.export_state();bad[Unlock.FIELD].source_item_class_id=346901
	check(not service.check_load({Runtime.SAVE_KEY:bad,"card_draw_fusion":host.card_draw_fusion.export_state()}).is_empty(),"doll marker cannot unlock relic")
	host.queue_free();await process_frame
	print("RELIC_SUBSLOT_RUNTIME ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
