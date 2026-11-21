extends SceneTree
## 상자·선택상자 사용 (user report 2026-11-21 "아직 아이템 구현 안 돼서 사용
## 안 되는 거 많아"). The item-use audit (tests/item_use_audit523.gd) found
## every original 523 LuckyBag / SelectReward box silent in the bag: the
## events window owner (unconfirmed523.try_use) claimed all owned category
## 78/10381 items before the native box owner, and a selection box only
## printed "원본 UI에서 보상을 선택하세요" because World never opened the
## selection window. Now a box with a native use rule opens from the bag and
## a selection box opens patch523_reward_choice; UIShowFilter (a 0/1 display
## flag) no longer blocks a selection box.
## Without the pinned 523 tables only the projection rule runs. With them
## every box of the kind is checked for its route; with --runtime boxes are
## opened from the bag in actual Main (all of them with --all, else up to
## --per of each kind; --from/--to split --all across runs).
const PROJECTION = preload("res://scripts/loot/current523_native_item_projection.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const BOX_KINDS = ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag","source_selectable_reward","source_selectable_bag"]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void: call_deferred("run")

func arg(name: String, fallback: String) -> String:
	for raw: String in OS.get_cmdline_user_args():
		if raw.begins_with("--" + name + "="): return raw.trim_prefix("--" + name + "=")
	return fallback

func rules() -> void:
	var row: Dictionary = {"ID":1.0,"IsPossession":false,"bonus_type":{"Name":"UIShowFilter"},"unit":{"Name":"Value"},"bonus":{"ID":2.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0,"Value":1.0}}
	var reference: Dictionary = {"ID":3.0,"IsPossession":false,"bonus_type":{"Name":"SelectRewardClassID"},"unit":{"Name":"RewardID"},"bonus":{"ID":4.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0,"Value":9.0}}
	var item: Dictionary = {"ID":9.0,"TargettingTypeID":1.0,"ServiceRegionCode":""}
	var category: Dictionary = {"IsConsumable":true}
	var allowed: Dictionary = PROJECTION.consume_metadata([reference,row],item,category,{"SelectRewardClassID":"RewardID","UIShowFilter":"Value"},false)
	check(allowed.blocked_reasons.is_empty(), "a selection box's UIShowFilter display flag is accepted")
	var other: Dictionary = PROJECTION.consume_metadata([reference,row],item,category,{"SelectRewardClassID":"RewardID"},false)
	check(other.blocked_reasons.has("unsupported_item_bonus:UIShowFilter"), "outside selection boxes the flag rule is unchanged")
	var text: String = FileAccess.get_file_as_string("res://scripts/loot/current523_native_item_projection.gd")
	check(text.contains('{"SelectRewardClassID":"RewardID","UIShowFilter":"Value"}'), "selectable_reward passes UIShowFilter as a display flag")
	var world_text: String = FileAccess.get_file_as_string("res://scripts/world.gd")
	check(world_text.contains('native_stack.get("requires_original_selection",false) and consumable_service.open_owned_original_selection(item_name,native_stack)'), "the bag opens the selection window for a selection box")
	var events_text: String = FileAccess.get_file_as_string("res://scripts/unconfirmed523/runtime.gd")
	check(events_text.contains('in ["bag","selection"]: return false'), "the events owner leaves native boxes to the bag")

func box_ids() -> Dictionary:
	var by_kind: Dictionary = {}
	for row: Dictionary in SOURCE.rows("ItemClass"):
		if row.get("TestItem", true) != false or int(row.get("ID", 0)) <= 0: continue
		var summary: Dictionary = D.definition_id(str(int(row.ID)))
		if summary.is_empty(): continue
		var record: Dictionary = D.variant_item(summary.get("native_record", {}), 1)
		var spec: Dictionary = FIELDS.full(record).get("source_use_spec", {}) if not record.is_empty() else {}
		if str(spec.get("kind", "")) not in BOX_KINDS: continue
		var key: String = str(spec.kind) + ":" + str(spec.get("activation_status", ""))
		if not by_kind.has(key): by_kind[key] = []
		by_kind[key].append({"id":int(row.ID),"category":int(row.get("CategoryID",0)),"profile":str(STACK.profile(record).get("kind",""))})
	return by_kind

