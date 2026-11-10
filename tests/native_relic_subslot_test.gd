extends SceneTree
const Slot=preload("res://scripts/cards/native_relic_subslot.gd")
const Unlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
const DATA=preload("res://scripts/cards/patch523_slot_data.gd")
class Ledger extends RefCounted:
	var owned: Dictionary={"성물":{}}
class World extends RefCounted:
	var card_draw_fusion=Ledger.new()
	var equipped_catalog: Dictionary={"성물":{}}
class Core extends RefCounted:
	var catalog: Dictionary={"성물":{}}
	var source_server_context: Dictionary={}
	func owned(state: Dictionary,category: String,identity: String) -> bool:return state.get("owned",{}).get(category,{}).get(identity,false)==true
	func awakened(state: Dictionary,category: String,identity: String) -> bool:return state.get("cards",{}).get(category,{}).get(identity,{}).get("awakened",false)==true
class Runtime extends RefCounted:
	var progress: Dictionary={"cards":{"성물":{}}}
	var world=World.new()
	var core=Core.new()
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func card(identity: String) -> Dictionary:
	var row: Dictionary=Slot.definition(identity)
	return {"name":str(row.card.Name),"sourceId":identity.trim_prefix("source:"),"source":"lineagem_base508" if identity.begins_with("source:m508:") else "lineagem_patch523","source_deck_id":98,"source_card_id":int(row.card.ID),"source_grade_id":int(row.card.GradeID)}
