extends RefCounted

const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const IDS = [
	145073,158511,170094,170174,175852,175862,181884,188874,190784,196991,205111,206991,
	211371,214731,214881,219021,223391,223521,228102,231872,232002,238541,241001,249712,
	252732,255853,260398,262558,267932,270172,276768,279333,282303,285632,288482,290032,
	300811,301601,301661,305751,307441,307451,316121,319511,319521,324863,326603,326613,
	334582,335962,335982,340624,343964,351264,352564,356844,358242,360342,368342,369642,
]

class ClockWorld extends Node:
	var level := 1
	var active_item_buffs := {}
	var ui_preferences := {}

static func clock_cases(check: Callable) -> void:
	var world := ClockWorld.new()
	var spec := {"buff_delete_time_raw":202001290500}
	var previous := D.rotate_ended_dates
	D.rotate_ended_dates = false
	check.call(not STACK.buff_rule_problem(world,spec).is_empty(),"a past buff deadline alone refuses a fresh dose in strict mode")
	check.call(D.source_deadline_unix(202001290500,540) == Time.get_unix_time_from_datetime_string("2020-01-28T20:00:00"),"source event clock is Korean local time")
	D.rotate_ended_dates = true
	var runtime := {"remaining":300.0}
	STACK.buff_runtime_fields(world,spec,runtime)
	check.call(STACK.buff_rule_problem(world,spec).is_empty() and not runtime.has("source_buff_delete_at") and runtime.remaining == 300,"the offline rotation gives a historical dose its original duration")
	spec.buff_delete_time_raw = 209901290500
	STACK.buff_runtime_fields(world,spec,runtime)
	check.call(runtime.get("source_buff_delete_at") == D.source_deadline_unix(209901290500,540),"a future event cutoff is saved independently of the potion duration")
	D.rotate_ended_dates = previous
	world.free()

static func from_bag(w: Node, check: Callable) -> void:
	var pending := []
	var specs := {}
	for id: int in IDS:
		var record := D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)
		var spec: Dictionary = FIELDS.field(record,"source_use_spec",{})
		if not check.call(spec.get("activation_status") == "unrestricted" and spec.get("buff_delete_time_raw",0) > 0 and spec.get("typed_effects",{}).get("xp",0) > 0,"original buff deadline and XP #"+str(id)): continue
		specs[id] = spec
		w.catalog_db["아이템"].append(record)
		pending.append({"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0})
	w._index_catalog_item_sources()
	if not check.call(pending.size() == IDS.size() and INV.commit(w,pending,{"kind":"qa_dated_growth"}),"all 60 verified receipts supplied"): return
	var inputs := {}
	for uid: String in w.item_instances:
		var receipt: Dictionary = w.item_instances[uid].get(STACK.RECEIPT,{})
		if int(receipt.get("item_class_id",0)) in IDS: inputs[int(receipt.item_class_id)] = uid
	if not check.call(inputs.size() == IDS.size(),"one physical receipt per dated growth item"): return
	for id: int in IDS:
		var uid: String = inputs[id]
		var ref := str(w.item_instances[uid].name) + "@@@" + uid
		w.hud.inventory_item_activated.emit(ref)
		var spec: Dictionary = specs[id]
		check.call(not w.item_instances.has(uid) and w._active_item_buff_total("xp") == int(spec.typed_effects.xp),"bag use debits only the selected dose and awards original XP #"+str(id)+": "+str(w.hud.message_label.text))
		if id == 158511:
			w._load_game(true)
			check.call(not w.item_instances.has(uid) and w._active_item_buff_total("xp") == 500,"reloaded #158511 keeps its debit and +500%")
			var stored_level: int = w.level
			w.level = int(spec.erase_at_level)
			w._tick_item_buffs(0.0)
			check.call(w._active_item_buff_total("xp") == 0,"source maximum level ends the buff")
			w.level = stored_level
		if id == 170094 and not w.active_item_buffs.is_empty():
			var entry: Dictionary = w.active_item_buffs.values()[0]
			entry.source_buff_delete_at = int(Time.get_unix_time_from_system()) - 1
			if check.call(w._save_game(true) == OK,"durable cutoff fixture"):
				w._load_game(true)
				check.call(w._active_item_buff_total("xp") == 0,"expired calendar buff is gone before first restored stats")
		for buff: Dictionary in w.active_item_buffs.values():
			if buff.has("absolute_until"): buff.absolute_until = 0
		w._tick_item_buffs(10000000.0)
