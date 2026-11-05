extends SceneTree
const Runtime=preload("res://scripts/cards/skill_awakening_runtime.gd")
const Registry=preload("res://scripts/lineagem_base508.gd")
const Fixture=preload("res://tests/patch523_new_cards_test.gd")
var checks: int=0
var errors: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func run() -> void:
	var host=Fixture.Host.new();root.add_child(host);host.catalog_db=Registry.apply_catalog({});host.card_draw_fusion.configure(host.catalog_db)
	var service=Runtime.new();check(service.configure(host),"runtime configures")
	var identity: String="source:m523:2:25152";var material: String=""
	for key: String in service.core.cards:
		var row: Dictionary=service.core.cards[key]
		if row.category=="마법인형" and int(row.source_card.GradeID)==4 and not bool(row.source_card.IsNoMergeOut) and service.core.eligibility(key).ok:material=key;break
	check(not material.is_empty(),"real allowed same-grade source material exists")
	host.card_draw_fusion.owned["마법인형"][identity]=true;host.card_draw_fusion.owned["마법인형"][material]=true;host.card_draw_fusion.spare["마법인형"][material]=6
	host.equipped_catalog["마법인형"]=Registry.canonical({"source":"lineagem_patch523","sourceId":"m523:2:25152"})
	service.progress.cards[identity]={"spell_id":int(service.core.candidates(identity)[0].spell_id),"level":1,"experience":"0","future_metadata":{"preserved":true}}
	var before: int=hash([service.export_state(),host.card_draw_fusion.export_state(),host.gold,service.selection_rng.state,host.card_draw_fusion.rng.state])
	host.save_error=ERR_FILE_CANT_WRITE
	check(service.request_experience_feed(identity,material).code=="save_failed" and hash([service.export_state(),host.card_draw_fusion.export_state(),host.gold,service.selection_rng.state,host.card_draw_fusion.rng.state])==before,"failed durable feed preserves duplicates, gold, level, EXP and both RNGs")
	host.save_error=OK
	var fee: int=int(service.view(identity).growth_progress.quote.fee);var gold: int=host.gold
	for attempt: int in range(6):
		var outcome: Dictionary=service.request_experience_feed(identity,material,int(service.progress.revision))
		check(outcome.ok and outcome.committed and outcome.consumed_quantity==1,"one duplicate feed atomically committed "+str(attempt))
	check(host.gold==gold-fee*6 and host.card_draw_fusion.owned["마법인형"][material] and not host.card_draw_fusion.spare["마법인형"].has(material),"six custom fees and duplicates charged while first permanent card survives")
	check(service.progress.cards[identity].level==2 and service.progress.cards[identity].future_metadata.preserved,"cumulative source curve grows level and preserves future metadata")
	check(service.bonus_records()[0].hpFlat==service.core.profile(identity,2).hp,"grown source profile reaches existing live HP record")
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.save_path()))
	check(disk.card_skill_awakening.cards[identity].level==2 and disk.card_draw_fusion==JSON.parse_string(JSON.stringify(host.card_draw_fusion.export_state())) and disk.gold==host.gold,"EXP, level, duplicate debit and gold share durable payload")
	var revision: int=int(service.progress.revision);var xp: int=int(service.progress.cards[identity].experience)
	var hunted: Dictionary=service.on_hunt_experience(41)
	check(hunted.changed and service.progress.cards[identity].experience==str(xp+41) and int(service.progress.revision)==revision+1,"hunting adds exact earned amount without a fee or RNG")
	check(service.on_hunt_experience(0).changed==false and host.gold==gold-fee*6,"zero hunting reward and all hunting leave currency unchanged")
	service.save_blocked=true;before=hash(service.export_state());service.on_hunt_experience(999)
	check(hash(service.export_state())==before,"protected save cannot accrue new card growth")
	service.save_blocked=false;host.equipped_catalog["마법인형"]={};before=hash(service.export_state())
	check(not service.on_hunt_experience(999).changed and hash(service.export_state())==before,"unequipped card cannot gain hunting EXP")
	host.queue_free();await process_frame
	print("SKILL_GROWTH_RUNTIME ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
