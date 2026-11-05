extends RefCounted
## Optional original item markers only. No ownership/equipment/enhancement
## interpreter, persistent record schema, text formatter or pixel lookup.
const MEMBER="UI/CommonUi/Common_Slot.csb"
const SHA256="b0153e2324de4789e3a5f1d09030f370ed109583e893247656bee5affa3520d6"
const EQUIPPED=8328
const LOCKED=7304

static func build(bag: Object, entry: Dictionary) -> Dictionary:
	var offsets: Array[int]=[]
	var bindings: Dictionary={}
	var provenance: Dictionary={}
	var unresolved: Array=[]
	var reference: Variant=entry.get("reference")
	if not is_instance_valid(bag):return {"ok":false,"code":"source_inventory_marker_existing_bag_required"}
	if not reference is String or reference.is_empty():return {"ok":false,"code":"source_inventory_marker_exact_owned_reference_required"}
	# Source Sp_Left_Top is Icn_Slot_Equip.png at original (-33,21).
	# The same owner method renders the existing bag's equipped state and
	# already distinguishes physical instances and worn ammunition.
	if bag.has_method("_is_item_equipped"):
		var equipped: Variant=bag.call("_is_item_equipped",reference)
		if equipped is bool:
			offsets.append(EQUIPPED)
			bindings[EQUIPPED]={"visible":equipped}
			provenance[EQUIPPED]={"reference":reference,"owner_method":"lineage_inventory_ui._is_item_equipped(reference)","owner_value":equipped,"source_name":"Sp_Left_Top","source_asset":"Icn_Slot_Equip.png","source_position":Vector2(-33,21)}
		else:unresolved.append({"marker":"equipped","offset":EQUIPPED,"reason":"existing owner method did not supply a boolean"})
	else:unresolved.append({"marker":"equipped","offset":EQUIPPED,"reason":"existing _is_item_equipped method unavailable"})
	# Source Sp_Left_Bottom is Icn_Slot_Lock.png at original (-33,-33).
	# This exact opaque-reference lookup is the existing reusable slot's
	# InventoryLocked producer. It is not the separate Nd_Lock slot effect.
	var state: Variant=bag.get("character_state")
	var locks: Variant=state.get("item_locks") if state is Dictionary else null
	if locks is Dictionary:
		var raw_locked: Variant=locks.get(reference,false)
		var locked: bool=bool(raw_locked)
		offsets.append(LOCKED)
		bindings[LOCKED]={"visible":locked}
		provenance[LOCKED]={"reference":reference,"owner_field":"character_state.item_locks[reference]","owner_producer":"renewal_inventory._bind_reusable_slot InventoryLocked.visible","owner_value":locked,"source_name":"Sp_Left_Bottom","source_asset":"Icn_Slot_Lock.png","source_position":Vector2(-33,-33)}
	else:unresolved.append({"marker":"locked","offset":LOCKED,"reason":"existing owner item_locks map not supplied"})
	# The owner has a Level label and _enhance_level, but the original center
	# label says Test and the Img_Enchant resource is an Orim skill-slot line.
	# Neither establishes the native numeric enhancement role or its styling.
	unresolved.append({"marker":"enhancement","owner_producer":"renewal_inventory._bind_reusable_slot Level label","candidate_offsets":[6500,4760],"reason":"original enhancement-number text role not established; Label_Center is Test and Img_Enchant is Hud_Orim_SkillSlot_Line.png"})
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"reference":reference,"source_node_offsets":offsets,"bindings":bindings,"provenance":provenance,"unresolved_markers":unresolved,"partial_source_scene":true,"complete_screen_contract":false,"ownership_or_save_modified":false}
