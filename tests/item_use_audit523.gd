extends SceneTree
## Item-use audit (user report 2026-11-21 "아직 아이템 구현 안 돼서 사용 안
## 되는 거 많아"). In actual Main with the original 523 pack every listed
## item is put in the bag, its bag detail (use button / quick-slot button) is
## read, the bag use is pressed through World._on_inventory_item_activated
## and any confirmation the use opens is accepted. One JSON line per item is
## printed; tools/item_use_audit523.py classifies them against the original
## ItemClass data. Not part of CI (it walks tens of thousands of items).
##   -- --ids=<json array of ItemClassID> [--legacy] [--job=기사] [--from=i --to=j]
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const QA = preload("res://tests/qa_class_selection.gd")

var world: Node

func _initialize() -> void: call_deferred("run")

func arg(name: String, fallback: String = "") -> String:
	for raw: String in OS.get_cmdline_user_args():
		if raw.begins_with("--" + name + "="): return raw.trim_prefix("--" + name + "=")
	return fallback

var poisoned: String = ""
var baseline_consumables: Dictionary = {}
func reset() -> void:
	world.consumable_service.import_state(baseline_consumables.duplicate(true))
	poisoned = str(world.patch523_owner_state_problem)
	world.patch523_owner_state_problem = ""
	world.quest_service.save_blocked = false
	world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}; world.active_item_buffs = {}
	for slot: String in world.equipped_items.keys(): world.equipped_items.erase(slot)
	# Half HP/MP: a potion still heals, and a damage tick cannot kill the
	# character (a death would block every later use).
	world.hp = maxi(1, world._effective_max_hp() / 2); world.mp = maxi(1, world._effective_max_mp() / 2)
	world.portal_cooldown = 0.0; world.player.auto_enabled = false; world.player.movement_locked = false
	# A card result from the previous item is still presenting (processing
	# is off): close every reveal layer so the next item is not refused.
	world.hud.set("card_reveal_stage", null)
	for child: Node in world.hud.get_children():
		if str(child.name).begins_with("CardRevealLayer") or str(child.name).begins_with("EnhancementRevealLayer"):
			world.hud.remove_child(child); child.free()
	world.hud.set("enhancement_reveal", null)
	var controller: Variant = world.hud.get("original_main_ui_controller")
	if is_instance_valid(controller):
		for child: Node in (controller as Node).get_children():
			if child is CanvasItem and (child as CanvasItem).visible and child.has_method("close"): child.call("close")
	for dialog: Node in world.hud.get_node("Root").get_children():
		if dialog.name == "TwilightConfirmation" and dialog.has_method("dismiss"): dialog.dismiss()
	if world.hud.has_method("close_workspace"): world.hud.close_workspace()
	elif world.hud.workspace != null: world.hud.workspace.hide()
	world.hud.message_label.text = ""

func windows() -> Array:
	var names: Array = []
	for child: Node in world.hud.get_node("Root").get_children():
		if child is CanvasItem and (child as CanvasItem).visible and child.name not in ["MessageLabel"]: names.append(str(child.name))
	var controller: Variant = world.hud.get("original_main_ui_controller")
	if is_instance_valid(controller):
		for child: Node in (controller as Node).get_children():
			if child is CanvasItem and (child as CanvasItem).visible: names.append("O:" + str(child.name))
	return names

func snap() -> Dictionary:
	var equipped: Dictionary = {}
	for slot: String in world.equipped_items.keys(): equipped[slot] = str((world.equipped_items[slot] as Dictionary).get("instance_id", ""))
	return {"inv":world.inventory.duplicate(true),"hp":world.hp,"mp":world.mp,"gold":world.gold,"exp":world.experience,"level":world.level,
		"buffs":world.active_item_buffs.keys(),"equipped":equipped,"section":str(world.hud.active_section),
		"workspace":world.hud.workspace != null and world.hud.workspace.visible,"windows":windows() + (["card_reveal"] if world.hud.is_card_reveal_busy() else []),"ammo":str(world.get("equipped_ammo"))}

