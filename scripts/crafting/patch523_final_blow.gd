extends RefCounted
## Exact source probability/amplification; hit scope/order are TWILIGHT policy.
const FIELD_NAMES={"FinalBlowProbability":"source_final_blow_chance_pct","FinalBlowAdditionalScale":"source_final_blow_amp_pct"}

static func base(book: RefCounted,record: Dictionary,bless: int) -> Dictionary:
	var result: Dictionary={}
	var id: String=book.identity({"record":record})
	if not record.get("source_m_native_item",false) or bless not in [1,2] or not book.catalog_identity_matches(record,id):return result
	var item: Dictionary=book.item_entry(id)
	if item.get("item_class",{}).get("TestItem",true):return result
	for row: Dictionary in item.get("item_bonuses",[]):
		if row.get("IsPossession")!=false:continue
		var bonus: Dictionary=book.data.bonuses.get(str(int(row.BonusID)),{})
		var kind: Dictionary=book.data.bonus_types.get(str(int(bonus.get("BonusTypeID",0))),{})
		if not FIELD_NAMES.has(kind.get("Name","")) or kind.get("UnitID")!=3 or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0:continue
		var key: String=FIELD_NAMES[kind.Name]
		result[key]=float(result.get(key,0))+float(bonus.Value)/10000.0
	# A +0 family denotes whole values, so its baseline is not added twice.
	# The currently connected crystal families have no base final-blow rows.
	var families: Dictionary={}
	for row: Dictionary in item.get("enchant_effects",[]):
		var group: String=str(int(row.ItemEnchantBonusGroupID))
		if not families.has(group):families[group]=[]
		if not families[group].has(int(row.BlessCode)):families[group].append(int(row.BlessCode))
	for row: Dictionary in item.get("enchant_effects",[]):
		var codes: Array=families[str(int(row.ItemEnchantBonusGroupID))]
		if int(row.EnchantLevel)!=0 or int(row.BlessCode)!=(bless if codes.has(bless) else 0):continue
		var bonus: Dictionary=book.data.bonuses.get(str(int(row.BonusID)),{})
		var kind: Dictionary=book.data.bonus_types.get(str(int(bonus.get("BonusTypeID",0))),{})
		if FIELD_NAMES.has(kind.get("Name","")) and bonus.get("BonusApplicationTypeID")==0 and bonus.get("BonusApplicationTargetID")==0:result.erase(FIELD_NAMES[kind.Name])
	return result

static func conditional_stun_active(world: Node,target: Node) -> bool:
	var subject: String=str(world.PATCH523_ENHANCE.policy().get("source_stun_condition_subject","disabled"))
	if subject=="self_status":return is_instance_valid(world.player) and world.player.is_stunned()
	return subject=="target_status" and is_instance_valid(target) and target.has_method("is_stunned") and target.call("is_stunned")

static func conditional_magic_damage(world: Node,target: Node,by_spell: bool) -> int:
	var scope: String=str(world.PATCH523_ENHANCE.policy().get("source_conditional_magic_scope","disabled"))
	if scope!="all_successful_hits" and not (by_spell and scope=="spell_hits_only"):return 0
	return maxi(0,int(world._equipment_inven_sum("source_stun_magic_damage"))) if conditional_stun_active(world,target) else 0

static func totals(world: Node,target: Node=null) -> Dictionary:
	var out: Dictionary={"chance_pct":world._equipment_inven_sum("source_final_blow_chance_pct"),"amp_pct":world._equipment_inven_sum("source_final_blow_amp_pct")}
	if conditional_stun_active(world,target):out.chance_pct+=world._equipment_inven_sum("source_final_blow_stun_chance_pct")
	for record: Dictionary in world._all_equipped_records():
		var physical: Dictionary=world.item_instances.get(str(record.get("instance_id","")),{})
		var bless: int=world.patch523_equipment.bless_code(physical) if not physical.is_empty() else 1
		var extra: Dictionary=base(world.patch523_equipment,record,bless)
		out.chance_pct+=float(extra.get("source_final_blow_chance_pct",0))
		out.amp_pct+=float(extra.get("source_final_blow_amp_pct",0))
	return out

static func damage(world: Node,amount: int,by_spell: bool,target: Node=null) -> int:
	world.patch523_final_blow_fired=false
	var policy: Dictionary=world.PATCH523_ENHANCE.policy()
	if amount<=0 or (by_spell and policy.get("source_final_blow_scope","")!="all_successful_hits"):return amount
	var current: Dictionary=totals(world,target)
	var threshold: int=clampi(int(round(float(current.chance_pct)*10000.0)),0,1000000)
	var amplification: float=maxf(0,float(current.amp_pct))
	if threshold<=0 or amplification<=0:return amount
	if threshold<1000000 and world.rng.randi_range(0,999999)>=threshold:return amount
	var extra: float=float(amount)*amplification/100.0
	var increase: int=maxi(0,int(floor(extra)) if policy.get("source_final_blow_rounding","")=="floor" else int(round(extra)))
	world.patch523_final_blow_fired=true
	world.hud.append_log("결정타 · 대미지 +%d · 원본 증폭 %.2f%% · 계산 순서는 TWILIGHT 설정" % [increase,amplification])
	return amount+increase
