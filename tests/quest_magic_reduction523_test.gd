extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("QUEST_MAGIC_REDUCTION_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func hit(w: Node,actor: Node,kind: String,enabled: bool,source_spell: bool=false)->Dictionary:
 w.ui_preferences["quest523_source_magic_reduction_enabled"]=enabled;w.hp=w._effective_max_hp();w.rng.seed=424242
 var before: int=w.hp
 if source_spell:w.resolve_patch523_npc_hit(actor,1000,{},kind)
 else:w._on_player_hit(actor,1000,kind)
 return {"hp_loss":before-w.hp,"stage":w.quest_item_provider.equipment_owner.last_magic_hit.duplicate(true)}
func _initialize()->void:call_deferred("run")
func run()->void:
 var seed: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
 check(seed.length()==64 and FileAccess.file_exists("user://twilight_v20_save.json") and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact actual27-unit gear/remaining source producer save before Main")
 if not failures.is_empty():quit(1);return
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main/class")
 var owner: RefCounted=w.quest_item_provider.equipment_owner;var id: String=""
 for uid: String in w.item_instances:
  if int(w.item_instances[uid].get("record",{}).get("source_item_class_id",0))==30213 and w.item_instances[uid].has("quest_reward_receipt"):id=uid;break
 check(not id.is_empty(),"genuine remaining source30213 reward")
 if id.is_empty():w.queue_free();await process_frame;quit(1);return
 var input: Dictionary=w.item_instances[id].duplicate(true);var objects: Dictionary=w.item_instances.duplicate(true);var inventory: Dictionary=w.inventory.duplicate(true);var claims: Dictionary=w.quest_service.claimed.duplicate(true);var slots: Array=w.quickslots.duplicate(true);var rng: int=w.rng.state;var gold: int=w.gold;var hash: String=FileAccess.get_sha256(w.save_path())
 var q: Dictionary=owner.quote(w,id);check(q.get("ok",false),"exact full positive source profile AC5/MR2/magic3percent supports current source constraints")
 if not q.get("ok",false):print("MAGIC_HELD "+str(q.get("reason")));w.queue_free();await process_frame;quit(1);return
 owner.cancel(q.token);check(not owner.commit(w,q).get("ok",false) and FileAccess.get_sha256(w.save_path())==hash,"cancelled selection has no debit/effect/save")
 w.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
 check(not owner.commit(w,owner.quote(w,id)).get("ok",false),"failed equip save refused");w.equipment_collections.test_save_writer=Callable()
 check(w.item_instances==objects and w.inventory==inventory and FileAccess.get_sha256(w.save_path())==hash,"failed source equip preserves physical ownership and old bytes")
 var bag: Variant=w.hud.lineage_inventory_ui;bag.set_character_state(w.hud.character_state);bag.inventory=w.inventory;bag._select_item(str(input.name)+"@@@"+id);check(not bag.detail_action.disabled,"existing actual inventory equip action; no UI replacement");bag.detail_action.pressed.emit()
 var output: String=""
 for uid: String in w.item_instances:
  if w.item_instances[uid].get("quest_source_input_physical_id")==id:output=uid;break
 check(not output.is_empty() and w.equipped_items.gaiters.get("instance_id")==output and owner._state_matches(w,output).get("ok",false),"one genuine selected unit -> exact physical UUID/equip/receipt")
 if output.is_empty():w.queue_free();await process_frame;quit(1);return
 for uid: String in objects:
  if uid!=id:check(w.item_instances.get(uid)==objects[uid],"all unrelated source/legacy/native physical copies unchanged")
 check(int(w.equipped_items.gaiters.def)==5 and int(w.equipped_items.gaiters.mr)==2 and int(w.equipped_items.gaiters.quest_source_magic_reduction.source_percent)==3,"original AC5/MR2/magic3percent retained separately from host calculation policy")
 for raw: int in [1,17,50,1000,1001]:
  check(owner.reduce_hit(w,raw,"magic")==maxi(1,int(round(raw*.97))),"exact source3percent with existing labelled rounding/min1")
  check(owner.reduce_hit(w,raw,"melee")==raw and owner.reduce_hit(w,raw,"ranged")==raw,"physical/ranged damage channels do not receive magic-only reduction")
 var original: Dictionary=w.item_instances[output].duplicate(true);w.item_instances[output].level=1
 check(owner.reduce_hit(w,1000,"magic")==1000,"unsupported modified/enhanced physical state cannot receive the reviewed+0 effect");w.item_instances[output]=original.duplicate(true)
 # Controlled actor/channel/RNG/unsafe-position fixture, not a natural encounter.
 var old_position: Vector2=w.player.global_position;var point: Vector2=old_position;var unsafe: bool=false
 for delta: Vector2 in [Vector2(1024,1024),Vector2(-1024,1024),Vector2(1024,-1024),Vector2(-1024,-1024)]:
  if w.field_map!=null and not w.field_map.is_safe(old_position+delta):point=old_position+delta;unsafe=true;break
 if not unsafe and w.field_map!=null:
  for child: Node in w.monsters_root.get_children():
   if child is TwilightMonster and not w.field_map.is_safe(child.global_position) and w.field_map.point_clear(child.global_position,4):point=child.global_position;unsafe=true;break
 if not unsafe and w.field_map!=null:
  var cells: Variant=w.field_map.get("entry_cells")
  if cells is PackedInt32Array:
   var stride: int=maxi(1,int(cells.size()/2048))
   for n: int in range(0,cells.size(),stride):
    var flat: int=int(cells[n]);var candidate: Vector2=w.field_map.cell_to_world(Vector2i(flat%w.field_map.width,int(flat/w.field_map.width)))
    if not w.field_map.is_safe(candidate) and w.field_map.point_clear(candidate,4):point=candidate;unsafe=true;break
 print("MAGIC_CONTEXT "+JSON.stringify({"unsafe_found":unsafe,"active_map":w.active_map_id,"point":[point.x,point.y],"field":w.field_map.get_script().resource_path if w.field_map!=null else "missing"}))
 check(unsafe,"existing map has a controlled non-safe hit context")
 var hp_before: int=w.hp;var mp_before: int=w.mp;var active_skills: Dictionary=w.active_skill_buffs.duplicate(true);var active_items: Dictionary=w.active_item_buffs.duplicate(true)
 w.active_skill_buffs={};w.active_item_buffs={};w.player.global_position=point
 var actor: TwilightMonster=w.MONSTER_SCENE.instantiate();w.monsters_root.add_child(actor);actor.setup(w.monster_db[0].duplicate(true),w.player,w,null);actor.set_physics_process(false);actor.global_position=point+Vector2(32,0);actor.magic_accuracy=999999;actor.melee_accuracy=999999;actor.ranged_accuracy=999999;actor.magic_critical_rate=0;actor.melee_critical_rate=0;actor.ranged_critical_rate=0;actor.attack_element="physical"
 for kind: String in ["stun","silence","hold","fear","poison","bleed"]:
  actor.set(kind+"_duration",0);actor.set(kind+"_accuracy",0)
 var measured: Dictionary={}
 if unsafe:
  for kind: String in ["magic","melee","ranged"]:
   var disabled: Dictionary=hit(w,actor,kind,false);var enabled: Dictionary=hit(w,actor,kind,true);measured[kind]={"disabled":disabled,"enabled":enabled}
   if kind=="magic":check(disabled.hp_loss>0 and enabled.hp_loss>0 and enabled.hp_loss<disabled.hp_loss and enabled.stage.get("damage_before")==1000 and enabled.stage.get("damage_after")==970,"actual common player-hit magic damage executes source3percent before existing later defenses")
   else:check(enabled.hp_loss==disabled.hp_loss and enabled.stage.is_empty(),"actual other hit channels retain existing damage behavior")
  var disabled: Dictionary=hit(w,actor,"magic",false,true);var enabled: Dictionary=hit(w,actor,"magic",true,true);measured["source_spell_entry"]={"disabled":disabled,"enabled":enabled}
  check(disabled.hp_loss>enabled.hp_loss and enabled.stage.get("damage_after")==970,"existing source-NPC spell entry reaches same single authoritative reduction hook")
 actor.queue_free();w.player.global_position=old_position;w.hp=hp_before;w.mp=mp_before;w.active_skill_buffs=active_skills;w.active_item_buffs=active_items;w.rng.state=rng;w.ui_preferences.erase("quest523_source_magic_reduction_enabled")
 bag.set_character_state(w.hud.character_state);bag._select_item(str(original.name)+"@@@"+output);bag.detail_action.pressed.emit();check(owner.reduce_hit(w,1000,"magic")==1000 and w.item_instances[output]==original,"same-UUID unequip removes effect without altering owned physical proof")
 bag.set_character_state(w.hud.character_state);bag._select_item(str(original.name)+"@@@"+output);bag.detail_action.pressed.emit();check(owner.reduce_hit(w,1000,"magic")==970,"same-UUID re-equip restores original reduction without regrant")
 check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots) and w.gold==gold and w.rng.state==rng,"original claims50slots/currency/RNG preserved after restoring controlled combat context")
 check(w._save_game(true)==OK,"effect equipment/receipt/original ownership saved")
 var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));hash=FileAccess.get_sha256(w.save_path());w.queue_free();await process_frame
 w=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"fresh actual Main reconnect")
 check(norm(w.item_instances)==saved.item_instances and norm(w.equipped_items)==saved.equipped_items and w.quest_item_provider.equipment_owner.reduce_hit(w,1000,"magic")==970 and FileAccess.get_sha256(w.save_path())==hash,"same saved source UUID/receipt/equipment/magic effect restore")
 print("QUEST_MAGIC_REDUCTION_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"actual_item_class":30213,"source_magic_damage_reduction_percent":3,"measured_controlled_hits":measured,"native_order_rounding_or_natural_encounter_probability_verified":false,"final_save_sha256":hash}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
