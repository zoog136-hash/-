extends SceneTree
## Real Main, production bag request and exact original rectangles, with
## controlled source-field coordinates for positive and boundary checks.
## This test does not certify that the device has the tower S32 map installed.
const RAW=preload("res://scripts/resources/current523_definition_rows.gd")
const DTO=preload("res://scripts/loot/current523_native_item_projection.gd")
const FIELDS=preload("res://scripts/loot/current523_native_fields.gd")
const E=preload("res://scripts/loot/source523_item_effects.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const S=preload("res://scripts/loot/current523_native_stack.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const LAND=45374
const LOW=Vector2i(32768,32832)
const LAST=Vector2i(32830,32894)
const OUT=Vector2i(32831,32894)
const FIRST=[137513,137523,137533]
class Host extends TwilightWorld:
	var original_regional_owner_fixture:bool=false
	func current523_aden_source_active()->bool:return original_regional_owner_fixture or super.current523_aden_source_active()
var checks:int=0
var failures:Array[String]=[]
var rejected:Dictionary={}
func ck(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);printerr("TRIAL_COIN_MAIN_FAIL ",label)
	return ok
func refuse(_path:String,payload:Dictionary)->Error:
	rejected=payload
	return ERR_CANT_CREATE
func _initialize()->void:run.call_deferred()
func run()->void:
	var source:String=OS.get_environment("TWILIGHT_TRIAL_COIN_DEFINITIONS")
	if not source.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated file"):
		await exact(source)
	else:
		ck(DTO.TRIAL_COIN_IDS.size()==21 and not DTO.TRIAL_COIN_IDS.has(208612),"active source identities only")
	print("TRIAL_COIN_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"basis":"actual_main_bag_source_coordinate_fixture; live_Map_pack_entry_not_tested"}))
	quit(0 if failures.is_empty() else 1)
static func record(id:int)->Dictionary:
	return D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)
static func mount(w:Node,field:OriginalPlayableField,cell:Vector2i)->void:
	w.field_map=field;w.original_regional_owner_fixture=true
	w.player.global_position=field.coordinates.to_world(Vector2(cell))
static func restore(w:Node,field:PlayableField,position:Vector2)->void:
	w.field_map=field;w.original_regional_owner_fixture=false;w.player.global_position=position

func exact(source:String)->void:
	var w:Node=load("res://Main.tscn").instantiate();w.set_script(Host);root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"actual Main enters")
	await process_frame;await process_frame;w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",source);RAW.reset()
	ck(RAW.identity().get("source_sha256")==RAW.SOURCE_SHA,"pinned original data")
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var areas:Variant=E.consume_areas([10353])
	if not ck(areas is Array and areas.size()==100 and areas[0].land==LAND and areas[0].rect==Rect2i(LOW,Vector2i(63,63)),"100 exact allowed rectangles; real half-open floor 1"):w.queue_free();await process_frame;return
	for id:int in DTO.TRIAL_COIN_IDS:
		var item:Dictionary=record(id)
		var p:Dictionary=S.profile(item)
		var spec:Dictionary=p.get("spec",{})
		ck(p.get("kind")=="buff" and spec.get("source_trial_tower_territory_id")==10353 and spec.get("duration_seconds")==300 and spec.get("typed_effects",{}).size()==8,"shared exact original static contract "+str(id))
		if id in FIRST:w.catalog_db["아이템"].append(item)
	for id:int in [208612,208622,208632]:ck(S.profile(record(id)).is_empty() and S.supply_profile(record(id)).is_empty(),"excludes unused source coin "+str(id))
	w._index_catalog_item_sources()
	var grants:Array=[]
	for id:int in FIRST:grants.append({"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0})
	if not ck(INV.commit(w,grants,{"kind":"qa_native_trial_coins"}),"real original physical supply for ranks 1-3"):w.queue_free();await process_frame;return
	var ids:Dictionary={}
	for uid:String in w.item_instances:
		var proof:Dictionary=S.proof(w,uid)
		var id:int=int(proof.get("receipt",{}).get("item_class_id",0))
		if id in FIRST:ids[id]=[str(proof.record.name),uid]
	if not ck(ids.size()==3,"three independent source receipts"):w.queue_free();await process_frame;return
	var previous:PlayableField=w.field_map;var previous_point:Vector2=w.player.global_position
	var field:=OriginalPlayableField.new()
	field.definition={"source_land_id":LAND,"source_map_id":13246,"source_sha256":RAW.SOURCE_SHA};field.data={"source_land_id":LAND}
	if not ck(field.coordinates.configure([LOW.x,LOW.y],[64,64]),"configured canonical source coordinates"):w.queue_free();await process_frame;return
	var first:String=str(ids[FIRST[0]][0])+"@@@"+str(ids[FIRST[0]][1])
	var bytes:String=FileAccess.get_sha256(w.save_path())
	w.hud.inventory_item_activated.emit(first)
	ck(w.hud.message_label.text.contains("원본 시련의 탑") and S.proof(w,ids[FIRST[0]][1]).get("remaining")==1 and FileAccess.get_sha256(w.save_path())==bytes,"normal play/local floor grants no buff and makes no debit")
	mount(w,field,OUT)
	w.hud.inventory_item_activated.emit(first)
	ck(w.hud.message_label.text.contains("좌표 밖") and S.proof(w,ids[FIRST[0]][1]).get("remaining")==1 and FileAccess.get_sha256(w.save_path())==bytes,"exclusive end cell refuses physical use")
	mount(w,field,LOW)
	w.equipment_collections.test_save_writer=refuse
	w.hud.inventory_item_activated.emit(first)
	ck(not rejected.get("item_instances",{}).has(ids[FIRST[0]][1]) and not rejected.get("active_item_buffs",{}).is_empty(),"refused save would contain exact coin debit and source buff: "+w.hud.message_label.text)
	ck(S.proof(w,ids[FIRST[0]][1]).get("remaining")==1 and w._active_item_buff_total("melee_damage")==0 and FileAccess.get_sha256(w.save_path())==bytes,"save refusal changes neither rank nor debit")
	w.equipment_collections.test_save_writer=Callable()
	restore(w,previous,previous_point);w._load_game(true)
	for index:int in FIRST.size():
		mount(w,field,LAST if index==2 else LOW)
		var r:Array=ids[FIRST[index]];var ref:String=str(r[0])+"@@@"+str(r[1])
		w.hud.inventory_item_activated.emit(ref)
		ck(not w.item_instances.has(r[1]) and w._active_item_buff_total("melee_damage")==[3,5,10][index] and w.active_item_buffs.get(r[0],{}).get("duration")==300.0,"real physical use valid at half-open inside cell, exact non-stacking rank "+str(index+1)+": "+w.hud.message_label.text)
	restore(w,previous,previous_point);w._load_game(true)
	ck(w._active_item_buff_total("melee_damage")==0 and not w._combined_active_buffs().has(ids[FIRST[2]][0]),"reloaded outside the source tower never borrows its stats or icon")
	mount(w,field,LOW)
	ck(w._active_item_buff_total("melee_damage")==10 and not w.item_instances.has(ids[FIRST[2]][1]),"captured field witness restores exact unexpired effect and the saved debit")
	w._tick_item_buffs(301.0)
	ck(w._active_item_buff_total("melee_damage")==0,"the original 300 seconds runs out")
	restore(w,previous,previous_point);field.close()
	w.queue_free();await process_frame
