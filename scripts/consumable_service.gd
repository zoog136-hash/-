extends Node
class_name TwilightConsumableService

# An isolated runtime extension; world map/rendering/combat animation are not changed.
const REGIONAL_RETURN = preload("res://scripts/quickslots/regional_return.gd")
const RULES = preload("res://scripts/consumable_rules.gd")
const COORD = preload("res://scripts/maps/world_coordinates.gd")
const ELEMENT_RULES = preload("res://scripts/elemental_rules.gd")
const QUEST_RETURN239 = preload("res://scripts/quests/quest_return239.gd")
const BLESSING = preload("res://scripts/equipment_blessing.gd")
const NATIVE_STACK = preload("res://scripts/loot/current523_native_stack.gd")
const ELIXIR_LIMIT: int = 10
const STAT_CAP: int = 45

var world: Variant = null
var source_skill_book_receipts: Array = []
var elemental_enchants: Dictionary = {}
var elixirs_used: int = 0
var half_elixirs_used: int = 0
var permanent_damage_bonuses: Dictionary = {
	"melee_damage": 0, "ranged_damage": 0, "magic_damage": 0
}

## Compatible PR247 bc0ce721 result interface. The same movement consumer is
## shared with the exact quest-receipt input, without a transient native grant.
func use_owned_native_return(item_name: String) -> Dictionary:
	return _commit_return239(item_name)

func use_owned_quest_return(physical_id: String) -> Dictionary:
	var input: Dictionary=QUEST_RETURN239.prepare(world,physical_id)
	if not input.ok:return {"ok":false,"saved":false,"handled":true,"consumed":0,"reason":str(input.reason),"source_item_id":239}
	return _commit_return239(str(input.inventory_key),input)

func _commit_return239(item_name: String, quest_input: Dictionary={}) -> Dictionary:
	var is_quest: bool=not quest_input.is_empty()
	var record: Dictionary=quest_input.get("record",{}) if is_quest else world._find_catalog_item_record(item_name)
	var stack: Dictionary=REGIONAL_RETURN.stack_identity(str(record.get("name","")) if is_quest else item_name,record)
	var result: Dictionary={"ok":false,"saved":false,"handled":is_quest or REGIONAL_RETURN.claims_identity(item_name,record),"consumed":0,"inventory_key":item_name,"source_item_id":239}
	if world.quest_service.save_blocked:
		result["reason"]="저장 보호 중 · 정상 저장 불러오기 필요";return result
	if stack.is_empty() or stack.get("origin")!="patch523_native_normal" or int(stack.get("item_class_id",0))!=239:
		result["reason"]="정확한 원본239 Normal 소지 키가 필요합니다 · 주문서 보존";return result
	if is_quest and not QUEST_RETURN239.current(world,quest_input):
		result["reason"]="원본 퀘스트 소지 영수증 변경 · 주문서 보존";return result
	if not world._patch523_item_allowed() or world.patch523_npc_spells.blocks("CannotTeleport"):
		result["reason"]="현재 원본 아이템 사용·이동 제한 · 주문서 보존";return result
	var physical_id: String=str(quest_input.get("physical_id",""))
	if int(world.inventory.get(item_name,0))<1 or world._item_locked(item_name,physical_id) or world._item_locked(item_name,"") or int(world.hp)<=0 or _player_busy_for_travel():
		result["reason"]="소지량·잠금·생존·이동 상태 조건 미충족 · 주문서 보존";return result
	var problem: String=preload("res://scripts/loot/patch523_item_use.gd").eligibility(world,record)
	if not problem.is_empty():result["reason"]=problem;return result
	if world.has_method("current523_aden_source_active") and world.current523_aden_source_active():
		# Existing exact ownership/debit preparation above remains the owner.
		# The map adapter supplies only its destination and normal save boundary.
		var source_overrides: Dictionary=quest_input.get("override",{}).duplicate(true)
		if not is_quest:
			var source_inventory: Dictionary=world.inventory.duplicate(true)
			source_inventory[item_name]=int(source_inventory[item_name])-1
			if int(source_inventory[item_name])==0:source_inventory.erase(item_name)
			source_overrides["inventory"]=source_inventory
		var returned: Dictionary=world.return_current523_source_to_aden(source_overrides)
		if not returned.get("ok",false):result.merge(returned,true);return result
		world.inventory=source_overrides.inventory
		if source_overrides.has("item_instances"):world.item_instances=source_overrides.item_instances
		if source_overrides.has("quest_state"):world.quest_service.import_state(source_overrides.quest_state)
		world.deferred_save.cancel();world.hud.refresh_inventory(world.inventory);world._update_hud()
		result.merge(returned,true)
		result.merge({"ok":true,"saved":true,"handled":true,"consumed":1,"source_item_id":239,"message":"아덴으로 귀환했습니다 · 자체 지정 목적지"},true)
		if is_quest:result["physical_id"]=physical_id;result["ownership_origin"]="quest523_receipt"
		return result
	if str(world.active_map_id)!="aden_world" or world.field_map==null:
		result["reason"]="이 지역의 원자 귀환 목적지 연결이 필요합니다 · 주문서 보존";return result
	var destination: Vector2=_safe_region_position()
	if destination==Vector2.INF:destination=world._spawn_position()
	if not destination.is_finite() or not world.field_map.walkable(destination) or not world.field_map.point_clear(destination):
		result["reason"]="검증된 기존 아덴 귀환 위치 없음 · 주문서 보존";return result
	var overrides: Dictionary=quest_input.get("override",{}).duplicate(true)
	if not is_quest:
		var inventory: Dictionary=world.inventory.duplicate(true)
		inventory[item_name]=int(inventory[item_name])-1
		if int(inventory[item_name])==0:inventory.erase(item_name)
		overrides["inventory"]=inventory
	var old_position: Vector2=world.player.global_position
	var path: String=world.save_path()
	var prior_sha: String=FileAccess.get_sha256(path)
	_teleport_player(destination)
	var save_error: Error=world._save_game(true,overrides)
	if save_error!=OK:
		# Confirm the complete debit/receipt AND movement candidate. An error
		# after the atomic write must not expose stale ownership for a retry.
		var durable: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		var expected: Dictionary=JSON.parse_string(JSON.stringify(overrides))
		var confirmed: bool=durable is Dictionary
		if confirmed:
			for key: String in expected:
				if durable.get(key)!=expected[key]:confirmed=false;break
		if confirmed:confirmed=durable.get("map_id")=="aden_world" and durable.get("position")==[destination.x,destination.y]
		if confirmed:confirmed=world.equipment_collections.accept_load(durable)
		if not confirmed:
			_teleport_player(old_position)
			if FileAccess.get_sha256(path)!=prior_sha:world.quest_service.save_blocked=true;result["uncertain"]=true
			world._update_hud()
			result["save_error"]=save_error
			result["reason"]="저장 결과 미확정 · 재사용 중지, 정상 저장 불러오기 필요" if result.get("uncertain",false) else "귀환 저장 실패 · 위치와 정확한 원본 주문서 보존"
			return result
	world.inventory=overrides.inventory
	if overrides.has("item_instances"):world.item_instances=overrides.item_instances
	if overrides.has("quest_state"):world.quest_service.import_state(overrides.quest_state)
	world.deferred_save.cancel()
	world.hud.refresh_inventory(world.inventory);world._update_hud()
	result.merge({"ok":true,"saved":true,"handled":true,"consumed":1,"map_id":str(world.active_map_id),"position":[destination.x,destination.y],"message":"아덴 마을로 귀환했습니다 · TWILIGHT 기존 목적지"},true)
	if is_quest:result["physical_id"]=physical_id;result["ownership_origin"]="quest523_receipt"
	return result

