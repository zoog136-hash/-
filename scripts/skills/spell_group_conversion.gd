extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Source facts remain private. Counter/payment execution is explicit TWILIGHT policy.
const SOURCE_SHA='d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
const CommonSource=preload('res://scripts/resources/current523_definition_rows.gd')
const DEFAULT_SOURCE='user://sources/lineagem_patch523_all_content_validated_and_508_520_deltas.zip'
const CLASS_IDS={'요정':2,'마법사':3,'투사':5,'총사':34}
const ELEMENTS={'Elemental_Fire':'fire','Elemental_Earth':'earth','Elemental_Water':'water','Elemental_Wind':'wind'}
var world:Node
var settings:Array=[]
var costs:Array=[]
var replacements:Array=[]
var groups:Dictionary={}
var labels:Dictionary={}
var members:Dictionary={}
var items:Dictionary={}
# Input provenance is separate from the character/class save in state.
var source_input_identity:Dictionary={}
var source_row_metadata:Dictionary={}
var excluded_input_items:Dictionary={}
var excluded_input_item_reasons:Dictionary={}
var _input_read_problem:String=''
var state:Dictionary={'schema':1,'source_snapshot':'patch523','classes':{}}
var problem:String=''
var save_blocked:bool=false
var busy:bool=false
# TWILIGHT: counters belong to this character/class; choose one listed payment.
# Source defines counts 1 through 50 only. No extrapolation or free missing costs.
var policy:Dictionary={'payment_mode':'alternatives','max_defined_count':50,'allow_test_materials':false}
func configure(owner:Node)->void:
 world=owner
 problem=''
 _input_read_problem=''
 var input:Dictionary=_source_input()
 if input.is_empty():return
 var path:String=str(input.path)
 if FileAccess.get_sha256(path)!=SOURCE_SHA:problem='계열 변환 원본 ZIP SHA가 고정된 523 원문과 다릅니다. 입력 선택: '+str(input.selection);return
 var zip:=ZIPReader.new()
 if zip.open(path)!=OK:problem='계열 변환 523 원본 ZIP을 열 수 없습니다. 입력 선택: '+str(input.selection);return
 var parsed:Dictionary=_parse_source_input(zip)
 if parsed.is_empty():zip.close();return
 var config_path:String=''
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with('--spell-group-policy='):config_path=arg.trim_prefix('--spell-group-policy=')
 if not config_path.is_empty():
  var parser:=JSON.new()
  if not FileAccess.file_exists(config_path) or parser.parse(FileAccess.get_file_as_string(config_path))!=OK:
   problem='TWILIGHT 전환 정책 파일을 확인할 수 없습니다.'
  else:
   var config:Variant=parser.data
   if not config is Dictionary or not config.get('allow_test_materials',false) is bool or config.get('payment_mode','alternatives') not in ['alternatives','adena_only']:
    problem='TWILIGHT 전환 정책 형식이 잘못되었습니다.'
   else:
    policy.allow_test_materials=config.get('allow_test_materials',false)
    policy.payment_mode=config.get('payment_mode','alternatives')
 zip.close()
 if not problem.is_empty():return
 # Publish only a complete source read. A failed reconfiguration leaves the
 # previous registries and saved class state intact, with problem blocking quote.
 settings=parsed.settings;costs=parsed.costs;replacements=parsed.replacements
 groups=parsed.groups;labels=parsed.labels;members=parsed.members;items=parsed.items
 excluded_input_items=parsed.excluded_input_items
 excluded_input_item_reasons=parsed.excluded_input_item_reasons
 source_row_metadata=parsed.row_metadata
 source_input_identity={'kind':'twilight.spell-group.current523.input.v1','source_snapshot':'patch523','archive_sha256':SOURCE_SHA,'source_sha256':SOURCE_SHA,'selection':str(input.selection)}

