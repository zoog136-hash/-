extends SceneTree
const SERVICE=preload('res://scripts/skills/spell_group_conversion.gd')
const WRITER=preload('res://scripts/skills/save_writer.gd')
var failures:Array=[]
var checks:int=0
class Catalog extends RefCounted:
 var records:Array=[]
 var learned:Dictionary={}
 var schools:Dictionary={'요정':'water'}
 var revision:int=0
 var stat_signature:String=''
 var resolved_signature:String=''
 func owned(record:Dictionary)->bool:return int(learned.get(str(record.id),0))>0
 func export_state()->Dictionary:return {'learned':learned.duplicate(true),'schools':schools.duplicate(true),'archived':{},'class_slots':{}}
 func import_state(data:Dictionary)->void:
  learned=data.original_skill_state.learned.duplicate(true);schools=data.original_skill_state.schools.duplicate(true)
class Host extends RefCounted:
 var catalog=Catalog.new()
class Fixture extends Node:
 var job_class:String='요정'
 var gold:int=1000000000
 var inventory:Dictionary={}
 var item_instances:Dictionary={}
 var ui_preferences:Dictionary={'item_locks':{}}
 var quickslots:Array=[{'kind':'skill','id':'owned','auto':true}]
 var original_skills=Host.new()
 var fail_write:bool=false
 var writes:int=0
 var payload:Dictionary={}
 func _item_locked(name:String,id:String='')->bool:return bool(ui_preferences.item_locks.get(name+('@@@'+id if not id.is_empty() else ''),false))
 func _update_hud()->void:pass
 func _save_game(_quiet:bool,staged:Dictionary)->Error:
  writes+=1
  if fail_write:return ERR_CANT_CREATE
  var data:Dictionary={'gold':gold,'inventory':inventory,'item_instances':item_instances,'quickslots':quickslots,'original_skill_state':original_skills.catalog.export_state()}
  data.merge(staged,true)
  var result:Error=WRITER.write('user://conversion-unit-profile.json',data)
  if result==OK:payload=data.duplicate(true)
  return result
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr('CONVERSION_FAIL ',label)
func _initialize()->void:call_deferred('run')
func add_material(w:Fixture,service:RefCounted,item:int)->void:
 var name:String='fixture-'+str(item)
 w.inventory[name]=1
 w.item_instances[str(item)]={'name':name,'record':{'name':name,'source':'lineagem_patch523','source_snapshot':'patch523','sourceId':'m523:item:'+str(item),'source_item_class_id':item,'source_original_item':service.items[item].duplicate(true)}}
