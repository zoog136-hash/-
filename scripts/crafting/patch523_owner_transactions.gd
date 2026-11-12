extends RefCounted
## Save boundary only. Source providers retain acquisition/crafting semantics.
const QUEST_GROWTH_KEYS=["level","experience","exp_need","max_hp","max_mp","hp","mp","attack","defense","stat_points"]

static func quest_error(world: Node,state: Variant) -> String:
	var script: Script=world.quest_service.get_script()
	if script.has_method("validate_saved_state"):
		var result: Variant=script.call("validate_saved_state",state)
		return result if result is String else "퀘스트 소유자 검증 결과 확인 필요"
	if not state is Dictionary:return "퀘스트 저장 형식 확인 필요"
	if state.get("schema_version",1)!=1:return "최신 원본 퀘스트 저장을 읽을 공급자가 없습니다 · 기존 보상 보존"
	for field: String in ["claimed","progress","unlocked"]:
		var values: Variant=state.get(field,{})
		if not values is Dictionary:return "퀘스트 장부 형식 확인 필요"
		for id: Variant in values:
			if str(id).begins_with("m523:"):return "원본 퀘스트 완료 영수증을 보존합니다 · 호환 공급자 설치 필요"
	return ""

static func protection_error(world: Node,state: Variant) -> String:
	if world.protection523==null:return "가호 저장 소유자 미설치 · 기존 상태 보존"
	var script: Script=world.protection523.get_script()
	if not script.has_method("validate"):return "가호 소유자 검증 계약 미설치"
	var result: Variant=script.call("validate",state)
	return result if result is String else "가호 소유자 검증 결과 확인 필요"

static func expedition_error(world: Node,state: Variant) -> String:
	if world.expedition_local==null:return "탐험 저장 소유자 미설치 · 기존 상태 보존"
	var result: Variant=world.expedition_local.call("validate",state)
	return result if result is String else "탐험 소유자 검증 결과 확인 필요"

static func rng_error(state: Variant) -> String:
	if not state is Dictionary or state.get("schema")!=1:return "제작·강화 난수 저장 버전 확인 필요"
	for key: String in ["seed","state"]:
		var value: Variant=state.get(key)
		if not value is String or not value.is_valid_int() or str(int(value))!=value:return "제작·강화 난수 저장 정체 확인 필요"
	return ""

static func override_error(world: Node,staged: Dictionary) -> String:
	if staged.has("protection523") and world.protection523!=null:
		var usage: Dictionary=world.patch523_crafting_usage
		if not world.patch523_equipment.CONDITIONS.valid_usage(usage):return "기존 제작 제한 장부 손상 · 가호 재료/이력 보존"
		for id: String in staged.protection523.get("crafted",{}):
			if world.protection523.state.get("crafted",{}).has(id):continue
			var entries: Dictionary=usage.get("recipes",{})
			if entries.has(id) or entries.has("patch523:"+id):return "기존 일반 제작의 생애 제한 이력 보존 · 중복 가호 거부"
	var debit_error: String=protected_debit_error(world,staged)
	if not debit_error.is_empty():return debit_error
	if staged.has("expedition523_local"):
		var error: String=expedition_error(world,staged.expedition523_local)
		if not error.is_empty():return error
	if staged.has("quest_state"):
		if world.quest_auto==null:return "퀘스트 공급자 거래 미설치"
		var error: String=quest_error(world,staged.quest_state)
		if not error.is_empty():return error
	# A recovered EXP receipt may really cross a level boundary. Only the
	# death owner currently committing this exact complete transaction can
	# authorize its growth fields; a saved death ledger alone cannot do so.
	var death_growth_owned: bool=false
	if not staged.has("quest_state") and staged.has("death_recovery523"):
		var death_owner: Variant=world.get("death_recovery")
		if death_owner!=null and death_owner.has_method("authorizes_recovery_save"):
			death_growth_owned=death_owner.call("authorizes_recovery_save",staged)==true
	for key: String in QUEST_GROWTH_KEYS:
		if not staged.has(key):continue
		if not staged.has("quest_state") and not death_growth_owned:
			var owner: String=nonquest_vital_owner(world,staged)
			if owner!="sealed_monsterbook_reward" and (key not in ["hp","mp","experience"] or owner.is_empty() or (key=="experience" and owner not in ["source_dungeon523","source_dungeon_play","death_recovery523","sealed_current_native_stack_consumer"])):return "퀘스트 성장 거래와 완료 장부가 함께 필요합니다"
		var value: Variant=staged[key]
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=float(int(value)) or float(value)<0 or float(value)>9007199254740991:return "퀘스트 성장 수치 형식 확인 필요"
		if key in ["level","exp_need","max_hp"] and int(value)<1:return "퀘스트 성장 기본값 확인 필요"
	if staged.has("protection523"):
		var error: String=protection_error(world,staged.protection523)
		if not error.is_empty():return error
	return ""