func _source_input()->Dictionary:
 var explicit:bool=OS.has_environment('TWILIGHT_SPELL_GROUP_SOURCE')
 var path:String=OS.get_environment('TWILIGHT_SPELL_GROUP_SOURCE') if explicit else DEFAULT_SOURCE
 var selection:String='explicit_environment' if explicit else 'default_archive'
 for arg:String in OS.get_cmdline_user_args():
  if arg=='--spell-group-source' or arg.begins_with('--spell-group-source='):
   explicit=true
   selection='explicit_argument'
   path='' if arg=='--spell-group-source' else arg.trim_prefix('--spell-group-source=')
 if explicit and path.is_empty():
  problem='계열 변환 원본 경로를 빈 값으로 명시했습니다. 입력 선택: '+selection
  return {}
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:
  var open_error:Error=FileAccess.get_open_error()
  if explicit or open_error!=ERR_FILE_NOT_FOUND:
   problem='계열 변환 원본 경로를 읽을 수 없습니다. 입력 선택: '+selection+' · '+error_string(open_error)
   return {}
  # Only the absent, unoverridden default may use the already supplied archive.
  # An explicit path, permission error, bad SHA or parse error is authoritative.
  path=CommonSource.archive_path()
  if path.is_empty():
   problem='계열 변환 기본 ZIP이 없고 보유 원본523 입력도 연결되지 않았습니다. '+CommonSource.problem()
   return {}
  selection='held_current523_archive'
 else:file.close()
 return {'path':path,'selection':selection}

func _parse_source_input(zip:ZIPReader)->Dictionary:
 var next_settings:Array=rows(zip,'GameClassSpellGroup')
 var next_costs:Array=rows(zip,'GameClassSpellGroupCostView')
 var next_replacements:Array=rows(zip,'GameClassSpellGroupChangeSpell')
 var next_groups:Dictionary={}
 var next_labels:Dictionary={}
 var next_members:Dictionary={}
 var selected_items:Dictionary={}
 var next_items:Dictionary={}
 var excluded:Dictionary={}
 var excluded_reasons:Dictionary={}
 for row:Dictionary in rows(zip,'SpellGroup'):next_groups[int(row.ID)]=row
 if not _input_read_problem.is_empty():problem=_input_read_problem;return {}
 var wanted:Dictionary={}
 for setting:Dictionary in next_settings:
  if not next_groups.has(int(setting.SpellGroupID)):
   problem='원본 계열의 SpellGroup 참조가 없습니다: '+str(setting.SpellGroupID)
   return {}
  wanted[int(next_groups[int(setting.SpellGroupID)].DescID)]=int(setting.SpellGroupID)
 # The common reader holds these same pinned bytes; its large tables are
 # filtered there (same rows, same order) instead of parsed whole again.
 var shared:bool=CommonSource.identity().get('source_sha256')==SOURCE_SHA
 var group_ids:Dictionary={}
 for setting:Dictionary in next_settings:group_ids[int(setting.SpellGroupID)]=true
 for row:Dictionary in (CommonSource.rows_matching('DescData_Korean','ID',wanted) if shared else rows(zip,'DescData_Korean')):
  if wanted.has(int(row.ID)):next_labels[wanted[int(row.ID)]]=str(row.Description)
 # These are original membership facts, not skill registration or acquisition.
 for row:Dictionary in (CommonSource.rows_matching('SpellClass','SpellGroupID',group_ids) if shared else rows(zip,'SpellClass')):
  if next_settings.any(func(s:Dictionary)->bool:return int(s.SpellGroupID)==int(row.SpellGroupID)):next_members[int(row.ID)]=row
 for row:Dictionary in (CommonSource.rows_matching('ItemClass','ID',{26:true,1122:true,32801:true}) if shared else rows(zip,'ItemClass')):
  var id:int=int(row.ID)
  if id not in [26,1122,32801]:continue
  selected_items[id]=row
  var evidence:Dictionary=CommonSource.declared_exclusion('ItemClass',row)
  if row.get('TestItem')==true or not evidence.is_empty():
   excluded[id]=row
   excluded_reasons[id]={'test_item':row.get('TestItem')==true,'declared_exclusion':evidence}
  else:next_items[id]=row
 if not _input_read_problem.is_empty():problem=_input_read_problem;return {}
 if next_settings.size()!=16 or next_costs.size()!=1200 or next_members.size()!=193 or next_replacements.size()!=4:
  problem='523 계열 원문 행 수가 기존 입력 계약과 다릅니다: settings=%d, costs=%d, members=%d, replacements=%d' % [next_settings.size(),next_costs.size(),next_members.size(),next_replacements.size()]
  return {}
 return {'settings':next_settings,'costs':next_costs,'replacements':next_replacements,'groups':next_groups,'labels':next_labels,'members':next_members,'items':next_items,'excluded_input_items':excluded,'excluded_input_item_reasons':excluded_reasons,'row_metadata':{'GameClassSpellGroup':{'row_count':next_settings.size()},'GameClassSpellGroupCostView':{'row_count':next_costs.size()},'GameClassSpellGroupChangeSpell':{'row_count':next_replacements.size()},'SpellClass':{'selected_row_count':next_members.size(),'role':'group_membership_read_only'},'ItemClass':{'selected_row_count':selected_items.size()}}}

