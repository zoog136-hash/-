extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Bounded PR238 learning transaction + public PR245 exact evidence contract.
## No cast engine, reference activation, skill replacement or estimated formulas.
const BOOK=preload("res://scripts/loot/patch523_skill_book.gd")
const USE=preload("res://scripts/loot/patch523_item_use.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const CONSUMPTION=preload("res://scripts/quests/quest_reward_consumption.gd")
const PACK_SHA="256f0ba0944e05b86134b40ed3aea97c71e1073b3947ea6e46cb018b6179926a"
const BINDING_SHA="497a594e7312ce98dd966b737b1bfb4555072af3c0d5b63d61b8ee2c33075346"
const SOURCE_SHA="d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const ITEM_PIN="38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
const REFERENCE=preload("res://scripts/quests/quest_reference_learning.gd")
const IDS=[177292,177322,177342,177432,177192,177202,177212,177222,177232,177252,177332,177452]
const BINDINGS_PATH="res://data/skills/player_skills523_bindings.json"
var profiles: Dictionary={}
var bindings: Dictionary={}
var active_sha256: String=""
var last_error: String=""
func reject(reason: String)->bool:last_error=reason;return false
func load_pack(path: String, expected: String)->bool:
 if expected!=PACK_SHA or not FileAccess.file_exists(path):return reject("exact reviewed v3 input required")
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null or file.get_length()!=4415307:return reject("exact v3 size required")
 var bytes: PackedByteArray=file.get_buffer(file.get_length())
 var hashing:=HashingContext.new();hashing.start(HashingContext.HASH_SHA256);hashing.update(bytes)
 if hashing.finish().hex_encode()!=PACK_SHA:return reject("v3 SHA mismatch")
 var raw_bindings: String=FileAccess.get_file_as_string(BINDINGS_PATH)
 if raw_bindings.sha256_text()!=BINDING_SHA:return reject("public245 binding revision mismatch")
 var value: Variant=JSON.parse_string(bytes.get_string_from_utf8())
 var bound: Variant=JSON.parse_string(raw_bindings)
 if not value is Dictionary or not bound is Dictionary:return reject("invalid document")
 if value.get("schema_version")!=1 or value.get("patch")!=523 or value.get("source_zip_sha256")!=SOURCE_SHA or value.get("bindings_sha256")!=BINDING_SHA:return reject("source/binding identity mismatch")
 if not value.get("profiles") is Dictionary or value.profiles.size()!=441 or value.profiles.size()!=bound.skills.size():return reject("incomplete profiles")
 for id: String in bound.skills:
  var profile: Dictionary=value.profiles.get(id,{})
  var row_json: Variant=profile.get("row_json")
  if not row_json is String or row_json.sha256_text()!=bound.skills[id].row_sha256 or JSON.parse_string(row_json)!=profile.get("row") or int(profile.row.get("ID",-1))!=int(bound.skills[id].spell_id):return reject("source row identity mismatch")
 profiles=value.profiles;bindings=bound;active_sha256=PACK_SHA;last_error=""
 return true
func configure_arguments()->void:
 var path: String="";var expected: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--player-skills523-pack="):path=arg.trim_prefix("--player-skills523-pack=")
  if arg.begins_with("--player-skills523-sha256="):expected=arg.trim_prefix("--player-skills523-sha256=")
 if not path.is_empty() or not expected.is_empty():load_pack(path,expected)
func identity(record: Dictionary,world: Node=null)->Dictionary:
 if int(record.get("source_item_class_id",0)) not in IDS:return {}
 var result: Dictionary={}
 var evidence: Dictionary={}
 if active_sha256==PACK_SHA:
  result=BOOK.resolve(self,NATIVE_FIELDS.full(record).get("source_use_spec",{}))
  evidence={"kind":"compiled_pack","source_sha256":SOURCE_SHA,"binding_sha256":BINDING_SHA,"skill_pack_sha256":PACK_SHA}
 elif world!=null and world.get("original_skills")!=null:
  # Consume the existing public source reader's actually loaded adapter. No
  # second reader, virtual v3 fingerprint or unreviewed skill-ID join.
  var adapter: Variant=world.original_skills.catalog.source523
  if adapter==null or adapter.get_script()!=preload("res://scripts/skills/player_skills523.gd") or adapter.get("source_mode")!="original_bound_profiles":return {}
  var source: Variant=adapter.get("source_identity")
  if not source is Dictionary or source.get("source_snapshot")!="patch523" or source.get("source_sha256")!=SOURCE_SHA or source.get("source_bytes")!=25031173:return {}
  if FileAccess.get_file_as_string(BINDINGS_PATH).sha256_text()!=BINDING_SHA:return {}
  result=BOOK.resolve(adapter,NATIVE_FIELDS.full(record).get("source_use_spec",{}))
  evidence={"kind":"original_bound_profiles","source_sha256":SOURCE_SHA,"binding_sha256":BINDING_SHA,"source_identity":source.duplicate(true)}
 if result.is_empty():return {}
 if not preload("res://scripts/quests/source_dummy523.gd").evidence("SpellClass",result.get("profile",{}).get("row",{})).is_empty():return {}
 if str(result.get("local_skill_id","")).begins_with("lmref_") and not REFERENCE.matches(int(record.get("source_item_class_id",0)),int(NATIVE_FIELDS.full(record).get("source_use_spec",{}).get("spell_class_id",0)),str(result.local_skill_id),str(NATIVE_FIELDS.full(record).get("source_use_spec",{}).get("source_spell_row_sha256",""))):return {}
 result["skill_evidence"]=evidence
 return result
func fail(world: Node,reason: String)->Dictionary:
 world.hud.show_message(reason+" · 스킬서 보존")
 return {"handled":true,"ok":false,"saved":false,"consumed":0,"reason":reason}
func use(world: Node,record: Dictionary,physical_id: String="")->Dictionary:
 if world.quest_service.save_blocked or not world._patch523_item_allowed():return fail(world,"현재 저장·아이템 사용 보호")
 var canonical: Dictionary=USE.canonical(record)
 var spec: Dictionary=NATIVE_FIELDS.full(canonical).get("source_use_spec",{})
 if NATIVE_FIELDS.full(record).get("source_use_spec")!=spec:return fail(world,"제공된 주문 원본 증명 불일치")
 var error: String=USE.eligibility(world,canonical)
 if not error.is_empty():return fail(world,error)
 if spec.get("kind")!="source_skill_book" or spec.get("activation_status")!="unrestricted":return fail(world,"원본 학습 효과 미지원")
 var requirements: Dictionary=spec.get("item_requirements",{})
 if int(requirements.get("targetting_type_id",-1))!=1 or not str(requirements.get("service_region_code","")).is_empty():return fail(world,"원본 대상·서비스 조건 미지원")
 if not requirements.get("can_use_when_invisible",false) and world.is_player_concealed():return fail(world,"원본 은신 사용 제한")
 if world._option_awakening_busy() or (world.hud.has_method("is_card_reveal_busy") and world.hud.is_card_reveal_busy()):return fail(world,"다른 사용 처리 중")
 if float(world.item_use_cooldowns.get("m523:item:"+str(int(canonical.source_item_class_id)),0.0))>0.0:return fail(world,"원본 재사용 대기")
 error=BOOK.source_limit_problem(world,spec)
 if not error.is_empty():return fail(world,error)
 var target: Dictionary=identity(canonical,world)
 if target.is_empty():return fail(world,"정확한 원본/검토된 v3 입력·기존 학습 ID 연결 필요")
 var catalog: Object=world.original_skills.catalog
 var key: String=str(target.local_skill_id)
 var skill: Dictionary=catalog.record_for(key)
 var learning_only: bool=REFERENCE.matches(int(canonical.source_item_class_id),int(spec.spell_class_id),key,str(spec.source_spell_row_sha256))
 if skill.get("id")!=key:return fail(world,"정확한 기존 학습 ID 확인 필요")
 if learning_only:
  if catalog.learned.has(key) and catalog.learned[key]!=0:return fail(world,"이미 학습 기록이 있습니다")
  for required: String in catalog.relations.get(key,{}).get("requires_skill",[]):
   if int(catalog.learned.get(required,0))<int(catalog.relations[key].get("requires_skill_level",{}).get(required,1)):return fail(world,"기존 선행 스킬 조건 미충족")
 else:
  if bool(skill.get("runtime_blocked",false)):return fail(world,"현재 실행 소유자 미지원")
  error=catalog.reason(skill,true)
  if not error.is_empty():return fail(world,error)
 var inventory_key: String=str(canonical.name)
 var prepared: Dictionary={}
 var input_proof: Dictionary={}
 var payload: Dictionary={}
 var source_step: Dictionary={}
 if not physical_id.is_empty():
  prepared=OWN.prepare_debit(world,physical_id,1)
  if not prepared.get("ok",false):return fail(world,str(prepared.get("reason","소지 증명 실패")))
  if int(prepared.ownership.item_class_id)!=int(canonical.source_item_class_id) or int(prepared.ownership.bless_code_id)!=int(canonical.source_bless_raw) or prepared.ownership.source_item!=D.definition_id(str(int(canonical.source_item_class_id))).original_item:return fail(world,"원본 소지 정체 불일치")
  inventory_key=str(prepared.ownership.inventory_key)
  source_step=CONSUMPTION.stage(world,[{"physical_id":physical_id,"quantity":1,"expected_quantity":int(prepared.ownership.quantity),"expected_remaining":int(prepared.ownership.quantity)-1,"quest_reward_receipt":world.item_instances[physical_id].quest_reward_receipt.duplicate(true)}],ITEM_PIN)
  if not source_step.get("ok",false):return fail(world,str(source_step.get("reason","공동 학습 소비 영수증 불일치")))
  payload=source_step.overrides.duplicate(true)
  input_proof={"physical_id":physical_id,"original_quantity":int(prepared.ownership.original_quantity),"remaining_before":int(prepared.ownership.quantity),"quest_receipt":world.item_instances[physical_id].quest_reward_receipt.duplicate(true)}
 else:
  if world._item_locked(inventory_key,"") or int(world.inventory.get(inventory_key,0))<1:return fail(world,"소지량·잠금 확인 필요")
  var issued: Array=[]
  for qid: String in world.quest_service.item_grants:
   if world.quest_service.claimed.get(qid)!=true:continue
   for receipt: Dictionary in world.quest_service.item_grants[qid]:
    if receipt.has("origin") or receipt.get("inventory_key")!=inventory_key or receipt.get("pack_sha256")!=ITEM_PIN or int(receipt.get("item_class_id",0))!=int(canonical.source_item_class_id) or int(receipt.get("bless_raw",0))!=int(canonical.source_bless_raw):continue
    issued.append({"quest_id":qid,"receipt":receipt.duplicate(true)})
  if issued.is_empty():return fail(world,"실제 원본 퀘스트 지급 영수증 필요")
  input_proof={"inventory_key":inventory_key,"remaining_before":int(world.inventory[inventory_key]),"issued_receipts":issued}
  payload["inventory"]=USE.debit(world,inventory_key)
 var learned: Dictionary=catalog.export_state()
 learned.learned[key]=1
 var source_learning: Dictionary={}
 if learning_only:
  source_learning=REFERENCE.make_record(world,int(canonical.source_item_class_id),target.skill_evidence)
  if not learned.has("source_quest_knowledge"):learned["source_quest_knowledge"]={}
  learned.source_quest_knowledge[key]=source_learning.duplicate(true)
 var consumables: Dictionary=world.consumable_service.export_state()
 if not consumables.get("source_skill_book_receipts",[]) is Array:return fail(world,"학습 영수증 저장 형식 확인 필요")
 var receipts: Array=consumables.get("source_skill_book_receipts",[]).duplicate(true)
 receipts.append({"source_snapshot":"patch523","source_sha256":SOURCE_SHA,"item_pack_sha256":ITEM_PIN,"skill_source_evidence":target.skill_evidence.duplicate(true),"item_class_id":int(canonical.source_item_class_id),"bless_raw":int(canonical.source_bless_raw),"card_id":int(spec.card_id),"spell_class_id":int(spec.spell_class_id),"spell_row_sha256":str(spec.source_spell_row_sha256),"local_skill_id":key,"cannot_swap":bool(spec.get("buff_card_cannot_swap",false)),"cannot_stack_card":bool(spec.get("cannot_stack_card",false)),"input":input_proof})
 if target.skill_evidence.kind=="compiled_pack":receipts[-1]["skill_pack_sha256"]=PACK_SHA
 if learning_only:receipts[-1]["source_learning_record"]=source_learning.duplicate(true)
 consumables["source_skill_book_receipts"]=receipts
 payload["original_skill_state"]=learned;payload["consumable_state"]=consumables
 payload["item_use_cooldowns"]=USE.next_cooldowns(world,canonical,spec)
 if not prepared.is_empty() and not OWN.current(world,prepared):return fail(world,"소지 영수증 변경")
 if not source_step.is_empty() and not CONSUMPTION.matches_payload(world,source_step,payload):return fail(world,"최종 학습·선택 개체·사용 영수증 불일치")
 if not CONSUMPTION.same(identity(canonical,world),target):return fail(world,"학습 후보 생성 후 원본 주문 공급 정체 변경")
 var prior: String=FileAccess.get_sha256(world.save_path())
 var saved: Error=world._save_game(true,payload)
 if saved!=OK:
  if not world.patch523_owner_state_problem.is_empty():
   world.quest_service.save_blocked=true
   return fail(world,"공동 학습 저장 결과 미확정 · 재사용 중지")
  var durable: Variant=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
  var normalized: Dictionary=JSON.parse_string(JSON.stringify(payload,"",true,true))
  var confirmed: bool=durable is Dictionary
  if confirmed:
   for field: String in normalized:
    if durable.get(field)!=normalized[field]:confirmed=false;break
  if not confirmed:
   if FileAccess.get_sha256(world.save_path())!=prior:world.quest_service.save_blocked=true
   return fail(world,"학습 저장 실패·결과 확인 필요")
  if not world.equipment_collections.accept_load(durable):world.quest_service.save_blocked=true;return fail(world,"학습 저장 재확인 필요")
 if payload.has("quest_state") and world.quest_service.import_state(payload.quest_state)!=true:
  world.quest_service.save_blocked=true
  return fail(world,"학습 후보는 저장됐지만 사용 장부 활성화 미확정 · 다시 불러오기 필요")
 world.inventory=payload.inventory
 if payload.has("item_instances"):world.item_instances=payload.item_instances
 world.item_use_cooldowns=payload.item_use_cooldowns
 world.consumable_service.import_state(consumables)
 # Adopt only the staged learning map; unrelated quickslots/archives are not migrated.
 catalog.source_quest_knowledge=learned.get("source_quest_knowledge",{}).duplicate(true)
 catalog.learned=learned.learned.duplicate(true);catalog.revision+=1
 world.original_skills.refresh_buffs_after_learning(key)
 world.deferred_save.cancel();world._refresh_speed_modifiers()
 world.quest_auto.refresh_context(world);world.hud.refresh_inventory(world.inventory);world._update_hud()
 world.hud.show_message(str(skill.name)+" 원본 학습 완료 · 실행 대기" if learning_only else str(skill.name)+" 습득 · 원본 주문 #"+str(int(spec.spell_class_id)))
 return {"handled":true,"ok":true,"saved":true,"consumed":1,"local_skill_id":key,"physical_id":physical_id,"learning_only":learning_only,"execution_allowed":not learning_only}