func setup(world_node: Node) -> void:
	world = world_node

var source_native_bag_uses_present: bool=false
var source_native_bag_uses: Variant={}

var source_native_stack_partitions_present: bool=false
var source_native_stack_partitions: Variant={}

var source_native_stack_uses_present: bool=false
var source_native_stack_uses: Variant={}

var instant_cure_present: bool=false
var instant_cure_state: Variant={}

var reusable_state_present: bool=false
var reusable_state: Variant={}

var source_alchemy_item_uses_present: bool=false
var source_alchemy_item_uses: Variant={}
var source_ground_acquisitions_present: bool=false
var source_ground_acquisitions: Variant={}
var source_quest_craft_receipts_present: bool=false
var source_quest_craft_receipts: Variant={}
var source_monsterbook_grants_present: bool=false
var source_monsterbook_grants: Variant={}

var quest_equipment_receipts_present: bool=false
var quest_equipment_receipts: Variant=[]

func export_state() -> Dictionary:
	var state: Dictionary={
		"elemental_enchants": elemental_enchants.duplicate(true),
		"elixirs_used": elixirs_used,
		"half_elixirs_used": half_elixirs_used,
		"permanent_damage_bonuses": permanent_damage_bonuses.duplicate(true),
		"source_skill_book_receipts": source_skill_book_receipts.duplicate(true)
	}

	if source_native_bag_uses_present:state["source_native_bag_uses"]=source_native_bag_uses.duplicate(true) if source_native_bag_uses is Dictionary or source_native_bag_uses is Array else source_native_bag_uses
	if source_native_stack_partitions_present:state["source_native_stack_partitions"]=source_native_stack_partitions.duplicate(true) if source_native_stack_partitions is Dictionary or source_native_stack_partitions is Array else source_native_stack_partitions
	if source_native_stack_uses_present:state["source_native_stack_uses"]=source_native_stack_uses.duplicate(true) if source_native_stack_uses is Dictionary or source_native_stack_uses is Array else source_native_stack_uses
	if source_alchemy_item_uses_present:state["source_alchemy_item_uses"]=source_alchemy_item_uses.duplicate(true) if source_alchemy_item_uses is Dictionary or source_alchemy_item_uses is Array else source_alchemy_item_uses
	if source_ground_acquisitions_present:state["source_ground_acquisitions"]=source_ground_acquisitions.duplicate(true) if source_ground_acquisitions is Dictionary or source_ground_acquisitions is Array else source_ground_acquisitions
	if source_quest_craft_receipts_present:state["source_quest_craft_receipts"]=source_quest_craft_receipts.duplicate(true) if source_quest_craft_receipts is Dictionary or source_quest_craft_receipts is Array else source_quest_craft_receipts
	if source_monsterbook_grants_present:state["source_monsterbook_grants"]=source_monsterbook_grants.duplicate(true) if source_monsterbook_grants is Dictionary or source_monsterbook_grants is Array else source_monsterbook_grants
	if instant_cure_present:state["source_instant_cure_uses"]=instant_cure_state.duplicate(true) if instant_cure_state is Dictionary or instant_cure_state is Array else instant_cure_state
	if reusable_state_present:state["source_reusable_item_uses"]=reusable_state.duplicate(true) if reusable_state is Dictionary or reusable_state is Array else reusable_state
	if not source_skill_book_receipts.is_empty():state["source_skill_book_receipts"]=source_skill_book_receipts.duplicate(true)
	if quest_equipment_receipts_present:state["source_quest_equipment_receipts"]=quest_equipment_receipts.duplicate(true) if quest_equipment_receipts is Array or quest_equipment_receipts is Dictionary else quest_equipment_receipts
	return state

