extends SceneTree
const Core=preload("res://scripts/cards/skill_awakening_service.gd")
const Growth=preload("res://scripts/cards/skill_awakening_growth.gd")
const Source=preload("res://data/cards/base508_skill_awakening.json")
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message)
func fixture(core: RefCounted,identity: String) -> Dictionary:
	var card: Dictionary=core.cards[identity]
	var state: Dictionary=Core.fresh_state()
	state.metadata={"future":["keep",123]};state.rng_state="987654321";state.last_operation_id="old-operation"
	state.cards[identity]={"spell_id":int(core.candidates(identity)[0].spell_id),"level":1,"experience":"0","future_entry":{"keep":true}}
	state.cards["source:m523:98:99999999"]={"spell_id":1,"level":7,"experience":"123","unknown":"preserve"}
	return {"state":state,"cards":{"version":1,"owned":{card.category:{identity:true}},"spare":{card.category:{identity:2}},"pity":{"희귀":13},"preserved_unmapped_collection":{"future":7},"future_card_metadata":["preserve"]},"equipped":{card.category:{"sourceId":identity.trim_prefix("source:")}},"gold":10000000}
func rejected_unchanged(core: RefCounted,f: Dictionary,identity: String,material_id: String,expected_code: String) -> void:
	var before: int=hash(f)
	var result: Dictionary=Growth.prepare_feed(core,f.state,f.cards,f.gold,identity,material_id,int(f.state.revision),"feed-invalid")
	check(not result.ok and result.code==expected_code,"reject "+expected_code)
	check(hash(f)==before,"rejection leaves all inputs unchanged "+expected_code)