func rows(zip:ZIPReader,name:String)->Array:
 var member:String='content/'+name+'.json'
 if not zip.file_exists(member):_input_read_problem='계열 변환 원문 표가 없습니다: '+name;return []
 var parser:=JSON.new()
 if parser.parse(zip.read_file(member).get_string_from_utf8().trim_prefix('\ufeff'))!=OK:_input_read_problem='계열 변환 원문 JSON을 읽을 수 없습니다: '+name;return []
 if not parser.data is Dictionary or not parser.data.get('rows') is Array:_input_read_problem='계열 변환 원문 행 구조가 다릅니다: '+name;return []
 for row:Variant in parser.data.rows:
  if not row is Dictionary:_input_read_problem='계열 변환 원문 행이 객체가 아닙니다: '+name;return []
 return parser.data.rows
func export_state()->Dictionary:return state.duplicate(true)
func validate(value:Variant)->String:
 if not value is Dictionary or not (value.get('schema') is int or value.get('schema') is float) or value.get('schema')!=1 or value.get('source_snapshot')!='patch523' or not value.get('classes') is Dictionary:return '계열 전환 저장 형식이 손상되었습니다.'
 for key:Variant in value.classes:
  if not CLASS_IDS.has(key) or not value.classes[key] is Dictionary:return '계열 전환 직업 저장이 손상되었습니다.'
  var row:Dictionary=value.classes[key]
  for field:String in ['group','count']:
   var v:Variant=row.get(field)
   if not (v is int or v is float) or not is_finite(float(v)) or float(v)!=floorf(float(v)) or float(v)<0 or float(v)>1000000000:return '계열 전환 숫자 저장이 손상되었습니다.'
  if int(row.count)>int(policy.max_defined_count):return '정의되지 않은 전환 회차입니다.'
  if not settings.is_empty() and not settings.any(func(s:Dictionary)->bool:return int(s.GameClassID)==int(CLASS_IDS[key]) and int(s.SpellGroupID)==int(row.group)):return '직업과 계열 저장이 일치하지 않습니다.'
 return ''
func restore(value:Dictionary)->void:
 var error:String=validate(value)
 if not error.is_empty():save_blocked=true;return
 state=value.duplicate(true);save_blocked=false
 if world!=null and world.original_skills!=null:
  world.original_skills.catalog.stat_signature='';world.original_skills.catalog.resolved_signature=''
func current_group()->int:
 var job:String=world.job_class
 if state.classes.has(job):return int(state.classes[job].group)
 if job=='요정':
  var school:String=world.original_skills.catalog.schools.get(job,'water')
  for id:int in groups:
   if ELEMENTS.get(str(groups[id].Name),'')==school:return id
 return 0