func import_state(input: Variant) -> void:
	source_native_bag_uses_present=input is Dictionary and input.has("source_native_bag_uses")
	var bag_uses: Variant=input.get("source_native_bag_uses",{}) if input is Dictionary else {}
	source_native_bag_uses=bag_uses.duplicate(true) if bag_uses is Dictionary or bag_uses is Array else bag_uses
	source_native_stack_partitions_present=input is Dictionary and input.has("source_native_stack_partitions")
	var partitions: Variant=input.get("source_native_stack_partitions",{}) if input is Dictionary else {}
	source_native_stack_partitions=partitions.duplicate(true) if partitions is Dictionary or partitions is Array else partitions
	source_native_stack_uses_present=input is Dictionary and input.has("source_native_stack_uses")
	var stack_uses: Variant=input.get("source_native_stack_uses",{}) if input is Dictionary else {}
	source_native_stack_uses=stack_uses.duplicate(true) if stack_uses is Dictionary or stack_uses is Array else stack_uses
	source_monsterbook_grants_present=input is Dictionary and input.has("source_monsterbook_grants")
	var book_grants: Variant=input.get("source_monsterbook_grants",{}) if input is Dictionary else {}
	source_monsterbook_grants=book_grants.duplicate(true) if book_grants is Dictionary or book_grants is Array else book_grants
	source_quest_craft_receipts_present=input is Dictionary and input.has("source_quest_craft_receipts")
	var craft_receipts: Variant=input.get("source_quest_craft_receipts",{}) if input is Dictionary else {}
	source_quest_craft_receipts=craft_receipts.duplicate(true) if craft_receipts is Dictionary or craft_receipts is Array else craft_receipts
	source_ground_acquisitions_present=input is Dictionary and input.has("source_ground_acquisitions")
	var ground_receipts: Variant=input.get("source_ground_acquisitions",{}) if input is Dictionary else {}
	source_ground_acquisitions=ground_receipts.duplicate(true) if ground_receipts is Dictionary or ground_receipts is Array else ground_receipts
	source_alchemy_item_uses_present=input is Dictionary and input.has("source_alchemy_item_uses")
	var alchemy_uses: Variant=input.get("source_alchemy_item_uses",{}) if input is Dictionary else {}
	source_alchemy_item_uses=alchemy_uses.duplicate(true) if alchemy_uses is Dictionary or alchemy_uses is Array else alchemy_uses
	instant_cure_present=input is Dictionary and input.has("source_instant_cure_uses")
	var cure: Variant=input.get("source_instant_cure_uses",{}) if input is Dictionary else {}
	instant_cure_state=cure.duplicate(true) if cure is Dictionary or cure is Array else cure
	reusable_state_present=input is Dictionary and input.has("source_reusable_item_uses")
	var reusable: Variant=input.get("source_reusable_item_uses",{}) if input is Dictionary else {}
	reusable_state=reusable.duplicate(true) if reusable is Dictionary or reusable is Array else reusable
	quest_equipment_receipts_present=input is Dictionary and input.has("source_quest_equipment_receipts")
	var gear: Variant=input.get("source_quest_equipment_receipts",[]) if input is Dictionary else []
	quest_equipment_receipts=gear.duplicate(true) if gear is Array or gear is Dictionary else gear
	source_skill_book_receipts.clear()
	elemental_enchants.clear()
	elixirs_used = 0
	half_elixirs_used = 0
	source_skill_book_receipts = []
	permanent_damage_bonuses = {"melee_damage":0, "ranged_damage":0, "magic_damage":0}
	if not (input is Dictionary):
		return
	var data: Dictionary = input as Dictionary
	if data.get("source_skill_book_receipts") is Array:source_skill_book_receipts=data.source_skill_book_receipts.duplicate(true)
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

