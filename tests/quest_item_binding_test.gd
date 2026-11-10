extends SceneTree
const BINDINGS = preload("res://scripts/quests/quest_item_bindings.gd")
const SOURCE = preload("res://scripts/quests/source_quest523.gd")
const SYMBOL = preload("res://scripts/growth/symbol_source523.gd")
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message);printerr("QUEST_BINDING_FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--quest-pack="): check(SOURCE.install_zip(arg.trim_prefix("--quest-pack=")).ok,"unchanged received v1 installs")
	var source := SOURCE.new()
	check(source.load_pack() and source.quests.size()==3621,"full original quest input")
	var symbol := SYMBOL.new()
	var reward: Dictionary = {}
	for row: Dictionary in source.quests:
		for item: Dictionary in source.full(row).source_rewards:
			if item.type_name=="Item" and int(item.RewardClassID)==117304 and int(item.ItemBlessCodeID)==1 and not item.UseImmediately: reward=item
	check(not reward.is_empty(),"real quest has original symbol holy-water reward")
	if reward.is_empty(): quit(1);return
	var record: Dictionary = symbol.item_record(117304)
	var consumer: Callable = Callable(symbol,"material")
	var indexed: Dictionary = BINDINGS.index([[record],[record.duplicate(true)]])
	check(indexed["117304"].size()==1,"identical duplicated catalog rows retain one identity")
	var bound: Dictionary = BINDINGS.resolve(reward,indexed,consumer)
	check(bound.record==record and bound.reason.is_empty(),"real existing symbol consumer accepts exact current original row")
	check(symbol.recharge({"name":bound.record.name,"record":bound.record}).amount>0,"bound record reaches the production recharge definition")
	check(BINDINGS.resolve(reward,indexed,Callable()).record.is_empty(),"catalog presence without a live consumer stays held")
	var changed: Dictionary = record.duplicate(true)
	changed.source_original_item.Name = "same ID with altered original row"
	check(BINDINGS.resolve(reward,BINDINGS.index([[changed]]),consumer).record.is_empty(),"same source ID cannot replace differing original rows")
	changed=record.duplicate(true)
	changed.desc="conflicting catalog definition"
	check(BINDINGS.resolve(reward,BINDINGS.index([[record,changed]]),consumer).record.is_empty(),"conflicting candidates cannot use last-row-wins")
	changed=record.duplicate(true)
	changed.source_automation_catalog_only=true
	check(BINDINGS.resolve(reward,BINDINGS.index([[changed]]),consumer).record.is_empty(),"storage-only supplier catalog is not an item-use consumer")
	changed=record.duplicate(true)
	changed.sourceId="m508:item:117304"
	check(BINDINGS.index([[changed]]).is_empty(),"another source identity is not promoted")
	changed=record.duplicate(true);changed.source_item_class_id=117304.5
	check(BINDINGS.index([[changed]]).is_empty(),"fractional source ID is rejected rather than truncated")
	changed=record.duplicate(true);changed.source_bless_raw=2
	check(BINDINGS.resolve(reward,BINDINGS.index([[changed]]),consumer).record.is_empty(),"consumer bless metadata cannot override the original quest state")
	for code: int in [0,2,3]:
		var variant: Dictionary=reward.duplicate(true);variant.ItemBlessCodeID=code
		check(BINDINGS.resolve(variant,indexed,consumer).record.is_empty(),"original bless state retained without an exact consumer: "+str(code))
	var immediate: Dictionary=reward.duplicate(true);immediate.UseImmediately=true
	check(BINDINGS.resolve(immediate,indexed,consumer).record.is_empty(),"immediate-use reward cannot become an ordinary usable item")
	var packed: RefCounted = BINDINGS.lookup([[record],[record.duplicate(true)]])
	check(packed.candidates("117304")==indexed["117304"] and BINDINGS.resolve(reward,packed,consumer)==bound,"packed lookup returns the index candidates and binding")
	check(BINDINGS.resolve(reward,BINDINGS.lookup([[record,changed]]),consumer).record.is_empty() and packed.candidates("1").is_empty(),"packed lookup keeps the index admission rules")
	check(record==symbol.item_record(117304),"binding leaves producer definitions unchanged")
	print("QUEST_BINDING_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"real_source_item_id":117304,"consumer":"symbol_source523.material/recharge","external_pr_consumers_installed":false}))
	quit(0 if failures.is_empty() else 1)
