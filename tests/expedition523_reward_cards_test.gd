extends SceneTree
const Source=preload("res://scripts/expedition/source_catalog.gd")
const Adapter=preload("res://scripts/expedition/reward_cards.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Base=preload("res://scripts/lineagem_base508.gd")
class ProfileHost extends Node:
	var catalog_db:Dictionary={}
	var skill_awakening=preload("res://scripts/cards/skill_awakening_runtime.gd").new()
var failures:Array=[]
var checks:int=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:
	var source=Source.new();var path:String="";var sha:String="";var reference:String=""
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--expedition523-pack="):path=arg.trim_prefix("--expedition523-pack=")
		if arg.begins_with("--expedition523-sha256="):sha=arg.trim_prefix("--expedition523-sha256=")
		if arg.begins_with("--card523-reference="):reference=arg.trim_prefix("--card523-reference=")
	check(source.install(path,sha),"verified unchanged native pack")
	if not source.ready():finish();return
	var catalog:Dictionary=Base.apply_catalog({})
	var before=Cards.new();before.configure(catalog)
	var old_pools:String=JSON.stringify(before.pools)
	var original:Dictionary=catalog.duplicate(true)
	Adapter.supplement(catalog,source)
	var after=Cards.new();after.configure(catalog)
	check(JSON.stringify(after.pools)==old_pools,"every existing draw/fusion pool entry unchanged")
	var found:int=0;var blocked:int=0
	for item:Dictionary in source.rows("ItemClass"):
		var raw:Dictionary=Adapter.fixed_target(source,int(item.ID))
		if raw.is_empty():continue
		found+=1
		check(not Adapter.registered(catalog,raw).is_empty(),"exact fixed-card target "+str(item.ID))
		if not Adapter.item_conditions(source,int(item.ID)).is_empty():blocked+=1
	check(found==28 and blocked==7,"28 fixed items retain6 TestItem and1 server772 restriction")
	check(after.known_ids["변신"].size()==before.known_ids["변신"].size()+1 and after.known_ids["마법인형"].size()==before.known_ids["마법인형"].size()+1,"only two missing source definitions appended")
	var raw:Dictionary=source.record("BuffCard",25242)
	var registered:Dictionary=Adapter.registered(catalog,raw)
	check(registered.sourceId=="m523:1:25242" and registered.source_original_card==raw and registered.grade=="희귀","new transform retains PR249 stable ID and full original row")
	check(after.receive_source_card("변신",registered,{"card_id":25242,"cannot_swap":true}).ok,"existing deterministic ownership API accepts verified new identity")
	check(after.receive_source_card("변신",registered,{"card_id":25242,"cannot_swap":true}).ok,"second actual copy becomes duplicate")
	var saved:Dictionary=after.export_state()
	var absent=Cards.new();absent.configure(original);absent.import_state(saved)
	check(absent.preserved_unmapped_collection["변신"].owned.get("source:m523:1:25242",false),"missing pack keeps owned new identity inert and preserved")
	var restored=Cards.new();restored.configure(catalog);restored.import_state(absent.export_state())
	check(restored.total_count("변신","source:m523:1:25242")==2,"returning pack recovers exact permanent and duplicate count")
	check(restored.source_card_receipts.size()==2 and restored.source_card_receipts[0].cannot_swap,"native source receipt provenance survives roundtrip")
	var bad:Dictionary=catalog.duplicate(true)
	for record:Dictionary in bad["변신"]:
		if record.sourceId=="m523:1:25242":record.sourceId="m523:1:25172"
	check(Adapter.registered(bad,raw).is_empty(),"wrong stable suffix cannot substitute another card")
	check(not Adapter.item_conditions(source,365592).is_empty(),"source TestItem is not inferred active from reward existence")
	if not reference.is_empty():
		# Read-only PR249 definitions; no gameplay branch/pack is merged or installed.
		var document:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(reference))
		var host:=ProfileHost.new();host.catalog_db=document.catalog
		Adapter.register_profiles(host,source)
		var count:int=0
		for category:String in document.catalog:
			for record:Dictionary in document.catalog[category]:
				var row:Dictionary=source.record("BuffCard",int(record.source_card_id))
				check(row==record.source_original_card,"PR249 original definition "+str(record.source_card_id))
				check(host.skill_awakening.core.cards.has(Cards.card_id(record)),"registered profile identity "+str(record.source_card_id))
				count+=1
		check(count==720,"all720 PR249 IDs supported when that catalog is registered")
		host.free()
	finish()
func finish()->void:
	print("EXPEDITION523_REWARD_CARDS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