func _initialize() -> void:
	var core:=Core.new()
	check(Growth.validate_policy().is_empty(),"separate configurable economy validates")
	var tested: Dictionary={}
	var first: String=""
	for identity: String in core.cards:
		var card: Dictionary=core.cards[identity]
		var group: String=str(card.category)+":"+str(int(card.source_card.GradeID))
		if tested.has(group) or bool(card.source_card.IsNoMergeOut) or not core.eligibility(identity).ok:continue
		tested[group]=true
		if first.is_empty():first=identity
		var f: Dictionary=fixture(core,identity)
		var before: int=hash(f)
		var snapshot: Dictionary=Growth.view(core,f.state,f.cards.owned,identity,f.cards.spare,f.gold)
		check(snapshot.can_feed and not snapshot.can_enhance and not snapshot.enhancement_rng,"only deterministic EXP feed "+group)
		check(snapshot.quote.quantity==1 and snapshot.quote.provenance=="twilight_custom_economy","one-card local quote "+group)
		var threshold: int=int(core.profile(identity,1).experience_row.CumExp)
		var grade: String=str(int(card.source_card.GradeID))
		var economy: Dictionary=Growth.POLICY.data.custom_economy.grades[grade]
		var amount: int=int(snapshot.quote.experience)
		check(amount*int(economy.cards_per_level)>=threshold and (amount-1)*int(economy.cards_per_level)<threshold,"ceil conversion uses full static level gap "+group)
		var result: Dictionary=Growth.prepare_feed(core,f.state,f.cards,f.gold,identity,identity,0,"feed:"+group)
		check(result.ok and not result.committed and result.consumed_quantity==1 and int(result.consumed_gold)==int(economy.fee_adena),"staged exact debit "+group)
		check(result.card_state.spare[card.category][identity]==1 and result.card_state.owned==f.cards.owned,"duplicate debit preserves permanent owned card "+group)
		check(result.card_state.pity==f.cards.pity and result.card_state.preserved_unmapped_collection==f.cards.preserved_unmapped_collection and result.card_state.future_card_metadata==f.cards.future_card_metadata,"other card progress preserved "+group)
		check(result.gold==f.gold-int(economy.fee_adena) and result.state.revision==1 and result.state.last_operation_id=="feed:"+group,"single revision and quoted gold "+group)
		check(result.state.rng_state==f.state.rng_state and result.state.metadata==f.state.metadata and result.state.cards[identity].future_entry.keep and result.state.cards["source:m523:98:99999999"]==f.state.cards["source:m523:98:99999999"],"RNG and unknown metadata preserved "+group)
		check(hash(f)==before and core.validate_state(result.state).is_empty(),"pure preparation produces valid state "+group)
		var almost: Dictionary=f.state.duplicate(true)
		almost.cards[identity].experience=str(threshold-1)
		var leveled: Dictionary
		var multi: Dictionary
		var enough: int=int(core.profile(identity,19).experience_row.CumExp)
		if card.category=="성물":
			var no_hunt: Dictionary=Growth.prepare_hunt(core,almost,f.cards.owned,f.equipped,1)
			check(no_hunt.ok and not no_hunt.changed and no_hunt.state==almost,"unverified relic hunting cannot grant EXP "+group)
			leveled=Growth.prepare_feed(core,almost,f.cards,f.gold,identity,identity,0)
			check(leveled.ok and leveled.state.cards[identity].level==2 and leveled.state.cards[identity].experience==str(threshold-1+amount),"relic duplicate crosses exact source boundary "+group)
			var near_cap: Dictionary=f.state.duplicate(true)
			near_cap.cards[identity].experience=str(enough-1)
			multi=Growth.prepare_feed(core,near_cap,f.cards,f.gold,identity,identity,0)
			check(multi.ok and multi.state.cards[identity].level==20 and multi.state.cards[identity].experience==str(enough-1+amount),"relic duplicate crosses source thresholds up to level20 "+group)
		else:
			leveled=Growth.prepare_hunt(core,almost,f.cards.owned,f.equipped,1)
			check(leveled.ok and leveled.changed and leveled.state.cards[identity].level==2 and leveled.state.cards[identity].experience==str(threshold),"one earned EXP crosses exact source boundary "+group)
			multi=Growth.prepare_hunt(core,f.state,f.cards.owned,f.equipped,enough)
			check(multi.ok and multi.state.cards[identity].level==20 and multi.state.cards[identity].experience==str(enough),"large hunt gain crosses source thresholds up to level20 "+group)
		check(int(core.profile(identity,2).hp)==int(core.profile(identity,int(leveled.state.cards[identity].level)).hp),"level resolves actual source HP/invoke profile "+group)
		var maxed: Dictionary=Growth.prepare_hunt(core,multi.state,f.cards.owned,f.equipped,100)
		check(maxed.ok and not maxed.changed and maxed.state==multi.state,"max level preserves saved EXP and revision "+group)
		check(not Growth.view(core,multi.state,f.cards.owned,identity,f.cards.spare,f.gold).can_feed,"max level cannot spend a duplicate "+group)
		var last: Dictionary=f.cards.duplicate(true);last.spare[card.category][identity]=1
		var last_result: Dictionary=Growth.prepare_feed(core,f.state,last,f.gold,identity,identity,0)
		check(last_result.ok and not last_result.card_state.spare[card.category].has(identity) and last_result.card_state.owned[card.category][identity],"last duplicate is removed, first card retained "+group)
	check(tested.size()>=12,"eligible awakening deck/grade profiles: "+str(tested.keys()))
	if first.is_empty():errors.append("no eligible native fixture");finish();return
	var f: Dictionary=fixture(core,first)
	var category: String=str(core.cards[first].category)
	var before: int=hash(f)
	check(Growth.prepare_feed(core,f.state,f.cards,f.gold,first,first,99).code=="stale_revision" and hash(f)==before,"stale feed cannot spend")
	check(Growth.prepare_feed(core,f.state,f.cards,f.gold,first,first,0,"old-operation").code=="duplicate_operation" and hash(f)==before,"duplicate operation cannot spend")
	f.gold=0;rejected_unchanged(core,f,first,first,"insufficient_gold");f.gold=10000000
	f.cards.spare[category][first]=0;rejected_unchanged(core,f,first,first,"insufficient_material")
	f.cards.spare[category][first]=0.5;rejected_unchanged(core,f,first,first,"material_quantity")
	f.cards.spare[category][first]=2
	for material_id: String in ["193364","source:m523:item:193364","source:m508:41:25262","fallback:희귀:test:card"]:rejected_unchanged(core,f,first,material_id,"material_identity")
	var wrong_material: String=""
	var wrong_grade: String=""
	var restricted: String=""
	for identity: String in core.cards:
		if core.cards[identity].category!=category and core.eligibility(identity).ok:wrong_material=identity
		if core.cards[identity].category==category and int(core.cards[identity].source_card.GradeID)!=int(core.cards[first].source_card.GradeID) and core.eligibility(identity).ok:wrong_grade=identity
		if core.cards[identity].category==category and int(core.cards[identity].source_card.GradeID)==int(core.cards[first].source_card.GradeID) and bool(core.cards[identity].source_card.IsNoMergeOut) and core.eligibility(identity).ok:restricted=identity
	rejected_unchanged(core,f,first,wrong_material,"material_grade")
	rejected_unchanged(core,f,first,wrong_grade,"material_grade")
	if not restricted.is_empty():
		f.cards.owned[category][restricted]=true;f.cards.spare[category][restricted]=2
		rejected_unchanged(core,f,first,restricted,"material_restricted")
	f.cards.owned[category][first]=false;rejected_unchanged(core,f,first,first,"not_owned");f.cards.owned[category][first]=true
	var bad_card_state: Dictionary=f.cards.duplicate(true);bad_card_state.version=2
	check(Growth.prepare_feed(core,f.state,bad_card_state,f.gold,first,first,0).code=="card_state","unsupported card schema cannot be consumed")
	var raw: Dictionary=core.cards[first].source_card
	var original_start: int=int(raw.StartDateTimeID)
	raw.StartDateTimeID=99999999
	rejected_unchanged(core,f,first,first,"time_condition")
	check(not Growth.prepare_hunt(core,f.state,f.cards.owned,f.equipped,1).changed,"time restricted equipped source receives no EXP")
	raw.StartDateTimeID=original_start
	var invalid: Dictionary=f.state.duplicate(true);invalid.cards[first].experience="01"
	check(Growth.prepare_hunt(core,invalid,f.cards.owned,f.equipped,1).code=="invalid_state","noncanonical saved EXP rejected")
	for amount: Variant in [-1,0.5,Core.MAX_EXPERIENCE+1,"1"]:check(Growth.prepare_hunt(core,f.state,f.cards.owned,f.equipped,amount).code=="experience_amount","invalid hunt amount "+str(amount))
	check(not Growth.prepare_hunt(core,f.state,{},f.equipped,100).changed,"unowned equipped card receives no EXP")
	check(not Growth.prepare_hunt(core,f.state,f.cards.owned,{},100).changed,"unequipped cards receive no EXP")
	check(not Growth.prepare_hunt(core,f.state,f.cards.owned,f.equipped,0).changed,"zero EXP preserves state")
	var overflow: Dictionary=Growth.prepare_hunt(core,f.state,f.cards.owned,f.equipped,Core.MAX_EXPERIENCE)
	check(overflow.ok and overflow.state.cards[first].experience==str(Core.MAX_EXPERIENCE) and overflow.state.cards[first].level==20,"large EXP saturates safely at canonical maximum")
	var old: Dictionary=f.state.duplicate(true);old.cards[first].level=8;old.cards[first].experience="123"
	var preserved: Dictionary=Growth.prepare_hunt(core,old,f.cards.owned,f.equipped,1)
	check(preserved.ok and preserved.state.cards[first].level==8 and preserved.state.cards[first].experience=="124","existing low-EXP higher-level records never downgrade or reset")
	var final_before: int=hash(f)
	Growth.prepare_hunt(core,f.state,f.cards.owned,f.equipped,7)
	Growth.prepare_feed(core,f.state,f.cards,f.gold,first,first,0)
	check(hash(f)==final_before,"successful feed and hunt both preserve all original inputs")
	finish()
func finish() -> void:
	print("SKILL_AWAKENING_GROWTH ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
