extends SceneTree
const QA=preload('res://tests/qa_class_selection.gd')
const WRITER=preload('res://scripts/skills/save_writer.gd')
var failures:Array=[]
var checks:int=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr('SPELL_GROUP_MAIN_FAIL ',label)
func normalized(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func slots_preserved(before:Array,after:Array)->bool:
 if before.size()!=after.size():return false
 for i:int in range(before.size()):
  for key:Variant in before[i]:
   if normalized(before[i][key])!=normalized(after[i].get(key)):return false
  for key:Variant in after[i]:
   if not before[i].has(key) and key!='skill_id':return false
 return true
func _initialize()->void:call_deferred('run')
func pause_world(world:Node)->void:
 world.set_process(false);world.save_timer=-100000.0;world.player.set_physics_process(false)
func select_group(view:Control,group:int)->void:
 for i:int in range(view.choices.item_count):
  if view.choices.get_item_id(i)==group:view.choices.select(i);view.choices.item_selected.emit(i);return
 check(false,'source group candidate exists')
func run()->void:
 check(not OS.get_environment('TWILIGHT_SOURCE_MAP_PACK').is_empty(),'explicit committed Aden pack')
 var packed=load('res://Main.tscn');var world=packed.instantiate();root.add_child(world)
 pause_world(world)
 check(QA.enter_game(world,'요정'),'actual class confirmation')
 check(world.field_map!=null and world.field_map.get_script().resource_path.ends_with('source_map_runtime_field.gd'),'actual current source map')
 check(world.spell_group_conversion.problem.is_empty(),'validated source installed')
 # Test-only profile progression. Ownership is acquired through existing book APIs.
 world.level=100;world.gold=3000000
 var catalog=world.original_skills.catalog
 var water:Dictionary=catalog.record_for('네이쳐스 터치');var earth:Dictionary=catalog.record_for('아이언 스킨');var active:Dictionary=catalog.record_for('블러드 투 소울')
 for record:Dictionary in [water,earth,active]:
  if not catalog.owned(record):
   check(catalog.buy_book(str(record.id)),'existing book acquisition '+str(record.name))
   check(catalog.learn(str(record.id)),'existing book learning '+str(record.name))
 world.gold=1000000
 world.quickslots[0]={'kind':'skill','id':str(active.name),'skill_id':str(active.id),'auto':true}
 world._normalize_quickslots()
 var slots:Array=world.quickslots.duplicate(true);var learned:Dictionary=catalog.learned.duplicate(true)
 var defense_before:int=world._effective_defense()
 check(catalog.enabled(water) and not catalog.enabled(earth),'existing selected school effect')
 check(world._save_game(true)==OK,'real baseline atomic save')
 var path:String=world.save_path();var baseline_sha:String=FileAccess.get_sha256(path)
 world.hud._navigate('menu')
 var tile=world.hud.menu_page.find_child('MenuTile_spell_groups',true,false)
 check(tile!=null,'actual Main menu tile');tile.pressed.emit()
 var view=world.hud.workspace.find_child('SpellGroupConversionView',true,false)
 check(view!=null and view.choices.item_count==4,'actual source candidate UI')
 select_group(view,4)
 view.confirm.pressed.emit()
 check(view.dialog.visible,'real confirmation dialog')
 view.dialog.get_cancel_button().pressed.emit()
 check(world.gold==1000000 and FileAccess.get_sha256(path)==baseline_sha,'cancel preserves state and save bytes')
 world.gold=0;view.refresh_quote();check(view.confirm.disabled,'insufficient UI is disabled');world.gold=1000000;view.refresh_quote()
 var prior_migrated:String=world.migrated_save_path
 world.migrated_save_path='user://missing-conversion-test-directory/save.json'
 view.confirm.pressed.emit();view.dialog.get_ok_button().pressed.emit()
 check(world.gold==1000000 and world.spell_group_conversion.current_group()==5,'actual writer failure rollback')
 check(FileAccess.get_sha256(path)==baseline_sha,'writer failure preserves durable save')
 world.migrated_save_path=prior_migrated
 view.refresh_quote();view.confirm.pressed.emit();view.dialog.get_ok_button().pressed.emit()
 check(world.gold==750000 and world.spell_group_conversion.current_group()==4,'actual UI payment and source group selection')
 check(catalog.enabled(earth) and not catalog.enabled(water),'real owned skill activation changes')
 check(world._effective_defense()==defense_before+int(earth.stats.get('def',0)),'existing passive defense reaches actual world stats')
 check(normalized(catalog.learned)==normalized(learned) and world.quickslots==slots,'learned ownership slots and auto flags preserved')
 view.dialog.confirmed.emit();check(world.gold==750000,'duplicate click not charged')
 # Isolated consumption fixture only. This is not a production supply/grant path.
 var native:Dictionary=world.spell_group_conversion.items[1122]
 var candle_name:String=str(native.Name);var instance_id:String=str(world.next_item_instance_id);world.next_item_instance_id+=1
 world.inventory[candle_name]=1
 world.item_instances[instance_id]={'name':candle_name,'level':0,'record':{'name':candle_name,'type':'계열 전환 재료','slot':'','grade':'일반','source':'lineagem_patch523','source_snapshot':'patch523','sourceId':'m523:item:1122','source_item_class_id':1122,'source_original_item':native.duplicate(true)}}
 world.ui_preferences.item_locks[candle_name]=true
 select_group(view,5);view.payment.select(1);view.payment.item_selected.emit(1)
 check(view.confirm.disabled,'actual Main locked candle rejected')
 world.ui_preferences.item_locks.erase(candle_name);view.refresh_quote()
 check(not view.confirm.disabled,'exact owned candle available')
 view.confirm.pressed.emit();view.dialog.get_ok_button().pressed.emit()
 check(world.gold==750000 and world.spell_group_conversion.current_group()==5,'actual UI alternative candle payment')
 check(not world.item_instances.has(instance_id) and not world.inventory.has(candle_name),'actual physical candle consumed once')
 check(catalog.enabled(water) and not catalog.enabled(earth),'existing effects follow second source selection')
 var durable:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 check(durable.gold==750000 and int(durable.spell_group_conversion.classes['요정'].group)==5,'actual Main durable transaction')
 world.queue_free();await process_frame
 var restarted=packed.instantiate();root.add_child(restarted);pause_world(restarted)
 check(restarted.gold==750000 and restarted.spell_group_conversion.current_group()==5,'new Main instance reconnect')
 check(normalized(restarted.original_skills.catalog.learned)==normalized(learned) and slots_preserved(slots,restarted.quickslots),'reconnect ownership slots and auto preserved')
 var corrupt:Dictionary=durable.duplicate(true);corrupt.spell_group_conversion.classes['요정'].count='bad'
 check(WRITER.write(path,corrupt)==OK,'isolated damaged-save fixture')
 var damaged_sha:String=FileAccess.get_sha256(path);restarted.gold=123
 restarted._load_game(true)
 check(restarted.spell_group_conversion.save_blocked and restarted.gold==123,'corrupt feature save rejects before mutation')
 check(restarted._save_game(true)!=OK and FileAccess.get_sha256(path)==damaged_sha,'corrupt save cannot be overwritten')
 check(WRITER.write(path,durable)==OK,'restore isolated valid fixture')
 restarted._load_game(true)
 check(not restarted.spell_group_conversion.save_blocked and restarted.gold==750000,'valid-save recovery')
 print('SPELL_GROUP_MAIN_RESULT ',JSON.stringify({'checks':checks,'failures':failures,'scope':'ACTUAL_MAIN_UI_TRANSACTION_RECONNECT_WITH_PINNED_ADEN; ISOLATED_PROFILE'}))
 restarted.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