func run()->void:
 var w=Fixture.new();root.add_child(w)
 var s=SERVICE.new();s.configure(w)
 check(s.problem.is_empty(),'verified full523 source')
 check(s.labels.get(3)=='불' and s.labels.get(4)=='땅' and s.labels.get(5)=='물' and s.labels.get(6)=='바람','original Korean group labels')
 check(s.settings.size()==16 and s.costs.size()==1200 and s.members.size()==193,'full source coverage')
 for row:Dictionary in s.settings:
  if row.CheckSpellLearned:
   var id:String='fixture-'+str(int(row.CheckLearnSpellClassID));w.original_skills.catalog.records.append({'id':id,'spell_class_id':int(row.CheckLearnSpellClassID)});w.original_skills.catalog.learned[id]=1
 var seen:Dictionary={};s.policy.allow_test_materials=true
 for cost:Dictionary in s.costs:
  var setting:Dictionary={}
  for row:Dictionary in s.settings:
   if int(row.SpellGroupID)==int(cost.SpellGroupID):setting=row;break
  w.job_class='요정' if int(setting.GameClassID)==2 else '마법사'
  s.state.classes[w.job_class]={'group':0,'count':int(cost.ChangeCount)-1}
  add_material(w,s,1122);add_material(w,s,32801)
  var quote:Dictionary=s.quote(int(cost.SpellGroupID),int(cost.ItemClassID))
  check(quote.get('error','')=='' and int(quote.get('amount',-1))==int(cost.ItemAmount),'source cost row '+str(int(cost.ID)))
  var key:String='%d:%d:%d' % [cost.SpellGroupID,cost.ChangeCount,cost.ItemClassID]
  check(not seen.has(key),'unique composite cost '+key);seen[key]=true
 check(seen.size()==1200,'all cost rows compared')
 s.state={'schema':1,'source_snapshot':'patch523','classes':{}};w.job_class='요정';s.policy.allow_test_materials=false
 var slots:Array=w.quickslots.duplicate(true);var learned:Dictionary=w.original_skills.catalog.learned.duplicate(true)
 w.gold=1000000
 var plan:Dictionary=s.quote(3)
 w.fail_write=true
 check(not s.commit(plan).is_empty() and w.gold==1000000 and s.current_group()==5,'write failure preserves resources and selection')
 w.fail_write=false
 check(s.commit(plan).is_empty(),'atomic commit')
 check(w.gold==750000 and s.current_group()==3 and w.original_skills.catalog.schools['요정']=='fire','source price and existing school effect')
 check(not s.commit(plan).is_empty() and w.gold==750000,'duplicate confirmation does not spend')
 check(w.quickslots==slots and w.original_skills.catalog.learned==learned,'ownership slots and auto retained')
 var restored=SERVICE.new();restored.configure(w);restored.restore(w.payload.spell_group_conversion)
 check(restored.current_group()==3,'restart selection')
 check(restored.validate({'schema':1,'source_snapshot':'patch523','classes':{'요정':{'group':3,'count':1.5}}})!='','fractional save rejected')
 check(restored.validate({'schema':1,'source_snapshot':'patch523','classes':{'요정':{'group':501,'count':1}}})!='','cross-class save rejected')
 restored.restore({'schema':-1});check(restored.save_blocked,'corrupt load protects save')
 w.gold=0;check(not s.quote(4).get('error','').is_empty(),'insufficient gold')
 add_material(w,s,1122)
 var name:String='fixture-1122';w.ui_preferences.item_locks[name]=true
 check(not s.quote(4,1122).get('error','').is_empty(),'locked material rejected')
 w.ui_preferences.item_locks.clear()
 plan=s.quote(4,1122);check(s.commit(plan).is_empty(),'exact source candle payment')
 check(not w.item_instances.has('1122') and not w.inventory.has(name) and w.gold==0,'candle paid once without gold charge')
 check(not s.quote(6,32801).get('error','').is_empty(),'test item not silently enabled')
 w.job_class='투사';check(not s.quote(408).get('error','').is_empty(),'missing cost cannot become free')
 w.job_class='마법사';w.original_skills.catalog.learned.clear();check(not s.quote(501).get('error','').is_empty(),'missing learned prerequisite')
 w.gold=1000000000
 for record:Dictionary in w.original_skills.catalog.records:w.original_skills.catalog.learned[str(record.id)]=1
 for setting:Dictionary in s.settings:
  for job:String in SERVICE.CLASS_IDS:
   if int(SERVICE.CLASS_IDS[job])==int(setting.GameClassID):w.job_class=job
  s.state.classes[w.job_class]={'group':0,'count':50}
  check(not s.quote(int(setting.SpellGroupID)).get('error','').is_empty(),'no undefined count51 or missing-price extrapolation')
  if setting.CheckSpellLearned:
   var saved:Dictionary=w.original_skills.catalog.learned.duplicate(true)
   w.original_skills.catalog.learned.clear()
   check(not s.quote(int(setting.SpellGroupID)).get('error','').is_empty(),'every original learned guard')
   w.original_skills.catalog.learned=saved
 for member_id:int in s.members:
  var member:Dictionary=s.members[member_id]
  for setting:Dictionary in s.settings:
   if int(setting.SpellGroupID)!=int(member.SpellGroupID):continue
   for job:String in SERVICE.CLASS_IDS:
    if int(SERVICE.CLASS_IDS[job])==int(setting.GameClassID):w.job_class=job
  s.state.classes[w.job_class]={'group':0,'count':0}
  check(s.allows({'spell_class_id':member_id})==not bool(member.IsRequireSpellGroupMastery),'every source mastery exception')
  s.state.classes[w.job_class].group=int(member.SpellGroupID)
  check(s.allows({'spell_class_id':member_id}),'every selected source member')
 for setting:Dictionary in s.settings:
  for job:String in SERVICE.CLASS_IDS:
   if int(SERVICE.CLASS_IDS[job])==int(setting.GameClassID):w.job_class=job
  var matching:Array=s.candidates().filter(func(row:Dictionary)->bool:return int(row.ID)==int(setting.ID))
  check(matching.size()==1,'every current-class source setting')
  check(bool(matching[0].source_has_costs)==s.costs.any(func(row:Dictionary)->bool:return int(row.SpellGroupID)==int(setting.SpellGroupID)),'source missing-price classification')
 check(s.source_id({'sourceId':'47432','name':'슬로우'})==0,'website or display identity is not native identity')
 check(s.source_id({'fields':{'basic':{'original_skill_id':{'value':47432,'status':'VERIFIED','domain':'Website.SkillID'}}}})==0,'wrong ID domain rejected')
 check(s.source_id({'fields':{'basic':{'original_skill_id':{'value':47432,'status':'VERIFIED','domain':'SpellClass.ID'}}}})==47432,'explicit native domain adapter')
 w.job_class='요정';s.state={'schema':1,'source_snapshot':'patch523','classes':{}}
 add_material(w,s,1122)
 w.item_instances['1122'].record.source_item_class_id=1122.5
 check(not s.quote(3,1122).get('error','').is_empty(),'fractional item ID rejected')
 add_material(w,s,1122);w.inventory['fixture-1122']=1.5
 check(not s.quote(3,1122).get('error','').is_empty(),'fractional inventory count rejected')
 add_material(w,s,1122)
 w.item_instances['duplicate-1122']=w.item_instances['1122'].duplicate(true)
 check(not s.quote(3,1122).get('error','').is_empty(),'inconsistent physical and aggregate counts rejected')
 print('SPELL_GROUP_CONVERSION_RESULT ',JSON.stringify({'checks':checks,'failures':failures,'source_cost_rows':seen.size(),'scope':'ISOLATED_TRANSACTION_FIXTURE_NOT_MAIN_MAP_APPROVAL'}))
 w.queue_free();quit(0 if failures.is_empty() else 1)
