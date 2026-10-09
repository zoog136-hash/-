extends Node
class_name TwilightConsumableService

# An isolated runtime extension; world map/rendering/combat animation are not changed.
const RULES = preload("res://scripts/consumable_rules.gd")
const COORD = preload("res://scripts/maps/world_coordinates.gd")
const ELEMENT_RULES = preload("res://scripts/elemental_rules.gd")
const BLESSING = preload("res://scripts/equipment_blessing.gd")
const ELIXIR_LIMIT: int = 10
const STAT_CAP: int = 45

var world: Variant = null
var elemental_enchants: Dictionary = {}
var elixirs_used: int = 0
var half_elixirs_used: int = 0
var permanent_damage_bonuses: Dictionary = {
	"melee_damage": 0, "ranged_damage": 0, "magic_damage": 0
}

func setup(world_node: Node) -> void:
	world = world_node

func export_state() -> Dictionary:
	return {
		"elemental_enchants": elemental_enchants.duplicate(true),
		"elixirs_used": elixirs_used,
		"half_elixirs_used": half_elixirs_used,
		"permanent_damage_bonuses": permanent_damage_bonuses.duplicate(true)
	}

func import_state(input: Variant) -> void:
	elemental_enchants.clear()
	elixirs_used = 0
	half_elixirs_used = 0
	permanent_damage_bonuses = {"melee_damage":0, "ranged_damage":0, "magic_damage":0}
	if not (input is Dictionary):
		return
	var data: Dictionary = input as Dictionary
	elixirs_used = clampi(int(data.get("elixirs_used", 0)), 0, ELIXIR_LIMIT)
	half_elixirs_used = clampi(int(data.get("half_elixirs_used", 0)), 0, ELIXIR_LIMIT)
	var raw_bonuses: Variant = data.get("permanent_damage_bonuses", {})
	if raw_bonuses is Dictionary:
		for key: String in permanent_damage_bonuses.keys():
			permanent_damage_bonuses[key] = clampi(int((raw_bonuses as Dictionary).get(key, 0)), 0, ELIXIR_LIMIT)
	var raw_enchants: Variant = data.get("elemental_enchants", {})
	if raw_enchants is Dictionary:
		for item_key: Variant in (raw_enchants as Dictionary).keys():
			var info: Variant = (raw_enchants as Dictionary)[item_key]
			if not (info is Dictionary):
				continue
			var enchant: Dictionary = info as Dictionary
			var channel: String = str(enchant.get("element", ""))
			var strength: int = clampi(int(enchant.get("level", 0)), 0, 5)
			if RULES.ELEMENT_NAMES.has(channel) and strength > 0:
				elemental_enchants[str(item_key)] = {"element":channel, "level":strength}

func permanent_damage_bonus(bonus_name: String) -> int:
	return int(permanent_damage_bonuses.get(bonus_name, 0))

func migrate_legacy_elemental() -> void:
	# Old consumables used item *names* as elemental keys. Migrate that one
	# shared enchant to ONE stable physical instance instead of all duplicates.
	var instances: Dictionary = world.get("item_instances") as Dictionary
	for key: Variant in elemental_enchants.keys():
		var old_key: String = str(key)
		var value: Variant = elemental_enchants[key]
		if not (value is Dictionary):
			continue
		var element: String = str((value as Dictionary).get("element", ""))
		var strength: int = clampi(int((value as Dictionary).get("level", 0)), 0, 5)
		if not RULES.ELEMENT_NAMES.has(element) or strength <= 0:
			continue
		var instance_id: String = old_key if instances.has(old_key) else ""
		if instance_id.is_empty():
			instance_id = str(world.call("_chosen_instance", old_key))
		if not instances.has(instance_id):
			continue
		var item: Dictionary = instances[instance_id] as Dictionary
		if int(item.get("element_level", 0)) == 0:
			item["element"] = element
			item["element_level"] = strength
			instances[instance_id] = item
	elemental_enchants.clear()

func _enchant_for_weapon(weapon_record: Dictionary) -> Dictionary:
	var item_id: String = str(weapon_record.get("instance_id", ""))
	if item_id.is_empty():
		return {}
	var instances: Dictionary = world.get("item_instances") as Dictionary
	var record_value: Variant = instances.get(item_id, {})
	if not (record_value is Dictionary):
		return {}
	var entry: Dictionary = record_value as Dictionary
	if str(entry.get("name", "")) != str(weapon_record.get("name", "")):
		return {}
	return entry

