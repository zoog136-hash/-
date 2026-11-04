extends SceneTree
const Runtime=preload("res://scripts/combinations/runtime.gd")
const Writer=preload("res://scripts/skills/save_writer.gd")
class Draw extends RefCounted:
	var owned: Dictionary={}
class Context extends RefCounted:
	var profile: Dictionary={}
	func source_server_context() -> Dictionary:return profile
	func set_source_server_context(value: Dictionary) -> bool:profile=value;return true
class Host extends Node:
	var catalog_db: Dictionary={"아이템":[]}
	var card_draw_fusion=Draw.new()
	var card_collections=Context.new()
	var inventory: Dictionary={}
	var item_instances: Dictionary={}
	var gold: int=10000
	var equipment_records_dirty: bool=true
	var equipment_effects_dirty: bool=true
	var save_error: Error=OK
	var reentrant: Callable
	var reentrant_result: Dictionary={}
	func _save_game(_quiet: bool,override: Dictionary) -> Error:
		if reentrant.is_valid():reentrant_result=reentrant.call()
		if save_error!=OK:return save_error
		var payload: Dictionary={"inventory":inventory,"item_instances":item_instances,"card_draw_fusion":{"owned":card_draw_fusion.owned},"quest_state":{"preserved":true},"gold":gold}
		payload.merge(override,true);return Writer.write("user://combination-contract.json",payload)
var checks: int=0
var errors: Array[String]=[]
var req_checks: int=0
var effect_checks: int=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
static func fixture(host: Node,combo: Dictionary,override_req: Dictionary={}) -> void:
	host.inventory={};host.item_instances={};host.card_draw_fusion.owned={"변신":{},"마법인형":{}}
	for slot: Dictionary in combo.slots:
		var req: Dictionary=slot.candidates[0]
		if not override_req.is_empty() and int(override_req.source.RequirementIndex)==int(slot.index):req=override_req
		if int(req.kind) in [14,4]:
			var deck: int=1 if int(req.kind)==14 else 2;var category: String="변신" if deck==1 else "마법인형"
			host.card_draw_fusion.owned[category]["source:m508:"+str(deck)+":"+str(int(req.class_id))]=true
		else:
			var name_value: String="native-"+str(int(req.class_id));host.inventory[name_value]=int(host.inventory.get(name_value,0))+1
			host.item_instances[str(int(slot.index))]={"name":name_value,"level":int(req.min_enchant),"record":{"name":name_value,"source":"lineagem_patch523","sourceId":"m508:item:"+str(int(req.class_id)),"source_item_class_id":int(req.class_id)}}
func choose_context(runtime: RefCounted,combo: Dictionary) -> void:
	var host: Node=runtime.world
	host.card_collections.set_source_server_context({})
	if runtime.evaluate(int(combo.id)).ok:return
	for row: Dictionary in runtime.catalog.server_limits:
		host.card_collections.set_source_server_context({"source_snapshot":"base508","ServiceRegionCode":row.ServiceRegionCode,"WorldNo":row.WorldNo})
		if runtime.evaluate(int(combo.id)).ok:return
