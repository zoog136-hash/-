extends RefCounted
## Exact ItemClass.SpriteID selection for an already admitted ground item.
## Ground dispatch remains an explicit caller contract, separate from UI icons.
const SOURCE = preload("res://scripts/resources/current523_source_bank.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")

static func fail(reason: String, reference: Dictionary = {}) -> Dictionary:
	return {"ok":false,"enabled":true,"status":"source_only_pending","reason":reason,
		"consumer":"ground_item","source_snapshot":"patch523","source_reference":reference.duplicate(true)}

static func select(original_item: Dictionary, context: Dictionary = {}, binding: Dictionary = {}) -> Dictionary:
	var reference: Dictionary = {"table":"ItemClass","row":original_item.duplicate(true),"field":"SpriteID",
		"gameplay_admission":"existing_ground_loot_owner_only; no_spawn_pickup_quantity_or_save_changes_by_visual_loader"}
	if not BANK.integer(original_item.get("ID"),1): return fail("current523_ground_complete_source_item_required",reference)
	var supplied: Dictionary = SOURCE.source_tables(context,["ItemClass"])
	if not supplied.get("ok",false):
		var pending: Dictionary = fail(str(supplied.get("reason","current523_ground_source_tables_unavailable")),reference)
		pending["source_tables_status"] = supplied.duplicate(true)
		return pending
	var native: Dictionary = supplied.by_id.get("ItemClass",{}).get(int(original_item.ID),{})
	if native.is_empty() or native != original_item: return fail("current523_ground_complete_item_definition_differs",reference)
	if not native.get("TestItem") is bool or native.TestItem != false: return fail("current523_test_ground_item_not_admitted",reference)
	if not BANK.integer(native.get("SpriteID"),1): return fail("current523_ground_source_sprite_missing",reference)
	var sprite: int = int(native.SpriteID)
	reference["original_sprite_animation_id"] = native.get("SpriteAnimationID")
	reference["caller_binding"] = binding.duplicate(true)
	# ItemClass.SpriteID is not permission to bind a same-numbered actor action.
	# Ground item sprites are declarations without SPR actions; the client's
	# no-action static branch (LineageM 1.10.22.0 auxiliary-layer analysis) draws
	# Sprite/<remapped id>-0.sp2 direction 0 picture 0 plus its 101 shadow. The
	# bank's static_pictures registry carries exactly that relationship.
	var bank_options: Dictionary = supplied.options
	var statics = BANK.new()
	var picture: Dictionary = statics.load_static(str(bank_options.manifest_path),str(bank_options.manifest_sha256),sprite)
	if picture.get("ok",false):
		return {"ok":true,"enabled":true,"status":"selected_static_picture","consumer":"ground_item","source_snapshot":"patch523",
			"source_reference":reference,"request_key":"current523:item:%d:ground" % int(native.ID),"sprite_id":sprite,
			"layers":picture.layers,"branch":picture.branch,"source_declaration":picture.source_declaration,
			"manifest_path":str(bank_options.manifest_path),"manifest_sha256":str(bank_options.manifest_sha256),
			"source_tables_sha256":supplied.source_tables_sha256}
	var pending: Dictionary = fail("current523_ground_original_member_and_renderer_role_unresolved",reference)
	pending["static_picture_status"] = picture.duplicate(true)
	pending["request_key"] = "current523:item:%d:ground" % int(native.ID)
	pending["sprite_id"] = sprite
	pending["source_tables_sha256"] = supplied.source_tables_sha256
	pending["source_bank_context"] = {"current523_source_bank":supplied.options.duplicate(true)}
	pending["source_ground_role_required"] = ["exact_ItemClass_SpriteID_to_original_member_and_frame_relationship","original_ground_renderer_role","declared_SpriteAnimationAsset_Delay_Order_if_present"]
	return pending
