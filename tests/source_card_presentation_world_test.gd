extends SceneTree
## Actual Main refusal/reconnect test. Owned items/cards are explicit fixtures.
const QA=preload("res://tests/qa_class_selection.gd")
const P=preload("res://scripts/cards/source_card_operation_presentation.gd")
const Acquisition=preload("res://scripts/cards/native_card_acquisition.gd")
const Items=preload("res://scripts/cards/source_awakening_items.gd")
var world: Node
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	print("SOURCE_UI_WORLD_CHECK ",checks," ",label," ",value)
	if not value:errors.append(label);push_error(label)
func state_hash() -> int:
	return hash(JSON.parse_string(JSON.stringify([world.inventory,world.item_instances,world.gold,world.hp,world.mp,world.card_draw_fusion.export_state(),world.option_awakening.export_state(),world.skill_awakening.export_state(),world.quest_service.export_state(),str(world.rng.state),str(world.card_draw_fusion.rng.state),str(world.skill_awakening.selection_rng.state)])))
func denied(reply: Dictionary) -> bool:return reply.get("handled",false) and not reply.get("ok",true) and not reply.get("committed",true) and reply.get("code")=="source_presentation_unregistered"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if OS.get_environment("TWILIGHT_SOURCE_UI_BOUNDARY_ISOLATED")!="1":push_error("Explicit isolated profile required");quit(2);return
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.field_population.set_process(false);world.save_timer=-100000;world.player.set_physics_process(false)
	for frame: int in range(6):await process_frame
	check(QA.enter_game(world) and not world.map_bootstrap_blocked,"actual Main and pinned current map load")
	if world.map_bootstrap_blocked:finish();return
	check(world.hud.companion_detail_view==null or world.hud.companion_detail_view.source_craft_button==null,"authored card-crafting button is not constructed")
	var target: String="source:m523:2:25152"
	world.card_draw_fusion.owned["마법인형"][target]=true;world.card_draw_fusion.spare["마법인형"][target]=6
	world.equipped_catalog["마법인형"]=world.skill_awakening.view(target).target_record
	world.skill_awakening.progress.cards[target]={"spell_id":int(world.skill_awakening.core.candidates(target)[0].spell_id),"level":1,"experience":"0","future_metadata":{"retain":true}}
	world.gold=10000000
	var coin: Dictionary=Acquisition.record(3252)
	var pickup: Dictionary=Items.prepare_pickup({"item_name":coin.name,"item_record":coin,"quantity":3000000},world.item_instances,world.next_item_instance_id)
	world.item_instances=pickup.item_instances;world.next_item_instance_id=pickup.next_item_instance_id;world.inventory[coin.name]=3000000
	var book_id: int=int(world.skill_awakening.core.book_requirement(target).item_class_id)
	var book: Dictionary={}
	for row: Dictionary in world.catalog_db["아이템"]:
		if row.get("source")=="lineagem_base508" and int(row.get("source_item_class_id",0))==book_id:book=row;break
	check(not book.is_empty(),"existing exact awakening book definition retained")
	if book.is_empty():finish();return
	var uid: String=str(Acquisition.next_safe_id(world.item_instances,world.next_item_instance_id))
	world.item_instances[uid]={"name":book.name,"level":0,"record":book.duplicate(true)};world.inventory[book.name]=1
	world._invalidate_equipment_static()
	check(world._save_game(true)==OK,"funded isolated state saves through actual writer")
	var before: int=state_hash();var disk: String=FileAccess.get_sha256(world.save_path())
	var quote: Dictionary=world.option_awakening.nemesis_craft_view();var skill_quote: Dictionary=world.skill_awakening.view(target)
	check(int(quote.available_coins)==3000000 and quote.conditions_verified and not quote.can_craft,"funded source craft stays non-actionable without original presentation")
	check(skill_quote.owned and not skill_quote.can_awaken and not skill_quote.can_feed and not skill_quote.growth_progress.can_feed,"owned funded skill and growth quotes remain non-actionable")
	var section: String=world.hud.active_section;var children: int=world.hud.workspace.content.get_child_count();var visible: bool=world.hud.workspace.visible
	for attempt: int in range(2):
		check(denied(world.hud.open_native_card_craft()),"actual HUD craft request stops at the unregistered boundary")
		check(denied(world.hud.open_card_skill_growth("마법인형",target)),"actual HUD growth request stops at the unregistered boundary")
		world.hud.open_card_skill_awakening("마법인형",target)
		check(world.hud.active_section==section and world.hud.workspace.content.get_child_count()==children and world.hud.workspace.visible==visible,"all three requests preserve the current workspace without replacement forms")
		check(denied(world.option_awakening.craft_nemesis()) and denied(world.option_awakening._craft_native_nemesis()),"production craft APIs cannot use either debit path")
		check(denied(world.skill_awakening.request_operation(target)) and denied(world.skill_awakening.request_experience_feed(target,target)),"production skill APIs cannot consume a book, duplicate or fee")
	check(state_hash()==before and FileAccess.get_sha256(world.save_path())==disk,"all refused UI/API requests preserve disk, items, receipts, cards, vitals and RNGs")
	world._load_game(true)
	check(state_hash()==before and FileAccess.get_sha256(world.save_path())==disk,"actual reconnect preserves the full funded state and saved bytes")
	var gold: int=world.gold;var inventory: int=hash(world.inventory)
	var hunted: Dictionary=world.skill_awakening.on_hunt_experience(41)
	check(hunted.get("changed",false) and world.skill_awakening.progress.cards[target].experience=="41" and world.gold==gold and hash(world.inventory)==inventory,"independent earned hunting EXP remains connected without material consumption")
	check(world._save_game(true)==OK,"independent earned EXP still uses the existing save owner")
	finish()
func finish() -> void:
	print("SOURCE_CARD_PRESENTATION_WORLD ",JSON.stringify({"checks":checks,"errors":errors,"scope":"ACTUAL_MAIN_REFUSAL_AND_RECONNECT; FIXTURE_OWNERSHIP; NO_SOURCE_PIXEL_PLAYBACK"}))
	if is_instance_valid(world):world.queue_free();await process_frame
	quit(0 if errors.is_empty() else 1)
