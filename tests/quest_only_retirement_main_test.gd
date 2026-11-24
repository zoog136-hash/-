extends SceneTree
## New default catalog/download decisions never rewrite old ownership or
## disable a normal quest award merely because it is quest-granted.
const Q=preload("res://scripts/quests/retired_quest_items523.gd")
const RET=preload("res://scripts/loot/retired_enhancement_items523.gd")
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const RAW=preload("res://scripts/resources/current523_definition_rows.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const NAME="[퀘스트] 죽은 모험가의 일지"
const SAME_LOOT="일반 획득물"
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);printerr("QUEST_ONLY_RETIREMENT_FAIL ",label)
	return ok
func _initialize()->void:run.call_deferred()
func run()->void:
	ck(Q.IDS.size()==424 and Q.IDS.has(1214) and Q.IDS.has(129691) and Q.IDS.has(122562),"pinned exact ID group and category/legacy examples")
	ck(Q.matches_reference({},NAME) and Q.matches_reference({"source_item_class_id":1214.0},NAME) and not Q.matches_reference({"source_item_class_id":233},NAME),"legacy aliases exact and different positive identity wins")
	ck(not Q.matches_reference({},"[퀘스트] 임의 재료") and not Q.matches_reference({"source_item_class_id":366},"[재료] 가죽") and not Q.item(139581),"ordinary similar name, quest-goal leather, and Diamond remain")
	for id: int in [366,233,139781,306611,901,307971,19372]:
		ck(not RET.item(id),"nonquest ordinary reward, material or behavior survives: "+str(id))
	var ordinary:Dictionary={"ID":99,"type_name":"Exp","Amount":5,"CharacterClassID":0,"RewardClassID":0,"ClanOnly":false,"RewardEnhancementTypeID":1}
	var prop:Dictionary={"ID":98,"type_name":"Item","Amount":1,"CharacterClassID":0,"RewardClassID":1214,"ClanOnly":false,"RewardEnhancementTypeID":1}
	var plan:Dictionary=SOURCE.new().reward_plan({"enhancements":[],"source_rewards":[ordinary,prop]}, {})
	ck(plan.get("ok",false) and plan.exp==5 and plan.items.is_empty() and plan.source_retired_rewards.size()==1,"exclude the exact prop without refusing or changing a valid neighboring award")
	if ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated gameplay file"):
		await main_fixture()
	print("QUEST_ONLY_RETIREMENT_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func main_fixture()->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"actual Main entered")
	await process_frame;await process_frame
	w.player.set_physics_process(false);w.field_population.set_process(false)
	for id:int in Q.IDS:
		ck(not INV.stage(w,[{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"qa"}).get("ok",false),"normal supplier denies exact quest-only item "+str(id))
	var h:Node=w.hud
	var bag:Control=h.lineage_inventory_ui
	w.inventory[NAME]=1
	w.inventory[SAME_LOOT]=1
	ck(w._save_game(true)==OK,"old quest-only plain holding remains saved")
	var before:String=FileAccess.get_sha256(w.save_path())
	w._load_game(true)
	ck(w.inventory.get(NAME)==1,"load does not delete old quest-only count")
	h.refresh_inventory(w.inventory);w._update_hud();h.toggle_inventory()
	var rows:Array=bag._inventory_entries()
	ck(rows.any(func(r:Dictionary)->bool:return r.get("reference")==SAME_LOOT) and not rows.any(func(r:Dictionary)->bool:return r.get("name")==NAME),"the shared active bag list hides only the quest-only row")
	h.inventory_item_activated.emit(NAME)
	ck(h.message_label.text==RET.REASON and w.inventory.get(NAME)==1 and FileAccess.get_sha256(w.save_path())==before,"real activation refuses without changing old save bytes")
	# An older receipt may still reference the disabled row. The bag's shared
	# view filters it without touching the historical object or receipt.
	var receipt:Dictionary={"item_class_id":1214,"reward_id":862,"quest_id":"m523:quest:271"}
	var held:String="[원본 보상] "+NAME
	w.inventory[held]=1
	w.item_instances["aaaa1200"]={"name":held,"record":{"name":held,"source_item_class_id":1214},"source_reward_quantity":1,"quest_reward_receipt":receipt.duplicate(true)}
	h.refresh_inventory(w.inventory);w._update_hud()
	ck(not bag._inventory_entries().any(func(r:Dictionary)->bool:return r.get("name")==held) and w.item_instances.get("aaaa1200",{}).get("quest_reward_receipt")==receipt,"active surfaces suppress physical row, not receipt history")
	var raw:String=OS.get_environment("TWILIGHT_QUEST_ONLY_DEFINITIONS")
	if not raw.is_empty():
		OS.set_environment("TWILIGHT_PATCH523_CONTENT",raw);RAW.reset()
		ck(RAW.identity().get("source_sha256")==RAW.SOURCE_SHA,"verified unchanged original source")
		var parsed:Array[Dictionary]=RAW.rows("ItemClass")
		var normal:int=0
		for original:Dictionary in parsed:
			if original.get("TestItem")==false and Q.item(original.ID):normal+=1
		ck(normal==206 and parsed.size()==34743 and RAW.row("ItemClass",1214).get("TestItem")==true,"all current original IDs and raw history remain; exact scope has 206 non-test")
	w.queue_free();await process_frame
