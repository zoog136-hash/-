extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const FIXED=preload("res://scripts/quests/quest_fixed_cards523.gd")
const CARDS=preload("res://scripts/card_draw_fusion.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("QUEST_FIXED_CARD_FAIL: "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func make_world()->TwilightWorld:
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w)
 w.set_process(false);w.player.set_physics_process(false)
 check(QA.enter_game(w),"real class-selected Main")
 return w
func activate(w: TwilightWorld,item: int,uid: String)->void:
 var record: Dictionary=D.variant_item(D.definition_id(str(item)).native_record,1)
 if not uid.is_empty() and w.item_instances.has(uid):
  var bag: Variant=w.hud.lineage_inventory_ui;bag.set_character_state(w.hud.character_state);bag.inventory=w.inventory
  bag._select_item(str(w.item_instances[uid].name)+"@@@"+uid)
  check(not bag.detail_action.disabled,"actual selected source card item button enabled")
  bag.detail_action.pressed.emit()
 else:w._on_inventory_item_activated(str(record.name))
func _initialize()->void:call_deferred("run")
func run()->void:
 var fresh: bool=false;var seed: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--quest-pack="):fresh=true;check(SOURCE.install_zip(arg.trim_prefix("--quest-pack=")).ok,"unchanged questv1 installed")
  if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
 if not fresh:
  check(FileAccess.get_sha256("user://twilight_v20_save.json")==seed and seed.length()==64,"untouched actual811 source-issued copy")
  if not failures.is_empty():quit(1);return
 var w: TwilightWorld=make_world()
 if fresh:
  for batch: int in range(100):
   w.quest_auto.retry_at=0;w.quest_auto.next_scan=0
   var count: int=w.quest_service.claimed.size();w.quest_auto.tick(w)
   if count==w.quest_service.claimed.size():break
  for i: int in range(50):w.quickslots[i]={"kind":"item","id":"HP 물약"} if i%3==0 else {}
  w.ui_preferences.edited_quickslots[w.job_class]=true
 var input_ids: Dictionary={};var targets: Dictionary={};var initial_quantities: Dictionary={}
 for item: int in FIXED.IDS:
  var record: Dictionary=D.variant_item(D.definition_id(str(item)).native_record,1)
  var target: Dictionary=FIXED.target(w,record);targets[item]=target
  check(not target.is_empty() and w.quest_item_provider.has_definition(item),"actual stable registry/NoSwap/NoMerge owner available "+str(item))
  var ids: Array=[]
  for uid: String in w.item_instances:
   if int(w.item_instances[uid].get("record",{}).get("source_item_class_id",0))==item:ids.append(uid)
  input_ids[item]=ids
  var quantity: int=int(w.inventory.get(str(record.name),0)) if fresh else ids.size()
  initial_quantities[str(item)]=quantity
  check(quantity==5 if item in [306611,306621] else quantity==10,"all actual source rewards retained "+str(item))
  if not fresh:
   for uid: String in ids:check(OWN.proof(w,uid).ok and int(OWN.proof(w,uid).original_quantity)==1,"real immutable individual source reward proof "+uid)
 for item: int in [969,970,992,993,994,996,997,998,999,1001,1003,1004,1005,1007,1009,1010,1012,1013,1016,1025,1030,1055,1063,1067,1076,35101,35111]:
  check(not w.quest_item_provider.has_definition(item),"source TestItem remains blocked "+str(item))
 var claims: Dictionary=w.quest_service.claimed.duplicate(true);var slots: Array=w.quickslots.duplicate(true)
 var before_cards: Dictionary=w.card_draw_fusion.export_state();var pity: Dictionary=w.card_draw_fusion.pity.duplicate(true);var rng: int=w.card_draw_fusion.rng.state
 var path: String=w.save_path();var hash: String=FileAccess.get_sha256(path)
 var inventory: Dictionary=w.inventory.duplicate(true);var instances: Dictionary=w.item_instances.duplicate(true)
 var item: int=306611;var target: Dictionary=targets[item]
 var uid: String="" if fresh else str(input_ids[item][0])
 var record: Dictionary=D.variant_item(D.definition_id(str(item)).native_record,1)
 var key: String=str(record.name) if fresh else str(w.item_instances[uid].name)
 var lock: String=key if fresh else key+"@@@"+uid
 w.ui_preferences.item_locks[lock]=true;activate(w,item,uid);w.ui_preferences.item_locks.erase(lock)
 check(w.inventory==inventory and w.card_draw_fusion.export_state()==before_cards and FileAccess.get_sha256(path)==hash,"lock blocks owned card grant without debit/save")
 var blocked_key: String=str(target.category)+":"+str(target.identity)
 w.card_draw_fusion.source_merge_blocked.erase(blocked_key);activate(w,item,uid);w.card_draw_fusion.source_merge_blocked[blocked_key]=true
 check(w.inventory==inventory and FileAccess.get_sha256(path)==hash,"missing actual downstream NoMerge guard blocks card grant")
 var wrong: Dictionary=D.variant_item(D.definition_id(str(item)).native_record,2)
 check(not FIXED.use(w,wrong,uid).ok and w.inventory==inventory,"different input blessing cannot consume actual source stock")
 var invalid: Dictionary=record.duplicate(true);invalid.source_use_spec.card_id=999999
 check(not FIXED.use(w,invalid,uid).ok and w.inventory==inventory,"tampered original card proof rejects")
 w.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
 activate(w,item,uid)
 check(w.inventory==inventory and w.item_instances==instances and w.card_draw_fusion.export_state()==before_cards and w.card_draw_fusion.rng.state==rng and FileAccess.get_sha256(path)==hash,"failed owner save preserves item/card/duplicates/receipt/RNG/bytes")
 w.equipment_collections.test_save_writer=Callable()
 activate(w,item,uid)
 check(w.card_draw_fusion.total_count(target.category,target.identity)==1 and w.card_draw_fusion.owned[target.category].get(target.identity)==true,"first actual quest unit unlocks one exact stable card")
 if not fresh:check(not w.item_instances.has(uid),"actual selected physical input spent without canonical conversion")
 var first_hash: String=FileAccess.get_sha256(path)
 if not fresh:
  w._on_inventory_item_activated(key+"@@@"+uid)
  check(FileAccess.get_sha256(path)==first_hash,"spent physical reward cannot regrant card")
 var second_uid: String="" if fresh else str(input_ids[item][1])
 w.equipment_collections.test_save_writer=func(p: String,data: Dictionary)->Error:
  var error: Error=WRITER.write(p,data)
  return ERR_FILE_CANT_WRITE if error==OK else error
 activate(w,item,second_uid)
 check(w.card_draw_fusion.total_count(target.category,target.identity)==2 and CARDS.quest_reserved_spare(w.card_draw_fusion.export_state(),target.category,target.identity)==1 and not w.quest_service.save_blocked,"write-then-error confirms exactly one duplicate and protected-copy receipt")
 w.equipment_collections.test_save_writer=Callable()
 var spare: int=int(w.card_draw_fusion.spare[target.category][target.identity])
 w.card_draw_fusion.spare[target.category][target.identity]=1000000
 var third_uid: String="" if fresh else str(input_ids[item][2]);var overflow_hash: String=FileAccess.get_sha256(path)
 var overflow_inventory: Dictionary=w.inventory.duplicate(true);activate(w,item,third_uid)
 check(w.inventory==overflow_inventory and FileAccess.get_sha256(path)==overflow_hash,"duplicate limit blocks before source debit")
 w.card_draw_fusion.spare[target.category][target.identity]=spare
 for source_item: int in FIXED.IDS:
  if fresh:
   var native: Dictionary=D.variant_item(D.definition_id(str(source_item)).native_record,1)
   while int(w.inventory.get(str(native.name),0))>0:
    var prior: int=int(w.inventory[native.name]);activate(w,source_item,"")
    if int(w.inventory.get(str(native.name),0))!=prior-1:check(false,"actual remaining native unit consumed");break
  else:
   for physical: String in input_ids[source_item]:
    if w.item_instances.has(physical):activate(w,source_item,physical)
 for source_item: int in FIXED.IDS:
  var t: Dictionary=targets[source_item];var expected: int=int(initial_quantities[str(source_item)])
  check(w.card_draw_fusion.total_count(t.category,t.identity)==expected and int(w.card_draw_fusion.spare[t.category].get(t.identity,0))==expected-1,"all genuine source units grant exact permanent+duplicate count "+str(source_item))
  check(CARDS.quest_reserved_spare(w.card_draw_fusion.export_state(),t.category,t.identity)==expected-1,"only new quest duplicate units protected against unsupported outgoing material use")
 check(w.card_draw_fusion.source_card_receipts.size()==30 and w.card_draw_fusion.pity==pity and w.card_draw_fusion.rng.state==rng,"thirty ownership receipts with unchanged ordinary draw/pity/RNG")
 var cards: Dictionary=w.card_draw_fusion.export_state()
 for grade: String in ["고급","희귀","영웅","전설"]:
  var prior: String=FileAccess.get_sha256(path)
  check(w.card_draw_fusion.spare_count("변신",grade)==0 and w.card_draw_fusion.fusion_batch_limit("변신",grade)==0,"source global NoMerge removes all four grade material counts")
  check(not w.card_draw_fusion.fuse("변신",grade).ok and not w.card_draw_fusion.fuse_many("변신",grade,10).ok and w.card_draw_fusion.export_state()==cards and w.card_draw_fusion.rng.state==rng,"actual single/batch fusion cannot consume restricted native identity "+grade)
  w._on_card_fusion_requested("변신",grade,10)
  check(FileAccess.get_sha256(path)==prior and w.card_draw_fusion.export_state()==cards,"actual world fusion button receiver preserves all source copies "+grade)
 w.hud.open_card_fusion("변신");await process_frame;await RenderingServer.frame_post_draw
 var view: Node=w.hud.card_fusion_view
 for grade: String in ["고급","희귀","영웅","전설"]:
  view._select_grade(grade,false)
  check(view._fuse.disabled and view.registered_materials.is_empty() and view._available(grade)==0,"actual fusion UI never registers original NoMerge stock "+grade)
 check(view._cards.item_count==4,"actual UI lists the four genuinely owned native identities")
 check(w.card_draw_fusion.get_method_list().filter(func(row: Dictionary)->bool:return str(row.name).contains("swap") or str(row.name).contains("exchange")).is_empty(),"current owner exposes no consuming card swap/exchange operation")
 # Isolated quote-only target/extra-spare fixture exercises the existing real
 # option-feed owner without granting any live target or source reward.
 var option_checked: bool=false
 var core: RefCounted=w.option_awakening.core
 for target_id: String in core.definitions.get("변신",{}):
  if option_checked:break
  for source_item: int in FIXED.IDS:
   var id: String=str(targets[source_item].identity)
   var quote_cards: Dictionary=cards.duplicate(true);quote_cards.owned["변신"][target_id]=true
   var reserved: int=CARDS.quest_reserved_spare(quote_cards,"변신",id)
   quote_cards.spare["변신"][id]=reserved+2
   var allowed: Dictionary=core.prepare_feed(w.option_awakening.export_state(),quote_cards,maxi(w.gold,1000000000),"변신",target_id,{id:2})
   if not allowed.get("ok",false):continue
   check(int(allowed.card_state.spare["변신"][id])==reserved,"preexisting unrestricted copies remain independently consumable in real option owner")
   quote_cards.spare["변신"][id]=reserved
   var refused: Dictionary=core.prepare_feed(w.option_awakening.export_state(),quote_cards,maxi(w.gold,1000000000),"변신",target_id,{id:1})
   check(not refused.ok and refused.get("code")=="quest_source_copy_reserved","actual native/legacy feed wrapper rejects new protected quest copies before debit")
   var live_before: String=FileAccess.get_sha256(path)
   check(w.card_draw_fusion.export_state()==cards and FileAccess.get_sha256(path)==live_before,"quote fixture never grants/debits live ownership")
   option_checked=true;break
 check(option_checked,"an exact installed option target exercises the downstream protected-copy guard")
 var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var final_hash: String=FileAccess.get_sha256(path)
 check(durable.card_draw_fusion==norm(cards) and durable.inventory==norm(w.inventory) and durable.item_instances==norm(w.item_instances),"all actual stock/card/receipt states match durable atomic save")
 check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots),"original claims and50 slots remain intact")
 w.queue_free();await process_frame;w=make_world()
 check(norm(w.card_draw_fusion.export_state())==durable.card_draw_fusion and norm(w.inventory)==durable.inventory and norm(w.item_instances)==durable.item_instances,"fresh Main restores exact restricted ownership/debit/source receipts")
 for source_item: int in FIXED.IDS:
  var t: Dictionary=targets[source_item]
  check(w.card_draw_fusion.source_merge_blocked.get(t.category+":"+t.identity)==true and CARDS.quest_reserved_spare(w.card_draw_fusion.export_state(),t.category,t.identity)==int(initial_quantities[str(source_item)])-1,"global merge and per-copy unsupported-out guard survive reconnect")
 check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots),"all original completion and user slots survive reconnect")
 w.quest_auto.refresh_context(w);var completed: int=0;var pending: int=0
 for entry: Dictionary in w.quest_service.entries(w.level,w.inventory):
  if entry.get("source_id")!=null and entry.completed:
   completed+=1
   if not entry.rewards.get("pending_use",[]).is_empty():pending+=1
 print("QUEST_FIXED_CARDS_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":"real_native_30_units" if fresh else "real_held_30_original_receipts","source_completions":completed,"some_use_pending":pending,"source_units":initial_quantities,"permanent_cards":4,"protected_quest_spares":26,"new_source_receipts":30,"ordinary_rng_pity_unchanged":true,"existing_swap_action":"absent; equip/selection is not native exchange","scope":"actual full eligible four-class quest ownership,UI,source global merge/UI and unsupported option-copy guard,atomic failure/confirmed error/reconnect;27Test cards remain blocked","final_save_sha256":FileAccess.get_sha256(path),"seed_sha256":seed}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