func try_use(item_name: String,selected_instance: String="") -> bool:
	var stack: Dictionary=preload("res://scripts/loot/current523_native_stack.gd").try_use(world,item_name,selected_instance)
	if stack.get("handled",false):
		if stack.get("silent",false):return true # The owner shows its own chooser or message.
		_message(str(stack.get("message",stack.get("reason","원본 물리 수량 확인 필요"))))
		if stack.get("ok",false):world.hud.refresh_inventory(world.inventory);world._update_hud()
		return true
	var native: Dictionary=world.option_awakening.use_source_awakening_item(item_name,selected_instance)
	if native.get("handled",false):
		if native.get("ok",false):world._update_hud();world.hud.refresh_inventory(world.inventory)
		_message(str(native.get("message",native.get("error","원본 각성 물품 확인 필요"))))
		return true
	if not item_name.is_empty() and item_name==str(preload("res://scripts/cards/native_card_acquisition.gd").record().get("name","")):
		var received: Dictionary=world.option_awakening.use_nemesis_ticket(item_name,selected_instance)
		if bool(received.get("ok",false)):
			world._update_hud();world.hud.refresh_inventory(world.inventory)
			_message("네메시스 마법인형 획득" if bool(received.get("new",false)) else "네메시스 중복 카드 1장 획득")
		else:_message(str(received.get("error","카드권 사용 실패")))
		return true
	if not item_name.is_empty() and item_name==str(preload("res://scripts/cards/native_relic_reward_box.gd").record().get("name","")):
		var opened: Dictionary=world.option_awakening.use_relic_reward_box(item_name,selected_instance)
		if bool(opened.get("ok",false)):
			world._update_hud();world.hud.refresh_inventory(world.inventory)
			_message("상자 개봉 · 에바의 계시와 특별한 성물 소환 주문서 각 1개 획득")
		else:_message(str(opened.get("error","상자 개봉 실패")))
		return true
	if not item_name.is_empty() and item_name==str(preload("res://scripts/cards/native_relic_reward_box.gd").record(365758).get("name","")):
		_message("추가 성물 소환 주문서의 적용·기간 규칙 확인 필요 · 아이템 보존")
		return true
	if not item_name.is_empty() and item_name==str(preload("res://scripts/cards/native_relic_unlock_item.gd").record().get("name","")):
		var result: Dictionary=world.option_awakening.use_relic_unlock_item(item_name,selected_instance)
		if bool(result.get("handled",false)):
			if bool(result.get("ok",false)):
				world._update_hud();world.hud.refresh_inventory(world.inventory)
				_message("에바의 계시 습득 · 추가 성물 소환 해금")
			else:_message(str(result.get("error","성물 해금 아이템 사용 실패")))
			return true
	var source_record: Dictionary = world.call("_find_catalog_item_record", item_name)
	if preload("res://scripts/loot/patch523_item_use.gd").try_use(world, source_record): return true
	if preload("res://scripts/shop/source523_wisdom.gd").try_use(world,item_name):return true
	if preload("res://scripts/shop/source523_restoration.gd").try_use(world,item_name):return true
	if try_use_regional_return(item_name): return true
	if not item_name.is_empty() and item_name==str(preload("res://scripts/cards/native_doll_unlock_item.gd").record().get("name","")):
		if world.has_method("_patch523_item_allowed") and not bool(world.call("_patch523_item_allowed")): return true
		var source_result: Dictionary=world.option_awakening.use_native_unlock_item(item_name,selected_instance)
		if bool(source_result.get("handled",false)):
			if bool(source_result.get("ok",false)):
				world._update_hud();world.hud.refresh_inventory(world.inventory)
				_message("에바의 부름 습득 · 추가 인형 소환 해금")
			else:_message(str(source_result.get("error","해금 아이템 사용 실패")))
			return true
	var spec: Dictionary = RULES.definition(item_name)
	if spec.is_empty() and REGIONAL_RETURN.supported(item_name): spec = {"kind":"return"}
	if spec.is_empty():
		return false
	if world.has_method("_patch523_item_allowed") and not bool(world.call("_patch523_item_allowed")): return true
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
		"ain_charge", "ain_orb":
			if bool(world.call("_apply_ain_consumable", item_name, spec)):
				_consume(item_name)
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
		"element_change", "element_reset":
			_use_element_management_scroll(item_name, spec)
	return true

func _message(value: String) -> void:
	world.hud.show_message(value)