func source_id(record:Dictionary)->int:
 # Exact adapter only. Hashed historical IDs and names never become source IDs.
 var explicit:Dictionary=_explicit_source_claim(record)
 if explicit.present:return _source_id_value(explicit.value)
 return _accepted_bound_source_id(record)

static func _source_id_value(value:Variant)->int:
 return int(value) if (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>0 and float(value)<=1000000000 else 0

static func _explicit_source_claim(record:Dictionary)->Dictionary:
 # Keep the original two-step resolution: a null direct value may still use
 # the existing valid VERIFIED legacy claim. Presence only blocks the NEW
 # bound fallback; it must not erase an old successful legacy resolution.
 var value:Variant=record.get('source_spell_class_id',record.get('spell_class_id'))
 var identity:Dictionary={}
 var fields:Variant=record.get('fields',{})
 if fields is Dictionary:
  var basic:Variant=fields.get('basic',{})
  if basic is Dictionary:
   var claim:Variant=basic.get('original_skill_id',{})
   if claim is Dictionary:identity=claim
 var verified:bool=identity.get('status')=='VERIFIED'
 if value==null and verified and identity.get('domain')=='SpellClass.ID':value=identity.get('value')
 return {'present':record.has('source_spell_class_id') or record.has('spell_class_id') or verified,'value':value}

func _accepted_bound_source_id(record:Dictionary)->int:
 # This is the already accepted public canonical binding, not name matching,
 # hash decoding, skill registration, ownership or a new group choice.
 if not is_instance_valid(world):return 0
 var service:Variant=world.get('original_skills')
 if not service is Object or not is_instance_valid(service):return 0
 var catalog:Variant=service.get('catalog')
 if not catalog is Object or not is_instance_valid(catalog):return 0
 var canonical_id:Variant=record.get('id')
 var canonical_rows:Variant=catalog.get('by_id')
 if not canonical_id is String or canonical_id.is_empty() or not canonical_rows is Dictionary:return 0
 var canonical:Variant=canonical_rows.get(canonical_id)
 if not canonical is Dictionary or canonical.get('id')!=canonical_id or _explicit_source_claim(canonical).present:return 0
 var adapter:Variant=catalog.get('source523')
 if not adapter is Object or not is_instance_valid(adapter) or not adapter.has_method('_profile_problem'):return 0
 var profile_type:Script=adapter.get_script()
 if profile_type==null:return 0
 var constants:Dictionary=profile_type.get_script_constant_map()
 if constants.get('BINDINGS_PATH')!='res://data/skills/player_skills523_bindings.json' or constants.get('SOURCE_SHA')!=SOURCE_SHA:return 0
 var bindings:Variant=adapter.get('bindings')
 var profiles:Variant=adapter.get('profiles')
 if not bindings is Dictionary or not profiles is Dictionary or bindings.get('source_zip_sha256')!=SOURCE_SHA or not bindings.get('skills') is Dictionary:return 0
 var binding:Variant=bindings.skills.get(canonical_id)
 var profile:Variant=profiles.get(canonical_id)
 if not binding is Dictionary or not profile is Dictionary or not profile.get('row') is Dictionary:return 0
 var bound_sha:Variant=binding.get('row_sha256')
 if not bound_sha is String or bound_sha.length()!=64 or not bound_sha.is_valid_hex_number(false):return 0
 var id:int=_source_id_value(binding.get('spell_id'))
 if id==0 or _source_id_value(profile.row.get('ID'))!=id or not adapter._profile_problem(canonical_id,profile,binding).is_empty():return 0
 if source_input_identity.get('kind')!='twilight.spell-group.current523.input.v1' or source_input_identity.get('source_snapshot')!='patch523' or source_input_identity.get('archive_sha256')!=SOURCE_SHA or source_input_identity.get('source_sha256')!=SOURCE_SHA:return 0
 var identity:Dictionary=CommonSource.identity()
 if identity.is_empty() or identity.get('source_sha256')!=SOURCE_SHA:return 0
 var original:Dictionary=CommonSource.row('SpellClass',id)
 if original.is_empty() or original!=profile.row or original.get('TestSpell') is not bool or original.TestSpell or not CommonSource.declared_exclusion('SpellClass',original).is_empty():return 0
 if members.has(id) and (not members[id] is Dictionary or members[id]!=original):return 0
 return id


func owns_source(id:int)->bool:
 for record:Dictionary in world.original_skills.catalog.records:
  if source_id(record)==id and world.original_skills.catalog.owned(record):return true
 return false
func allows(record:Dictionary)->bool:
 var id:int=source_id(record)
 if not members.has(id) or not bool(members[id].IsRequireSpellGroupMastery):return true
 return int(members[id].SpellGroupID)==current_group()
func candidates()->Array:
 var result:Array=[]
 for row:Dictionary in settings:
  if int(row.GameClassID)!=int(CLASS_IDS.get(str(world.job_class),-1)):continue
  var copy:Dictionary=row.duplicate(true);copy['name']=labels.get(int(row.SpellGroupID),groups.get(int(row.SpellGroupID),{}).get('Name',str(row.SpellGroupID)))
  copy['source_member_count']=members.values().filter(func(member:Dictionary)->bool:return int(member.SpellGroupID)==int(row.SpellGroupID)).size()
  copy['source_has_costs']=costs.any(func(cost:Dictionary)->bool:return int(cost.SpellGroupID)==int(row.SpellGroupID))
  copy['replacement_definitions']=replacements.filter(func(change:Dictionary)->bool:return int(change.GameClassSpellGroupID)==int(row.ID)).duplicate(true)
  result.append(copy)
 return result
func quote(group:int,item:int=26)->Dictionary:
 if excluded_input_items.has(item):return {"ok":false,"reason":"원문 시험·더미 제외 결제 재료는 연결하지 않습니다."}
 if not problem.is_empty():return {'error':problem}
 if save_blocked:return {'error':'손상된 계열 저장을 보호 중입니다.'}
 if policy.payment_mode=='adena_only' and item!=26:return {'error':'현재 TWILIGHT 설정은 아데나 결제만 허용합니다.'}
 var selected:Dictionary={}
 for row:Dictionary in candidates():
  if int(row.SpellGroupID)==group:selected=row;break
 if selected.is_empty():return {'error':'현재 직업에 없는 계열입니다.'}
 if group==current_group():return {'error':'이미 선택한 계열입니다.'}
 if selected.CheckSpellLearned and not owns_source(int(selected.CheckLearnSpellClassID)):return {'error':'원본 ID가 확인된 선행 보유스킬이 필요합니다: %d' % int(selected.CheckLearnSpellClassID)}
 var count:int=int(state.classes.get(str(world.job_class),{}).get('count',0))+1
 var amount:int=-1
 for row:Dictionary in costs:
  if int(row.SpellGroupID)==group and int(row.ChangeCount)==count and int(row.ItemClassID)==item:amount=int(row.ItemAmount)
 if amount<0:return {'error':'이 계열·회차·재료의 원본 비용 정의가 없습니다.'}
 var consumed:Array=[]
 if item==26:
  if int(world.gold)<amount:return {'error':'아데나가 부족합니다: %d 필요' % amount}
 else:
  if not items.has(item):return {'error':'원본 재료 정의가 없습니다.'}
  if bool(items[item].get('TestItem',false)) and not policy.allow_test_materials:return {'error':'원본 테스트 재료는 기본 실행 정책에서 사용할 수 없습니다.'}
  consumed=material_instances(item,amount)
  if consumed.size()!=amount:return {'error':'원본 ID가 확인된 잠금 해제 재료가 부족합니다.'}
 var token:String=JSON.stringify([world.job_class,state,world.gold,world.inventory,world.item_instances,world.ui_preferences.get('item_locks',{}),world.original_skills.catalog.export_state()]).sha256_text()
 return {'error':'','group':group,'item':item,'amount':amount,'count':count,'job':str(world.job_class),'token':token,'consumed_instances':consumed}
func material_instances(item:int,amount:int)->Array:
 var result:Array=[];var counts:Dictionary={};var physical_counts:Dictionary={}
 for entry:Variant in world.item_instances.values():
  if entry is Dictionary:
   var name:String=str(entry.get('name',''))
   physical_counts[name]=int(physical_counts.get(name,0))+1
 for id:Variant in world.item_instances:
  var instance:Variant=world.item_instances[id]
  if not instance is Dictionary:continue
  var record:Variant=instance.get('record')
  if not record is Dictionary or record.get('source')!='lineagem_patch523' or record.get('source_snapshot')!='patch523' or record.get('sourceId')!='m523:item:'+str(item) or NATIVE_FIELDS.full(record).get('source_original_item')!=items[item]:continue
  var raw_id:Variant=record.get('source_item_class_id')
  if not (raw_id is int or raw_id is float) or not is_finite(float(raw_id)) or float(raw_id)!=float(item) or instance.get('name')!=record.get('name'):continue
  var name:String=instance.name
  if world._item_locked(name,str(id)) or world._item_locked(name):continue
  if world.has_method('_is_instance_equipped') and world._is_instance_equipped(str(id)):continue
  var quantity:Variant=world.inventory.get(name,0)
  if not (quantity is int or quantity is float) or not is_finite(float(quantity)) or float(quantity)!=floorf(float(quantity)) or float(quantity)<1:continue
  if float(physical_counts.get(name,0))>float(quantity):continue
  counts[name]=int(counts.get(name,0))+1
  if float(quantity)<float(counts[name]):continue
  result.append(str(id))
  if result.size()==amount:break
 return result
func commit(plan:Dictionary)->String:
 if busy:return '전환 처리 중입니다.'
 var fresh:Dictionary=quote(int(plan.get('group',-1)),int(plan.get('item',26)))
 if not fresh.get('error','').is_empty():return fresh.error
 if fresh.get('token')!=plan.get('token') or fresh.get('amount')!=plan.get('amount'):return '상태가 변경되었습니다. 비용을 다시 확인하세요.'
 busy=true
 var staged:Dictionary=state.duplicate(true);staged.classes[fresh.job]={'group':fresh.group,'count':fresh.count}
 var skills:Dictionary=world.original_skills.catalog.export_state()
 var school:String=ELEMENTS.get(str(groups[int(fresh.group)].Name),'')
 if not school.is_empty():skills.schools[fresh.job]=school
 var gold:int=int(world.gold)-(int(fresh.amount) if int(fresh.item)==26 else 0)
 var inventory:Dictionary=world.inventory.duplicate(true);var instances:Dictionary=world.item_instances.duplicate(true)
 for id:String in fresh.consumed_instances:
  var name:String=instances[id].name
  inventory[name]=int(inventory[name])-1
  if int(inventory[name])==0:inventory.erase(name)
  instances.erase(id)
 var error:Error=world._save_game(true,{'spell_group_conversion':staged,'original_skill_state':skills,'gold':gold,'inventory':inventory,'item_instances':instances})
 if error!=OK:busy=false;return '저장 실패로 전환과 비용 차감을 취소했습니다.'
 state=staged;world.gold=gold;world.inventory=inventory;world.item_instances=instances;world.original_skills.catalog.schools=skills.schools.duplicate(true)
 world.original_skills.catalog.revision+=1
 world.original_skills.catalog.stat_signature='';world.original_skills.catalog.resolved_signature=''
 world._update_hud();busy=false
 return ''
