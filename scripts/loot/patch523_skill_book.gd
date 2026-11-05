extends RefCounted
## Consumer contract only. PR245 owns the loaded source spell adapter and engine.
static func resolve(adapter: Object, spec: Dictionary) -> Dictionary:
	if adapter == null: return {}
	var profiles: Variant = adapter.get("profiles")
	var bindings: Variant = adapter.get("bindings")
	if not profiles is Dictionary or not bindings is Dictionary: return {}
	var matches: Array[Dictionary] = []
	for key: String in profiles:
		var profile: Dictionary = profiles[key]
		var binding: Dictionary = bindings.get("skills",{}).get(key,{})
		if int(binding.get("spell_id",-1)) != int(spec.get("spell_class_id",-2)): continue
		if binding.get("row_sha256") != spec.get("source_spell_row_sha256"): continue
		if profile.get("row_json","") != spec.get("source_spell_row_json",null): continue
		if str(profile.row_json).sha256_text() != spec.get("source_spell_row_sha256"): continue
		if profile.get("row",{}) != spec.get("source_spell_class",{}): continue
		matches.append({"local_skill_id":key,"profile":profile})
	return matches[0] if matches.size() == 1 else {}

static func _adapter(catalog: Object) -> Object:
	for property: Dictionary in catalog.get_property_list():
		if property.name == "source523": return catalog.get("source523")
	return null

static func source_limit_problem(world: Node, spec: Dictionary) -> String:
	if spec.get("source_spell_group_mastery_required",false): return "원본 스펠 그룹 마스터리 조건 · 학습 엔진 지원 확인 필요"
	var class_id: int = world.BASE508.source_class_id(world.job_class)
	var ordinary: Array[Dictionary] = []
	for row: Dictionary in spec.get("source_learn_limits",[]):
		if int(row.get("ClassID",-1)) == class_id and not row.get("IsTutorialSpell",true): ordinary.append(row)
	if ordinary.is_empty(): return "원본 스킬서 학습 직업 조건 불일치"
	for row: Dictionary in ordinary:
		if int(row.get("CharacterPolymorphGradeID",0)) != 0 or int(row.get("LimitBuffCardID",0)) != 0: continue
		if world.level >= int(row.get("CharacterMinLevel",0)): return ""
	return "원본 스킬서 레벨·변신·선행 카드 학습 조건 미충족 또는 미지원"

static func use(world: Node, record: Dictionary, spec: Dictionary) -> bool:
	var problem: String = source_limit_problem(world,spec)
	if not problem.is_empty():
		world.hud.show_message(problem+" · 스킬서 보존")
		return false
	if world.original_skills == null: return false
	var catalog: Object = world.original_skills.catalog
	var identity: Dictionary = resolve(_adapter(catalog),spec)
	if identity.is_empty():
		world.hud.show_message("PR245 원본 주문 ID·정의 SHA 일치 연결 필요 · 스킬서 보존")
		return false
	var skill_id: String = str(identity.local_skill_id)
	var skill: Dictionary = catalog.record_for(skill_id)
	if skill.get("id") != skill_id: return false
	problem = catalog.reason(skill,true)
	if not problem.is_empty():
		world.hud.show_message(problem+" · 스킬서 보존")
		return false
	var inventory: Dictionary = world.inventory.duplicate(true)
	var item_name: String = str(record.name)
	if int(inventory.get(item_name,0)) < 1: return false
	inventory[item_name] = int(inventory[item_name])-1
	if int(inventory[item_name]) == 0: inventory.erase(item_name)
	var staged: Dictionary = catalog.export_state()
	staged.learned[skill_id] = 1
	var consumables: Dictionary = world.consumable_service.export_state()
	if not consumables.has("source_skill_book_receipts"): consumables["source_skill_book_receipts"] = []
	consumables.source_skill_book_receipts.append({"source_snapshot":"patch523","item_class_id":int(record.source_item_class_id),"card_id":int(spec.card_id),"spell_class_id":int(spec.spell_class_id),"spell_row_sha256":str(spec.source_spell_row_sha256),"local_skill_id":skill_id,"cannot_swap":bool(spec.get("buff_card_cannot_swap",false)),"cannot_stack_card":bool(spec.get("cannot_stack_card",false))})
	if world._save_game(true,{"inventory":inventory,"original_skill_state":staged,"consumable_state":consumables}) != OK:
		world.hud.show_message("스킬서 학습 저장 실패 · 아이템과 학습 상태 보존")
		return false
	world.inventory = inventory
	world.consumable_service.import_state(consumables)
	catalog.import_state({"original_skill_state":staged})
	world.original_skills.refresh_buffs_after_learning(skill_id)
	world._refresh_speed_modifiers()
	world.hud.refresh_inventory(world.inventory)
	world._update_hud()
	world.hud.show_message(str(skill.name)+" 습득 · 원본 주문 #"+str(int(spec.spell_class_id)))
	return true
