extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
var failures: Array[String]=[]
var checks: int=0
func check(value: bool,label: String)->void:
 checks+=1
 if not value:failures.append(label);printerr("QUEST_BOOK_IDENTITY_FAIL: "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func _initialize()->void:call_deferred("run")
func run()->void:
 check(FileAccess.get_sha256("user://twilight_v20_save.json")=="975b900968005f768b0154f2a2a9fe396954a1f098791d704b5d6d5930cdba92","untouched actual811 source-issued seed")
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w)
 w.set_process(false);w.player.set_physics_process(false)
 check(QA.enter_game(w,"마법사"),"normal class picker selects eligible source class")
 var uid: String=""
 for id: String in w.item_instances:
  if int(w.item_instances[id].get("record",{}).get("source_item_class_id",0))==177252:uid=id;break
 check(not uid.is_empty(),"genuine quest4991 physical reward owned")
 if uid.is_empty():w.queue_free();quit(1);return
 var original: Dictionary=w.item_instances[uid].duplicate(true)
 var record: Dictionary=D.variant_item(D.definition_id("177252").native_record,1)
 var before: String=FileAccess.get_sha256(w.save_path())
 var inventory: Dictionary=w.inventory.duplicate(true)
 var reader: RefCounted=w.quest_item_provider.skill_books
 var wrong: Dictionary=D.variant_item(D.definition_id("177252").native_record,2)
 var result: Dictionary=reader.use(w,wrong,uid)
 check(not result.ok and not result.saved and int(result.consumed)==0,"different blessing cannot consume selected normal physical receipt")
 check(w.inventory==inventory and w.item_instances[uid]==original and FileAccess.get_sha256(w.save_path())==before,"wrong blessing preserves actual quantity/proof/save bytes")
 var invalid: Dictionary=record.duplicate(true);invalid.source_use_spec.source_spell_row_sha256="0".repeat(64)
 result=reader.use(w,invalid,uid)
 check(not result.ok and w.inventory==inventory and FileAccess.get_sha256(w.save_path())==before,"tampered source spell proof cannot learn or consume")
 w.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
 result=reader.use(w,record,uid)
 check(not result.ok and w.inventory==inventory and w.item_instances[uid]==original and FileAccess.get_sha256(w.save_path())==before,"new explicit blessing receipt also rolls back failed save")
 w.equipment_collections.test_save_writer=Callable()
 var bag: Variant=w.hud.lineage_inventory_ui
 bag.set_character_state(w.hud.character_state);bag.inventory=w.inventory
 bag._select_item(str(original.name)+"@@@"+uid)
 check(not bag.detail_action.disabled,"actual selected book inventory button enabled")
 bag.detail_action.pressed.emit()
 var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
 var receipts: Array=saved.consumable_state.get("source_skill_book_receipts",[])
 check(receipts.size()==1 and int(receipts[0].bless_raw)==1 and receipts[0].input.quest_receipt==norm(original.quest_reward_receipt),"exact input blessing and immutable actual quest proof saved")
 var key: String=str(reader.identity(record).local_skill_id)
 check(int(saved.original_skill_state.learned.get(key,0))==1 and int(saved.inventory.get(original.name,0))==int(inventory[original.name])-1 and not saved.item_instances.has(uid),"current learning and real selected debit saved together")
 w.consumable_service.import_state(saved.consumable_state)
 check(norm(w.consumable_service.export_state())==saved.consumable_state,"new blessing proof retained by receipt import/export")
 print("QUEST_BOOK_IDENTITY_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"source_item_id":177252,"input_bless":1,"rejected_bless":2,"actual_inventory_button":true,"final_save_sha256":FileAccess.get_sha256(w.save_path())}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
