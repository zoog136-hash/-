extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Exact normal quest fixed cards; staged existing public243 card owner.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const USE=preload("res://scripts/loot/patch523_item_use.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const CARDS=preload("res://scripts/card_draw_fusion.gd")
const IDS=[306611,306621,306631,306641]
const PIN="38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
static func target(world: Node,record: Dictionary)->Dictionary:
 var id: int=int(record.get("source_item_class_id",0))
 if id not in IDS or int(record.get("source_bless_raw",0))!=1:return {}
 var definition: Dictionary=D.definition_id(str(id))
 var spec: Dictionary=NATIVE_FIELDS.full(record).get("source_use_spec",{})
 if definition.get("original_item",{}).get("TestItem",true) or spec.get("kind")!="fixed_card" or spec.get("activation_status")!="unrestricted":return {}
 var original: Dictionary=spec.get("original_card",{})
 if original.get("IsNoMergeOut")!=true or original.get("IsNoSwapOut")!=true or int(original.get("ServerLimitSetID",-1))!=0 or int(original.get("StartDateTimeID",-1))!=0 or int(original.get("EndDateTimeID",-1))!=0:return {}
 var category: String=str(spec.get("card_kind",""));var found: Array=[]
 for row: Dictionary in world.catalog_db.get(category,[]):
  if row.get("source")!="lineagem_base508" or int(row.get("source_card_id",0))!=int(spec.card_id) or row.get("source_original_card")!=original:continue
  var identity: String=CARDS.card_id(row)
  if identity!="source:m508:"+str(int(original.BuffCardDeckID))+":"+str(int(spec.card_id)):continue
  if row.get("source_merge_out_disabled")!=true or row.get("source_swap_out_disabled")!=true:continue
  if world.card_draw_fusion.source_merge_blocked.get(category+":"+identity)!=true or world.card_draw_fusion.known_ids.get(category,{}).get(identity)!=row.grade:continue
  found.append({"category":category,"identity":identity,"record":row})
 return found[0] if found.size()==1 and world.card_draw_fusion.has_method("receive_source_card") else {}
static func fail(world: Node,message: String)->Dictionary:
 world.hud.show_message(message+" · 원본 카드 아이템 보존")
 return {"handled":true,"ok":false,"saved":false,"consumed":0,"reason":message}
static func use(world: Node,record: Dictionary,physical_id: String="")->Dictionary:
 if world.quest_service.save_blocked or not world._patch523_item_allowed():return fail(world,"현재 저장·사용 보호")
 var canonical: Dictionary=USE.canonical(record)
 if NATIVE_FIELDS.full(record).get("source_use_spec")!=NATIVE_FIELDS.full(canonical).get("source_use_spec"):return fail(world,"전달된 원본 카드 증명 불일치")
 var problem: String=USE.eligibility(world,canonical)
 if not problem.is_empty():return fail(world,problem)
 var exact: Dictionary=target(world,canonical)
 if exact.is_empty():return fail(world,"정확한 카드 등록·원본 전역 제한 확인 필요")
 var spec: Dictionary=NATIVE_FIELDS.full(canonical).source_use_spec;var requirements: Dictionary=spec.get("item_requirements",{})
 if int(requirements.get("targetting_type_id",-1))!=1 or not str(requirements.get("service_region_code","")).is_empty():return fail(world,"원본 대상·서버 조건 미지원")
 if not requirements.get("can_use_when_invisible",false) and world.is_player_concealed():return fail(world,"원본 은신 사용 제한")
 if float(world.item_use_cooldowns.get("m523:item:"+str(int(canonical.source_item_class_id)),0))>0:return fail(world,"원본 사용 대기")
 if world._option_awakening_busy() or (world.hud.has_method("is_card_reveal_busy") and world.hud.is_card_reveal_busy()):return fail(world,"다른 카드 처리 중")
 var payload: Dictionary={};var prepared: Dictionary={};var input: Dictionary={}
 var item_key: String=str(canonical.name)
 if not physical_id.is_empty():
  prepared=OWN.prepare_debit(world,physical_id,1)
  if not prepared.get("ok",false):return fail(world,str(prepared.get("reason","선택 소지 증명 실패")))
  var owned: Dictionary=prepared.ownership
  if int(owned.item_class_id)!=int(canonical.source_item_class_id) or int(owned.bless_code_id)!=1 or owned.source_item!=D.definition_id(str(int(owned.item_class_id))).original_item:return fail(world,"선택 원본 정체·축복 불일치")
  payload=prepared.override.duplicate(true)
  var usage: Dictionary=OWN.use_state(world,prepared,PIN)
  if not usage.ok:return fail(world,str(usage.reason))
  payload["quest_state"]=usage.state
  input={"physical_id":physical_id,"quest_receipt":world.item_instances[physical_id].quest_reward_receipt.duplicate(true),"original_quantity":int(owned.original_quantity),"remaining_before":int(owned.quantity)}
 else:
  if world._item_locked(item_key,"") or int(world.inventory.get(item_key,0))<1:return fail(world,"정확한 소지량·잠금 확인 필요")
  var issued: Array=[]
  for qid: String in world.quest_service.item_grants:
   if world.quest_service.claimed.get(qid)!=true:continue
   for row: Dictionary in world.quest_service.item_grants[qid]:
    if row.has("origin") or row.get("inventory_key")!=item_key or row.get("pack_sha256")!=PIN or int(row.item_class_id)!=int(canonical.source_item_class_id) or int(row.bless_raw)!=1:continue
    issued.append({"quest_id":qid,"receipt":row.duplicate(true)})
  if issued.is_empty():return fail(world,"실제 퀘스트 지급 영수증 없음")
  payload["inventory"]=USE.debit(world,item_key)
  input={"inventory_key":item_key,"remaining_before":int(world.inventory[item_key]),"issued_receipts":issued}
 var candidate=CARDS.new();candidate.configure(world.catalog_db);candidate.import_state(world.card_draw_fusion.export_state())
 var duplicate: bool=candidate.owned[exact.category].has(exact.identity)
 var proof: Dictionary={"origin":"quest_current523","source_snapshot":"patch523","source_sha256":world.quest_service.source.SOURCE_SHA,"item_pack_sha256":PIN,"item_class_id":int(canonical.source_item_class_id),"card_id":int(spec.card_id),"bless":1,"buff_card_cannot_swap":bool(spec.get("buff_card_cannot_swap",false)),"source_global_no_swap":true,"source_global_no_merge":true,"quest_option_feed_hold":1 if duplicate else 0,"quest_option_feed_policy":"TWILIGHT_host_hold_until_option_owner_verified","quest_copy_role":"spare" if duplicate else "permanent","quest_use_token":JSON.stringify([OWN.stamp(world),input,exact.identity]).sha256_text(),"input":input}
 var outcome: Dictionary=candidate.receive_source_card(exact.category,exact.record,proof)
 if not outcome.get("ok",false):return fail(world,str(outcome.get("error","원본 카드 지급 실패")))
 payload["card_draw_fusion"]=candidate.export_state()
 payload["item_use_cooldowns"]=USE.next_cooldowns(world,canonical,spec)
 if not prepared.is_empty() and not OWN.current(world,prepared):return fail(world,"소지 증명 변경")
 var previous: String=FileAccess.get_sha256(world.save_path())
 var error: Error=world._save_game(true,payload)
 if error!=OK:
  var durable: Variant=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
  var expected: Dictionary=JSON.parse_string(JSON.stringify(payload));var confirmed: bool=durable is Dictionary
  if confirmed:
   for key: String in expected:
    if durable.get(key)!=expected[key]:confirmed=false;break
  if not confirmed:
   if FileAccess.get_sha256(world.save_path())!=previous:world.quest_service.save_blocked=true
   return fail(world,"저장 실패·결과 확인 필요")
  if not world.equipment_collections.accept_load(durable):world.quest_service.save_blocked=true;return fail(world,"저장 결과 재확인 필요")
 world.inventory=payload.inventory
 if payload.has("item_instances"):world.item_instances=payload.item_instances
 if payload.has("quest_state"):world.quest_service.import_state(payload.quest_state)
 world.item_use_cooldowns=payload.item_use_cooldowns
 world.card_draw_fusion.import_state(payload.card_draw_fusion)
 world.deferred_save.cancel();world._invalidate_equipment_static()
 world.quest_auto.refresh_context(world);world.hud.refresh_inventory(world.inventory);world._update_hud()
 world.hud.show_message("원본 지정 카드 획득 · "+str(exact.record.name)+(" · 중복" if duplicate else " · 신규"))
 return {"handled":true,"ok":true,"saved":true,"consumed":1,"category":exact.category,"identity":exact.identity,"duplicate":duplicate,"results":outcome.get("results",[])}