func diff(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var inv_delta: Dictionary = {}
	for key: Variant in a.inv.keys() + b.inv.keys():
		var change: int = int(b.inv.get(key, 0)) - int(a.inv.get(key, 0))
		if change != 0: inv_delta[str(key)] = change
	if not inv_delta.is_empty(): out["inv"] = inv_delta
	for key: String in ["hp","mp","gold","exp","level"]:
		if b[key] != a[key]: out[key] = int(b[key]) - int(a[key])
	if b.buffs != a.buffs: out["buffs"] = b.buffs
	if b.equipped != a.equipped: out["equipped"] = b.equipped
	if b.ammo != a.ammo: out["ammo"] = b.ammo
	if b.section != a.section or b.workspace != a.workspace: out["section"] = b.section if b.workspace else ""
	var opened: Array = []
	for name: Variant in b.windows:
		if not a.windows.has(name): opened.append(name)
	if not opened.is_empty(): out["windows"] = opened
	return out

func reference_for(before: Dictionary) -> String:
	for key: Variant in world.inventory.keys():
		if int(world.inventory.get(key, 0)) > int(before.get(key, 0)):
			for uid: Variant in world.item_instances.keys():
				var entry: Variant = world.item_instances[uid]
				if entry is Dictionary and str(entry.get("name", "")) == str(key) and (D.equipment(entry.get("record", {})) or int(world.inventory[key]) == 1):
					return str(key) + "@@@" + str(uid)
			return str(key)
	return ""

func bag_detail(reference: String) -> Dictionary:
	var ui: Node = world.hud.get("lineage_inventory_ui")
	if ui == null: return {}
	world.hud.refresh_inventory(world.inventory)
	ui.call("_refresh_detail", reference)
	var action: Button = ui.get("detail_action")
	var quick: Button = ui.get("quick_button")
	return {"action":action.text if action != null else "","action_disabled":action.disabled if action != null else true,
		"action_tip":action.tooltip_text if action != null else "","quick_disabled":quick.disabled if quick != null else true,
		"quick_tip":quick.tooltip_text if quick != null else ""}

func accept_dialogs(log: Array) -> void:
	for round: int in range(3):
		var found: bool = false
		for dialog: Node in world.hud.get_node("Root").get_children():
			if dialog.name == "TwilightConfirmation" and not dialog.is_queued_for_deletion() and dialog.has_method("_accept"):
				log.append(str(dialog.get("title_label").text if dialog.get("title_label") != null else "confirm"))
				dialog.call("_accept"); found = true
				break
		if not found: break
	var choice: Variant = world.hud.get_meta("patch523_reward_choice") if world.hud.has_meta("patch523_reward_choice") else null
	if is_instance_valid(choice):
		var rows: Array = choice.call("original_rows")
		log.append("selection:%d" % rows.size())
		if not rows.is_empty(): log.append("claim:" + str(choice.call("claim_entity", int(rows[0].entity_id))))
		if is_instance_valid(choice): choice.queue_free()

func use(reference: String, quick: bool) -> Dictionary:
	world.hud.message_label.text = ""
	world.item_use_cooldowns = {}
	var name: String = reference.split("@@@")[0]
	var before: Dictionary = snap()
	var started: int = Time.get_ticks_usec()
	if quick: world._use_quickslot_item(name)
	else: world._on_inventory_item_activated(reference)
	var first_message: String = world.hud.message_label.text
	var dialogs: Array = []
	for frame: int in range(3): await process_frame
	accept_dialogs(dialogs)
	for frame: int in range(3): await process_frame
	var after: Dictionary = snap()
	var problem: String = str(world.patch523_owner_state_problem)
	if world.death_recovery.blocked(): problem += " · death_recovery_blocked"
	return {"problem":problem,"msg":first_message,"msg2":world.hud.message_label.text if world.hud.message_label.text != first_message else "","dialogs":dialogs,"diff":diff(before, after),"us":Time.get_ticks_usec() - started}

func audit_native(id: int) -> Dictionary:
	reset()
	var row: Dictionary = {"id":id}
	var summary: Dictionary = D.definition_id(str(id))
	var record: Dictionary = D.variant_item(summary.get("native_record", {}), 1) if not summary.is_empty() else {}
	var spec: Dictionary = FIELDS.full(record).get("source_use_spec", {}) if not record.is_empty() else {}
	row["spec"] = {"kind":spec.get("kind",""),"status":spec.get("activation_status",""),"reasons":spec.get("blocked_reasons",[])}
	row["profile"] = str(STACK.profile(record).get("kind","")) if not record.is_empty() else ""
	row["supply"] = str(STACK.supply_profile(record).get("kind","")) if not record.is_empty() else ""
	row["slot"] = str(record.get("slot",""))
	var amount: int = 1 if D.equipment(record) else 3
	var staged: Dictionary = INV.stage(world, [{"item_class_id":id,"amount":amount,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not staged.get("ok", false):
		row["stage_error"] = str(staged.get("error",""))
		return row
	var before_inv: Dictionary = world.inventory.duplicate()
	var saved: Error = world._save_game(true, staged.overrides)
	if saved != OK:
		row["stage_error"] = "save_" + str(saved)
		return row
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	if staged.overrides.has("gold"): world.gold = int(staged.overrides.gold)
	var reference: String = reference_for(before_inv)
	row["ref"] = reference
	if reference.is_empty():
		row["stage_error"] = "no_inventory_key"
		return row
	row["bag"] = bag_detail(reference)
	row["quick_reg"] = world._quickslot_registration_error("item", reference.split("@@@")[0])
	if "--probe" in OS.get_cmdline_user_args():
		var parts: PackedStringArray = reference.split("@@@")
		row["probe_record_source"] = str(world._find_catalog_item_record(parts[0]).get("source",""))
		row["probe_stack"] = STACK.try_use(world, parts[0], parts[1] if parts.size() > 1 else "")
		return row
	row["use"] = await use(reference, false)
	if row.quick_reg == "" and int(world.inventory.get(reference.split("@@@")[0], 0)) > 0 and not D.equipment(record):
		row["quick"] = await use(reference, true)
	return row

func audit_legacy(name: String) -> Dictionary:
	reset()
	var row: Dictionary = {"legacy":name}
	var record: Dictionary = world._find_catalog_item_record(name)
	row["slot"] = str(record.get("slot","")); row["type"] = str(record.get("type",""))
	world.inventory[name] = 1 if world._equipment_slot_base(record) != "" else 3
	world._sync_item_instances()
	world._save_game(true)
	var reference: String = name
	for uid: Variant in world.item_instances.keys():
		if str((world.item_instances[uid] as Dictionary).get("name","")) == name and world._equipment_slot_base(record) != "": reference = name + "@@@" + str(uid)
	row["ref"] = reference
	row["bag"] = bag_detail(reference)
	row["quick_reg"] = world._quickslot_registration_error("item", name)
	row["use"] = await use(reference, false)
	if row.quick_reg == "" and int(world.inventory.get(name, 0)) > 0: row["quick"] = await use(reference, true)
	return row

func run() -> void:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	var job: String = arg("job", "기사")
	if not QA.enter_game(world, job):
		print("ITEM_USE_AUDIT_FATAL enter_game"); quit(2); return
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	world.level = 85
	baseline_consumables = world.consumable_service.export_state()
	world.inventory = {}; world.item_instances = {}
	world._save_game(true)
	var started: int = Time.get_ticks_msec()
	var budget_ms: int = int(arg("budget", "480000"))
	var ids: Array = []
	var path: String = arg("ids")
	if not path.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Array: ids = parsed
	var from: int = int(arg("from", "0")); var to: int = int(arg("to", str(ids.size())))
	var done: int = 0
	if "--specs" in OS.get_cmdline_user_args():
		# Every listed item's use signature, then a runtime use of up to
		# --per items of each distinct signature within the time budget.
		var groups: Dictionary = {}
		var skip_specs: bool = int(arg("sample-from", "0")) > 0 or "--no-specs" in OS.get_cmdline_user_args()
		var per: int = int(arg("per", "3"))
		for index: int in range(from, mini(to, ids.size())):
			var id: int = int(ids[index])
			var summary: Dictionary = D.definition_id(str(id))
			var record: Dictionary = D.variant_item(summary.get("native_record", {}), 1) if not summary.is_empty() else {}
			var spec: Dictionary = FIELDS.full(record).get("source_use_spec", {}) if not record.is_empty() else {}
			var row: Dictionary = {"id":id,"kind":spec.get("kind",""),"status":spec.get("activation_status",""),"reasons":spec.get("blocked_reasons",[]),
				"profile":str(STACK.profile(record).get("kind","")) if not record.is_empty() else "","supply":str(STACK.supply_profile(record).get("kind","")) if not record.is_empty() else "",
				"slot":str(record.get("slot","")),"equip":D.equipment(record) if not record.is_empty() else false,"empty":record.is_empty(),"quick":world._quickslot_item_supported(str(record.get("name",""))) if not record.is_empty() else false}
			if skip_specs == false: print("ITEM_USE_AUDIT_SPEC " + JSON.stringify(row))
			var signature: String = JSON.stringify([row.kind,row.status,row.reasons,row.profile,row.supply,row.slot,row.equip,row.quick])
			if not groups.has(signature): groups[signature] = []
			if groups[signature].size() < per: groups[signature].append(id)
		var sample: Array = []
		for signature: String in groups: sample.append_array(groups[signature])
		print("ITEM_USE_AUDIT_SAMPLE " + JSON.stringify({"groups":groups.size(),"items":sample.size()}))
		var skip: int = int(arg("sample-from", "0"))
		for id: Variant in sample.slice(skip, int(arg("sample-to", str(sample.size())))):
			print("ITEM_USE_AUDIT_BEGIN " + str(id))
			print("ITEM_USE_AUDIT_ROW " + JSON.stringify(await audit_native(int(id))))
			done += 1
			if Time.get_ticks_msec() - started > budget_ms: break
	elif "--legacy" in OS.get_cmdline_user_args():
		var names: Dictionary = {}
		for source: Variant in [world.catalog_db.get("아이템", []), world.item_db]:
			if not source is Array: continue
			for record: Variant in source:
				if record is Dictionary and not record.get("source_m_native_item", false) and not str(record.get("name","")).is_empty(): names[str(record.name)] = true
		var ordered: Array = names.keys(); ordered.sort()
		print("ITEM_USE_AUDIT_LEGACY " + str(ordered.size()))
		for index: int in range(from, mini(int(arg("to", str(ordered.size()))), ordered.size())):
			print("ITEM_USE_AUDIT_BEGIN L" + str(index))
			print("ITEM_USE_AUDIT_ROW " + JSON.stringify(await audit_legacy(str(ordered[index]))))
			done = index + 1
			if Time.get_ticks_msec() - started > budget_ms: break
	else:
		for index: int in range(from, mini(to, ids.size())):
			print("ITEM_USE_AUDIT_BEGIN " + str(ids[index]))
			print("ITEM_USE_AUDIT_ROW " + JSON.stringify(await audit_native(int(ids[index]))))
			done = index + 1
			if Time.get_ticks_msec() - started > budget_ms: break
	print("ITEM_USE_AUDIT_DONE " + JSON.stringify({"next":done,"ms":Time.get_ticks_msec() - started,"job":world.job_class}))
	quit(0)
