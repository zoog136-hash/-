extends RefCounted
## Rebind proven, untouched Amount=1 alchemy equipment; never grants or saves.
## The caller must recheck current() and commit overrides with its atomic writer.
const C = preload("res://scripts/equipment523/common.gd")
const Native = preload("res://scripts/equipment523/native_catalog.gd")
const OWNER_PATH: String = Native.OWNER_PATH
const OLD_SOURCE: String = "lineagem_current523"
const OLD_SNAPSHOT: String = "current523"
const PREFIX: String = "[원본보상]"
const LEGACY_DESCRIPTION: String = "미등록 원본 아이템: 실제 장비 효과는 카탈로그 등록 후 적용합니다."
const LEGACY_RECORD_FIELDS: Array[String] = ["name","source","source_snapshot","sourceId","source_item_class_id","source_original_item","source_bless_code_id","source_reward_quantity","source_reward_id","desc","bless_state","blessed"]
const LEGACY_PHYSICAL_FIELDS: Array[String] = ["name","level","element","element_level","source_bless_code","bless_state","record","source_reward_quantity","equipment523_last_processing","equipment523","source_smelt","sourceId","locked","equipped"]

static func _integer(value: Variant, minimum: int = 0) -> int:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < minimum or float(value) > 9007199254740991.0: return -1
	return int(value)

static func _digest(value: Variant) -> bool:
	return value is String and value.length() == 64 and value == value.to_lower() and value.is_valid_hex_number(false)

static func _property(world: Node, field: String) -> Variant:
	for entry: Dictionary in world.get_property_list():
		if entry.name == field: return world.get(field)
	return null