func weapon_element(weapon_record: Dictionary) -> String:
	var entry: Dictionary = _enchant_for_weapon(weapon_record)
	if int(entry.get("element_level", 0)) <= 0:
		return ""
	return str(entry.get("element", ""))

func weapon_element_bonus(weapon_record: Dictionary, target: Node) -> int:
	if target == null or not is_instance_valid(target):
		return 0
	var entry: Dictionary = _enchant_for_weapon(weapon_record)
	var strength: int = int(entry.get("element_level", 0))
	var channel: String = str(entry.get("element", ""))
	if strength <= 0 or not RULES.ELEMENT_NAMES.has(channel):
		return 0
	if target.has_method("elemental_resistance_percent"):
		return ELEMENT_RULES.damage_after_resistance(strength, float(target.call("elemental_resistance_percent", channel)))
	return strength

func prune_removed() -> void:
	if world == null:
		return
	var inv: Dictionary = world.get("inventory") as Dictionary
	for item_key: Variant in inv.keys():
		if RULES.is_removed_item(str(item_key)):
			inv.erase(item_key)
	var shortcuts: Array = world.get("quickslots") as Array
	for index: int in range(shortcuts.size()):
		var value: Variant = shortcuts[index]
		if value is Dictionary and str((value as Dictionary).get("kind", "")) == "item" and RULES.is_removed_item(str((value as Dictionary).get("id", ""))):
			shortcuts[index] = {}
	var buffs: Dictionary = world.get("active_item_buffs") as Dictionary
	for item_key: Variant in buffs.keys():
		if RULES.is_removed_item(str(item_key)):
			buffs.erase(item_key)

func try_use(item_name: String) -> bool:
	var spec: Dictionary = RULES.definition(item_name)
	if spec.is_empty():
		return false
	var inv: Dictionary = world.get("inventory") as Dictionary
	if int(inv.get(item_name, 0)) <= 0:
		_message("아이템이 없습니다: %s" % item_name)
		return true
	var kind: String = str(spec.get("kind", ""))
	match kind:
		"regen", "food", "buff":
			var record: Dictionary = world.call("_find_catalog_item_record", item_name)
			world.call("_use_timed_item_buff", record)
		"instant_mp":
			_use_instant_mp(item_name, spec)
		"return":
			_use_return(item_name)
		"teleport":
			_use_random_teleport(item_name)
		"elixir":
			_use_elixir(item_name, spec)
		"half_elixir":
			_use_half_elixir(item_name, spec)
		"element":
			_use_elemental_scroll(item_name, spec)
		"equipment_bless":
			_use_bless_scroll(item_name)
	return true

func _message(value: String) -> void:
	world.hud.show_message(value)

func _consume(item_name: String) -> void:
	var inv: Dictionary = world.get("inventory") as Dictionary
	inv[item_name] = maxi(0, int(inv.get(item_name, 0)) - 1)
	if int(inv.get(item_name, 0)) == 0:
		inv.erase(item_name)
	world.hud.refresh_inventory(inv)
	world.call("_update_hud")
	world.call("_save_game", true)

func _use_instant_mp(item_name: String, spec: Dictionary) -> void:
	var cooldowns: Dictionary = world.get("item_use_cooldowns") as Dictionary
	var cooldown: float = float(cooldowns.get(item_name, 0.0))
	if cooldown > 0.0:
		_message("재사용 대기 %s" % str(world.call("_format_seconds_short", cooldown)))
		return
	var maximum: int = int(world.get("max_mp"))
	if int(world.get("mp")) >= maximum:
		_message("MP가 가득 찼습니다")
		return
	world.set("mp", mini(maximum, int(world.get("mp")) + maxi(1, int(spec.get("amount", 0)))))
	cooldowns[item_name] = maxf(0.0, float(spec.get("cooldown", 0.0)))
	_consume(item_name)
	_message("%s 사용 · MP 회복" % item_name)

func _player_busy_for_travel() -> bool:
	return bool(world.player.is_stunned() or world.player.is_feared())

func _teleport_player(destination: Vector2) -> void:
	world.player.set_auto_enabled(false)
	world.player.clear_click_path()
	world.player.set_touch_vector(Vector2.ZERO)
	world.player.velocity = Vector2.ZERO
	world.player.global_position = destination
	world.player.camera.reset_smoothing()
	world.set("selected_monster", null)
	world.set("auto_target", null)
	world.hud.clear_target()

