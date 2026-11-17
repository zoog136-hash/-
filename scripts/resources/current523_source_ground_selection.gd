extends RefCounted
## Exact ItemClass.SpriteID selection for an already admitted ground item.
## Ground dispatch remains an explicit caller contract, separate from UI icons.
const SOURCE = preload("res://scripts/resources/current523_source_bank.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const CATEGORY = preload("res://scripts/loot/current523_ground_category_sprite.gd")

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
	var native: Dictionary = SOURCE.table_row("ItemClass",int(original_item.ID))
	if native.is_empty() or native != original_item: return fail("current523_ground_complete_item_definition_differs",reference)
	if not native.get("TestItem") is bool or native.TestItem != false: return fail("current523_test_ground_item_not_admitted",reference)
	var sprite: int = int(native.SpriteID) if BANK.integer(native.get("SpriteID"),1) else 0
	reference["original_sprite_animation_id"] = native.get("SpriteAnimationID")
	reference["caller_binding"] = binding.duplicate(true)
	# ItemClass.SpriteID is not permission to bind a same-numbered actor action.
	# Ground item sprites are declarations without SPR actions; the client's
	# no-action static branch (LineageM 1.10.22.0 auxiliary-layer analysis) draws
	# Sprite/<remapped id>-0.sp2 direction 0 picture 0 plus its 101 shadow. The
	# bank's static_pictures registry carries exactly that relationship.
	var bank_options: Dictionary = supplied.options
	var path: String = str(bank_options.manifest_path)
	var sha: String = str(bank_options.manifest_sha256)
	var statics = BANK.new()
	var kind: String = statics.ground_kind(path,sha,sprite)
	var picture: Dictionary = {}
	var basis: String = "ItemClass.SpriteID"
	var selected_sprite: int = sprite
	if kind == "static": picture = statics.load_static(path,sha,sprite)
	elif kind == "still": picture = statics.load_ground_still(path,sha,sprite)
	elif kind != "action3":
		# 원본에 없으면 근사: the same original category's floor sprite.
		var approx: Dictionary = CATEGORY.select(native,path+"|"+sha,func(id: int) -> bool: return statics.ground_kind(path,sha,id) == "static")
		reference["category_approximation"] = approx.duplicate(true)
		if approx.get("ok",false):
			selected_sprite = int(approx.sprite_id)
			basis = str(approx.basis)
			picture = statics.load_static(path,sha,selected_sprite)
		else: picture = {"ok":false,"error":str(approx.get("reason","")),"own_sprite_kind":kind}
	if kind == "still": basis = "approx_static_branch_of_declared_action_body"
	if picture.get("ok",false):
		return {"ok":true,"enabled":true,"status":"selected_static_picture","consumer":"ground_item","source_snapshot":"patch523",
			"source_reference":reference,"request_key":"current523:item:%d:ground" % int(native.ID),"sprite_id":selected_sprite,"own_sprite_id":sprite,"basis":basis,
			"layers":picture.layers,"branch":picture.branch,"source_declaration":picture.source_declaration,
			"manifest_path":path,"manifest_sha256":sha,
			"source_tables_sha256":supplied.source_tables_sha256}
	if sprite <= 0 and kind != "action3":
		var empty: Dictionary = fail("current523_ground_source_sprite_missing",reference)
		empty["static_picture_status"] = picture.duplicate(true)
		return empty
	var pending: Dictionary = fail("current523_ground_original_member_and_renderer_role_unresolved",reference)
	pending["static_picture_status"] = picture.duplicate(true)
	pending["request_key"] = "current523:item:%d:ground" % int(native.ID)
	pending["sprite_id"] = sprite
	pending["source_tables_sha256"] = supplied.source_tables_sha256
	pending["source_bank_context"] = {"current523_source_bank":supplied.options.duplicate(true)}
	pending["source_ground_role_required"] = ["exact_ItemClass_SpriteID_to_original_member_and_frame_relationship","original_ground_renderer_role","declared_SpriteAnimationAsset_Delay_Order_if_present"]
	return pending
