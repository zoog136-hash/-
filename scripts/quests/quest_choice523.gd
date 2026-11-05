extends RefCounted
## Exact existing source selection UI/consumer; no alternative loot or equipment engine.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const USE=preload("res://scripts/loot/patch523_item_use.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const HELD=preload("res://scripts/quests/quest_held_use238.gd")
const CHOICE_UI=preload("res://scripts/ui/patch523_reward_choice.gd")
static func class_matches(values: Array,id: int)->bool:return USE.class_matches(values,id)
static func open(world: Node, record: Dictionary, physical_id: String="")->bool:
	if int(record.get("source_item_class_id",0))!=369002:return false
	if world.hud.has_meta("patch523_reward_choice") and is_instance_valid(world.hud.get_meta("patch523_reward_choice")):return true
	var canonical: Dictionary=USE.canonical(record)
	var error: String=USE.eligibility(world,canonical)
	if not error.is_empty():world.hud.show_message(error);return true
	if world.quest_service.save_blocked or not world._patch523_item_allowed():return true
	if not physical_id.is_empty():
		var input: Dictionary=OWN.prepare_debit(world,physical_id,1)
		if not input.get("ok",false) or int(input.ownership.item_class_id)!=369002:world.hud.show_message("선택 보상 소지 영수증 확인 필요");return true
		canonical["quest_selected_physical_id"]=physical_id
	elif int(world.inventory.get(str(canonical.name),0))<1 or world._item_locked(str(canonical.name),""):
		world.hud.show_message("선택 상자 소지량·잠금 확인 필요");return true
	var dialog:=CHOICE_UI.new()
	dialog.configure(world,canonical)
	dialog.use_service=load("res://scripts/quests/quest_choice523.gd")
	world.hud.set_meta("patch523_reward_choice",dialog)
	world.hud.add_child(dialog)
	return true
static func claim_selection(world: Node, saved: Dictionary, entity_id: int)->bool:
	if world.quest_service.save_blocked or not world._patch523_item_allowed():return false
	var canonical: Dictionary=USE.canonical(saved)
	if int(canonical.get("source_item_class_id",0))!=369002:return false
	var physical: String=str(saved.get("quest_selected_physical_id",""))
	if physical.is_empty():
		if world._item_locked(str(canonical.name),""):return false
		var before: String=FileAccess.get_sha256(world.save_path())
		var result: bool=USE.claim_selection(world,canonical,entity_id)
		if not result and FileAccess.get_sha256(world.save_path())!=before:
			world.quest_service.save_blocked=true;world.hud.show_message("선택 저장 결과 확인 필요 · 정상 저장 다시 불러오기")
		return result
	# Quote actual selected ownership NOW, never keep a stale native grant or
	# inventory snapshot alive while the UI is open/cancelled.
	var prepared: Dictionary=OWN.prepare_debit(world,physical,1)
	if not prepared.get("ok",false) or int(prepared.ownership.item_class_id)!=369002 or D.definition_id("369002").original_item!=prepared.ownership.source_item:return false
	var view: Node=HELD.make_view(world,prepared,canonical)
	view.selection_entity_id=entity_id
	var result: bool=USE.claim_selection(view,canonical,entity_id)
	var committed: bool=view.committed
	view.free()
	if committed:
		world.quest_auto.refresh_context(world);world.hud.refresh_inventory(world.inventory)
	return result and committed