func _safe_region_position() -> Vector2:
	var field: Variant = world.get("field_map")
	if field == null:
		return Vector2.INF
	var best: float = INF
	var result: Vector2 = Vector2.INF
	for value: Variant in field.data.get("regions", []):
		if not (value is Dictionary):
			continue
		var region: Dictionary = value as Dictionary
		if str(region.get("type", "")) != "safe":
			continue
		var center: Vector2 = COORD.array_vector(region.get("center", [0, 0]))
		if not field.walkable(center) or not field.point_clear(center):
			continue
		var distance: float = world.player.global_position.distance_squared_to(center)
		if distance < best:
			best = distance
			result = center
	return result

func _use_return(item_name: String) -> void:
	if _player_busy_for_travel():
		_message("현재 상태에서는 귀환할 수 없습니다")
		return
	if not (world.get("maps_by_id") as Dictionary).has("aden_world"):
		_message("귀환 가능한 마을을 찾을 수 없습니다")
		return
	if str(world.get("active_map_id")) != "aden_world":
		world.call("_set_map", "aden_world", false)
	var place: Vector2 = _safe_region_position()
	if place != Vector2.INF:
		_teleport_player(place)
	else:
		_teleport_player(world.call("_spawn_position"))
	_consume(item_name)
	_message("아덴 마을로 귀환했습니다")

func _random_destination() -> Vector2:
	var field: Variant = world.get("field_map")
	var start: Vector2 = world.player.global_position
	var rng: RandomNumberGenerator = world.get("rng") as RandomNumberGenerator
	if field != null:
		for attempt: int in range(1500):
			var x: int = rng.randi_range(0, field.width - 1)
			var y: int = rng.randi_range(0, field.height - 1)
			var cell: Vector2i = Vector2i(x, y)
			if field.reachable[y * field.width + x] == 0 or field.astar.is_point_solid(cell):
				continue
			var position: Vector2 = field.cell_to_world(cell)
			if position.distance_to(start) < 160.0 or not field.point_clear(position):
				continue
			return position
		return Vector2.INF
	var spawn: Vector2 = world.call("_spawn_position")
	var candidate: Vector2 = world.call("_random_walkable_position", spawn, 180.0, INF)
	if candidate != Vector2.INF and bool(world.call("_is_walkable_world", candidate)):
		return candidate
	return Vector2.INF

func _use_random_teleport(item_name: String) -> void:
	if _player_busy_for_travel():
		_message("현재 상태에서는 순간이동할 수 없습니다")
		return
	var destination: Vector2 = _random_destination()
	if destination == Vector2.INF:
		_message("이동 가능한 위치가 없습니다")
		return
	_teleport_player(destination)
	_consume(item_name)
	_message("현재 맵 내 무작위 순간이동")

func _stat_value(stat_name: String) -> int:
	match stat_name:
		"STR": return int(world.get("str_stat"))
		"DEX": return int(world.get("dex_stat"))
		"CON": return int(world.get("con_stat"))
		"INT": return int(world.get("int_stat"))
		"WIS": return int(world.get("wis_stat"))
		"CHA": return int(world.get("cha_stat"))
	return STAT_CAP

func _increase_stat(stat_name: String) -> void:
	match stat_name:
		"STR": world.set("str_stat", int(world.get("str_stat")) + 1)
		"DEX": world.set("dex_stat", int(world.get("dex_stat")) + 1)
		"CON": world.set("con_stat", int(world.get("con_stat")) + 1)
		"INT": world.set("int_stat", int(world.get("int_stat")) + 1)
		"WIS": world.set("wis_stat", int(world.get("wis_stat")) + 1)
		"CHA": world.set("cha_stat", int(world.get("cha_stat")) + 1)

func _use_elixir(item_name: String, spec: Dictionary) -> void:
	if int(world.get("level")) < 50:
		_message("엘릭서는 레벨 50 이상부터 사용합니다")
		return
	if elixirs_used >= ELIXIR_LIMIT:
		_message("엘릭서는 최대 %d회까지 사용할 수 있습니다" % ELIXIR_LIMIT)
		return
	var stat_name: String = str(spec.get("stat", ""))
	if stat_name != "":
		apply_elixir(item_name, stat_name)
	else:
		_select_option(item_name, RULES.STAT_KEYS, "elixir", false)

