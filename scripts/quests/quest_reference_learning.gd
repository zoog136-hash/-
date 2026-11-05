extends RefCounted
## Original learning and unverified execution are separate states.
const SOURCE_SHA="d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const ITEM_PIN="38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
const SKILL_PIN="256f0ba0944e05b86134b40ed3aea97c71e1073b3947ea6e46cb018b6179926a"
const MAP={177292:{"spell": 347, "key": "lmref_558f725f5e8c3350", "sha": "5dadf2372e8b948e5fceceacaa06309225b3e22b82b8ca0c17f1e60f00328269", "reason": "원본 MP 재생·버프 실행 연결 확인"},177322:{"spell": 358, "key": "lmref_b2f791c9662ba809", "sha": "44834d756fa97b20524742fc49a23c6f6c4c1e19c1d7dd6b68b32229554899ed", "reason": "원본 감지·취소 조건 연결 확인"},177342:{"spell": 1133, "key": "lmref_caf0662f0a311237", "sha": "293aac2d9d72792bd54e205e974d06a8c32346e05a51852649b1dff916951b57", "reason": "원본 변경 시전 조건 연결 확인"},177432:{"spell": 70, "key": "lmref_64f77fcd9c52a02b", "sha": "fd1a8345fc9f8f144a069cb1c486f0ca36045aeaff0dcfc5533111cd15835ee9", "reason": "원본 버프 그룹·취소 면역 연결 확인"}}
static func matches(item: int,spell: int,key: String,sha: String)->bool:
 var row: Dictionary=MAP.get(item,{})
 return not row.is_empty() and int(row.spell)==spell and row.key==key and row.sha==sha
static func key_row(key: String)->Dictionary:
 for row: Dictionary in MAP.values():
  if row.key==key:return row
 return {}
static func make_record(world: Node,item: int,evidence: Dictionary={})->Dictionary:
 var row: Dictionary=MAP[item]
 var record: Dictionary={"schema":1,"kind":"quest523.source-learning.execution-pending","source_sha256":SOURCE_SHA,"item_pack_sha256":ITEM_PIN,"item_class_id":item,"spell_class_id":int(row.spell),"local_skill_id":str(row.key),"spell_row_sha256":str(row.sha),"learned_class_id":world.BASE508.source_class_id(world.job_class),"execution_status":"blocked_until_verified_owner","reason":str(row.reason)}
 if evidence.get("kind")=="original_bound_profiles":record["skill_source_evidence"]=evidence.duplicate(true)
 else:record["skill_pack_sha256"]=SKILL_PIN
 # New native quantity ownership cites its actual original definition, not a
 # historical BIN which was not consumed. Existing records remain unchanged.
 var archive: Variant=evidence.get("item_definition_archive")
 if archive is Dictionary and archive==preload("res://scripts/resources/current523_definition_rows.gd").identity():
  record.erase("item_pack_sha256");record["item_definition_archive"]=archive.duplicate(true)
 return record
static func status(knowledge: Dictionary,learned: Dictionary,key: String)->Dictionary:
 var row: Dictionary=key_row(key)
 if row.is_empty() or not knowledge.has(key) or int(learned.get(key,0))<=0:return {}
 var record: Variant=knowledge[key]
 var message: String="원본 학습 완료 · "+str(row.reason)+" · 실행 대기"
 return {"learned":true,"execution_allowed":false,"message":message,"spell_class_id":int(row.spell),"learned_class_id":int(record.get("learned_class_id",0)) if record is Dictionary else 0,"kind":"source_learning_only"}
static func restore(state: Dictionary,full_save: Dictionary)->Dictionary:
 var raw: Variant=state.get("source_quest_knowledge",{})
 var result: Dictionary=raw.duplicate(true) if raw is Dictionary else {}
 # A saved source learning receipt remains an execution hold even when an
 # older producer did not export the new presentation field. Never regrant.
 var consumables: Variant=full_save.get("consumable_state",{})
 if not consumables is Dictionary:return result
 var receipts: Variant=consumables.get("source_skill_book_receipts",[])
 if not receipts is Array:return result
 for receipt: Variant in receipts:
  if not receipt is Dictionary:continue
  var item: int=int(receipt.get("item_class_id",0))
  if not MAP.has(item) or str(receipt.get("local_skill_id",""))!=MAP[item].key or int(receipt.get("spell_class_id",0))!=int(MAP[item].spell):continue
  var key: String=str(MAP[item].key)
  if not result.has(key):
   var saved: Variant=receipt.get("source_learning_record",{})
   result[key]=saved.duplicate(true) if saved is Dictionary and not saved.is_empty() else {"schema":1,"execution_status":"source_receipt_preserved_execution_pending","learned_class_id":0}
 return result
