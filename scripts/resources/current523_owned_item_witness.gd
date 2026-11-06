extends RefCounted
## Optional read-only source witness. Never an ownership or collection receipt.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _hash(value: Dictionary) -> String:
	return JSON.stringify(value,"",true,true).sha256_text()

static func _json_value(value: Variant,depth: int=0) -> bool:
	if depth>64:return false
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _json_value(value[key],depth+1):return false
		return true
	if value is Array:
		for entry: Variant in value:
			if not _json_value(entry,depth+1):return false
		return true
	return typeof(value) in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_STRING] or (typeof(value)==TYPE_FLOAT and is_finite(value))

static func _held(out: Dictionary,reason: String) -> Dictionary:
	out.ok=false
	out.ready_for_owner_recheck=false
	out.pending.append(reason)
	return out

# book is the actual selected patch523_rules owner, not a new temporary model.
# physical_id must be its caller's real item_instances key; this helper cannot
# prove dictionary membership, locks, custody or atomic save eligibility.
static func inspect(book: RefCounted,selected: Dictionary,physical_id: String,physical: Dictionary) -> Dictionary:
	var out: Dictionary={"schema":"twilight.current523.owned-item-source-witness.v1","ok":false,"ready_for_owner_recheck":false,"reference_only":true,"ownership_authorized":false,"collection_eligible":false,"native_collection_identity_status":"not_established_by_item_projection","physical_membership_verified":false,"row_hash_encoding":"Godot JSON.stringify sorted keys/full precision; semantic row hash, not original member byte hash","pending":[],"original":{},"admission":{},"physical":{}}
	var archive: Dictionary=SOURCE.identity()
	if archive.is_empty():return _held(out,"selected_original_archive_unavailable")
	var id: Variant=selected.get("source_item_class_id")
	if not _integer(id) or int(id)<=0:return _held(out,"explicit_native_item_class_id_required")
	var raw: Dictionary=SOURCE.row("ItemClass",int(id))
	if raw.is_empty() or raw.get("TestItem")!=false or not SOURCE.declared_exclusion("ItemClass",raw).is_empty():return _held(out,"current_nonexcluded_original_item_required")
	if selected.get("source")!="lineagem_patch523" or selected.get("source_snapshot")!="patch523" or selected.get("source_projection")!="current523_original_typed_game_dto_v1" or selected.get("source_m_native_item")!=true or selected.get("source_definition_archive")!=archive or selected.get("source_original_item")!=raw or selected.get("sourceId")!="m523:item:"+str(int(id)):return _held(out,"selected_current_native_dto_identity_mismatch")
	out["source"]=archive.duplicate(true)
	out.original={"item_class_id":int(id),"source_id":selected.sourceId,"item_class_row":raw.duplicate(true),"item_class_row_sha256":_hash(raw),"item_class_member":SOURCE.table_metadata("ItemClass"),"relations":{}}
	# Complete owned link sets, including an empty set. No inferred slot/class,
	# collection ID, enchant group meaning or whole-archive admission is added.
	for spec: Array in [["ItemEquipSlot","EquipSlotID","EquipSlot"],["ItemClassLimit","ClassID","Class"]]:
		var links: Array=[]
		for link: Dictionary in SOURCE.related(spec[0],"ItemClassID",int(id)):
			var target_id: Variant=link.get(spec[1])
			if link.get("ItemClassID")!=id or not _integer(target_id) or int(target_id)<0:return _held(out,"invalid_original_relation:"+str(spec[0]))
			var target: Dictionary=SOURCE.row(spec[2],int(target_id))
			if target.is_empty() or not SOURCE.declared_exclusion(spec[0],link).is_empty() or not SOURCE.declared_exclusion(spec[2],target).is_empty():return _held(out,"unavailable_original_relation:"+str(spec[0]))
			links.append({"link":link.duplicate(true),"target":target.duplicate(true),"link_row_sha256":_hash(link),"target_row_sha256":_hash(target)})
		out.original.relations[spec[0]]={"links":links,"link_member":SOURCE.table_metadata(spec[0]),"target_member":SOURCE.table_metadata(spec[2]),"grants_slot_or_class_permission":false}
	out["original_evidence_available"]=true
	if book==null or not book.has_method("catalog_identity_matches") or not book.has_method("identity") or not book.has_method("bless_code"):return _held(out,"actual_selected_equipment_owner_required")
	var model: Variant=book.get("data")
	var digest: Variant=book.get("digest")
	if not model is Dictionary or not model.get("items") is Dictionary or not digest is String or digest.length()!=64 or not digest.is_valid_hex_number(false):return _held(out,"selected_equipment_model_identity_required")
	var entry: Variant=model.items.get(str(int(id)))
	if not entry is Dictionary or entry.get("item_class")!=raw or not book.catalog_identity_matches(selected,str(int(id))) or book.identity({"record":selected})!=str(int(id)):return _held(out,"item_not_admitted_by_selected_equipment_model")
	var admitted: Variant=entry.get("catalog_record")
	if not admitted is Dictionary or admitted.get("source_projection")!=selected.source_projection or admitted.get("source_definition_archive")!=archive or admitted.get("source_original_item")!=raw:return _held(out,"selected_model_lacks_current_original_dto_provenance")
	var entry_snapshot: Dictionary=entry.duplicate(true)
	out.admission={"equipment_model_sha256":digest,"equipment_item_key":str(int(id)),"catalog_identity_matches":true,"model_original_item_row_matches":true}
	if physical_id.is_empty() or not physical.get("record") is Dictionary:return _held(out,"explicit_physical_key_and_pinned_record_required")
	if not _json_value(physical):return _held(out,"physical_snapshot_not_finite_json_data")
	var pinned: Dictionary=physical.record
	for key: String in ["source","source_snapshot","source_projection","source_m_native_item","source_definition_archive","source_original_item","source_item_class_id","sourceId","name"]:
		if not selected.has(key) or pinned.get(key)!=selected[key]:return _held(out,"physical_pinned_source_identity_mismatch:"+key)
	if physical.get("name")!=pinned.name or (physical.has("sourceId") and physical.sourceId!=pinned.sourceId) or (pinned.has("instance_id") and pinned.instance_id!=physical_id):return _held(out,"physical_key_or_record_identity_mismatch")
	if not book.catalog_identity_matches(pinned,str(int(id))) or book.identity(physical)!=str(int(id)):return _held(out,"physical_not_bound_to_selected_equipment_model")
	out.physical={"provided_physical_id":physical_id,"source_id":pinned.sourceId,"input_snapshot_sha256":_hash(physical),"state_scope":"mutable caller-provided physical snapshot; not an immutable grant receipt","explicit_fields":{}}
	for key: String in ["level","source_bless_code","bless_state","blessed","element","element_level"]:
		if physical.has(key):out.physical.explicit_fields[key]=physical[key].duplicate(true) if physical[key] is Dictionary or physical[key] is Array else physical[key]
	var level: Variant=physical.get("level")
	if not _integer(level) or int(level)<0:return _held(out,"explicit_physical_enchant_level_required")
	if pinned.has("enhance_level") and pinned.enhance_level!=level:return _held(out,"physical_and_pinned_enchant_level_conflict")
	var bless: Variant=physical.get("source_bless_code")
	if not _integer(bless) or int(bless) not in [1,2,3] or not pinned.has("source_bless_raw") or pinned.source_bless_raw!=bless:return _held(out,"explicit_physical_and_pinned_blessing_required")
	if book.bless_code(physical)!=int(bless):return _held(out,"current_blessing_owner_rejects_physical_state")
	var bless_row: Dictionary=SOURCE.row("ItemBlessCode",int(bless))
	if bless_row.is_empty() or not SOURCE.declared_exclusion("ItemBlessCode",bless_row).is_empty():return _held(out,"original_blessing_code_row_unavailable")
	out.physical["enchant_level"]=int(level)
	out.physical["bless_code"]=int(bless)
	out.physical["bless_code_row"]=bless_row.duplicate(true)
	out.physical["bless_code_row_sha256"]=_hash(bless_row)
	out.physical["bless_code_member"]=SOURCE.table_metadata("ItemBlessCode")
	# Recheck selection/source after read-only projection; do not adopt a model.
	if SOURCE.identity()!=archive or book.get("digest")!=digest or book.get("data")!=model or model.items.get(str(int(id)))!=entry_snapshot or not book.catalog_identity_matches(selected,str(int(id))):return _held(out,"source_or_selected_model_changed")
	out.ready_for_owner_recheck=true
	out.ok=true
	return out