func apply_elixir(item_name: String, stat_name: String) -> void:
	var inv: Dictionary = world.get("inventory") as Dictionary
	if int(inv.get(item_name, 0)) <= 0 or int(world.get("level")) < 50 or elixirs_used >= ELIXIR_LIMIT:
		return
	if not RULES.STAT_KEYS.has(stat_name):
		return
	var spec: Dictionary = RULES.definition(item_name)
	if str(spec.get("kind", "")) != "elixir":
		return
	if str(spec.get("stat", "")) != "" and str(spec["stat"]) != stat_name:
		return
	if _stat_value(stat_name) >= STAT_CAP:
		_message("%s은(는) %d 이상으로 상승할 수 없습니다" % [stat_name, STAT_CAP])
		return
	_increase_stat(stat_name)
	elixirs_used += 1
	_consume(item_name)
	_message("엘릭서 사용 · %s 영구 +1 (%d/%d)" % [stat_name, elixirs_used, ELIXIR_LIMIT])

func _use_half_elixir(item_name: String, spec: Dictionary) -> void:
	if int(world.get("level")) < 50:
		_message("하프 엘릭서는 레벨 50 이상부터 사용합니다")
		return
	if half_elixirs_used >= ELIXIR_LIMIT:
		_message("하프 엘릭서 사용 한도에 도달했습니다")
		return
	var bonus_key: String = str(spec.get("bonus", ""))
	if not permanent_damage_bonuses.has(bonus_key):
		return
	permanent_damage_bonuses[bonus_key] = int(permanent_damage_bonuses.get(bonus_key, 0)) + 1
	half_elixirs_used += 1
	_consume(item_name)
	_message("%s 영구 대미지 +1 (%d/%d)" % [item_name, half_elixirs_used, ELIXIR_LIMIT])

func _use_bless_scroll(scroll_name: String) -> void:
	world.call("_sync_item_instances")
	var instances: Dictionary = world.get("item_instances") as Dictionary
	var inv: Dictionary = world.get("inventory") as Dictionary
	var candidates: Array[String] = []
	for raw_id: Variant in instances.keys():
		var id: String = str(raw_id)
		var physical: Dictionary = instances[id] as Dictionary
		var item_name: String = str(physical.get("name", ""))
		if int(inv.get(item_name, 0)) <= 0:
			continue
		var record: Dictionary = world.call("_find_catalog_item_record", item_name)
		if physical.get("record", {}) is Dictionary and not (physical.get("record", {}) as Dictionary).is_empty():
			record = physical["record"] as Dictionary
		var kind: String = str(world.call("_enhancement_kind_for_record", record))
		if kind not in ["weapon", "armor"]:
			continue
		if BLESSING.bonus_for(str(record.get("grade", "")), kind).is_empty() or BLESSING.is_blessed(physical, record):
			continue
		candidates.append(item_name + "@@@" + id)
	candidates.sort()
	if candidates.is_empty():
		_message("축복 부여가 가능한 미축복 무기·방어구가 없습니다")
		return
	_select_option(scroll_name, candidates, "blessing", false)