static func snapshot(world: Node) -> Dictionary:
	# References are examined conservatively. Unknown fields on physical items
	# themselves are retained byte-for-value by the candidate's deep copy.
	var references: Dictionary = {}
	for field: String in ["equipped_items","equipped_catalog","quickslots","ui_preferences","enhancement_levels","active_item_buffs","item_use_cooldowns"]:
		var value: Variant = _property(world,field)
		if value != null: references[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	var warehouse: Variant = _property(world,"warehouse")
	if warehouse != null and warehouse.has_method("snapshot"): references["warehouse"] = warehouse.call("snapshot")
	var catalog: Array = []
	# Hosts without a catalog (service fixtures, early boot) have nothing to
	# migrate; read every host field defensively instead of failing mid-tick.
	var catalog_db: Variant = _property(world,"catalog_db")
	for source: Variant in [catalog_db.get("아이템",[]) if catalog_db is Dictionary else [],_property(world,"item_db")]:
		if not source is Array: continue
		for record: Variant in source:
			if not record is Dictionary: continue
			var identity: Dictionary = {}
			for field: String in Native.IDENTITY_FIELDS:
				if record.has(field): identity[field] = record[field]
			catalog.append(identity)
	var inventory: Variant = _property(world,"inventory")
	var item_instances: Variant = _property(world,"item_instances")
	return {"inventory":inventory.duplicate(true) if inventory is Dictionary else {},"item_instances":item_instances.duplicate(true) if item_instances is Dictionary else {},"references":references,"catalog":catalog}

static func _referenced(value: Variant, name: String, id: String) -> bool:
	if value is String:
		return value == id or value.contains(name) or value.ends_with("@@@"+id)
	if value is Dictionary:
		for key: Variant in value:
			if _referenced(key,name,id) or _referenced(value[key],name,id): return true
	if value is Array:
		for entry: Variant in value:
			if _referenced(entry,name,id): return true
	return false

static func _pending(physical: Dictionary) -> bool:
	var record: Variant = physical.get("record")
	return record is Dictionary and (record.get("source") == OLD_SOURCE or record.get("source_snapshot") == OLD_SNAPSHOT) and record.get("source_original_item") is bool and record.source_original_item == true

static func _reason(pack: Dictionary, physical: Dictionary, id: String, references: Dictionary, authority: Dictionary, consumer_sha: String) -> String:
	var record: Dictionary = physical.record
	if physical.has("quest_reward_receipt") or record.has("quest_reward_receipt"): return "quest_receipt_preserved"
	if record.get("source") != OLD_SOURCE or record.get("source_snapshot") != OLD_SNAPSHOT: return "old_source_identity_mismatch"
	for field: Variant in record:
		if field not in LEGACY_RECORD_FIELDS: return "unknown_legacy_record_field_preserved"
	for field: String in LEGACY_RECORD_FIELDS:
		if not record.has(field): return "incomplete_legacy_record_preserved"
	for field: Variant in physical:
		if field not in LEGACY_PHYSICAL_FIELDS: return "unknown_physical_field_preserved"
	if record.get("desc") != LEGACY_DESCRIPTION: return "legacy_record_contract_mismatch"
	if _referenced(references,str(physical.get("name","")),id): return "external_reference_preserved"
	if not Native.same(physical.get("locked",false),false) or not Native.same(physical.get("equipped",false),false): return "locked_or_equipped_preserved"
	for field: String in ["equipment523","source_smelt"]:
		if physical.has(field) and (not physical[field] is Dictionary or not physical[field].is_empty()): return "later_processing_state_preserved"
	var source: int = _integer(record.get("source_item_class_id"),1)
	var item: Dictionary = C.item(pack,source)
	if source <= 0 or item.is_empty() or item.get("raw",{}).get("TestItem") != false: return "unknown_source_item"
	var old_name: String = PREFIX+str(item.get("name",""))
	if str(item.get("name","")).is_empty() or record.get("name") != old_name or physical.get("name") != old_name or record.get("sourceId") != "m523:item:"+str(source): return "old_identity_mismatch"
	if record.has("source_m_native_item") or record.has("source_pending_use") or record.has("source_m_reward_proof"): return "mixed_owner_identity_preserved"
	if physical.has("sourceId") and physical.sourceId != record.sourceId: return "physical_identity_mismatch"
	var result_id: int = _integer(record.get("source_reward_id"),1)
	var result: Dictionary = C.find(pack,"AlchemyResult",result_id)
	var recipe: Dictionary = C.find(pack,"AlchemyRecipeType",_integer(result.get("RecipeTypeID"),1))
	if result.is_empty() or _integer(result.get("RecipeTypeID"),1) not in [63,113] or not Native.same(recipe.get("IsEnabled"),true): return "inactive_or_missing_result"
	if _integer(result.get("ItemClassID"),1) != source or _integer(result.get("Amount"),1) != 1 or _integer(result.get("Enchant")) != 0 or _integer(result.get("BlessCode"),1) != 1 or _integer(result.get("ServerLimitSetID")) != 0 or _integer(result.get("Probability"),1) <= 0: return "unsupported_original_result"
	if _integer(record.get("source_reward_quantity"),1) != 1 or _integer(physical.get("source_reward_quantity"),1) != 1: return "physical_quantity_mismatch"
	if _integer(record.get("source_bless_code_id"),1) != 1 or _integer(physical.get("source_bless_code"),1) != 1 or _integer(physical.get("level")) != 0 or physical.get("element") != "" or _integer(physical.get("element_level")) != 0: return "physical_result_state_mismatch"
	for holder: Dictionary in [record,physical]:
		if holder.has("blessed") and not Native.same(holder.blessed,false) or holder.has("bless_state") and holder.bless_state != "normal": return "physical_blessing_mismatch"
	if physical.has("equipment523_last_processing"):
		var proof: Variant = physical.equipment523_last_processing
		if not proof is Dictionary: return "processing_proof_mismatch"
		for field: Variant in proof:
			if field not in ["kind","source_sha256","consumer_data_sha256","result_id","recipe_type"]: return "unknown_processing_proof_preserved"
		if proof.get("kind") != "alchemy" or proof.get("source_sha256") != C.SOURCE_SHA or proof.get("consumer_data_sha256") != consumer_sha or _integer(proof.get("result_id"),1) != result_id: return "processing_proof_mismatch"
		if proof.has("recipe_type") and _integer(proof.recipe_type,1) != _integer(result.RecipeTypeID,1): return "processing_recipe_mismatch"
	if authority.is_empty(): return "native_catalog_unavailable"
	var identity: Dictionary = Native.validate_identity(pack,authority.get("record",{}),authority.get("definition",{}),authority.get("expected",{}),authority.get("identity",{}),authority.get("equipment",false) == true)
	if identity.is_empty() or int(identity.source_id) != source or int(identity.bless_code) != 1: return "native_definition_mismatch"
	if not bool(identity.equipment): return "non_equipment_quantity_contract_pending"
	if authority.get("registered") != true: return "native_catalog_not_registered"
	return ""

static func stage_snapshot(pack: Dictionary, before: Dictionary, authorities: Dictionary, consumer_sha: String) -> Dictionary:
	# Pure reducer for tests and the actual read-only owner bridge below.
	if pack.get("source_sha256") != C.SOURCE_SHA or not _digest(consumer_sha) or not before.get("inventory") is Dictionary or not before.get("item_instances") is Dictionary or not before.get("references") is Dictionary:
		return {"ok":false,"error":"migration_input_unverified"}
	var inventory: Dictionary = before.inventory.duplicate(true)
	var physical: Dictionary = before.item_instances.duplicate(true)
	var migrated: Array[String] = []
	var held: Array[Dictionary] = []
	var bases: Dictionary = {}
	var retry: bool = false
	for key: Variant in before.item_instances:
		var value: Variant = before.item_instances[key]
		if not key is String or not value is Dictionary or not _pending(value): continue
		var authority: Dictionary = authorities.get(key,{})
		var reason: String = _reason(pack,value,key,before.references,authority,consumer_sha)
		var old_name: String = str(value.get("name",""))
		var new_name: String = str(authority.get("record",{}).get("name",""))
		if reason.is_empty():
			var old_total: int = 0
			var new_total: int = 0
			for other: Variant in before.item_instances.values():
				if not other is Dictionary: continue
				if other.get("name") == old_name:
					var amount: int = _integer(other.get("source_reward_quantity"),1)
					if amount <= 0 or old_total > 9007199254740991-amount: reason = "old_inventory_sum_mismatch"; break
					old_total += amount
				if other.get("name") == new_name:
					if _integer(other.get("source_reward_quantity",1),1) != 1 or not other.get("record") is Dictionary or not Native.same(other.record.get("source_item_class_id"),authority.record.get("source_item_class_id")) or other.record.get("source_m_native_item") != true: reason = "destination_ownership_ambiguous"; break
					new_total += 1
			if _integer(before.inventory.get(old_name),1) != old_total or _integer(before.inventory.get(new_name,0)) != new_total: reason = "inventory_sum_mismatch"
			if _integer(inventory.get(new_name,0)) < 0 or _integer(inventory.get(new_name,0)) >= 9007199254740991: reason = "destination_quantity_overflow"
		if not reason.is_empty():
			held.append({"physical_id":key,"reason":reason})
			if reason in ["native_catalog_unavailable","native_catalog_not_registered"]: retry = true
			continue
		var rebound: Dictionary = value.duplicate(true)
		rebound["name"] = new_name
		rebound["record"] = authority.record.duplicate(true)
		var basis: String = "verified_processing_proof" if value.has("equipment523_last_processing") else "legacy_exact_result_contract"
		bases[key] = basis
		rebound["equipment523_alchemy_catalog_migration"] = {"schema":1,"kind":"rebind_existing_alchemy_equipment","basis":basis,"source_sha256":C.SOURCE_SHA,"consumer_data_sha256":consumer_sha,"native_data_sha256":authority.identity.sha256,"result_id":value.record.source_reward_id,"original_record":value.record.duplicate(true)}
		physical[key] = rebound
		inventory[old_name] = int(inventory[old_name])-1
		if int(inventory[old_name]) == 0: inventory.erase(old_name)
		inventory[new_name] = int(inventory.get(new_name,0))+1
		migrated.append(key)
	return {"ok":true,"changed":not migrated.is_empty(),"before":before.duplicate(true),"overrides":{"inventory":inventory,"item_instances":physical} if not migrated.is_empty() else {},"migrated_ids":migrated,"migration_basis":bases,"held":held,"deferred_reasons":held.duplicate(true),"retry_when_catalog_available":retry}

static func stage(world: Node, pack: Dictionary, consumer_sha: String) -> Dictionary:
	var before: Dictionary = snapshot(world)
	var authorities: Dictionary = {}
	if ResourceLoader.exists(OWNER_PATH):
		var owner: Variant = load(OWNER_PATH)
		var ready: bool = owner != null
		for method: String in ["pack_identity","definition_id","expected_variant","equipment"]:
			if owner == null or not owner.has_method(method): ready = false
		if ready:
			var identity: Dictionary = owner.pack_identity()
			var by_source: Dictionary = {}
			for candidate: Variant in before.catalog:
				if not candidate is Dictionary or candidate.get("source_m_native_item") != true: continue
				var source_id: int = _integer(candidate.get("source_item_class_id"),1)
				if source_id <= 0: continue
				if not by_source.has(source_id): by_source[source_id] = []
				by_source[source_id].append(candidate)
			var resolved: Dictionary = {}
			for key: Variant in before.item_instances:
				var value: Variant = before.item_instances[key]
				if not key is String or not value is Dictionary or not _pending(value): continue
				var id: int = _integer(value.record.get("source_item_class_id"),1)
				if resolved.has(id): authorities[key] = resolved[id]; continue
				if identity.is_empty(): continue
				var definition: Dictionary = owner.definition_id(str(id)) if id > 0 else {}
				if definition.is_empty(): continue
				var record: Dictionary = owner.expected_variant(definition.get("native_record",{}),{"source_bless_raw":1}) if not definition.is_empty() else {}
				var registered: bool = false
				for candidate: Dictionary in by_source.get(id,[]):
					if not Native.validate_identity(pack,candidate,definition,record,identity,bool(owner.equipment(record))).is_empty(): registered = true
				authorities[key] = {"record":record,"definition":definition,"expected":record,"identity":identity,"equipment":bool(owner.equipment(record)),"registered":registered}
				resolved[id] = authorities[key]
	return stage_snapshot(pack,before,authorities,consumer_sha)

static func current(world: Node, candidate: Dictionary) -> bool:
	if candidate.get("ok",false) != true or not Native.same(snapshot(world),candidate.get("before")): return false
	if not ResourceLoader.exists(OWNER_PATH): return not candidate.get("changed",false)
	var owner: Variant = load(OWNER_PATH)
	if owner == null or not owner.has_method("pack_identity"): return false
	var identity: Dictionary = owner.pack_identity()
	for id: String in candidate.get("migrated_ids",[]):
		if candidate.overrides.item_instances[id].equipment523_alchemy_catalog_migration.native_data_sha256 != identity.get("sha256"): return false
	return true
