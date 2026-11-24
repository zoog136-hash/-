extends SceneTree
## The original 'AutoUseRegistrable' row no longer turns HP into an
## unsupported effect. Check actual bag and original-configured quickslot.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const ID=19473
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);printerr("NATIVE_AUTO_HP_MAIN_FAIL ",label)
	return ok
func _initialize()->void:run.call_deferred()
func run()->void:
	var source:String=OS.get_environment("TWILIGHT_AUTO_HP_DEFINITIONS")
	if not source.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated Main file"):
		await exact(source)
	else:
		ck(D.hp_use_metadata({}).get("ok")==false,"no input is not an HP potion")
	print("NATIVE_AUTO_HP_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

static func expected_hp(w:Node)->int:
	var rng:=RandomNumberGenerator.new();rng.seed=w.rng.seed;rng.state=w.rng.state
	var raw:int=20+rng.randi_range(1,6)+rng.randi_range(1,6)
	var amount:int=int(w._source_hp_potion_parameters(raw).heal_amount)
	return mini(w._effective_max_hp(),w.hp+int(w.patch523_npc_spells.extensions.healing(amount,true)))

func exact(source:String)->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"actual Main enters")
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",source);SOURCE.reset()
	ck(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"pinned original exact source")
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var item:Dictionary=D.variant_item(D.definition_id(str(ID)).get("native_record",{}),1)
	var profile:Dictionary=STACK.profile(item);var meta:Dictionary=profile.get("metadata",{})
	var dice:Dictionary=item.get("heal_spec",{})
	if not ck(profile.get("kind")=="hp" and meta.get("auto_use_registrable")==true and meta.get("source_consume_delay_ms")==1000 and meta.get("consume_effect_sprite_id")==16007 and dice.get("HPRestoration")==20 and dice.get("HPRestorationDiceNumber")==2 and dice.get("HPRestorationDiceSpotCount")==6,"original 20+2d6 HP, 1000ms, original effect, and auto flag"):
		w.queue_free();await process_frame;return
	w.catalog_db["아이템"].append(item);w._index_catalog_item_sources()
	if not ck(INV.commit(w,[{"item_class_id":ID,"amount":2,"bless_raw":1,"enchant":0}],{"kind":"qa_auto_hp_potion"}),"two physical units through the original supply owner"):
		w.queue_free();await process_frame;return
	var uid:String=""
	for candidate:String in w.item_instances:
		if STACK.proof(w,candidate).get("receipt",{}).get("item_class_id")==ID:uid=candidate;break
	if not ck(not uid.is_empty(),"physical receipt found"):
		w.queue_free();await process_frame;return
	var name:String=str(item.name);var ref:String=name+"@@@"+uid
	w.hp=w._effective_max_hp()
	w.hud.inventory_item_activated.emit(ref)
	ck(STACK.proof(w,uid).get("remaining")==2,"full HP refuses without wasting the original bottle")
	w.hp=10
	var expected:int=expected_hp(w)
	w.hud.inventory_item_activated.emit(ref)
	ck(w.hp==expected and STACK.proof(w,uid).get("remaining")==1 and w.item_use_cooldowns.get("m523:item:19473")==1.0,"actual manual bag use keeps source roll, consumes one and starts 1s cooldown: "+w.hud.message_label.text)
	w.hud.inventory_item_activated.emit(ref)
	ck(w.hp==expected and STACK.proof(w,uid).get("remaining")==1,"immediate second press preserves remaining copy")
	ck(w._save_game(true)==OK,"ordinary coalesced adjustment persists at normal save")
	w._load_game(true)
	ck(w.hp==expected and STACK.proof(w,uid).get("remaining")==1,"durable actual HP and debit after reload")
	w.item_use_cooldowns.clear();w.hp=10;w.auto_item_clock=0.0
	w.quickslots[0]={"kind":"item","id":name,"auto":true}
	ck(w._quickslot_registration_error("item",name).is_empty() and w._quickslot_auto_allowed(w.quickslots[0]),"real quickslot registration and enabled automatic use")
	expected=expected_hp(w)
	w._run_auto_item_quickslots(1.0)
	ck(w.hp==expected and not w.item_instances.has(uid) and not w.inventory.has(name),"actual auto quickslot consumes same physical bottle, exact roll and no second debit")
	w.queue_free();await process_frame