# The physical instance ID is mandatory: two copies of the same weapon can
# have different blessings, enchants, pinned catalog variants and equip state.
func apply_bless_scroll(scroll_name: String, target_reference: String, forced_roll: float = -1.0) -> bool:
	if str(RULES.definition(scroll_name).get("kind", "")) != "equipment_bless":
		return false
	var selected: Dictionary = world.call("_parse_enhancement_target", target_reference)
	var item_name: String = str(selected.get("name", ""))
	var item_id: String = str(selected.get("id", ""))
	if item_id.is_empty():
		_message("장비 개체 ID를 지정해야 축복을 부여할 수 있습니다")
		return false
	world.call("_sync_item_instances")
	var instances: Dictionary = world.get("item_instances") as Dictionary
	var inv: Dictionary = world.get("inventory") as Dictionary
	if int(inv.get(scroll_name, 0)) <= 0 or int(inv.get(item_name, 0)) <= 0:
		_message("축복 부여 주문서 또는 대상 장비가 부족합니다")
		return false
	if not instances.has(item_id):
		_message("장비 개체를 찾지 못했습니다")
		return false
	var physical: Dictionary = instances[item_id] as Dictionary
	if str(physical.get("name", "")) != item_name:
		return false
	var record: Dictionary = world.call("_find_catalog_item_record", item_name)
	if physical.get("record", {}) is Dictionary and not (physical.get("record", {}) as Dictionary).is_empty():
		record = physical["record"] as Dictionary
	var kind: String = str(world.call("_enhancement_kind_for_record", record))
	var grade: String = str(record.get("grade", ""))
	var effect: Dictionary = BLESSING.bonus_for(grade, kind)
	if effect.is_empty():
		_message("무기와 방어구에만 축복을 부여할 수 있습니다")
		return false
	if BLESSING.is_blessed(physical, record):
		_message("이미 축복받은 장비입니다")
		return false
	var rng: RandomNumberGenerator = world.get("rng") as RandomNumberGenerator
	var roll: float = forced_roll if forced_roll >= 0.0 else rng.randf_range(0.0, 100.0)
	var success: bool = BLESSING.roll_succeeds(grade, roll)
	if success:
		physical["bless_state"] = "blessed"
		physical["blessed"] = true
		instances[item_id] = physical
	_message("축복 부여 %s · %s [ID %s] · %s" % [
		"성공!" if success else "실패(장비 유지)",
		item_name, item_id, BLESSING.effect_text(grade, kind) if success else "주문서만 소모"
	])
	world.hud.append_log("축복 부여 %s · %s [ID %s]" % ["성공" if success else "실패", item_name, item_id])
	_consume(scroll_name)
	return success

func _use_elemental_scroll(item_name: String, spec: Dictionary) -> void:
	var candidates: Array[String] = []
	world.call("_sync_item_instances")
	var instances: Dictionary = world.get("item_instances") as Dictionary
	for id_key: Variant in instances.keys():
		var id: String = str(id_key)
		var entry: Dictionary = instances[id] as Dictionary
		var weapon_name: String = str(entry.get("name", ""))
		if int((world.get("inventory") as Dictionary).get(weapon_name, 0)) <= 0:
			continue
		var record: Dictionary = world.call("_find_catalog_item_record", weapon_name)
		if str(world.call("_enhancement_kind_for_record", record)) == "weapon":
			candidates.append(weapon_name + "@@@" + id)
	candidates.sort()
	if candidates.is_empty():
		_message("속성을 강화할 무기를 보유하고 있지 않습니다")
		return
	_select_option(item_name, candidates, "element", str(spec.get("element", "")) == "")

func _select_option(item_name: String, candidates: Array[String], purpose: String, choose_element: bool) -> void:
	if candidates.is_empty():
		return
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "%s 선택" % item_name
	dialog.dialog_text = "대상을 고른 다음 확인하세요. 확인 전에는 아이템이 소모되지 않습니다."
	var selector: OptionButton = OptionButton.new()
	selector.custom_minimum_size = Vector2(330, 42)
	for candidate: String in candidates:
		var display_name: String = candidate
		if candidate.contains("@@@"):
			var parts: PackedStringArray = candidate.split("@@@", false, 1)
			var instance_id: String = parts[1]
			var instances: Dictionary = world.get("item_instances") as Dictionary
			var entry: Dictionary = instances.get(instance_id, {}) as Dictionary
			var grade_text: String = "+%d" % int(entry.get("level", 0))
			if purpose == "blessing":
				var record: Dictionary = world.call("_find_catalog_item_record", parts[0])
				if entry.get("record", {}) is Dictionary and not (entry.get("record", {}) as Dictionary).is_empty():
					record = entry["record"] as Dictionary
				var grade: String = str(record.get("grade", "일반"))
				var kind: String = str(world.call("_enhancement_kind_for_record", record))
				display_name = "%s %s [ID %s] · %s · 축복 %0.1f%% (임시)" % [
					grade_text, parts[0], instance_id,
					BLESSING.effect_text(grade, kind), BLESSING.success_chance(grade)
				]
			var element_level: int = int(entry.get("element_level", 0))
			var element_name: String = str(RULES.ELEMENT_NAMES.get(str(entry.get("element", "")), ""))
			if purpose != "blessing":
				display_name = "%s %s [%s] %s" % [grade_text, parts[0], instance_id, ("%s %d단계" % [element_name, element_level]) if element_level > 0 else ""]
		selector.add_item(display_name)
	dialog.get_vbox().add_child(selector)
	var element_selector: OptionButton = null
	if choose_element:
		element_selector = OptionButton.new()
		element_selector.custom_minimum_size = Vector2(330, 42)
		for element_code: String in ["fire", "water", "earth", "wind"]:
			element_selector.add_item(str(RULES.ELEMENT_NAMES[element_code]))
		dialog.get_vbox().add_child(element_selector)
	world.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		if selector.selected >= 0 and selector.selected < candidates.size():
			var candidate: String = candidates[selector.selected]
			if purpose == "elixir":
				apply_elixir(item_name, candidate)
			elif purpose == "blessing":
				apply_bless_scroll(item_name, candidate)
			elif purpose == "element":
				var spec: Dictionary = RULES.definition(item_name)
				var element_code: String = str(spec.get("element", ""))
				if choose_element and element_selector != null:
					element_code = ["fire", "water", "earth", "wind"][element_selector.selected]
				apply_element_scroll(item_name, candidate, element_code)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(440, 270 if choose_element else 215))