func table(by_kind: Dictionary) -> void:
	var counts: Dictionary = {}
	for key: String in by_kind:
		counts[key] = by_kind[key].size()
		if not key.ends_with(":unrestricted"): continue
		var wrong: Array = []
		for entry: Dictionary in by_kind[key]:
			var expected: String = "selection" if key.begins_with("source_selectable") else "bag"
			if entry.profile != expected: wrong.append(entry.id)
		check(wrong.is_empty(), "every usable %s box has the native %s use owner: %s" % [key, "selection" if key.begins_with("source_selectable") else "bag", str(wrong.slice(0, 10))])
	evidence["boxes"] = counts

func use_box(world: Node, id: int) -> Dictionary:
	world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}
	world.consumable_service.import_state(baseline.duplicate(true))
	var staged: Dictionary = INV.stage(world, [{"item_class_id":id,"amount":2,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not staged.get("ok", false): return {"ok":false,"reason":"stage:" + str(staged.get("error",""))}
	if world._save_game(true, staged.overrides) != OK: return {"ok":false,"reason":"save"}
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	var name: String = ""
	for key: Variant in world.inventory: name = str(key)
	world.hud.message_label.text = ""
	world._on_inventory_item_activated(name)
	var message: String = world.hud.message_label.text
	var choice: Variant = world.hud.get_meta("patch523_reward_choice") if world.hud.has_meta("patch523_reward_choice") else null
	var chosen: bool = false
	if is_instance_valid(choice):
		var rows: Array = choice.call("original_rows")
		if not rows.is_empty(): chosen = bool(choice.call("claim_entity", int(rows[0].entity_id)))
		if is_instance_valid(choice): choice.free()
		if world.hud.has_meta("patch523_reward_choice"): world.hud.remove_meta("patch523_reward_choice")
	var left: int = int(world.inventory.get(name, 0))
	var rewards: int = 0
	for key: Variant in world.inventory:
		if str(key) != name: rewards += int(world.inventory[key])
	var problem: String = str(world.patch523_owner_state_problem)
	world.patch523_owner_state_problem = ""
	return {"ok":left == 1,"left":left,"rewards":rewards,"chosen":chosen,"message":message if message != "" else world.hud.message_label.text,"problem":problem}

var baseline: Dictionary = {}
func runtime(by_kind: Dictionary) -> void:
	var save_path: String = ""
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	save_path = world.save_path()
	var had_save: bool = FileAccess.file_exists(save_path)
	var original_save: PackedByteArray = FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	world.level = 85
	baseline = world.consumable_service.export_state()
	var all: bool = "--all" in OS.get_cmdline_user_args()
	var per: int = int(arg("per", "6"))
	var ids: Array = []
	for key: String in by_kind:
		if not key.ends_with(":unrestricted"): continue
		var list: Array = by_kind[key]
		for index: int in range(list.size() if all else mini(per, list.size())):
			ids.append(int(list[index if all else int(index * list.size() / maxi(1, per))].id))
	ids.sort()
	var from: int = int(arg("from", "0")); var to: int = mini(int(arg("to", str(ids.size()))), ids.size())
	var opened: int = 0
	var refused: Dictionary = {}
	for index: int in range(from, to):
		var outcome: Dictionary = use_box(world, int(ids[index]))
		if outcome.ok: opened += 1
		else: refused[str(ids[index])] = outcome
	# A box whose class has no reward for the knight is refused by its own
	# original class rule; every other refusal is a failure.
	var other: Dictionary = {}
	for key: String in refused:
		if not str(refused[key].get("message","")).contains("직업"): other[key] = refused[key]
	check(other.is_empty(), "every opened box consumes one and grants its rewards: " + JSON.stringify(other).left(1500))
	evidence["runtime"] = {"tried":to - from,"opened":opened,"class_refused":refused.size() - other.size(),"range":[from, to],"total":ids.size()}
	world.queue_free()
	await process_frame
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null: file.store_buffer(original_save); file.close()
	elif FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		var by_kind: Dictionary = box_ids()
		table(by_kind)
		if "--runtime" in OS.get_cmdline_user_args(): await runtime(by_kind)
	print("ITEM_USE523_BOXES_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
