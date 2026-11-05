extends SceneTree
## Real Main integration with an isolated profile.
## Run only with isolated XDG directories and TWILIGHT_GROWTH_TEST_ISOLATED=1.
## Uses the real Main/World writer and load path; production guards stay active.
const QA=preload("res://tests/qa_class_selection.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Core=preload("res://scripts/cards/skill_awakening_service.gd")
var checks: int=0
var errors: Array[String]=[]

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)

func normalized(value: Variant) -> Variant:return JSON.parse_string(JSON.stringify(value))

func fingerprint(world: Node) -> int:
	return hash([world.skill_awakening.export_state(),world.card_draw_fusion.export_state(),world.inventory,world.item_instances,world.gold,world.hp,world.mp,world.skill_awakening.selection_rng.state,world.card_draw_fusion.rng.state])

func freeze(world: Node) -> void:
	world.set_process(false);world.save_timer=-100000
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children():monster.set_physics_process(false)

func held_receipt(category: String,identity: String,card_id: int) -> Dictionary:
	# Explicit ownership fixture, not a real quest grant or a bypass in runtime.
	return {"origin":"quest_current523","category":category,"identity":identity,"card_id":card_id,"source_sha256":"d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832","item_pack_sha256":"38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27","quest_use_token":"a".repeat(64),"quest_option_feed_hold":1,"quest_option_feed_policy":"TWILIGHT_host_hold_until_option_owner_verified","future_receipt":{"preserve":["opaque",true]}}

func _initialize() -> void:call_deferred("run")