func run() -> void:
	var path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--catalog="):path=arg.trim_prefix("--catalog=")
	if path.is_empty():quit(2);return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var host:=Host.new();root.add_child(host);var runtime=Runtime.new();runtime.world=host
	var accepted: bool=runtime.accept_catalog(data)
	check(accepted,"full private catalog accepted")
	if not accepted:host.free();quit(1);return
	for combo: Dictionary in data.combinations:
		fixture(host,combo);choose_context(runtime,combo)
		check(runtime.evaluate(int(combo.id)).ok,"all slots eligible "+str(combo.id))
		for slot: Dictionary in combo.slots:
			for req: Dictionary in slot.candidates:
				fixture(host,combo,req);runtime.invalidate()
				check(runtime.evaluate(int(combo.id)).ok,"exact source requirement alternative "+str(req.source.ID));req_checks+=1
				if int(req.kind)==24:
					var iid: String=str(int(slot.index));host.item_instances[iid].level=int(req.min_enchant)+1
					check(runtime.evaluate(int(combo.id)).ok,"higher enchant accepted "+str(req.source.ID))
					host.item_instances[iid].level=int(req.min_enchant)-1
					check(not runtime.evaluate(int(combo.id)).ok,"below minimum rejected "+str(req.source.ID))
				else:
					var category: String="변신" if int(req.kind)==14 else "마법인형";host.card_draw_fusion.owned[category].clear()
					check(not runtime.evaluate(int(combo.id)).ok,"rental/equipped looks never replace permanent ownership "+str(req.source.ID))
		fixture(host,combo);runtime.invalidate()
		var before: int=hash([host.inventory,host.item_instances,host.card_draw_fusion.owned,host.gold])
		var result: Dictionary=runtime.request_selection(int(combo.id),int(runtime.progress.revision),"full-"+str(int(combo.id)))
		check(result.ok and hash([host.inventory,host.item_instances,host.card_draw_fusion.owned,host.gold])==before,"one selected combo without material debit "+str(combo.id))
		for effect: Dictionary in combo.effects:
			var expected: float=0
			for row: Dictionary in combo.effects:
				if row.type==effect.type and int(row.target)==int(effect.target):expected+=float(row.value)
			check(is_equal_approx(runtime.amount(effect.type,int(effect.target)),expected),"typed active effect "+str(effect.source_link.ID));effect_checks+=1
		var last: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://combination-contract.json"))
		check(last.quest_state.preserved and int(last.combination523.selected_id)==int(combo.id),"single save preserves unrelated data "+str(combo.id))
	# Failure and replay paths operate against the real atomic save writer.
	var combo: Dictionary=data.combinations[0];fixture(host,combo);choose_context(runtime,combo);runtime.invalidate()
	var before: int=hash([host.inventory,host.item_instances,host.gold,runtime.progress]);var disk: String=FileAccess.get_sha256("user://combination-contract.json")
	host.save_error=ERR_FILE_CANT_WRITE
	check(runtime.request_selection(int(combo.id),int(runtime.progress.revision),"fail").code=="save_failed","save failure reported")
	check(hash([host.inventory,host.item_instances,host.gold,runtime.progress])==before and FileAccess.get_sha256("user://combination-contract.json")==disk,"failure preserves live and disk bytes")
	host.save_error=OK;runtime.policy.selection_fee_adena=10001
	check(runtime.request_selection(int(combo.id),int(runtime.progress.revision),"short").code=="insufficient_gold","configured local fee cannot overdraft")
	runtime.policy.selection_fee_adena=3
	host.reentrant=func()->Dictionary:return runtime.request_selection(int(combo.id),int(runtime.progress.revision),"reentrant")
	var success: Dictionary=runtime.request_selection(int(combo.id),int(runtime.progress.revision),"success")
	check(success.ok and host.gold==9997 and host.reentrant_result.code=="busy","atomic exact fee with reentrant click guard")
	host.reentrant=Callable();before=hash([host.inventory,host.item_instances,host.gold,runtime.progress])
	check(runtime.request_selection(int(combo.id),int(runtime.progress.revision),"success").code=="duplicate_operation" and hash([host.inventory,host.item_instances,host.gold,runtime.progress])==before,"duplicate request unchanged")
	var loaded: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://combination-contract.json"));var restored=Runtime.new();restored.world=host;restored.accept_catalog(data)
	check(restored.accept_load(loaded) and restored.export_state()==runtime.export_state(),"JSON state survives new runtime instance")
	host.item_instances.clear();restored.invalidate();check(restored.stat_record().is_empty() and int(restored.progress.selected_id)==int(combo.id),"condition loss suspends without erasing selection")
	fixture(host,combo);restored.invalidate();check(not restored.stat_record().is_empty(),"restored conditions resume only the saved selection")
	var damaged: Dictionary=runtime.export_state();damaged.selected_id="64"
	check(not restored.accept_load({Runtime.SAVE_KEY:damaged}) and restored.save_blocked,"corrupt state blocked without coercion")
	check(req_checks==272 and effect_checks==91,"full source coverage rather than samples")
	host.queue_free();await process_frame
	print("COMBINATION_FULL_CONTRACT ",JSON.stringify({"checks":checks,"requirements":req_checks,"effects":effect_checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
