extends SceneTree
## Exact user disposition of the 124 unprojected raw item IDs. No private
## inputs required for policy/real Main grant and save checks; raw-source
## recharge is added only with the explicitly supplied original definition.
const R=preload("res://scripts/loot/retired_enhancement_items523.gd")
const T=preload("res://scripts/content523/tutorial523.gd")
const S=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const EFFECTS=preload("res://scripts/loot/source523_item_effects.gd")
const RULES=preload("res://scripts/einasad/einasad523_rules.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const DIAMOND=139581
const OLD_SCROLL="[퀘스트] 은기사 마을 이동 주문서 · 원본#141203"
var checks:int=0
var failures:Array[String]=[]
var rejected:Dictionary={}
func ck(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message);printerr("AUDITED_ITEM_DISPOSITION_FAIL ",message)
	return ok
func reject(_path:String,payload:Dictionary)->Error:
	rejected=payload
	return ERR_CANT_CREATE
func _initialize()->void:run.call_deferred()
func run()->void:
	var ids:Dictionary=R.IDS.duplicate()
	ids.merge(R.AUDIT_IDS);ids.merge(R.AUDIT_SCROLL_IDS)
	ck(ids.size()==94 and R.IDS.size()==17 and R.AUDIT_IDS.size()==38 and R.AUDIT_SCROLL_IDS.size()==39,"exact three non-overlapping exclusion groups")
	ck(not R.item(DIAMOND) and not T.item(DIAMOND) and not T.item(141203) and T.item(6171),"Dragon Diamond allowed; retired scroll not purged by tutorial migration")
	ck(not R.retired_reference("은기사 마을 이동 주문서") and not R.retired_reference("은기사 마을 이동 주문서 · 원본#141204") and R.retired_reference(OLD_SCROLL+" · 축복@@@123"),"retirement exact numeric reference only")
	var clean:Dictionary=T.restored_grants({"removed_items":{"139581":3,"141203":5,"6171":2},"restored_items":{"139581":1}})
	ck(clean.get("ledger")=={"139581":3} and clean.get("grants",[{}])[0].get("amount")==2,"only recorded eligible quantity can return, never retired scroll")
	ck(T.restored_grants({"removed_items":{"139581":"3"}}).is_empty() and T.restored_grants({"removed_items":{"139581":3.5}}).is_empty(),"malformed migration count cannot issue items")
	if ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated fixture"):
		await main(ids)
	print("AUDITED_ITEM_DISPOSITION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func main(ids:Dictionary)->void:
	var w:Node=load("res://Main.tscn").instantiate()
	root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"real Main initialization")
	w.player.set_physics_process(false);w.field_population.set_process(false)
	for id:int in ids:
		ck(R.item(id) and R.item(float(id)) and not INV.stage(w,[{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"qa"}).get("ok",false),"normal native grant rejected exactly: "+str(id))
	w.inventory[OLD_SCROLL]=1
	ck(w._save_game(true)==OK,"exact old scroll can persist without restoring gameplay")
	var before:String=FileAccess.get_sha256(w.save_path())
	w.hud.inventory_item_activated.emit(OLD_SCROLL)
	ck(w.inventory.get(OLD_SCROLL)==1 and w.hud.message_label.text==R.REASON and FileAccess.get_sha256(w.save_path())==before,"actual bag refuses old scroll without spending or modifying saved bytes")
	ck(w.consumable_service.try_use(OLD_SCROLL) and w.hud.message_label.text==R.REASON and w.inventory.get(OLD_SCROLL)==1 and FileAccess.get_sha256(w.save_path())==before,"direct consumer rejects same exact retired reference without altering old ownership")
	w.inventory={};w._load_game(true)
	ck(w.inventory.get(OLD_SCROLL)==1,"old scroll record is preserved after file reload")
	var src:String=OS.get_environment("TWILIGHT_AUDIT_DIAMOND_DEFINITIONS")
	if not src.is_empty():
		await actual_diamond(w,src)
	w.queue_free();await process_frame

func actual_diamond(w:Node,src:String)->void:
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",src);S.reset();RULES.reset_cache()
	if not ck(S.identity().get("source_sha256")==S.SOURCE_SHA,"verified original definition"):
		return
	# Configure the actual already-booted owners with their exact single admitted
	# ItemClass. This avoids re-materializing unrelated 30k rows for this fixture.
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var item:Dictionary=D.variant_item(D.definition_id(str(DIAMOND)).get("native_record",{}),1)
	if not ck(not item.is_empty() and STACK.profile(item).get("kind")=="ain" and EFFECTS.ain(item).get("points")==100 and EFFECTS.ain(item).get("consume_rate_group")==12,"original Dragon Diamond routes to existing exact 100-point recharge"):
		return
	w.catalog_db["아이템"].append(item);w._index_catalog_item_sources()
	w.tutorial523={"start_grant":{},"removed_items":{"139581":2,"141203":5}}
	var name:String=item.name
	ck(w._save_game(true)==OK,"durable baseline with historical migration ledger")
	var before:String=FileAccess.get_sha256(w.save_path())
	w.equipment_collections.test_save_writer=reject
	w._tutorial523_grant_retry_at=0.0;w._tutorial523_start_grant()
	ck(rejected.get("inventory",{}).get(name)==2 and rejected.get("tutorial523",{}).get("restored_items",{}).get("139581")==2,"one candidate contains restored physical inventory and idempotence marker")
	ck(not w.inventory.has(name) and not w.tutorial523.has("restored_items") and FileAccess.get_sha256(w.save_path())==before,"failed atomic save grants nothing and keeps retryable ledger")
	w.equipment_collections.test_save_writer=Callable()
	w._tutorial523_grant_retry_at=0.0;w._tutorial523_start_grant()
	ck(w.inventory.get(name)==2 and w.tutorial523.get("restored_items",{})=={"139581":2} and w.inventory.get(OLD_SCROLL)==1,"only previous physical Diamond quantity returned; old scroll neither granted nor removed")
	var uid:String=""
	for key:String in w.item_instances:
		var value:Dictionary=w.item_instances[key]
		if value.get("name")==name and not STACK.proof(w,key).is_empty():uid=key;break
	if not ck(not uid.is_empty(),"original held receipt exists"):return
	w.level=50
	w.ain_service.blessing=150
	ck(w._save_game(true)==OK,"clean charge checkpoint")
	var projected:Dictionary=EFFECTS.prepare(w,item,"ain")
	if not ck(projected.get("ok",false),"original recharge allowed on ordinary character: "+str(projected.get("reason",""))):return
	var target:int=int(projected.ainhasad_state.blessing)
	var ref:String=name+"@@@"+uid
	before=FileAccess.get_sha256(w.save_path())
	rejected.clear()
	w.equipment_collections.test_save_writer=reject
	w.hud.inventory_item_activated.emit(ref)
	ck(rejected.get("inventory",{}).get(name)==1 and rejected.get("ainhasad_state",{}).get("blessing")==target,"actual writer saw both one-item debit and recharge: "+str(w.hud.message_label.text))
	ck(w.inventory.get(name)==2 and w.ain_service.blessing==150 and FileAccess.get_sha256(w.save_path())==before,"ordinary bag recharge rolls back pack and blessing when writer refuses")
	w.equipment_collections.test_save_writer=Callable()
	w._load_game(true) # a refused physical write holds repeat use until reload
	w.hud.inventory_item_activated.emit(ref)
	ck(w.inventory.get(name)==1 and w.ain_service.blessing==target and target>150 and STACK.proof(w,uid).get("remaining")==1,"actual Main bag consumes one exact Diamond and applies original recharge: "+str(w.hud.message_label.text)+" inv="+str(w.inventory.get(name))+" blessing="+str(w.ain_service.blessing)+" target="+str(target)+" proof="+str(STACK.proof(w,uid).get("remaining")))
	w._load_game(true);w._tutorial523_grant_retry_at=0.0;w._tutorial523_start_grant()
	ck(w.inventory.get(name)==1 and w.ain_service.blessing==target and w.tutorial523.get("restored_items",{}).get("139581",0)==2,"file reload and another tick cannot resurrect the used Diamond: "+str(w.inventory.get(name))+" "+str(w.ain_service.blessing))
	await process_frame