func element_stage_cap(weapon_name: String, instance_id: String = "") -> int:
	# Common weapons permit 3; +10/+11 reach 4/5. Legacy special weapons
	# (마족/집행) may reach 5 even without +11, based on community references.
	var levels: Dictionary = world.get("enhancement_levels") as Dictionary
	var enchant: int = maxi(0, int(levels.get(weapon_name, 0)))
	var instances: Dictionary = world.get("item_instances") as Dictionary
	if instance_id != "" and instances.has(instance_id):
		enchant = maxi(0, int((instances[instance_id] as Dictionary).get("level", 0)))
	if weapon_name.contains("마족") or weapon_name.contains("집행"):
		return 5
	if enchant >= 11:
		return 5
	if enchant >= 10:
		return 4
	return 3

func apply_element_scroll(scroll_name: String, weapon_reference: String, element_name: String) -> void:
	var selection: Dictionary = world.call("_parse_enhancement_target", weapon_reference)
	var weapon_name: String = str(selection.get("name", weapon_reference))
	var instance_id: String = str(selection.get("id", ""))
	world.call("_sync_item_instances")
	if instance_id == "":
		instance_id = str(world.call("_chosen_instance", weapon_name))
	var instances: Dictionary = world.get("item_instances") as Dictionary
	var inv: Dictionary = world.get("inventory") as Dictionary
	if int(inv.get(scroll_name, 0)) <= 0 or int(inv.get(weapon_name, 0)) <= 0:
		return
	if not instances.has(instance_id) or str((instances[instance_id] as Dictionary).get("name", "")) != weapon_name:
		_message("해당 무기 개체를 찾을 수 없습니다")
		return
	var spec: Dictionary = RULES.definition(scroll_name)
	if str(spec.get("kind", "")) != "element" or not RULES.ELEMENT_NAMES.has(element_name):
		return
	if str(spec.get("element", "")) != "" and str(spec["element"]) != element_name:
		return
	var weapon: Dictionary = world.call("_find_catalog_item_record", weapon_name)
	if str(world.call("_enhancement_kind_for_record", weapon)) != "weapon":
		return
	var entry: Dictionary = instances[instance_id] as Dictionary
	var previous_type: String = str(entry.get("element", ""))
	var previous_level: int = int(entry.get("element_level", 0))
	if previous_type != "" and previous_type != element_name:
		_message("다른 속성을 강화한 무기입니다. 속성 변경은 별도 기능입니다")
		return
	var cap: int = element_stage_cap(weapon_name, instance_id)
	if previous_level >= cap:
		_message("%s [%s] 속성 강화 한도 %d단계입니다" % [weapon_name, instance_id, cap])
		return
	var chance: float = RULES.element_success_chance(previous_level)
	var rng: RandomNumberGenerator = world.get("rng") as RandomNumberGenerator
	var success: bool = rng.randf_range(0.0, 100.0) < chance
	if success:
		entry["element"] = element_name
		entry["element_level"] = previous_level + 1
		instances[instance_id] = entry
	_consume(scroll_name)
	_message("%s [%s] · %s %s · 현재 %d단계 (확률 %.1f%%)" % [
		weapon_name, instance_id, str(RULES.ELEMENT_NAMES[element_name]),
		"성공" if success else "실패/무기 유지",
		previous_level + (1 if success else 0), chance
	])