static func nonquest_vital_owner(world: Node,staged: Dictionary) -> String:
	# Each namespace retains its own validator at the shared writer boundary.
	# This classification never permits progression fields without quest_state.
	var cards: Variant = world.get("card_selection_saves")
	if cards is RefCounted and cards.get_script() == preload("res://scripts/cards/card_selection_save.gd") and cards.authorizes(staged): return "card_owner"
	var book: Variant=world.get("monsterbook523_runtime")
	if book is RefCounted and book.get_script()==preload("res://scripts/monsterbook/monsterbook523_runtime.gd") and book.authorizes_reward_save(staged):return "sealed_monsterbook_reward"
	var native_stack: Script=load("res://scripts/loot/current523_native_stack.gd")
	if native_stack!=null and native_stack.call("authorizes",staged):return "sealed_current_native_stack_consumer"
	var alchemy: Variant=world.get("alchemy_held_items")
	if alchemy is RefCounted and alchemy.get_script()==preload("res://scripts/equipment523/alchemy_held_use.gd") and alchemy.authorizes(staged):return "sealed_alchemy_item_consumer"
	var provider: Variant=world.get("quest_item_provider")
	if staged.has("equipped_items"):
		if provider!=null and provider.equipment_owner.authorizes_save(staged):return "sealed_quest_equipment"
		return ""
	if staged.has("source_dungeon523") and world.source_dungeon_runs.validate(staged.source_dungeon523).is_empty():return "source_dungeon523"
	if staged.has("source_dungeon_play") and world.dungeon_play.valid(staged.source_dungeon_play).is_empty():return "source_dungeon_play"
	if staged.has("death_recovery523") and world.death_recovery.validate(staged.death_recovery523,staged.get("item_instances",world.item_instances)).is_empty():return "death_recovery523"
	if not staged.has("inventory"):return ""
	var allowed: Array=["inventory","item_instances","gold","active_item_buffs","item_use_cooldowns","hp","mp","consumable_state","original_skill_state","equipped_ammo","ammo_unequipped","card_draw_fusion","card_option_awakening","card_skill_awakening","next_item_instance_id","equipped_catalog"]
	for key: String in staged:
		if key not in allowed:return ""
	if staged.has("active_item_buffs") or staged.has("item_use_cooldowns") or staged.has("consumable_state") or staged.has("original_skill_state"):return "source_item_consumer"
	if staged.has("card_option_awakening") or staged.has("card_skill_awakening"):return "card_owner"
	return ""

static func committed(world: Node,path: String,candidate: Dictionary) -> bool:
	if not FileAccess.file_exists(path):return false
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK or not parser.data is Dictionary:return false
	var normalized: Variant=JSON.parse_string(JSON.stringify(candidate,"",true,true))
	# Exact whole transaction, including source receipts and unrelated fields.
	if parser.data!=normalized:return false
	return world.equipment_collections.accept_load(parser.data)

static func quest_ownership_provider() -> Script:
	var path: String="res://scripts/quests/quest_reward_ownership.gd"
	if not ResourceLoader.exists(path):return null
	var provider: Script=load(path)
	var bytes: PackedByteArray=provider.get_source_code().to_utf8_buffer()
	var header: PackedByteArray=("blob "+str(bytes.size())).to_utf8_buffer();header.append(0)
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA1);hash.update(header);hash.update(bytes)
	return provider if hash.finish().hex_encode()=="708c5816f59464427a08e085adb569160c18b740" else null

static func protected_inputs_error(world: Node) -> String:
	for id: String in world.item_instances:
		var physical: Dictionary=world.item_instances[id]
		var record: Dictionary=physical.get("record",{})
		if record.get("source_pending_use")!=true or int(record.get("source_item_class_id",0)) not in [96004,96014,200698]:continue
		var provider: Script=quest_ownership_provider()
		if provider==null:return "가호 재료의 공개 퀘스트 소지 증명 공급자 미설치 · 원래 개체 보존"
		var proof: Dictionary=provider.call("proof",world,id)
		if not proof.get("ok",false):return str(proof.get("reason","원본 퀘스트 소지 증명 확인 필요"))
	return ""

static func protected_debit_error(world: Node,staged: Dictionary) -> String:
	if not staged.has("protection523") or not staged.has("item_instances"):return ""
	var debits: Dictionary={}
	for id: String in world.item_instances:
		var old: Dictionary=world.item_instances[id]
		var record: Dictionary=old.get("record",{})
		if record.get("source_pending_use")!=true or int(record.get("source_item_class_id",0)) not in [96004,96014,200698]:continue
		var next: Variant=staged.item_instances.get(id)
		if next==old:continue
		var provider: Script=quest_ownership_provider()
		if provider==null:return "가호 재료의 공개 영수증 소비 계약 미설치 · 보존"
		var proof: Dictionary=provider.call("proof",world,id)
		if not proof.get("ok",false):return str(proof.get("reason","원본 퀘스트 소지 증명 확인 필요"))
		if world._item_locked(str(proof.inventory_key),id) or world._item_locked(str(proof.inventory_key)) or proof.source_use_immediately or proof.source_item.get("TestItem",false):return "잠금/즉시사용/시험 가호 재료 보존"
		var remaining: int=0
		if next!=null:
			if not next is Dictionary:return "원본 보상 개체의 부분 소비 형식 확인 필요"
			var value: Variant=next.get("source_reward_quantity")
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or float(value)!=float(int(value)) or int(value)<1:return "원본 잔여 수량 확인 필요"
			remaining=int(value)
			var expected: Dictionary=old.duplicate(true);expected.source_reward_quantity=remaining
			if expected!=next:return "가호 재료의 원래 영수증/정체 변경은 허용하지 않습니다"
		var consumed: int=int(proof.quantity)-remaining
		if consumed<1:return "원본 지급량/잔여량을 구분해 감소시켜야 합니다"
		var key: String=str(proof.inventory_key)
		debits[key]=int(debits.get(key,0))+consumed
	for key: String in debits:
		if not staged.has("inventory") or int(staged.inventory.get(key,0))!=int(world.inventory.get(key,0))-int(debits[key]):return "가호 재료 개체와 인벤토리의 공동 차감 불일치"
	return ""
