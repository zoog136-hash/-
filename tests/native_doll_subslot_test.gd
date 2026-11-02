extends SceneTree
const Runtime=preload("res://scripts/cards/option_awakening_runtime.gd")
const Subslot=preload("res://scripts/cards/native_doll_subslot.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Fixture=preload("res://tests/native_option_awakening_test.gd")
class Host extends Fixture.Host:
	var level: int=95
	var active_skill_buffs: Dictionary={}
var checks: int=0
var errors: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--native-cards="):path=arg.trim_prefix("--native-cards=")
	if path.is_empty():quit(2);return
	var host=Host.new();root.add_child(host);host.catalog_db=JSON.parse_string(FileAccess.get_file_as_string(path)).catalog;host.card_draw_fusion.configure(host.catalog_db)
	host.card_collections.context={"source_snapshot":"base508","ServiceRegionCode":"KR","WorldNo":1}
	var service=Runtime.new();check(service.configure(host),"configure")
	var cards: Dictionary={}
	for record: Dictionary in host.catalog_db["마법인형"]:cards[Cards.card_id(record)]=record
	var chosen: String="source:m508:2:40";var main: String=""
	for id: String in cards:
		if int(cards[id].source_grade_id)!=int(cards[chosen].source_grade_id):main=id;break
	host.equipped_catalog["마법인형"]=cards[main];host.card_draw_fusion.owned["마법인형"][main]=true;host.card_draw_fusion.owned["마법인형"][chosen]=true
	check(not service.select_subslot(chosen).ok,"level95 alone cannot grant unlock")
	host.active_skill_buffs["untrusted"]={"name":"에바의 부름"}
	check(not service.select_subslot(chosen).ok,"name does not prove source unlock")
	host.active_skill_buffs={"verified":{"source_snapshot":"base508","source_buff_class_id":91531}}
	host.level=94;check(not service.select_subslot(chosen).ok,"minimum95")
	host.level=95;host.card_draw_fusion.owned["마법인형"].erase(main)
	check(not service.select_subslot(chosen).ok,"unowned main cannot authorize extra summon")
	host.card_draw_fusion.owned["마법인형"][main]=true
	host.level=95;host.equipped_catalog["마법인형"]=cards[chosen]
	check(not service.select_subslot(chosen).ok,"same card and grade rejected")
	host.equipped_catalog["마법인형"]=cards[main]
	var before: int=hash([service.export_state(),host.gold,host.card_draw_fusion.export_state()]);host.save_error=ERR_FILE_CANT_WRITE
	check(not service.select_subslot(chosen).ok and hash([service.export_state(),host.gold,host.card_draw_fusion.export_state()])==before,"atomic save failure no ownership or state mutation")
	host.save_error=OK;check(service.select_subslot(chosen).ok and service.subslot_view().active,"select source secondary doll")
	check(service.subslot_view(false).active and service.subslot_view(false).effects.is_empty(),"per-frame actor and UI reads skip source bonus materialization")
	var plain: Dictionary=service.subslot_view().effects
	check(plain.source_zero_effects.size()==1 and int(plain.source_zero_effects[0].bonus.Value)==0,"source zero saving row is metadata, not an unsupported benefit")
	check(not plain.stats.has("xp") and not plain.stats.has("weightBonus") and not plain.stats.has("blessing_consumption_reduction_pct"),"exact source secondary buff excludes primary XP weight blessing")
	service.progress.cards["마법인형"][chosen]={"experience":0,"awakened":true,"attempts":1,"failures":0};service.progress.revision+=1
	var awakened: Dictionary=service.subslot_view().effects
	check(awakened.status_effect_ids.size()==1 and awakened.stats!=plain.stats,"slot11 group uses same awakened state")
	var total: float=service.catalog_bonus("sp");service.catalog_bonus("sp");check(service.catalog_bonus("sp")==total,"repeated reads never stack")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(service.export_state()))
	check(service.core.validate_state(saved,{"owned":host.card_draw_fusion.owned}).is_empty() and service.core.normalized_state(saved)[Subslot.FIELD]==chosen,"choice survives save normalization")
	host.equipped_catalog["마법인형"]=cards[chosen];check(not service.subslot_view().active,"main change safely suspends conflicting extra slot")
	host.equipped_catalog["마법인형"]=cards[main];host.active_skill_buffs.clear();check(not service.subslot_view().active,"unlock removal clears effect authority")
	check(service.select_subslot("").ok and not service.subslot_view().active,"release remains available when locked")
	host.active_skill_buffs={"verified":{"source_snapshot":"base508","source_buff_class_id":91531}}
	for id: String in ["source:m508:2:24712","source:m508:2:24702","source:m508:2:24692"]:
		host.card_draw_fusion.owned["마법인형"][id]=true
		check(service.select_subslot(id).get("code","")=="subslot_expiry_condition","absolute DeleteTime target cannot be silently ignored "+id)
	check(not Subslot.validate({Subslot.FIELD:42}).is_empty(),"corrupt choice rejected")
	host.queue_free();await process_frame
	print("NATIVE_DOLL_SUBSLOT ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