func _consume(item_name: String) -> void:
	var inv: Dictionary = world.get("inventory") as Dictionary
	var infinite: bool = bool(world.regional_return_stack(item_name).get("infinite", false))
	inv[item_name] = maxi(0, int(inv.get(item_name, 0)) - (0 if infinite else 1))
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
	var maximum: int = int(world.call("_effective_max_mp"))
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
	if is_instance_valid(world.world_interactions): world.world_interactions.clear_selection()
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
	if world.has_method("current523_aden_source_active") and world.call("current523_aden_source_active"):
		_use_source_aden_return(item_name)
		return
	# A current source field cannot inherit a PC destination from its host ID.
	var current_field: Variant = world.get("field_map")
	if current_field is OriginalPlayableField and bool(current_field.get_meta("source_map84",false)):
		_message("현재 원본 지도의 검증된 귀환 목적지가 연결되지 않았습니다 · 주문서 보존")
		return
	if int(world.regional_return_stack(item_name).get("item_class_id", 0)) == 126424:
		_use_regional_return(item_name)
		return
	if _player_busy_for_travel():
		_message("현재 상태에서는 귀환할 수 없습니다")
		return
	if world.get("field_map") is OriginalPlayableField and world.field_map.uses_original_gameplay_rules():
		if world.call("return_from_original_map"): _consume(item_name)
		return
	if not (world.get("maps_by_id") as Dictionary).has("aden_world"):
		_message("귀환 가능한 마을을 찾을 수 없습니다")
		return
	if str(world.get("active_map_id")) != "aden_world":
		world.call("_set_map", "aden_world", false)
		# A missing/corrupt native PNG pack deliberately leaves the old field
		# active. Do not spend the scroll or move within that dungeon on failure.
		if str(world.get("active_map_id")) != "aden_world":
			return
	var place: Vector2 = _safe_region_position()
	if place != Vector2.INF:
		_teleport_player(place)
	else:
		_teleport_player(world.call("_spawn_position"))
	_consume(item_name)
	_message("아덴 마을로 귀환했습니다" + (" · TWILIGHT 귀환 효과" if world.regional_return_stack(item_name).get("origin") == "patch523_native_normal" else ""))

func _use_source_aden_return(item_name: String) -> void:
	var stack: Dictionary=world.regional_return_stack(item_name)
	var count: int=int(world.inventory.get(item_name,0))
	if int(stack.get("item_class_id",0))==126424 and not REGIONAL_RETURN.DATA.data.lands.has(str(world._regional_return_land())):
		_message("잊혀진 귀환 주문서는 원본 지정 지역에서만 사용할 수 있습니다 · 주문서 보존");return
	if stack.is_empty() or count<1 or _player_busy_for_travel() or world._item_locked(item_name,"") or not world._patch523_item_allowed() or world.patch523_npc_spells.blocks("CannotTeleport"):
		_message("현재 귀환 주문서의 소지·잠금·이동 조건이 맞지 않아 보존합니다.");return
	var changes: Dictionary={}
	if not bool(stack.get("infinite",false)):
		var inventory: Dictionary=world.inventory.duplicate(true)
		inventory[item_name]=count-1
		if int(inventory[item_name])==0:inventory.erase(item_name)
		changes["inventory"]=inventory
	var result: Dictionary=world.return_current523_source_to_aden(changes)
	if result.get("ok",false):
		if changes.has("inventory"):world.inventory=changes.inventory
		world.deferred_save.cancel();world.hud.refresh_inventory(world.inventory);world._update_hud()
	_message(str(result.get("reason","아덴 귀환 결과 확인 필요")))

func _random_destination() -> Vector2:
	var field: Variant = world.get("field_map")
	var start: Vector2 = world.player.global_position
	var rng: RandomNumberGenerator = world.get("rng") as RandomNumberGenerator
	if field is OriginalPlayableField:
		if field.uses_original_gameplay_rules() and not bool(field.definition.rules.get("teleportable",0)): return Vector2.INF
		return field.random_landing(rng,start)
	if field is NativePngField:
		# A PNG canvas can be almost entirely closed terrain. Sample the cached,
		# reachable floor instead of repeatedly guessing across the whole image.
		return field.random_landing(rng,start,160.0)
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
	if world.growth.travel.enabled():
		world.growth.travel.open({"kind":"scroll","name":item_name})
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
		record=world.PATCH523_ENHANCE.prepare(world.patch523_equipment,record,1)
		var kind: String = str(world.call("_enhancement_kind_for_record", record))
		if kind not in ["weapon", "armor", "accessory"]:
			continue
		if BLESSING.bonus_for(str(record.get("grade", "")), kind, record).is_empty() or BLESSING.is_blessed(physical, record):
			continue
		candidates.append(item_name + "@@@" + id)
	candidates.sort()
	if candidates.is_empty():
		_message("축복 부여가 가능한 미축복 장비가 없습니다")
		return
	var guaranteed: bool = bool(NATIVE_STACK.bless_scroll_owned(world, scroll_name).get("spec", {}).get("guaranteed", false))
	# Use the game's native touch-friendly equipment chooser, not a floating
	# ConfirmationDialog which can be unreachable in Android editor/play mode.
	var views: Array = []
	for reference: String in candidates:
		var parts: PackedStringArray = reference.split("@@@", false, 1)
		if parts.size() != 2: continue
		var physical: Dictionary = instances.get(parts[1], {}) as Dictionary
		var record: Dictionary = world.call("_find_catalog_item_record", parts[0])
		if physical.get("record", {}) is Dictionary and not (physical.get("record", {}) as Dictionary).is_empty():
			record = physical["record"] as Dictionary
		var grade: String = str(record.get("grade", "일반"))
		record=world.PATCH523_ENHANCE.prepare(world.patch523_equipment,record,1)
		var kind: String = str(world.call("_enhancement_kind_for_record", record))
		views.append({"name": parts[0], "target_id": reference, "instance_id": parts[1],
			"level": int(physical.get("level", 0)), "success_chance": BLESSING.success_chance(grade, record, guaranteed),
			"success_basis": BLESSING.success_basis(grade, record, guaranteed),
			"bonus_text": BLESSING.effect_text(grade, kind, record), "equipped": false})
	world.hud.call("open_blessing_targets", scroll_name, views)

