extends SceneTree
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Native=preload("res://scripts/cards/native_collection_rules.gd")
var errors: Array[String]=[]
var checks: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	if not ResourceLoader.exists("res://scripts/lineagem_base508.gd"):push_error("PR217 native runtime required");quit(2);return
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world)
	for frame: int in range(2):await process_frame
	world.set_process(false);world.save_timer=-10000
	for category: String in Cards.CATEGORIES:world.card_draw_fusion.owned[category]={}
	world._invalidate_equipment_static()
	var before_dg: int=world._effective_dg()
	var before_magic: int=world._player_critical_rate("magic")
	var before_fear_hit: int=world._fear_accuracy_stat()
	var before_fear_resist: int=world._fear_resistance_stat()
	for category: String in Cards.CATEGORIES:
		for record: Dictionary in world.catalog_db[category]:world.card_draw_fusion.owned[category][Cards.card_id(record)]=true
	world._invalidate_equipment_static()
	var record: Dictionary=world.card_collections.stat_record()
	var totals: Dictionary=world.card_collections.totals.duplicate(true)
	check(world.card_collections.core is Native,"native catalog selects native core")
	check(world._record_dg(record)==int(totals.get("melee_evasion:flat",0)),"World DG consumer reads exact source melee-evasion value")
	check(world._record_critical_bonus(record,"magic")==int(totals.get("magic_critical_rate:percent",0)),"World magic-critical consumer reads exact source scoped rate")
	check(world._record_fear_accuracy(record)==int(totals.get("fear_hit:percent",0)),"World fear-hit consumer reads exact native target8 value")
	check(world._record_fear_resistance(record)==int(totals.get("fear_resistance:percent",0)),"World fear-resistance consumer reads exact native target8 value")
	check(world._effective_dg()>=before_dg+int(totals.get("melee_evasion:flat",0)),"source DG reaches actual player stat")
	check(world._player_critical_rate("magic")>=before_magic+int(totals.get("magic_critical_rate:percent",0)),"source magic crit reaches actual player stat")
	check(world._fear_accuracy_stat()>=before_fear_hit+int(totals.get("fear_hit:percent",0)),"source fear hit reaches actual player stat")
	check(world._fear_resistance_stat()>=before_fear_resist+int(totals.get("fear_resistance:percent",0)),"source fear resistance reaches actual player stat")
	var ledger_hash: int=hash(world.card_draw_fusion.export_state())
	var count: int=0
	for equipped: Dictionary in world._all_equipped_records():
		if bool(equipped.get("_card_collection_bonus",false)):count+=1
	check(count==1,"derived collection record enters equipped stat pipeline once")
	world._invalidate_equipment_static()
	check(world.card_collections.stat_record()==record,"rebuild preserves exact record without double bonus")
	check(hash(world.card_draw_fusion.export_state())==ledger_hash,"stat reads/rebuild do not modify ownership")
	for category: String in Cards.CATEGORIES:world.card_draw_fusion.owned[category]={}
	world._invalidate_equipment_static()
	check(world.card_collections.stat_record().is_empty(),"source rewards removed when required owned cards removed")
	check(world._effective_dg()==before_dg and world._player_critical_rate("magic")==before_magic and world._fear_accuracy_stat()==before_fear_hit and world._fear_resistance_stat()==before_fear_resist,"actual player stat channels return to empty-owned baseline")
	print(JSON.stringify({"checks":checks,"errors":errors,"native_added_channels":Native.stat_record_additions(totals),"test_state":"in-memory isolated native ownership fixture, no gameplay or save changes"}))
	world.queue_free();for frame: int in range(3):await process_frame
	quit(0 if errors.is_empty() else 1)
