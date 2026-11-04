extends RefCounted
## Existing permanent-card and physical-inventory contracts, never equipped looks.
const Conditions=preload("res://scripts/cards/source_collection_conditions.gd")
var conditions=Conditions.new()
var legacy_catalog: Dictionary={}
var policy: Dictionary={}
func configure(data: Dictionary,catalog: Dictionary,execution_policy: Dictionary) -> void:
	conditions.configure(data.get("server_limits",[]));policy=execution_policy
	legacy_catalog.clear()
	for item: Dictionary in catalog.get("아이템",[]):
		var name_value: String=str(item.get("name",""))
		if not legacy_catalog.has(name_value):legacy_catalog[name_value]=[]
		if not str(item.get("sourceId","")).is_empty():legacy_catalog[name_value].append(item)
static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))
func server_allowed(limit_id: int,context: Dictionary) -> bool:
	return conditions.evaluate(limit_id,context).status in ["unrestricted","eligible"]
func candidate(req: Dictionary,owned: Dictionary,inventory: Dictionary,instances: Dictionary,context: Dictionary,used: Dictionary) -> Dictionary:
	var kind: int=int(req.kind);var id: int=int(req.class_id)
	if kind in [14,4]:
		var category: String="변신" if kind==14 else "마법인형"
		var key: String="source:m508:"+str(1 if kind==14 else 2)+":"+str(id)
		var value: Variant=owned.get(category,{}).get(key,false)
		var ok: bool=value is bool and value and server_allowed(int(req.target.ServerLimitSetID),context)
		return {"ok":ok,"identity":key,"reason":"영구 보유 및 원본 서버 조건 필요" if not ok else "보유","name":req.name}
	var eligible: Array=[]
	for raw_id: Variant in instances:
		var iid: String=str(raw_id)
		if bool(policy.get("distinct_equipment_per_slot",true)) and used.has(iid):continue
		var physical: Variant=instances[raw_id]
		if not physical is Dictionary or not integer(physical.get("level",0)) or int(physical.get("level",0))<int(req.min_enchant):continue
		var name_value: String=str(physical.get("name",""));var count: Variant=inventory.get(name_value,0)
		if not integer(count) or int(count)<1:continue
		var physical_count: int=0
		for item: Variant in instances.values():
			if item is Dictionary and item.get("name","")==name_value:physical_count+=1
		if physical_count>int(count):continue
		var pinned: Dictionary=physical.get("record",{}) if physical.get("record",{}) is Dictionary else {}
		var source: String=str(pinned.get("sourceId",""))
		var native: bool=source=="m508:item:"+str(id) and int(pinned.get("source_item_class_id",0))==id and pinned.get("source","") in ["lineagem_base508","lineagem_patch523"]
		var bridge: bool=false
		if not native and bool(policy.get("legacy_exact_catalog_bridge",true)) and name_value==str(req.name) and not source.begins_with("m508:item:"):
			var matches: Array=legacy_catalog.get(name_value,[])
			# This is an explicit local compatibility policy. It neither equates
			# unrelated numeric IDs nor writes a native ID onto old equipment.
			bridge=matches.size()==1 and (pinned.is_empty() or (source==str(matches[0].sourceId) and pinned.get("source","")==matches[0].get("source","")))
		if native or bridge:eligible.append({"id":iid,"level":int(physical.level),"identity_mode":"native_item_class" if native else "twilight_exact_catalog_bridge"})
	eligible.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return int(a.level)<int(b.level) or (a.level==b.level and str(a.id)<str(b.id)))
	if eligible.is_empty():return {"ok":false,"name":req.name,"reason":"인벤토리 장비 및 최소 강화 +"+str(int(req.min_enchant))+" 필요"}
	return {"ok":true,"name":req.name,"reason":"보유","instance_id":eligible[0].id,"enchant":eligible[0].level,"identity_mode":eligible[0].identity_mode}
func evaluate(combo: Dictionary,owned: Dictionary,inventory: Dictionary,instances: Dictionary,context: Dictionary) -> Dictionary:
	var result: Dictionary={"ok":server_allowed(int(combo.source.ServerLimitSetID),context),"slots":[],"reason":""}
	if not result.ok:result.reason="원본 조합 서버 조건 확인 필요"
	var used: Dictionary={}
	for slot: Dictionary in combo.slots:
		var candidates: Array=[];var matched: Dictionary={}
		for req: Dictionary in slot.candidates:
			var view: Dictionary=candidate(req,owned,inventory,instances,context,used);candidates.append(view)
			if matched.is_empty() and view.ok:matched=view
		if matched.is_empty():result.ok=false
		elif matched.has("instance_id"):used[str(matched.instance_id)]=true
		result.slots.append({"index":slot.index,"ok":not matched.is_empty(),"candidates":candidates,"matched":matched})
	if not result.ok and str(result.reason).is_empty():result.reason="보유 또는 최소 강화 조건 미충족"
	return result