# The physical instance ID is mandatory: two copies of the same weapon can
# have different blessings, enchants, pinned catalog variants and equip state.
func apply_bless_scroll(scroll_name: String, target_reference: String, forced_roll: float = -1.0) -> bool:
	if world.has_method("_patch523_item_allowed") and not bool(world.call("_patch523_item_allowed")): return false
	# An original 523 bless scroll is a physical stack debited through its
	# grant receipt; other scrolls keep the existing rule and name count.
	var native: Dictionary = NATIVE_STACK.bless_scroll_owned(world, scroll_name)
	if native.has("error"):
		_message(str(native.error) + " · 주문서 보존")
		return false
	if native.is_empty() and str(RULES.definition(scroll_name).get("kind", "")) != "equipment_bless":
		return false
	var guaranteed: bool = bool(native.get("spec", {}).get("guaranteed", false))
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
	record=world.PATCH523_ENHANCE.prepare(world.patch523_equipment,record,1)
	var kind: String = str(world.call("_enhancement_kind_for_record", record))
	var grade: String = str(record.get("grade", ""))
	var effect: Dictionary = BLESSING.bonus_for(grade, kind, record)
	if effect.is_empty():
		_message("이 장비에는 확인된 축복 옵션이 없습니다")
		return false
	if BLESSING.is_blessed(physical, record):
		_message("이미 축복받은 장비입니다")
		return false
	if bool(world.call("_item_locked",item_name,item_id)):
		_message("축복하려면 장비 잠금을 해제하세요")
		return false
	var rng: RandomNumberGenerator = world.get("rng") as RandomNumberGenerator
	var before: Dictionary={"inventory":inv.duplicate(true),"instances":instances.duplicate(true),"rng":rng.state,
		"equipped":world.equipped_items.duplicate(true),"hp":world.hp,"mp":world.mp}
	var roll: float = forced_roll if forced_roll >= 0.0 else rng.randf_range(0.0, 100.0)
	var success: bool = BLESSING.roll_succeeds(grade, roll, record, guaranteed)
	if success:
		physical["bless_state"] = "blessed"
		physical["blessed"] = true
		physical["source_bless_code"]=2
		record["bless_state"]="blessed"
		record["blessed"]=true
		if record.get("source_m_native_item",false): record["source_bless_raw"]=2
		physical["record"]=world.PATCH523_ENHANCE.prepare(world.patch523_equipment,record,2)
		instances[item_id] = physical
	var state_before: Dictionary = export_state()
	if native.is_empty():
		inv[scroll_name]=int(inv[scroll_name])-1
		if int(inv[scroll_name])<=0: inv.erase(scroll_name)
	else:
		# Staged from the live state, which already holds the blessed target.
		var paid: Dictionary = NATIVE_STACK.stage_debit(world, [native.request])
		if not paid.get("ok", false):
			instances.clear();instances.merge(before.instances)
			rng.state=int(before.rng)
			_message(str(paid.get("reason", paid.get("error", "원본 축복 주문서 차감 확인 필요"))) + " · 주문서·장비 보존")
			return false
		world.inventory = paid.overrides.inventory
		world.item_instances = paid.overrides.item_instances
		import_state(paid.overrides.consumable_state)
	world.call("_invalidate_equipment_static")
	world.hp=mini(world.hp,int(world.call("_effective_max_hp")))
	world.mp=mini(world.mp,int(world.call("_effective_max_mp")))
	if int(world.call("_save_game",true))!=OK:
		inv.clear();inv.merge(before.inventory)
		instances.clear();instances.merge(before.instances)
		if not native.is_empty():
			world.inventory=inv;world.item_instances=instances;import_state(state_before)
		world.equipped_items=before.equipped
		rng.state=int(before.rng)
		world.hp=int(before.hp);world.mp=int(before.mp)
		world.call("_invalidate_equipment_static")
		world.call("_update_hud")
		_message("축복 저장 실패 · 주문서·장비·난수 상태를 보존했습니다")
		return false
	_message("축복 부여 %s · %s [ID %s] · %s" % [
		"성공!" if success else "실패(장비 유지)",
		item_name, item_id, BLESSING.effect_text(grade, kind, record) if success else "주문서만 소모"
	])
	world.hud.append_log("축복 부여 %s · %s [ID %s]" % ["성공" if success else "실패", item_name, item_id])
	world.hud.refresh_inventory(world.inventory)
	world.call("_update_hud")
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