func run() -> void:
	check(DATA.relic.counts.cards==147 and DATA.relic.counts.subslot_links==145 and DATA.relic.counts.option_groups==58,"complete523 relic definitions, subslot graph and contextual option groups")
	check(Slot.identity_key("source:m508:98:20548")=="98:20548" and Slot.identity_key("source:m523:98:20548")=="98:20548","explicit508/523 source identities resolve raw deck/card without rewriting ownership")
	for identity: String in ["20548","source:m523:2:20548","source:m523:98:020548","fallback:성물"]:check(Slot.identity_key(identity).is_empty(),"untyped or noncanonical identity rejected "+identity)
	check(Slot.validate({Slot.FIELD:42})!="" and Slot.validate({Slot.FIELD:"source:m523:98:20441"})!="","corrupt choice and unused card without a subslot graph rejected")
	var timer: Dictionary={"schema":1,"item_class_id":365758,"slot_index":11,"identity":"","expires_utc":0}
	check(Slot.validate({"native_relic_summon_time":timer}).is_empty(),"new pending timer retains exact source slot11")
	timer.slot_index=12
	check(not Slot.validate({"native_relic_summon_time":timer}).is_empty(),"corrupt timer cannot declare a different source summon slot")
	var runtime=Runtime.new();var chosen: String="source:m508:98:20548";var main: String=""
	for key: String in DATA.relic_card_keys():
		var row: Dictionary=DATA.relic_card(key)
		if row.has("subslot_buff") and int(row.card.GradeID)!=1 and int(row.card.ServerLimitSetID)==0 and int(row.card.StartDateTimeID)==0 and int(row.card.EndDateTimeID)==0:main="source:m523:"+key;break
	check(not main.is_empty(),"actual source different-grade main exists")
	runtime.core.catalog["성물"][chosen]=card(chosen);runtime.core.catalog["성물"][main]=card(main)
	runtime.world.card_draw_fusion.owned["성물"][chosen]=true;runtime.world.card_draw_fusion.owned["성물"][main]=true
	runtime.world.equipped_catalog["성물"]=card(main)
	check(not Slot.eligibility(runtime,chosen,96,{}).ok,"level96 alone never grants source unlock")
	check(not Slot.unlocked(96,{"named":{"name":"에바의 계시"}}),"display name never grants unlock")
	check(not Slot.unlocked(96,{"wrong":{"source_snapshot":"base508","source_buff_class_id":95648}}),"wrong snapshot does not grant523 unlock")
	runtime.progress[Unlock.FIELD]=Unlock.marker()
	check(Slot.eligibility(runtime,chosen,1,{}).ok,"exact permanent unlock uses source clauses without inventing numeric level96 gate")
	runtime.world.equipped_catalog["성물"]={}
	check(Slot.eligibility(runtime,chosen,1,{}).ok,"source supplies no main-presence gate for independently unlocked extra slot")
	runtime.world.equipped_catalog["성물"]=card(main)
	runtime.world.card_draw_fusion.owned["성물"].erase(chosen)
	check(Slot.eligibility(runtime,chosen,96,{}).code=="ownership_condition","additional relic requires exact permanent ownership")
	runtime.world.card_draw_fusion.owned["성물"][chosen]=true
	runtime.world.card_draw_fusion.owned["성물"].erase(main)
	check(Slot.eligibility(runtime,chosen,96,{}).code=="main_ownership_condition","unowned main cannot authorize additional relic")
	runtime.world.card_draw_fusion.owned["성물"][main]=true
	runtime.world.equipped_catalog["성물"]=card(chosen)
	check(Slot.eligibility(runtime,chosen,96,{}).code=="same_card_grade","explicit source UI same-card rule")
	var same_grade: String="source:m523:98:20558"
	runtime.world.card_draw_fusion.owned["성물"][same_grade]=true;runtime.world.equipped_catalog["성물"]=card(same_grade)
	check(Slot.eligibility(runtime,chosen,96,{}).code=="same_card_grade","explicit source UI same-grade rule")
	runtime.world.equipped_catalog["성물"]=card(main)
	var plain: Dictionary=Slot.effects(runtime,chosen)
	check(plain.stats.meleeHit==1 and plain.stats.hpPct==1 and plain.summon_binding.npc_class_id==83758,"exact secondary buff rows and typed slot11 NPC binding")
	check(not plain.stats.has("xp") and not plain.stats.has("skill_cooldown_reduction_pct"),"no main-only economics or cooldown copied")
	var hero: String=""
	for key: String in DATA.relic_option_group_keys():
		var group: Dictionary=DATA.relic_option_group(key)
		if int(group.card.ServerLimitSetID)==0 and int(group.card.StartDateTimeID)==0 and int(group.card.EndDateTimeID)==0 and int(group.group.ServerLimitsetID)==0:hero="source:m523:98:"+str(int(group.card.ID));break
	check(not hero.is_empty(),"actual unrestricted option group exists")
	var before: Dictionary=Slot.effects(runtime,hero)
	runtime.progress.cards["성물"][hero]={"awakened":true}
	var after: Dictionary=Slot.effects(runtime,hero)
	check(after.status_effect_ids.size()==1 and before.status_effect_ids.is_empty(),"same permanent awakening flag selects exact slot11 group")
	check(not after.stats.has("xp") and not after.stats.has("skill_cooldown_reduction_pct"),"additional awakening excludes primary-only options")
	check(Slot.status_available(runtime,hero,int(after.status_effect_ids[0])),"secondary aura requires its actual StatusEffectID row")
	check(Slot.effects(runtime,hero)==after,"repeated effect reads are deterministic and do not stack")
	check(Slot.eligibility(runtime,"",0,{}).ok,"release remains possible without unlock")
	var limited: Dictionary={}
	for key: String in DATA.relic_card_keys():
		var row: Dictionary=DATA.relic_card(key)
		if int(row.card.ServerLimitSetID)==274:limited=row;break
	check(not Slot.source_available(limited.card,{"source_snapshot":"patch523","ServiceRegionCode":"KR","WorldNo":1}),"missing source server definition and time conditions remain unavailable")
	check(not Slot.scope_available(772,{}),"server scope requires explicit source region/world")
	for row: Dictionary in DATA.relic_server_limits_for(772):
		if int(row.ServerLimitSetID)==772:
			check(Slot.scope_available(772,{"source_snapshot":"patch523","ServiceRegionCode":str(row.ServiceRegionCode),"WorldNo":int(row.WorldNo)}),"exact523 server tuple recognized");break
	print("NATIVE_RELIC_SUBSLOT ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
