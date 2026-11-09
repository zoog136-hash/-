extends SceneTree
const SERVICE = preload("res://scripts/quests/quest_service.gd")
const SOURCE = preload("res://scripts/quests/source_quest523.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("QUEST523_FAIL: "+label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--quest-pack="):
			check(SOURCE.install_zip(argument.trim_prefix("--quest-pack=")).ok,"real ZIP passes bounded install and atomic write")
			check(FileAccess.get_sha256(SOURCE.USER_PATH)==SOURCE.PAYLOAD_SHA,"installed bytes match the complete private source projection")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	var service := SERVICE.new()
	check(service.configure(data.get("아이템",[]),data.get("몬스터",[])),"production service configures")
	check(service.source.quests.size()==3621,"complete private source is installed; never substitute a fixture")
	var independent := SERVICE.new()
	check(independent.configure([],[]) and independent.source.quests.size()==3621,"native source loading never depends on retired sample monster/item names")
	if service.source.quests.size()!=3621: quit(1);return
	for native: Dictionary in service.source.quests:
		if int(service.source.full(native).definition.TypeID)==3: check(native.category=="common","original Common type is displayed as general quests")
	var at: int = int(Time.get_unix_time_from_system())
	var context: Dictionary = {"level":100,"max_level":100,"class_id":1,"source_items":{}}
	var all_claimed: Dictionary = {}
	for row: Dictionary in service.source.quests: all_claimed[str(row.id)]=true
	var plans: int = 0
	var held_items: int = 0
	var gate_reasons: Dictionary = {}
	var reward_reasons: Dictionary = {}
	var level_goals: int = 0
	var open_level_goals: int = 0
	for row: Dictionary in service.source.quests:
		var complete: Dictionary = service.source.full(row)
		check(row.id=="m523:quest:"+str(int(complete.definition.ID)),"native quest identity")
		check(row.blockers.is_empty(),"all original goal/reward/prerequisite links resolve")
		var reason: String = service.source.gate(row,context,all_claimed,at)
		gate_reasons[reason] = int(gate_reasons.get(reason,0))+1
		check(service.source.gate(complete,context,all_claimed,at)==reason and service.source.gate(complete,{"level":1,"class_id":-1},{},at)==service.source.gate(row,{"level":1,"class_id":-1},{},at),"resident compact row gates exactly like the complete row")
		for goal: Dictionary in complete.goals:
			if goal.type_name != "Level": continue
			level_goals += 1
			if not reason.is_empty(): continue # Period/exclusion/other source guards remain authoritative.
			open_level_goals += 1
			var below: Dictionary = context.duplicate();below.level=int(goal.Amount)-1;below.max_level=int(goal.Amount)-1
			check(not service.source.gate(row,below,all_claimed,at).is_empty(),"every currently open original level goal rejects an under-level character")
		var plan: Dictionary = service.source.reward_plan(row,context)
		if plan.ok:
			plans += 1
			if not plan.pending_use.is_empty(): held_items += 1
			for item: Dictionary in plan.items:
				check(str(item.record.sourceId)=="m523:item:"+str(int(item.record.source_item_class_id)),"all item rewards retain native identity")
		else:
			var issue: String = str(plan.error)
			reward_reasons[issue]=int(reward_reasons.get(issue,0))+1
	var first: Dictionary = service.index["m523:quest:236"]
	var level96: Dictionary = service.index["m523:quest:96201"]
	check(service.source.gate(level96,{"level":86,"class_id":1},all_claimed,at)=="레벨 96부터 이용","original level goal is preserved despite automatic objective completion")
	check(service.source.gate(level96,{"level":95,"class_id":1},all_claimed,at)=="레벨 96부터 이용","level95 cannot receive the original level96 reward")
	check(service.source.gate(level96,{"level":96,"class_id":1},all_claimed,at).is_empty(),"level96 can acquire the original reward after prerequisites")
	check(not service.source.gate(level96,{"level":96,"class_id":1},{},at).is_empty(),"meeting a level goal never waives source prerequisites")
	check(service.source.gate(first,{"level":1,"class_id":1},{},at).is_empty(),"original starting quest acquired without goal or NPC")
	var child: Dictionary = service.index["m523:quest:237"]
	check(not service.source.gate(child,{"level":1,"class_id":1},{},at).is_empty(),"source prerequisite enforced")
	check(service.source.gate(child,{"level":1,"class_id":1},{"m523:quest:236":true},at).is_empty(),"completed original prerequisite unlocks next quest")
	check(service.import_state({"schema_version":1,"claimed":{"twilight:main:001":true,"m523:quest:236":true,"m523:quest:999999":true},"progress":{"twilight:main:002":2},"day_key":SERVICE.korean_daily_key(at)+3},at),"old save migrates")
	var saved: Dictionary = service.export_state()
	check(saved.claimed.has("twilight:main:001") and saved.claimed.has("m523:quest:236") and saved.claimed.has("m523:quest:999999"),"legacy, current and unavailable source claims preserved")
	check(saved.day_key==SERVICE.korean_daily_key(at)+3,"future high-water day is not clamped backwards")
	check(not service.import_state({"schema_version":2,"claimed":{"m523:quest:236":1}}),"numeric completion corruption rejected")
	check(service.save_blocked and service.claimed.has("m523:quest:236"),"rejected import protects previous live claims")
	check(service.import_state(saved,at) and not service.save_blocked,"valid reload releases save protection")
	check(service.import_state({"schema_version":1,"claimed":{"twilight:daily:001":true},"day_key":SERVICE.korean_daily_key(at)-5},at) and service.claimed.has("twilight:daily:001"),"retired historical daily completion survives five missed resets")
	check(not SERVICE.validate_saved_state({"schema_version":99}).is_empty(),"future schema cannot be silently reset")
	check(not SERVICE.validate_saved_state({"progress":{"bad":-1}}).is_empty(),"negative progress rejected")
	check(not SOURCE.install_zip("res://project.godot").ok,"non-ZIP cannot replace installed data")
	var stats: Dictionary = {"checks":checks,"failures":failures,"source_quests":3621,"reward_storage_supported":plans,"quests_with_items_held_for_use_link":held_items,"gate_reasons_with_all_predecessors":gate_reasons,"unsupported_reward_reasons":reward_reasons}
	stats["original_level_goals"]={"total":level_goals,"currently_open_underlevel_checks":open_level_goals,"blocked_by_other_original_conditions":level_goals-open_level_goals}
	print("QUEST523_RESULT "+JSON.stringify(stats))
	var output := FileAccess.open("user://quest523-coverage.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(stats,"\t"))
	quit(0 if failures.is_empty() else 1)