func _use_element_management_scroll(item_name: String, spec: Dictionary) -> void:
	world.call("_sync_item_instances")
	var instances: Dictionary = world.get("item_instances") as Dictionary
	var candidates: Array[String] = []
	for key: Variant in instances.keys():
		var id: String = str(key)
		var entry: Dictionary = instances[key] as Dictionary
		var name_value: String = str(entry.get("name", ""))
		if int(entry.get("element_level", 0)) <= 0 or int((world.get("inventory") as Dictionary).get(name_value, 0)) <= 0:
			continue
		if str(world.call("_enhancement_kind_for_record", world.call("_find_catalog_item_record", name_value))) == "weapon":
			candidates.append(name_value + "@@@" + id)
	candidates.sort()
	if candidates.is_empty():
		_message("속성 강화된 무기가 없습니다")
		return
	var kind: String = str(spec.get("kind", ""))
	_select_option(item_name, candidates, kind, kind == "element_change")

func apply_element_management(scroll_name: String, weapon_reference: String, new_element: String = "") -> void:
	var spec: Dictionary = RULES.definition(scroll_name)
	var kind: String = str(spec.get("kind", ""))
	if kind != "element_change" and kind != "element_reset":
		return
	var selection: Dictionary = world.call("_parse_enhancement_target", weapon_reference)
	var item_id: String = str(selection.get("id", ""))
	var item_name: String = str(selection.get("name", ""))
	var inventory: Dictionary = world.get("inventory") as Dictionary
	var instances: Dictionary = world.get("item_instances") as Dictionary
	if not instances.has(item_id) or int(inventory.get(scroll_name, 0)) <= 0 or int(inventory.get(item_name, 0)) <= 0:
		return
	var item: Dictionary = instances[item_id] as Dictionary
	if str(item.get("name", "")) != item_name or int(item.get("element_level", 0)) <= 0:
		return
	if item.get("equipment523", {}) is Dictionary and item.get("equipment523", {}).has("elemental_smith"):
		_apply_processed_element_management(scroll_name,item_id,item_name,new_element,kind)
		return
	if kind == "element_change":
		if not RULES.ELEMENT_NAMES.has(new_element) or new_element == str(item.get("element", "")):
			_message("기존 속성과 다른 속성을 선택하세요")
			return
		item["element"] = new_element
	else:
		item["element"] = ""
		item["element_level"] = 0
	instances[item_id] = item
	_consume(scroll_name)
	_message("%s [%s] 속성 %s" % [item_name, item_id, "변경 완료" if kind == "element_change" else "초기화 완료"])

func _apply_processed_element_management(scroll_name: String, item_id: String, item_name: String, new_element: String, kind: String) -> void:
	if not world.item_instances[item_id].equipment523.elemental_smith is Dictionary:
		_message("기존 속성 세공 기록을 해석할 수 없어 장비와 주문서를 보존합니다")
		return
	if kind == "element_change" and (not RULES.ELEMENT_NAMES.has(new_element) or new_element == str(world.item_instances[item_id].get("element", ""))):
		_message("기존 속성과 다른 속성을 선택하세요")
		return
	if world.has_method("_item_locked") and (world.call("_item_locked",item_name,item_id) or world.call("_item_locked",scroll_name,"")):
		_message("잠긴 장비와 주문서는 사용할 수 없습니다")
		return
	# This legacy chooser selects a named stack, not a physical source reward.
	# Refuse ambiguous physical scrolls rather than lose their remaining quantity.
	for physical: Dictionary in world.item_instances.values():
		if str(physical.get("name", "")) == scroll_name:
			_message("물리 개체로 보관한 주문서는 정확한 개체 선택 경로가 필요합니다")
			return
	var staged_items: Dictionary = world.item_instances.duplicate(true)
	var staged_inventory: Dictionary = world.inventory.duplicate(true)
	var changed: Dictionary = staged_items[item_id]
	changed["equipment523_retired_elemental_smith"] = changed.equipment523.elemental_smith.duplicate(true)
	changed.equipment523.erase("elemental_smith")
	changed["element"] = new_element if kind == "element_change" else ""
	if kind == "element_reset": changed["element_level"] = 0
	staged_inventory[scroll_name] = int(staged_inventory[scroll_name]) - 1
	if int(staged_inventory[scroll_name]) == 0: staged_inventory.erase(scroll_name)
	var saved: Error = world.call("_save_game",true,{"inventory":staged_inventory,"item_instances":staged_items})
	if saved != OK:
		if world.has_method("_equipment523_commit") and world.equipment523._saved_candidate(world,{"inventory":staged_inventory,"item_instances":staged_items}):
			world.equipment523.save_blocked = true
			world.equipment523.problem = "속성 변경 저장 후보의 활성화가 불확실합니다. 정상 저장을 다시 불러오세요."
		_message("속성 변경 저장 실패 · 주문서와 세공 효과를 보존했습니다")
		return
	world.item_instances = staged_items
	world.inventory = staged_inventory
	world.call("_update_hud")
	_message("%s [%s] 속성 %s · 기존 속성 세공 효과 소실" % [item_name,item_id,"변경 완료" if kind == "element_change" else "초기화 완료"])

