extends SceneTree
const Registry=preload("res://scripts/lineagem_base508.gd")
const Patch=preload("res://scripts/cards/patch523_slot_data.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Options=preload("res://scripts/cards/option_awakening_runtime.gd")
const Skills=preload("res://scripts/cards/skill_awakening_runtime.gd")
const Fixture=preload("res://tests/native_option_awakening_test.gd")
const Readiness=preload("res://scripts/cards/skill_growth_readiness.gd")
const Slots=preload("res://scripts/cards/option_slot_definitions.gd")
class Host extends Fixture.Host:
	var inventory: Dictionary={}
	var item_instances: Dictionary={}
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Registry.CARD_PATH))
	var catalog: Dictionary=Registry.apply_catalog({})
	var legacy=Cards.new();legacy.configure(baseline.catalog)
	var old: String=Cards.card_id(baseline.catalog["변신"][0]);legacy.owned["변신"][old]=true;legacy.spare["변신"][old]=3
	var state: Dictionary=legacy.export_state();var upgraded=Cards.new();upgraded.configure(catalog);upgraded.import_state(state)
	check(upgraded.export_state()==state,"old acquired identities and duplicate counts survive registry expansion")
	var total: int=0;var additions: int=0
	var host=Host.new();root.add_child(host);host.catalog_db=catalog;host.card_draw_fusion.configure(catalog)
	var options=Options.new();check(options.configure(host),"mixed exact508/523 catalog configures option runtime")
	var skills=Skills.new();skills.configure(host)
	var eligible: String="";var limited: String=""
	for category: String in Cards.CATEGORIES:
		total+=catalog[category].size()
		check(catalog[category].size()=={"변신":402,"마법인형":171,"성물":147}[category],"current source registry with supplemental fields "+category)
		for record: Dictionary in Patch.new_cards.catalog[category]:
			additions+=1;var identity: String=Cards.card_id(record)
			var canonical: Dictionary=Registry.canonical({"source":"lineagem_patch523","sourceId":record.sourceId})
			check(identity.begins_with("source:m523:") and Cards.card_id(canonical)==identity and Registry.native(canonical),"independent exact523 namespace "+identity)
			check(not upgraded.owned[category].has(identity) and not upgraded.spare[category].has(identity),"new catalog row grants no ownership or duplicates "+identity)
			check(upgraded.pools[category].values().all(func(pool: Array) -> bool:return pool.all(func(entry: Dictionary) -> bool:return entry.id!=identity)),"source gacha pool not guessed "+identity)
			check(options.core.definitions[category].has(identity) and Slots.view(identity).size()==(1 if category=="변신" else 2),"source option slots connected "+identity)
			check(skills.core.cards.has(identity) and not skills.core.profile(identity,1).is_empty() and skills.core.candidates(identity).all(func(row: Dictionary) -> bool:return int(row.spell_id)>0),"actual skill profile/pool joins "+identity)
			check(Registry.select_visual(canonical).reason=="patch523_original_pack_required","no cross-snapshot pixel assumption "+identity)
			if int(record.source_original.server_limit_set_id)==274:limited=identity
			if eligible.is_empty() and skills.core.eligibility(identity).ok:eligible=identity
	check(total==720 and additions==16,"720 registry preserves16 supplemental awakening identities without appending")
	var nemesis: Dictionary=Registry.canonical({"source":"lineagem_patch523","sourceId":"m523:2:25152"})
	check(nemesis.get("meleeCrit",0)==2 and nemesis.get("rangedCrit",0)==2 and nemesis.get("magicCrit",0)==2,"Nemesis exact ValuePercent critical bonuses reach all three typed channels")
	var spear: Dictionary=Registry.canonical({"source":"lineagem_patch523","sourceId":"m523:1:25344"})
	check(spear.get("dg",0)==2 and spear.get("er",0)==2,"new spearman exact melee and ranged evasion channels")
	var warrior: Dictionary=Registry.canonical({"source":"lineagem_patch523","sourceId":"m523:1:25354"})
	check(warrior.get("pve_melee_damage",0)==3,"new warrior source PVE melee damage channel")
	var petal: Dictionary=Registry.canonical({"source":"lineagem_patch523","sourceId":"m523:98:25162"})
	check(int(petal.get("def",0))==2 and str(petal.desc).contains("AC -2"),"petal source defense applies AC2 with the game display sign")
	for card_id: int in [25182,25192,25202,25212,25324]:
		var transform: Dictionary=Registry.canonical({"source":"lineagem_patch523","sourceId":"m523:1:"+str(card_id)})
		check(int(transform.get("pve_damage_reduction",0))==2,"new transform source PVE reduction channel "+str(card_id))
	check(not limited.is_empty() and not skills.core.eligibility(limited).ok,"missing server274 definition never activates")
	var category: String=skills.core.cards[eligible].category
	host.card_draw_fusion.owned[category][eligible]=true
	var req: Dictionary=skills.core.book_requirement(eligible)
	var book: Dictionary={"name":"fixture book","source":"lineagem_base508","source_snapshot":"base508","source_item_class_id":req.item_class_id,"sourceId":"m508:item:"+str(req.item_class_id)}
	host.inventory={"fixture book":1};host.item_instances={"first":{"name":"fixture book","record":book}}
	var result: Dictionary=skills.request_operation(eligible,{"operation_id":"new523"})
	check(result.ok and skills.progress.cards[eligible].level==1 and skills.progress.cards[eligible].experience=="0" and host.inventory.is_empty(),"new card executes real atomic one-book skill awakening")
	var roundtrip: Dictionary=JSON.parse_string(JSON.stringify(skills.export_state()))
	check(skills.accept_load({Skills.SAVE_KEY:roundtrip}) and skills.core.validate_state(skills.export_state()).is_empty(),"523 skill identity safely roundtrips existing save schema")
	check(Readiness.view().can_feed==false and Readiness.view().can_enhance==false,"diagnostics still reject unverified test EXP items and separate enhancement RNG")
	host.queue_free();await process_frame
	print("PATCH523_NEW_CARDS ",JSON.stringify({"checks":checks,"errors":errors,"cards":total,"new_cards":additions}));quit(0 if errors.is_empty() else 1)
