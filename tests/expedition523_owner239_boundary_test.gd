extends SceneTree
## Real Main + published239 pure ownership reader. No copied owner World,
## fake successful consumer, recipe/effect completion or target grant.
const QA=preload("res://tests/qa_class_selection.gd")
const Bridge=preload("res://scripts/expedition/reward_bridge.gd")
var world:TwilightWorld
var checks:int=0
var failures:Array=[]
var ownership_proofs:int=0
var scroll_proofs:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("OWNER239_BOUNDARY_FAIL ",label)
func snap()->String:
	return JSON.stringify([world.inventory,world.item_instances,world.gold,world.expedition_local.export_state(),world.rng.state,world.card_draw_fusion.export_state()])
func _initialize()->void:call_deferred("run")
func run()->void:
	world=(load("res://Main.tscn") as PackedScene).instantiate() as TwilightWorld
	root.add_child(world);check(QA.enter_game(world),"actual Main entry")
	world.process_mode=Node.PROCESS_MODE_DISABLED;world.save_timer=-100000.0
	var source:RefCounted=world.get_expedition_catalog()
	check(source.ready(),"reuse already held expedition input")
	check(ResourceLoader.exists(Bridge.MATERIAL_SCRIPT),"real432ee5a6 ownership module installed in test stage")
	if not source.ready() or not ResourceLoader.exists(Bridge.MATERIAL_SCRIPT):finish();return
	var rules:RefCounted=load("res://scripts/crafting/patch523_rules.gd").new()
	var input:String=""
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--equipment523-reference="):input=arg.trim_prefix("--equipment523-reference=")
	check(rules.load_file(input,"b6b2589c15853b1998ecfc6484438a1fe0ef8e8e125d7d1d558e49c116f879ce"),"real current rules load existing unchanged v8 reference")
	if rules.data.is_empty():finish();return
	var helper:Script=load(Bridge.MATERIAL_SCRIPT)
	var context:Dictionary={"expedition_owner":world.expedition_local}
	var missing:Array=[]
	for id:int in helper.IDS:
		if not rules.data.items.has(str(id)):missing.append(id);continue
		var key:String="%d:1:0"%id
		world.expedition_local.state.storage[key]=2 # Explicit controlled stock, not an exploration RNG assertion.
		check(world.expedition_local.withdraw(key,2).ok,"real typed storage receipt "+str(id))
		var name:String=world.expedition_local.state.issued[key]
		var material:Dictionary={"source_id":str(id),"item":rules.record(str(id)).name,"physical":false,"bless_code":1,"level":0,"quantity":1}
		var before:String=snap();var disk:String=FileAccess.get_sha256(world.save_path())
		var owned:Dictionary=helper.owned(rules,material,world.inventory,world.item_instances,{},context)
		check(owned.has(name) and int(owned[name].amount)==2,"actual owner accepts exact issued-key ownership only "+str(id))
		check(rules.available_material(material,world.inventory,{},world.item_instances,{}, {},false,world.gold,context)==2,"published available_material reads typed quantity through actual context "+str(id))
		check(helper.owned(rules,material,world.inventory,world.item_instances,{name:true},context).is_empty(),"actual owner rejects source-key lock "+str(id))
		var record:Dictionary=world._find_catalog_item_record(name)
		record.source_m_native_item=true
		check(helper.owned(rules,material,world.inventory,world.item_instances,{},context).is_empty(),"namespace promotion is rejected "+str(id))
		record.erase("source_m_native_item")
		var can_store:bool=record.IsStorable;record.IsStorable=not can_store
		check(helper.owned(rules,material,world.inventory,world.item_instances,{},context).is_empty(),"changed source transfer restriction is rejected "+str(id))
		record.IsStorable=can_store
		world._on_inventory_item_activated(name)
		check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"missing integrated crafting host preserves receipt quantity and RNG "+str(id))
		ownership_proofs+=1
	check(missing==[341344,341354,341364],"held v8 absence distinguished from current owner definitions")
	check(ownership_proofs==41,"forty-one proofs are ownership only, not recipe/server qualification")
	for id:int in [137,138]:
		for bless:int in [1,2,3]:
			var key:String="%d:%d:0"%[id,bless]
			world.expedition_local.state.storage[key]=3
			check(world.expedition_local.withdraw(key,3).ok,"actual distinct scroll receipt "+key)
			var name:String=world.expedition_local.state.issued[key]
			check(helper.scroll(rules,name,world.inventory,world.item_instances,{},context).get("ok",false),"real owner proof preserves exact scroll blessing "+key)
			var before:String=snap();var disk:String=FileAccess.get_sha256(world.save_path())
			var boundary:Dictionary=world.expedition_local.inventory_activation(name)
			check(boundary.handled and not boundary.get("ok",false) and not boundary.get("committed",true),"missing full enhancement owner is explicit noncommit "+key)
			check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"selection boundary cannot debit/grant/save/roll "+key)
			world.expedition_local.state.issued.erase(key)
			check(not helper.scroll(rules,name,world.inventory,world.item_instances,{},context).get("ok",false),"actual owner rejects absent issuer proof "+key)
			before=snap();world._on_inventory_item_activated(name)
			check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"orphan typed scroll cannot fall into substring legacy enhancement "+key)
			world.expedition_local.state.issued[key]=name
			scroll_proofs+=1
	check(scroll_proofs==6,"six source tuples checked without claiming six enhancement executions")
	finish()
func finish()->void:
	print("EXPEDITION523_OWNER239_BOUNDARY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"ownership_proofs":ownership_proofs,"scroll_proofs":scroll_proofs,"actual_craft_or_enhancement_transactions":0,"requires_integrated_host":true}))
	world.queue_free();quit(0 if failures.is_empty() else 1)
