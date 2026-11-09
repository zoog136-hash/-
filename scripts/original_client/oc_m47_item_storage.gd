extends RefCounted
## M47 (C04/C11/C16/C17). DESIGN_NOT_RECOVERED_API. Item-detail storage helpers that the
## package fixes with its erratum (R47): each storage vtable occupies 0x38 bytes but only six
## qword slots are callable; the seventh qword is the NEXT table's RTTI Complete Object Locator
## (DATA). Extreme int64 quantities go to binary32 in one rounding (direct conversion companion).
## The item display/filter/equip semantics beyond these points are not in this package.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

const VTABLE_STRIDE_BYTES := 0x38
const QWORD_BYTES := 8
const CALLABLE_SLOTS := 6

static func classify_slot(index: int) -> String:
	if index >= 0 and index < CALLABLE_SLOTS:
		return "CALLABLE"
	if index == CALLABLE_SLOTS:
		return "NEXT_TABLE_RTTI_COL_DATA"
	return "OUTSIDE_TABLE"

## Reading `slots_read` qwords from each of `table_count` tables at the 0x38 stride.
@warning_ignore("integer_division")
static func classify_tables(table_count: int, slots_read: int) -> Dictionary:
	var per_table: int = VTABLE_STRIDE_BYTES / QWORD_BYTES
	if slots_read > per_table or table_count < 0:
		return V.rec("VtableClassification", "M47", V.REJECTED, {"reason": "reads past the 0x38 stride or negative count"})
	var callable: int = 0
	var data_col: int = 0
	for i: int in slots_read:
		if classify_slot(i) == "CALLABLE":
			callable += table_count
		else:
			data_col += table_count
	return V.rec("VtableClassification", "M47", V.CONFIRMED, {"qwords_per_stride": per_table, "callable_methods": callable, "col_data_slots": data_col})

## R47 companion: int64 -> binary32 directly (single rounding).
static func quantity_to_f32(quantity_i64: int) -> Dictionary:
	var direct: float = V.i64_to_f32_direct(quantity_i64)
	return V.rec("QuantityF32", "M47", V.CONFIRMED, {"f32": direct, "f32_bits": "%08X" % V.f32_bits(direct),
		"via_f64_bits_contrast": "%08X" % V.f32_bits(V.i64_to_f32_via_f64(quantity_i64))})