func run() -> void:
	if OS.get_environment("TWILIGHT_GROWTH_TEST_ISOLATED")!="1":
		check(false,"requires explicit isolated test profile; no user save is opened")
		finish();return
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world)
	freeze(world)
	for frame: int in range(8):await process_frame
	check(QA.enter_game(world),"actual startup class selection")
	freeze(world)
	var service: RefCounted=world.skill_awakening
	var identity: String="";var category: String="마법인형";var target_record: Dictionary={}
	for record: Dictionary in world.catalog_db.get(category,[]):
		var candidate: String=Cards.card_id(record)
		if not service.core.cards.has(candidate):continue
		var raw: Dictionary=service.core.cards[candidate].source_card
		if int(raw.GradeID)==3 and not bool(raw.IsNoMergeOut) and service.core.eligibility(candidate).ok:
			identity=candidate;target_record=record.duplicate(true);break
	check(not identity.is_empty(),"real eligible source material and awakening profile are registered")
	if identity.is_empty():world.queue_free();await process_frame;finish();return
	world.card_draw_fusion.owned[category][identity]=true
	world.card_draw_fusion.spare[category][identity]=2
	world.card_draw_fusion.source_card_receipts.append(held_receipt(category,identity,int(service.core.cards[identity].source_card.ID)))
	world.equipped_catalog[category]=target_record
	var next: Dictionary=Core.fresh_state()
	next.rng_state=str(service.selection_rng.state)
	next.future_top={"preserve":["growth",true]}
	next.cards[identity]={"spell_id":int(service.core.candidates(identity)[0].spell_id),"level":1,"experience":str(int(service.core.profile(identity,1).experience_row.CumExp)-1),"future_entry":{"preserve":true}}
	next.cards["source:m523:98:99999999"]={"spell_id":1,"level":7,"experience":"123","future_source":{"preserve":true}}
	service.progress=next
	world.gold=maxi(int(world.gold),10000000)
	world._invalidate_equipment_static();world.hp=world._effective_max_hp();world.mp=world._effective_max_mp()
	var initial_save: Error=world._save_game(true)
	check(initial_save==OK,"real World baseline save succeeds with all current owner and pack guards")
	if initial_save!=OK:world.queue_free();await process_frame;finish();return
	var path: String=world.save_path()
	var disk_hash: String=FileAccess.get_sha256(path)
	var receipts: Array=world.card_draw_fusion.source_card_receipts.duplicate(true)
	var inventory: Dictionary=world.inventory.duplicate(true)
	var physicals: Dictionary=world.item_instances.duplicate(true)
	var selection_state: int=service.selection_rng.state;var draw_state: int=world.card_draw_fusion.rng.state
	check(Cards.quest_reserved_spare(world.card_draw_fusion.export_state(),category,identity)==1 and Cards.outgoing_material_spare(world.card_draw_fusion.export_state(),category,identity)==1,"one protected and one previously owned spare are distinguished")
	var view: Dictionary=service.view(identity)
	var material_rows: Array=view.growth_progress.materials.filter(func(row: Dictionary)->bool:return row.id==identity)
	check(material_rows.size()==1 and material_rows[0].quantity==1 and material_rows[0].owned_quantity==2 and material_rows[0].reserved_quantity==1,"live growth view excludes the reserved copy")
	var before: int=fingerprint(world)
	var was_blocked: bool=world.source_save_blocked
	world.source_save_blocked=true
	var failed: Dictionary=service.request_experience_feed(identity,identity,int(service.progress.revision))
	world.source_save_blocked=was_blocked
	check(not failed.ok and failed.code=="save_failed","production World save guard rejects staged feed")
	check(fingerprint(world)==before and FileAccess.get_sha256(path)==disk_hash,"failed real save preserves HP, MP, receipts, materials, currency, both RNGs and durable bytes")
	var gold: int=world.gold;var hp_before: int=world.hp;var maximum_before: int=world._effective_max_hp()
	var fee: int=int(service.view(identity).growth_progress.quote.fee)
	var result: Dictionary=service.request_experience_feed(identity,identity,int(service.progress.revision))
	check(result.ok and result.committed and result.consumed_quantity==1 and result.consumed_gold==fee,"real World accepts the inventory-bearing card-owner override")
	if not result.ok:world.queue_free();await process_frame;finish();return
	check(world.gold==gold-fee and world.card_draw_fusion.spare[category][identity]==1 and world.card_draw_fusion.owned[category][identity],"exact one-card and custom-fee debit preserves first ownership")
	check(service.progress.cards[identity].level==2 and service.progress.cards[identity].future_entry.preserve and service.progress.future_top==next.future_top and service.progress.cards["source:m523:98:99999999"]==next.cards["source:m523:98:99999999"],"source level threshold and opaque growth records survive")
	check(world.hp==hp_before and world._effective_max_hp()>=maximum_before,"growth stages the real source HP profile without healing")
	check(world.inventory==inventory and world.item_instances==physicals and world.card_draw_fusion.source_card_receipts==receipts,"item receipts and source card receipts remain untouched")
	check(service.selection_rng.state==selection_state and world.card_draw_fusion.rng.state==draw_state,"feed does not advance either RNG")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.card_skill_awakening==normalized(service.export_state()) and saved.card_draw_fusion==normalized(world.card_draw_fusion.export_state()) and int(saved.gold)==int(world.gold) and int(saved.hp)==int(world.hp) and int(saved.mp)==int(world.mp),"one durable payload contains growth, debit, receipt ledger and staged vitals")
	before=fingerprint(world);disk_hash=FileAccess.get_sha256(path)
	var reserved: Dictionary=service.request_experience_feed(identity,identity,int(service.progress.revision))
	check(not reserved.ok and reserved.code=="material_reserved" and fingerprint(world)==before and FileAccess.get_sha256(path)==disk_hash,"protected final spare cannot be consumed or alter disk")
	var expected: Dictionary=service.export_state();var expected_cards: Dictionary=world.card_draw_fusion.export_state();var expected_gold: int=world.gold
	world._load_game(true)
	freeze(world)
	check(normalized(service.export_state())==normalized(expected) and normalized(world.card_draw_fusion.export_state())==normalized(expected_cards) and int(world.gold)==expected_gold,"actual World reload restores EXP, level, receipts, ownership and currency")
	check(service.selection_rng.state==selection_state and Cards.outgoing_material_spare(world.card_draw_fusion.export_state(),category,identity)==0,"reload preserves selection RNG and reserved-material protection")
	var previous_experience: int=int(service.progress.cards[identity].experience)
	var hunted: Dictionary=service.on_hunt_experience(41)
	check(hunted.ok and hunted.changed and service.progress.cards[identity].experience==str(previous_experience+41) and world.gold==expected_gold and service.selection_rng.state==selection_state,"real equipped source card gets exact hunt EXP without a fee or selection roll")
	check(world._save_game(true)==OK,"earned hunting EXP uses the existing full-save transaction")
	expected=service.export_state();world._load_game(true);freeze(world)
	check(normalized(service.export_state())==normalized(expected) and normalized(world.card_draw_fusion.export_state())==normalized(expected_cards),"hunting reload preserves cumulative EXP and the held receipt ledger")
	world.queue_free();await process_frame
	finish()

func finish() -> void:
	print("SKILL_GROWTH_WORLD ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
