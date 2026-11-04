extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("QUEST_GEAR_WEAPON_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func _initialize()->void:call_deferred("run")
func run()->void:
 var seed: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
 check(seed.length()==64 and FileAccess.file_exists("user://twilight_v20_save.json") and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact actual prior gear save before Main")
 if not failures.is_empty():quit(1);return
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual saved Main/class")
 var owner: RefCounted=w.quest_item_provider.equipment_owner;var claims: Dictionary=w.quest_service.claimed.duplicate(true);var slots: Array=w.quickslots.duplicate(true);var rng: int=w.rng.state;var gold: int=w.gold;var offhand: Dictionary=w.equipped_items.get("offhand",{}).duplicate(true);var ids: Array=[]
 for iid: int in [248]:
  var id: String=""
  for uid: String in w.item_instances:
   if int(w.item_instances[uid].get("record",{}).get("source_item_class_id",0))==iid and w.item_instances[uid].has("quest_reward_receipt"):id=uid;break
  check(not id.is_empty(),"genuine original weapon reward "+str(iid))
  if id.is_empty():continue
  var before: Dictionary=w.item_instances.duplicate(true);var q: Dictionary=owner.quote(w,id)
  if iid==929:
   check(not q.get("ok",false) and w.item_instances==before,"source UseImmediately reward remains held pending its exact immediate-use owner");print("QUEST_WEAPON_HELD "+JSON.stringify({"item_class_id":iid,"source_use_immediately":true,"reason":q.get("reason","")}));continue
  check(q.get("ok",false),"native plus existing class/weapon/shield conditions")
  if not q.get("ok",false):continue
  owner.cancel(q.token)
  var bag: Variant=w.hud.lineage_inventory_ui;bag.set_character_state(w.hud.character_state);bag.inventory=w.inventory;bag._select_item(str(w.item_instances[id].name)+"@@@"+id);check(not bag.detail_action.disabled,"actual selected weapon UI");bag.detail_action.pressed.emit()
  var output: String=""
  for uid: String in w.item_instances:
   if w.item_instances[uid].get("quest_source_input_physical_id")==id:output=uid;break
  check(not output.is_empty() and w.equipped_items.weapon.get("instance_id")==output and owner._state_matches(w,output).get("ok",false),"selected source weapon UUID/equip/receipt authenticated")
  if output.is_empty():continue
  for uid: String in before:
   if uid!=id:check(w.item_instances.get(uid)==before[uid],"no competing legacy/native physical object consumed")
  var snapshot: Dictionary=w._character_stats_snapshot();var small: int=10;var large: int=11
  check(int(snapshot.weapon_small_damage)==small and int(snapshot.weapon_large_damage)==large,"original small/large bounds reach actual character and damage input consumers")
  check(w.ITEM_OPTIONS.accuracy(w._equipped_weapon_record(),"melee")== (2 if iid==249 else 0),"exact weapon hit field reaches current accuracy consumer")
  check(w.equipped_items.get("offhand",{})==offhand and w.rng.state==rng,"compatible existing shield and normal draw/combat RNG unchanged by equip")
  check(w.equipped_items.weapon.get("quest_source_weapon_erosion",{}).get("original_value")==1 and not w.equipped_items.weapon.get("quest_source_weapon_erosion",{}).get("enhancement_destruction_exemption",true),"source erosion immunity retained separately from enhancement destruction")
  # Controlled size contexts verify the real existing host combat roll, not natural encounter rates.
  var physical_before: Dictionary=w.item_instances[output].duplicate(true)
  var target:=TwilightMonster.new();var control:=RandomNumberGenerator.new();control.state=w.rng.state
  for size: String in ["small","large"]:
   target.set_meta("size_class",size)
   for sample: int in range(8):
    var expected: int=control.randi_range(1,small if size=="small" else large)
    check(w._roll_weapon_damage(target)==expected,"actual existing1..source bound roll for controlled target size")
  target.free();w.rng.state=rng;check(w.item_instances[output]==physical_before,"controlled existing damage rolls never erode or alter the actual source weapon");ids.append(iid)
 check(ids==[248],"exact erosion-immune original sword selected and executed")
 check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots) and w.rng.state==rng and w.gold==gold,"original claims50bindings,unrelated currency/RNG preserved")
 var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));var hash: String=FileAccess.get_sha256(w.save_path());var current: Dictionary=w._character_stats_snapshot()
 w.queue_free();await process_frame;w=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"fresh actual Main reconnect")
 var restored: Dictionary=w._character_stats_snapshot();check(norm(w.item_instances)==saved.item_instances and norm(w.equipped_items)==saved.equipped_items and restored.weapon_small_damage==current.weapon_small_damage and restored.weapon_large_damage==current.weapon_large_damage and FileAccess.get_sha256(w.save_path())==hash,"exact source weapon ownership/equip/damage inputs reconnect")
 print("QUEST_WEAPON248_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"actual_additional_item_classes":ids,"save_sha256":hash,"host_uniform1_to_source_bound_preserved":true,"original_WeaponErodeProof1_preserved_under_existing_no_erosion_policy":true,"enhancement_break_immunity_not_inferred":true,"controlled_target_sizes_not_natural_probabilities":true,"scope":"existing host size-bound weapon/hit consumers; no native combat equivalence or erosion/other flags waived"}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
