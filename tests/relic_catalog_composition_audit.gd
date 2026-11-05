extends SceneTree
## Production catalog resolution with controlled ownership/class/weapon inputs.
## This is a capability audit, not 119 actual casts or a Main execution claim.
const Catalog = preload("res://scripts/skills/skill_catalog.gd")
const Rules = preload("res://scripts/cards/relic_spell_levels.gd")
const Base = preload("res://scripts/lineagem_base508.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
class Ledger extends RefCounted:
	var owned: Dictionary={"성물":{}}
class Conditions extends RefCounted:
	func source_server_context() -> Dictionary:return {}
class Host extends Node:
	var job_class: String="기사"
	var level: int=99
	var equipped_items: Dictionary={}
	var equipped_catalog: Dictionary={"성물":{}}
	var card_draw_fusion=Ledger.new()
	var card_collections=Conditions.new()
	var weapon: String="검"
	func _current_weapon_type() -> String:return weapon
func _initialize() -> void:
	var source: String="";var output: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-zip="):source=arg.trim_prefix("--source-zip=")
		if arg.begins_with("--audit-output="):output=arg.trim_prefix("--audit-output=")
	if not Rules.load_source(source).get("ok",false):printerr("Verified source required");quit(2);return
	var host:=Host.new();var catalog=Catalog.new();catalog.configure(host)
	if catalog.source523.profiles.size()!=441:printerr("Verified general skill pack required");host.free();quit(2);return
	for row: Dictionary in Base.cards().catalog["성물"]:
		if int(row.source_card_id)==21518:host.equipped_catalog["성물"]=row;host.card_draw_fusion.owned["성물"][Cards.card_id(row)]=true
	var rows: Array=[];var available: int=0;var blocked: Array=[];var pvp: Array=[]
	for id: String in Rules._rules.spell_profiles:
		var record: Dictionary=catalog.by_id[id]
		host.job_class=str(record.get("classes",[record["class"]])[0])
		host.weapon=str(record.get("weapons",["검"])[0]) if not record.get("weapons",[]).is_empty() else "검"
		host.equipped_items={"weapon":{"type":host.weapon}}
		catalog.schools["요정"]=str(record.get("school","water"))
		catalog.learned={id:1}
		for required: String in catalog.relations.get(id,{}).get("requires_skill",[]):catalog.learned[required]=1
		var raw: Dictionary=Rules.EFFECTS.project(record.duplicate(true),Rules._rules.spell_profiles[id],{"effective_level":1,"bonus":1,"code":"ready"},host.level,true)
		if raw.relic_spell_effect.applied.is_empty():continue
		var resolved: Dictionary=catalog.resolve(record)
		var meta: Dictionary=resolved.get("relic_spell_effect",{})
		var native: int=int(Rules._rules.spell_profiles[id].binding.spell_id)
		var row: Dictionary={"id":id,"native_spell_id":native,"name":record.name,"class":host.job_class,"source_block_reason":resolved.get("source523_block_reason",""),"enabled":catalog.enabled(record),"level_code":meta.get("code","unprojected"),"applied":meta.get("applied",[]),"pending":meta.get("pending",[])}
		rows.append(row)
		if native in [33162,69711]:pvp.append(row)
		elif meta.get("applied",[]).is_empty():blocked.append(row)
		else:available+=1
	var result: Dictionary={"scope":"PRODUCTION_CATALOG_CONTROLLED_STATE; NOT_ALL_MAIN_CASTS","projected_non_pvp":rows.size()-pvp.size(),"catalog_available":available,"blocked_base_contracts":blocked,"pvp_consumer_pending":pvp,"rows":rows}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		if file==null:printerr("Audit output unavailable");host.free();quit(2);return
		file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print("RELIC_CATALOG_COMPOSITION_AUDIT ",JSON.stringify({"catalog_available":available,"blocked_base_contracts":blocked.size(),"pvp_pending":pvp.size()}))
	for row: Dictionary in blocked:print("RELIC_BASE_CONTRACT_PENDING ",row.native_spell_id," ",row.name," ",row.source_block_reason)
	host.free();quit(0)
