extends SceneTree
## Host and clock below are explicitly test fixtures, not original dungeon art,
## instance admission, server time-zone interpretation or combat fidelity proof.
const RULES = preload("res://scripts/dungeons/source_dungeon_runtime.gd")
const RUNS = preload("res://scripts/dungeons/dungeon_run_service.gd")
const ECONOMY = preload("res://scripts/dungeons/dungeon_economy.gd")
const AIN = preload("res://scripts/ainhasad_service.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
var failures: Array[String] = []
var checks: int = 0

class ContractHost extends Node:
	var rules: RefCounted
	var level := 80
	var active_map_id := "fixture-source-instance"
	var gold := 1000
	var experience := 0
	var inventory: Dictionary = {"다이아":100,"드래곤의 다이아몬드":40}
	var item_instances: Dictionary = {}
	var item_db: Array = []
	var ain_service = AIN.new()
	var cycle := 100
	var enabled := false
	var deny_save := false
	var writes := 0
	var committed: Dictionary = {}
	func source_dungeon_host_context(stage_id: int) -> Dictionary:
		if not enabled: return {}
		var stage: Dictionary = rules.stage("tower",stage_id)
		return {"source_sha256":RUNS.SOURCE_SHA,"land_id":int(stage.place.land.ID),"stage_id":stage_id,"hard":bool(stage.stage.IsHard),"map_id":active_map_id,"cycle":cycle,"clock_contract":"TEST_FIXTURE_ONLY","stage_access":true,"combat_open":true,"completion_allowed":true,"completion_reward_ids":RUNS._reward_ids(rules.reward_preview("tower",stage_id)),"immediate_reward_ids":RUNS._reward_ids(rules.reward_preview("tower",stage_id,true))}
	func _find_catalog_item_record(name: String) -> Dictionary:
		for row: Dictionary in item_db:
			if row.name == name: return row
		return {}
	func source_dungeon_payment_plan(currency: int, amount: int) -> Dictionary:
		return ECONOMY.payment(self,currency,amount)
	func source_dungeon_reward_plan(rows: Array, payment: Dictionary) -> Dictionary:
		return ECONOMY.rewards(self,rows,payment)
	func commit_source_dungeon(next: Dictionary, changes: Dictionary) -> Error:
		if deny_save: return ERR_FILE_CANT_WRITE
		var payload: Dictionary = {"source_dungeon523":next,"gold":changes.get("gold",gold),"experience":changes.get("experience",experience),"inventory":changes.get("inventory",inventory),"item_instances":changes.get("item_instances",item_instances),"ainhasad_state":changes.get("ainhasad_state",ain_service.export_state())}
		var error: Error = WRITER.write("user://dungeon-execution-contract.json",payload)
		if error != OK: return error
		gold = int(payload.gold); experience = int(payload.experience)
		inventory = payload.inventory; item_instances = payload.item_instances
		ain_service.blessing = int(payload.ainhasad_state.blessing)
		committed = payload.duplicate(true); writes += 1
		return OK

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("DUNGEON_EXECUTION_FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := OS.get_environment("TWILIGHT_DUNGEON523_PACK")
	if path.is_empty():
		print("DUNGEON_EXECUTION_REAL_PACK_REQUIRED: not counted as a source execution pass")
		quit(0); return
	var rules = RULES.new()
	check(rules.load_pack(path).ok,"real523 data")
	var host := ContractHost.new()
	root.add_child(host)
	host.rules = rules
	for name: String in ["다이아","명예 코인","변신 제작 코인","마법인형 제작 코인","성물 제작 코인"]: host.item_db.append({"name":name,"slot":"currency"})
	ECONOMY.install_definitions(host,rules)
	var runs = RUNS.new()
	runs.configure(host,rules)
	check(runs.validate(RUNS.empty_state()).is_empty(),"old saves initialize empty ledger")
	check(not runs.begin(4).ok and host.ain_service.blessing == 200,"missing actual host cannot charge")
	host.enabled = true
	host.deny_save = true
	check(not runs.begin(4).ok and runs.state.active.is_empty() and host.ain_service.blessing == 200,"failed admission save rolls back payment and run")
	host.deny_save = false
	check(runs.begin(4).ok and host.ain_service.blessing == 190,"one source Ain10 entry payment")
	check(not runs.begin(4).ok and host.ain_service.blessing == 190,"reentrant begin cannot double spend")
	check(runs.record_event("kill","actor0:1").ok,"first real-host event")
	check(runs.record_event("kill","actor0:1").get("duplicate",false),"pooled-life replay deduplicated")
	for index: int in range(1,42): check(runs.record_event("kill","actor%d:1" % index).ok,"distinct source kill progress")
	check(runs.state.active.status == "cleared" and host.gold == 1000,"42-kill clear does not prematurely grant")
	check(not runs.record_event("kill","after-clear").ok,"post-clear event cannot add rewards")
	host.deny_save = true
	var hash_before := FileAccess.get_sha256("user://dungeon-execution-contract.json")
	check(not runs.claim().ok and host.gold == 1000 and runs.state.settled.is_empty(),"failed settlement is all-or-nothing")
	check(FileAccess.get_sha256("user://dungeon-execution-contract.json") == hash_before,"failed settlement preserves durable bytes")
	host.deny_save = false
	check(runs.claim().ok and host.gold == 71000,"exact normal Adena reward")
	check(host.inventory.get("시련의 증표",0) == 1 and host.inventory.get("성물 제작 코인",0) == 250,"typed token and coin rewards")
	check(not runs.claim().ok and host.gold == 71000,"claim replay cannot duplicate reward")
	var loaded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://dungeon-execution-contract.json"))
	var restored = RUNS.new(); restored.configure(host,rules)
	check(restored.restore(loaded.source_dungeon523) and not restored.claim().ok,"restart retains settlement receipt")
	check(not runs.immediate(4).ok,"same-day immediate completion denied")
	host.cycle += 1
	check(not runs.immediate(4).ok,"name-only diamonds cannot pay Currency764")
	for index: int in range(30):
		host.item_instances[str(100+index)] = {"name":"드래곤의 다이아몬드","level":0,"record":{"source":"lineagem_current523","source_snapshot":"current523","sourceId":"m523:item:549","source_item_class_id":549}}
	host.item_instances["wrong"] = {"name":"드래곤의 다이아몬드","level":0,"record":{"source":"lineagem_current523","source_snapshot":"current523","sourceId":"m523:item:113892","source_item_class_id":113892}}
	check(runs.immediate(4).ok,"next-cycle exact-ID payment and settlement")
	check(host.item_instances.size() == 21 and host.item_instances.has("wrong") and host.inventory["드래곤의 다이아몬드"] == 30,"only ten Item549 physicals consumed")
	check(host.gold == 161055 and host.experience == 12052320 and host.inventory["시련의 증표"] == 2,"immediate amounts and EXP are separate from normal")
	check(not runs.immediate(4).ok and host.item_instances.size() == 21,"immediate receipt and cycle budget prevent repeat")
	check(runs.buy_attempt(4).ok and host.inventory["다이아"] == 50,"one extra attempt costs Gem4x50")
	check(not runs.buy_attempt(4).ok and host.inventory["다이아"] == 50,"extra purchase is once per mode-cycle")
	check(runs.begin(4).ok and host.ain_service.blessing == 180,"extra normal attempt uses one Ain10 payment")
	check(runs.fail_run().ok and host.ain_service.blessing == 180,"explicit exit fails without refund")
	check(not runs.claim().ok,"failed run cannot claim")
	host.cycle += 1
	var bonus_id := int(rules.entries("tower")[5].stage.ID)
	check(runs.begin(bonus_id).ok,"bonus-stage goal remains distinct")
	check(not runs.record_event("pickup","wrong-token",327824).ok,"reward token is not goal Item135434")
	check(runs.record_event("pickup","goal-item",135434).ok and runs.state.active.status == "cleared","source goal Item135434 completes bonus")
	var incomplete: Dictionary = runs.state.duplicate(true)
	for key: String in incomplete.active.counts: incomplete.active.counts[key] = 0
	check(not runs.validate(incomplete).is_empty(),"cleared flag cannot override incomplete goal counts")
	check(runs.claim().ok,"bonus completion settles source rewards")
	var hard_id := int(rules.entries("tower",true)[0].stage.ID)
	check(runs.begin(hard_id).ok and runs.state.active.hard,"hard mode has an independent cycle budget")
	check(int(runs.state.cycles["normal:TEST_FIXTURE_ONLY:102"].tries) == 1,"hard attempt does not alter normal attempts")
	var broken: Dictionary = runs.state.duplicate(true); broken.schema = {}
	check(not runs.restore(broken) and runs.save_blocked,"malformed ledger fails safely")
	print("DUNGEON_EXECUTION_CONTRACT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"REAL_SOURCE_TABLES; TEST_HOST_AND_CLOCK; NOT_ORIGINAL_DUNGEON_RENDER_OR_COMBAT_PROOF"}))
	host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