func _select_option(item_name: String, candidates: Array[String], purpose: String, choose_element: bool) -> void:
	if candidates.is_empty():
		return
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "%s 선택" % item_name
	dialog.dialog_text = "대상을 고른 다음 확인하세요. 확인 전에는 아이템이 소모되지 않습니다."
	if purpose in ["element_change", "element_reset"]:
		dialog.dialog_text += "\n속성 변경·초기화 시 기존 속성 세공 효과가 사라집니다."
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
				record=world.PATCH523_ENHANCE.prepare(world.patch523_equipment,record,1)
				var kind: String = str(world.call("_enhancement_kind_for_record", record))
				var guaranteed: bool = bool(NATIVE_STACK.bless_scroll_owned(world, item_name).get("spec", {}).get("guaranteed", false))
				display_name = "%s %s [ID %s] · %s · 축복 %0.1f%% (%s)" % [
					grade_text, parts[0], instance_id,
					BLESSING.effect_text(grade, kind, record), BLESSING.success_chance(grade, record, guaranteed), BLESSING.success_basis(grade, record, guaranteed)
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
			elif purpose in ["element_change", "element_reset"]:
				var new_element: String = ""
				if choose_element and element_selector != null:
					new_element = ["fire", "water", "earth", "wind"][element_selector.selected]
				apply_element_management(item_name, candidate, new_element)
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

func _use_regional_return(item_name: String) -> void:
	if _player_busy_for_travel():
		_message("현재 상태에서는 귀환할 수 없습니다")
		return
	var land: int = world._regional_return_land()
	if not REGIONAL_RETURN.DATA.data.lands.has(str(land)):
		_message("잊혀진 귀환 주문서는 잊혀진 섬에서만 사용할 수 있습니다")
		return
	var field: Variant = world.field_map
	var binding: Dictionary = REGIONAL_RETURN.DATA.data.host_bindings.get(world.active_map_id, {})
	if field == null or binding.is_empty() or int(binding.get("land_id", 0)) != land or str(binding.get("return_mode", "")) != "spawn" or str(binding.get("return_map", "")) != str(world.active_map_id):
		_message("이 지역의 귀환 목적지가 아직 연결되지 않았습니다 · 주문서 보존")
		return
	var destination: Vector2 = world._spawn_position()
	if not field.walkable(destination) or not field.point_clear(destination):
		_message("안전한 귀환 위치를 확인할 수 없습니다 · 주문서 보존")
		return
	var old_position: Vector2 = world.player.global_position
	var old_count: int = int(world.inventory.get(item_name, 0))
	_teleport_player(destination)
	world.inventory[item_name] = old_count - 1
	if old_count == 1: world.inventory.erase(item_name)
	var save_error: Error = world._save_game(true)
	if save_error != OK:
		world.inventory[item_name] = old_count
		_teleport_player(old_position)
		world._update_hud()
		_message("귀환 저장 실패 · 위치와 주문서를 보존했습니다")
		return
	world.hud.refresh_inventory(world.inventory)
	world._update_hud()
	_message("잊혀진 섬 시작 지점으로 귀환 · TWILIGHT 대응 지도")

func try_use_regional_return(item_name: String) -> bool:
	var record: Dictionary = world._find_catalog_item_record(item_name)
	if not REGIONAL_RETURN.claims_identity(item_name, record): return false
	var stack: Dictionary = REGIONAL_RETURN.stack_identity(item_name, record)
	if stack.is_empty():
		_message("귀환 주문서의 원본 ID·이름·Normal 스택 확인 실패 · 아이템 보존")
		return true
	if stack.origin == "patch523_native_normal" and int(stack.item_class_id) == 239:
		var outcome: Dictionary=use_owned_native_return(item_name)
		_message(str(outcome.get("message",outcome.get("reason","귀환 결과 확인 필요"))))
		return true
	if int(world.inventory.get(item_name, 0)) <= 0:
		_message("아이템이 없습니다: "+item_name)
		return true
	_use_return(item_name)
	return true

## Result contract for external reward producers. Issuance/receipt is their transaction.
## Cross-map native travel needs its owner's atomic destination contract; preserve stock.

# Original UI supplies its own source nodes and exact source entity choice.
# Backend proposals are read-only; no replacement window is constructed here.
func quote_owned_original_selection(original_item: Dictionary,ownership: Dictionary) -> Dictionary:
	return preload("res://scripts/loot/current523_native_stack.gd").quote_original_selection(world,original_item,ownership)

func claim_owned_original_selection(original_item: Dictionary,ownership: Dictionary,entity_id: int) -> Dictionary:
	var result: Dictionary=preload("res://scripts/loot/current523_native_stack.gd").claim_original_selection(world,original_item,ownership,entity_id)
	if result.get("ok",false) and result.get("saved",false) and result.get("consumed")==1:
		world.quest_auto.refresh_context(world);world.hud.refresh_inventory(world.inventory);world._update_hud()
	return result
