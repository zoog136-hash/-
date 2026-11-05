extends SceneTree
## Run separately with --card523-slot-pack=<v1|v2> --slot-expect=<v1|v2|missing>.
## Optional --slot-test-dir=<isolated /tmp directory> exercises tamper rejection.
const DATA=preload("res://scripts/cards/patch523_slot_data.gd")
const Slots=preload("res://scripts/cards/option_slot_definitions.gd")
const Native=preload("res://scripts/cards/native_option_awakening.gd")
const Registry=preload("res://scripts/lineagem_base508.gd")
const Relic=preload("res://scripts/cards/native_relic_subslot.gd")
const Unlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
const BASE=preload("res://data/cards/base508_option_awakening.json")
var checks: int=0
var errors: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func run() -> void:
	var expected: String="";var folder: String=""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--slot-expect="):expected=argument.trim_prefix("--slot-expect=")
		if argument.begins_with("--slot-test-dir="):folder=argument.trim_prefix("--slot-test-dir=")
	if expected not in ["v1","v2","missing"]:push_error("Explicit --slot-expect required");quit(2);return
	var preserved: Dictionary={Unlock.FIELD:Unlock.marker(),Relic.FIELD:"source:m508:98:20548","future":{"fraction":0.125}}
	var fingerprint: int=hash(preserved)
	if expected=="missing":
		check(not DATA.installed(),"missing/tampered pack stays inactive")
		check(not Relic.validate(preserved).is_empty(),"existing selected relic blocks save validation without its pack")
		check(hash(preserved)==fingerprint,"missing pack never clears saved unlock/selection/future metadata")
		finish();return
	check(DATA.installed(),"pinned private pack loads")
	check(DATA.loaded_schema=="twilight.card-slots523."+expected,"schema matches requested legacy/current version")
	check(Relic.validate(preserved).is_empty() and hash(preserved)==fingerprint,"existing relic save validates without mutation in either pack")
	var catalog: Dictionary=Registry.apply_catalog({})
	var total: int=0;var identities: Dictionary={}
	for category: String in ["변신","마법인형","성물"]:
		for record: Dictionary in catalog[category]:identities[record.sourceId]=true;total+=1
	check(total==720 and identities.size()==720,"overlays preserve exactly 720 registry identities")
	var base: Dictionary={}
	for row: Dictionary in BASE.data.definitions:
		if row.id=="source:m508:2:25002":base=row
	var corrected: Dictionary=Slots.apply_reviewed_primary(base.duplicate(true))
	if expected=="v1":
		check(DATA.card_acquisition.is_empty() and DATA.relic_acquisition.is_empty(),"v1 leaves only new acquisition owners unavailable")
		check(DATA.options.reviewed_primary_keys.is_empty() and DATA.options.changed_primary_keys.is_empty(),"v1 replacement boundary unchanged")
		check(corrected==base,"v1 retains old primary behavior")
	else:
		check(int(DATA.card_acquisition.guaranteed_nemesis.view.raw.ItemCraftID)==258482 and int(DATA.relic_acquisition.box.item.raw.ID)==346921,"v2 exposes exact private acquisition contracts")
		check(DATA.options.groups.size()==446 and DATA.options.reviewed_primary_keys.size()==289,"v2 retains full reviewed slot graph")
		check(DATA.options.changed_primary_keys==["2:25002:1"],"one verified primary correction only")
		var unchanged: int=0
		for row: Dictionary in BASE.data.definitions:
			if row.id==base.id:continue
			if Slots.apply_reviewed_primary(row.duplicate(true))==row:unchanged+=1
		check(unchanged==288,"remaining 288 primaries retain their own behavior")
		check(corrected.stats=={"damage_reduction_ignore":1.0,"blessing_consumption_reduction_pct":3.0,"weightBonus":500.0,"xp":7.0},"only source-approved primary economy deltas are projected")
		var latest: Dictionary=Native.adapt({"cards":[]},catalog)
		var matching: Array=latest.cards.filter(func(row: Dictionary) -> bool:return row.id==base.id)
		check(matching.size()==1 and matching[0].stats.def==1 and matching[0].stats.xp==7,"native adaptation applies Mariela AC and XP once")
		check(latest.cards.size()==305,"primary execution keeps one definition per reviewed/new card")
		var secondary: Dictionary=Slots.group_for(base.id,11)
		var excluded: Array=[]
		for effect: Dictionary in secondary.effects:
			if effect.type.Name in ["ExperienceAdditionPercent","CarryPlus","EinasadSavingPercent"]:excluded.append(effect)
		check(excluded.is_empty(),"primary economy corrections are not copied to slot11")
	if not folder.is_empty():
		if not folder.begins_with("/tmp/"):push_error("Use isolated /tmp test directory");quit(2);return
		DirAccess.make_dir_recursive_absolute(folder)
		var initial_path: String=DATA.loaded_path
		var path: String=folder.path_join("tampered-slot.json")
		var file: FileAccess=FileAccess.open(path,FileAccess.WRITE)
		file.store_string(FileAccess.get_file_as_string(initial_path)+" ");file.close()
		check(DATA._read_pack(path).is_empty() and not DATA.problem.is_empty(),"tampered pinned pack fails closed")
		check(not Relic.validate(preserved).is_empty() and hash(preserved)==fingerprint,"tamper keeps old selected relic data and blocks saving")
		check(not DATA._read_pack(initial_path).is_empty(),"valid installed pack remains readable after rejected candidate")
	finish()
func finish() -> void:
	print("SLOT_PACK_COMPAT ",JSON.stringify({"checks":checks,"errors":errors,"schema":DATA.loaded_schema}))
	quit(0 if errors.is_empty() else 1)
