extends "res://tests/source_inventory_controls_main_test.gd"
## Original growth-pass ring in actual Main with a disposable character.
## The optional UI pack drives both taps on the original bag slot.
const RING := 286632
const D = preload("res://scripts/loot/patch523_monster_drops.gd")

func result_marker() -> String: return "EQUIPMENT_BUFF523_RESULT"

func fallback() -> void:
	if SOURCE.identity().is_empty():
		ck(SOURCE.not_installed(), "missing original definitions provide no equipment buff")
		return
	await exact("")

func exact(archive: String) -> void:
	if not archive.is_empty() and SOURCE.identity().is_empty():
		OS.set_environment("TWILIGHT_PATCH523_CONTENT", archive)
		SOURCE.reset()
		# Main was started without the private test archive.
		w.skill_awakening = w.SKILL_AWAKENING.new()
		w.skill_awakening.configure(w)
	if not ck(SOURCE.identity().get("source_sha256") == SOURCE.SOURCE_SHA, "pinned original 523 definitions"): return
	w._clear_monsters()
	w.level = 90
	w.equipped_items.clear()
	w.equipped_catalog["변신"] = {}
	w._invalidate_equipment_static()
	var record: Dictionary = w.source_item_definition(RING).get("native_record", {})
	if not ck(not record.is_empty(), "original wearable ItemClass #%d" % RING): return
	if w._catalog_item_from_source_id(str(record.sourceId)).is_empty():
		w.catalog_db["아이템"].append(record)
	w._index_catalog_item_sources()
	if not ck(grant(RING, 1, "equipped buff"), "existing original ring saved in the test bag"): return
	var reference: String = ""
	for uid: String in w.item_instances:
		var entry: Dictionary = w.item_instances[uid]
		if int(entry.get("record", {}).get("source_item_class_id", 0)) == RING:
			reference = "%s@@@%s" % [entry.name, uid]
			break
	if not ck(not reference.is_empty(), "the ring has an exact physical reference"): return
	var uid: String = reference.get_slice("@@@", 1)
	var name_value: String = reference.get_slice("@@@", 0)
	var buff: Dictionary = w.equipment_buff523.buff_of(w.item_instances[uid].record)
	if not ck(int(buff.get("buff_id", 0)) == 78962 and bool(buff.get("polymorph", false)), "ring owns original BuffClass #78962"): return
	var expect_ui: bool = not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty()
	if expect_ui:
		h.toggle_inventory()
		await frames()
		controller = h.original_main_ui_controller
		if not ck(is_instance_valid(controller) and h.original_inventory_is_open(), "original bag is active"): return
		view = controller._inventory_view

	var plain_cap: int = w._effective_max_hp()
	var plain_mp: int = w._effective_max_mp()
	w.hp = plain_cap - 30
	var expected_hp: int = w.hp + 100
	ck(w.equipment_buff523.buff_value("hp_flat") == 0, "bag ownership alone contributes no HP")
	if not await bag_equipment_action(reference, true, expect_ui): return
	var worn_cap: int = w._effective_max_hp()
	print("EQUIPMENT_BUFF523_VITALS ", JSON.stringify({"original_bag":expect_ui, "owned_only":plain_cap, "worn":worn_cap, "current_hp":w.hp}))
	ck(w._is_instance_equipped(uid) and int(w.inventory.get(name_value, 0)) == 1, "bag equips the selected ring without consuming it")
	ck(w.equipment_buff523.buff_value("hp_flat") == 100 and worn_cap == plain_cap + 100, "first worn equipment read and Main HP cap include the original +100")
	ck(w.hp == expected_hp and w._effective_max_mp() == plain_mp, "the existing equip transition applies only the HP cap delta")
	ck(w.equipment_buff523.buff_value("damage_reduction") == 2 and w.equipment_buff523.buff_value("attack_speed") == 108 and w.equipment_buff523.buff_value("move_speed") == 2, "existing damage reduction and speed remain")
	if not ck(w._save_game(true) == OK, "existing save schema persists the equipped physical ring"): return
	var former_hp: int = w.hp
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
	ck(state is Dictionary and not state.has("equipment_buff523") and int(state.get("hp", 0)) == former_hp, "no new save key or cached buff payload is written")

	# Re-enter through the existing restore path from a profile holding the
	# ring and prime the previous game's stat cache before loading it.
	w.equipped_items.clear()
	w._invalidate_equipment_static()
	ck(w.equipment_buff523.buff_value("hp_flat") == 0, "the previous live state has no worn bonus")
	w._load_game(true)
	await frames()
	ck(w._is_instance_equipped(uid) and w._effective_max_hp() == worn_cap and w.hp == former_hp, "existing profile reload derives the bonus once before clamping saved HP")
	if expect_ui:
		if not h.original_inventory_is_open(): h.toggle_inventory()
		await frames()
		view = controller._inventory_view
	w.hp = worn_cap
	if not await bag_equipment_action(reference, false, expect_ui): return
	ck(not w._is_instance_equipped(uid) and w.inventory.get(name_value, 0) == 1, "bag unequips and returns the exact item to storage in the bag")
	ck(w._effective_max_hp() == plain_cap and w.hp == plain_cap and w.equipment_buff523.buff_value("hp_flat") == 0, "unequip clears the bonus and clamps on the same transition")
	if not ck(w._save_game(true) == OK, "unequipped state saves without a new field"): return
	w._load_game(true)
	await frames()
	ck(not w._is_instance_equipped(uid) and w._effective_max_hp() == plain_cap and w.hp == plain_cap, "reload preserves the unequipped cap and physical item")

	# Exercise the existing host policy for an alternative active form. This
	# uses a persisted catalog selection independently of the original ring.
	var card: Dictionary = {}
	for value: Variant in w.catalog_db.get("변신", []):
		if value is Dictionary and not value.is_empty():
			card = value
			break
	if not card.is_empty():
		w.equipped_catalog["변신"] = card
		w._invalidate_equipment_static()
		w._equip_reference_in_slot(reference, "ring1")
		ck(w._is_instance_equipped(uid) and w.equipment_buff523.buff_value("damage_reduction") == 2 and w.equipment_buff523.buff_value("attack_speed") == 0 and w.equipment_buff523.buff_value("hp_flat") == 0, "a different active form keeps the existing exclusion policy and receives no Sharna form HP")

func bag_equipment_action(reference: String, equip: bool, original: bool) -> bool:
	if not original:
		if equip: w._activate_inventory_input(reference)
		else: w._unequip_item_reference(reference)
		return true
	var control: Control = view._hits.get(reference, {}).get("control")
	if not await tap(control, "original ring slot"): return false
	if not ck(bag.item_action_armed(reference) and bag.selected_item == reference, "first tap arms the exact equipment action"): return false
	control = view._hits.get(reference, {}).get("control")
	return await tap(control, "장착" if equip else "해제")
