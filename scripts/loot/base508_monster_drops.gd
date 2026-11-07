extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Native memberships select only verified existing item IDs. Host rolls remain authoritative.
const DATA_SHA="df3ebf9c5bc2bd18d97014e377ee434fce7b412385a7cb720b037f30f6f18151"
const DATA_PATH="res://data/lineagem_base508/monster_drops.bin"
static var _data: Dictionary={}
static var diagnostics: Dictionary={}
static func data(pack_root: String="") -> Dictionary:
 if not _data.is_empty(): return _data
 var paths: Array[String]=[]
 if not pack_root.is_empty(): paths.append(pack_root.path_join("monster_drops.bin"))
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--base508-drop-root="): paths.append(arg.trim_prefix("--base508-drop-root=").path_join("monster_drops.bin"))
 paths.append(DATA_PATH)
 var install=load("res://scripts/lineagem_pack_install.gd")
 paths.append(install.monster_root().path_join("monster_drops.bin"))
 for path: String in paths:
  if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=DATA_SHA: continue
  var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path).decompress_dynamic(64*1024*1024,FileAccess.COMPRESSION_GZIP)
  var value: Variant=JSON.parse_string(bytes.get_string_from_utf8())
  if value is Dictionary and value.get("kind")=="base508_monster_drop_membership" and value.get("source_snapshot")=="base508": _data=value;return _data
 return {}
static func identity(record: Dictionary) -> Dictionary:
 var native: Dictionary=record.get("source_m_original",{})
 var id: int=int(record.get("source_m_npc_id",-1))
 if record.get("source_m_snapshot","")!="base508" or id<=0 or int(native.get("ID",-2))!=id: return {}
 return {"kind":"base508_npc_drop_identity","source_npc_id":id,"source_sprite_id":int(native.get("Sprite",-1)),"pack_root":str(record.get("source_m_asset_manifest_path","")).get_base_dir()}
static func native(identity_value: Dictionary) -> bool:
 return identity_value.get("kind","")=="base508_npc_drop_identity" and int(identity_value.get("source_npc_id",-1))>0
static func _equipment(item: Dictionary) -> bool:
 if item.get("crafting_scroll",false): return bool(item.get("drop_as_equipment",false)) and item.get("slot","")=="consumable"
 return str(item.get("slot","") )not in ["","currency","consumable"]
static func _potion(item: Dictionary) -> bool:
 return item.get("slot","")=="consumable" and int(item.get("heal",0))>0
static func resolve_candidates(document: Dictionary, identity_value: Dictionary, catalog: Dictionary, quest_eligibility: Dictionary={}) -> Dictionary:
 var id: String=str(int(identity_value.get("source_npc_id",-1)))
 var npc: Dictionary=document.get("npcs",{}).get(id,{})
 var report: Dictionary={"native_npc_id":id,"missing_item_bindings":0,"blocked_quest_rows":0,"unsupported_bless_variants":0,"duplicate_rows_ignored":0}
 if not native(identity_value) or npc.is_empty() or int(npc.get("sprite_id",-1))!=int(identity_value.get("source_sprite_id",-2)): return {}
 var groups: Dictionary={}
 for row: Dictionary in document.get("drops",{}).get(id,[]):
  var quest: int=int(row.get("RequiredQuestID",0))
  var eligible: Variant=quest_eligibility.get(str(quest),false)
  if quest!=0 and (not eligible is bool or not eligible): report.blocked_quest_rows+=1;continue
  var item_id: String=str(int(row.ItemClassID));var link: Dictionary=document.get("bindings",{}).get(item_id,{})
  if link.is_empty(): report.missing_item_bindings+=1;continue
  var item: Dictionary=catalog.get("by_name",{}).get(str(link.game_name),{})
  if item.is_empty() or str(item.get("sourceId",""))!=str(link.game_source_id) or item.get("source","")!=link.game_source or item.get("sourceUrl","")!=link.game_source_url or item.get("name","")!=link.game_name or item.get("slot","")!=link.game_slot or item.get("type","")!=link.game_type: report.missing_item_bindings+=1;continue
  var bless: int=int(row.Bless)
  if bless not in [1,2,3] or (bless!=1 and (not _equipment(item) or item.get("slot","")=="consumable")): report.unsupported_bless_variants+=1;continue
  if not groups.has(item_id): groups[item_id]={"item_class_id":int(item_id),"item":item,"variants":{},"kind":"equipment"if _equipment(item)else("potion"if _potion(item)else"material")}
  var key: String=str(bless)
  if groups[item_id].variants.has(key): report.duplicate_rows_ignored+=1;continue
  groups[item_id].variants[key]={"bless_raw":bless,"bless_state":str(document.get("bless_codes",{}).get(key,"Normal")).to_lower(),"source_drop_row_id":int(row.ID),"required_quest_id":quest}
 diagnostics=report
 return groups
static func candidates(identity_value: Dictionary,catalog: Dictionary,quest_eligibility: Dictionary={}) -> Dictionary:
 var document: Dictionary=data(str(identity_value.get("pack_root","")))
 if document.is_empty():
  diagnostics={"status":"native_drop_membership_not_installed","source_npc_id":identity_value.get("source_npc_id",-1)}
  return {}
 return resolve_candidates(document,identity_value,catalog,quest_eligibility)
static func pick(groups: Dictionary, kind: String, grade: String, rng: RandomNumberGenerator) -> Dictionary:
 var choices: Array=[]
 for key: String in groups:
  var group: Dictionary=groups[key]
  if group.kind!=kind: continue
  # Equality implements the unchanged rarity roll; it is not an upper-grade ban.
  if kind=="equipment" and str(group.item.get("grade","일반"))!=grade: continue
  choices.append(group)
 if choices.is_empty(): return {}
 choices.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.item_class_id)<int(b.item_class_id))
 var selected: Dictionary=choices[rng.randi_range(0,choices.size()-1)]
 var keys: Array=selected.variants.keys();keys.sort()
 var variant: Dictionary=selected.variants[keys[rng.randi_range(0,keys.size()-1)]]
 var item: Dictionary=NATIVE_FIELDS.full(selected.item).duplicate(true)
 item["source_m_item_id"]=selected.item_class_id
 item["source_m_item_bless_raw"]=variant.bless_raw
 item["bless_state"]=variant.bless_state
 item["source_m_drop_proof"]=variant.duplicate(true)
 return {"item_name":str(item.name),"quantity":1,"item_record":item,"source_m_item_id":selected.item_class_id,"source_m_drop_proof":variant.duplicate(true)}
static func ground_metadata(entry: Dictionary, physical: bool) -> Dictionary:
 if not entry.has("source_m_drop_proof") or not entry.get("item_record") is Dictionary: return {}
 var item: Dictionary=NATIVE_FIELDS.full(entry.item_record).duplicate(true)
 var result: Dictionary={"item_record":item}
 if physical:
  var id: String=Crypto.new().generate_random_bytes(16).hex_encode()
  result["physical_item"]={"id":id,"data":{"name":str(entry.item_name),"level":0,"element":"","element_level":0,"record":item,"bless_state":item.bless_state,"source_m_drop_proof":entry.source_m_drop_proof.duplicate(true)}}
 return result
