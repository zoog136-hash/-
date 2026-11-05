extends SceneTree
const Native=preload("res://scripts/cards/native_collection_rules.gd")
const API=preload("res://scripts/lineagem_base508.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Presentation=preload("res://scripts/ui/source_collection_presentation.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures.append(why);push_error(why)
func run() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/patch523_collections.json"))
	var current: Dictionary=API.cards()
	var catalog: Dictionary=current.catalog
	check(current.content_snapshot=="patch523","current production API uses523")
	var expected: Dictionary={"변신":402,"마법인형":171,"성물":147}
	var by_id: Dictionary={}
	var variants: int=0
	for category: String in Cards.CATEGORIES:
		check(catalog[category].size()==expected[category],"exact latest count "+category)
		for record: Dictionary in catalog[category]:
			by_id[Cards.card_id(record)]=record
			variants+=record.source_class_variants.size()
			check(record.source_card_id==record.source_original_card.ID,"exact BuffCard identity "+str(record.sourceId))
			for role: String in record.source_ui_assets:
				var asset: Variant=record.source_ui_assets[role]
				check(asset==null or not str(asset.path).ends_with("/"),"no zero-ID placeholder asset for "+str(record.sourceId)+":"+role)
	check(variants==138 and by_id.size()==720,"class variants never become owned card identities")
	var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(API.CARD_PATH))
	for category: String in Cards.CATEGORIES:
		for record: Dictionary in baseline.catalog[category]:
			check(by_id.has(Cards.card_id(record)),"preserved prior save identity "+str(record.sourceId))
			check(by_id[Cards.card_id(record)].source_inworld_sprite_ids==record.source_inworld_sprite_ids and by_id[Cards.card_id(record)].source_sprite_bindings==record.source_sprite_bindings,"preserved verified actor bindings "+str(record.sourceId))
	var source_pool=Cards.new();source_pool.configure(catalog)
	var old_pool=Cards.new();old_pool.configure(baseline.catalog)
	for category: String in Cards.CATEGORIES:
		for grade: String in Cards.GRADES:
			check(source_pool.pools[category][grade].map(func(e: Dictionary) -> String:return e.id)==old_pool.pools[category][grade].map(func(e: Dictionary) -> String:return e.id),"new metadata does not invent draw/fusion membership "+category+grade)
		for record: Dictionary in catalog[category]:
			if record.get("source_snapshot", "")=="patch523":
				check(str(record.sourceId).begins_with("m523:") and API.select_visual(record).status=="selection_pending" and API.icon(record)==null,"new identity uses523 namespace and requires original art "+str(record.sourceId))
	var combined: Dictionary={"catalog":catalog.duplicate(true)}
	var extra: Dictionary={}
	for record: Dictionary in catalog["변신"]:
		if record.get("source_snapshot", "")=="patch523":extra=record.duplicate(true);break
	extra={"sourceId":extra.sourceId,"source":"lineagem_patch523","independent_supplement_readiness":true}
	combined.catalog["변신"].append(extra)
	API._index_cards(combined)
	check(combined.catalog["변신"].size()==402 and API.canonical(extra).get("independent_supplement_readiness",false) and API.canonical(extra).has("source_class_variants"),"same-ID independent supplement stays one card and preserves readiness metadata")
	API._index_cards(current)
	var core=Native.new()
	check(core.configure(data,catalog),"all current source joins configure: "+core.error)
	check(core.definitions.size()==1793 and data.excluded_test_deck_collections.size()==4,"real sets retained; four empty test sets excluded")
	var by_set: Dictionary={};var cross: int=0;var members: int=0;var effects: int=0
	for row: Dictionary in core.definitions:
		by_set[int(row.source_original.ID)]=row;members+=row.requirements.size();effects+=row.effects.size()
		check(not row.requirements.is_empty(),"empty all() never activates a set")
		for member: Dictionary in row.requirements:
			if member.category!=row.category:cross+=1
			check(by_id[member.id].source_card_id==member.source_original.BuffCardID,"member own card identity")
	check(cross==32 and members==5059 and effects==2052,"full current member/reward counts including32 cross-deck rows")
	var distinct: Array=[]
	for id: int in [27262,27272,27282,27292]:
		var row: Dictionary=by_set[id]
		check(row.requirements.map(func(m: Dictionary) -> Array:return [m.id,m.category,m.awakened,m.source_original.ServerLimitSetID])==by_set[27262].requirements.map(func(m: Dictionary) -> Array:return [m.id,m.category,m.awakened,m.source_original.ServerLimitSetID]),"same requirements remain distinct set "+str(id))
		check(not distinct.has(row.effects),"different rewards survive same-requirements grouping "+str(id))
		distinct.append(row.effects)
	for id: int in [11832,13342,13062,13352]:
		var row: Dictionary=by_set[id];var seen: Dictionary={};var different: bool=false
		for effect: Dictionary in row.effects:
			var raw: Dictionary=effect.source_original.bonus
			var type_id: int=int(raw.BonusTypeID)
			if seen.has(type_id):
				check(Presentation.effect_identity(effect)!=Presentation.effect_identity(seen[type_id]),"same type has separate actual target filter "+str(id));different=true
			seen[type_id]=effect
		check(different,"real repeated-target source case "+str(id))
	var all_owned: Dictionary={}
	for category: String in Cards.CATEGORIES:
		all_owned[category]={}
		for record: Dictionary in catalog[category]:all_owned[category][Cards.card_id(record)]=true
	var before: int=hash(all_owned)
	var full: Dictionary=core.derive({"owned":all_owned})
	check(hash(all_owned)==before and core.derive({"owned":all_owned}).totals==full.totals,"permanent owned ledger stays immutable and rewards idempotent")
	check(core.derive({"owned":{}}).completed.is_empty(),"no acquisition grants nothing")
	for row: Dictionary in full.rows:
		if int(row.source_original.ID) in [14813,16521]:
			check(not row.completed and not row.problems.has("native_interval_runtime_required") and row.problems.has("native_server_context_required"),"HP interval runtime connected; actual server still required")
			check(row.effects.any(func(e: Dictionary) -> bool:return e.source_original.nested_intervals.size()==3),"exact three interval branches retained")
	var source: Dictionary=by_set[27343]
	var member: Dictionary=source.requirements[0]
	check(member.category=="변신" and source.category=="마법인형","real cross-deck fixture")
	var corrupt: Dictionary=data.duplicate(true);corrupt.collections=[source.duplicate(true)]
	corrupt.collections[0].requirements[0].category="마법인형"
	check(not Native.new().configure(corrupt,catalog),"wrong member deck cannot reinterpret the same source ID")
	print("PATCH523_CARD_COLLECTION_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"cards":720,"sets":1793,"cross_deck_members":cross,"members":members,"effects":effects}))
	quit(0 if failures.is_empty() else 1)
