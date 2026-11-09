extends RefCounted
## M47/M49/M51/M53/M54/M62/M63/M64/M65/M80. DESIGN_NOT_RECOVERED_API. Corrected address and
## classification facts from the final QA errata (rules R47, R49, R51, R53, R53_COUNT, R54, R62,
## R63, R64, R65, R80). These are evidence locators for wiring and review; they are not callable
## original functions. A superseded (wrong) value is rejected, never silently mapped.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

## EXE RVAs unless noted "DLL" or "E" (EXE VA-style address used by the QA note).
const FACTS := {
	"R49_helper_cfg": {"module": "M49", "transfer_source_rows": 2631, "must_include_source_rva": "01CBFC5F", "kind": "REX_INDIRECT_TAIL", "ref": "S0696"},
	"R51_cast": {"module": "M51", "cast": "Node->cocos2d::ui::Button", "rtti_data_rva": "054F7668", "discarded_indirect_cfg_targets": 214, "ref": "S0359"},
	"R53_int3": {"module": "M53", "no_return_call_terminal_rva": "021F7A90", "leaf_context_int3_bytes": 47, "superseded_count": 46, "ref": "S0378/S0701"},
	"R54_ack": {"module": "M54", "ack_constant_rvas": ["0443B850", "0443B860", "0443B880"], "bytes_each": 16, "kind": "DATA", "ref": "S0389"},
	"R62_copy_call": {"module": "M62", "lea_rva": "02135799", "virtual0_copy_call_rva": "0213579E", "ref": "S0471"},
	"R63_entry": {"module": "M63", "entry_rva": "02547760", "internal_locator_rva": "02547770", "movsxd_rva": "01EC575C", "ref": "S0481"},
	"R64_switch": {"module": "M64", "parser_pdata": ["005058B0", "00506120"], "switch_table": ["005060D4", "00506120"], "ref": "S0494"},
	"R65_ctor": {"module": "M65", "ctor_pdata": ["024C39F0", "024C3A16"], "ref": "S0507"},
	"R80_arrow_tag": {"module": "M80", "arrow_tag_write": "E0330B7BC", "superseded": "E0330B7BB", "dot_tag_write": "E0330B531", "tag_value": 1234567, "ref": "S0685"},
}

## R54: the three addresses are 16-byte ACK constants (DATA), not getter functions.
static func classify_rva(rva: String) -> Dictionary:
	var key: String = rva.to_upper()
	if key in FACTS.R54_ack.ack_constant_rvas:
		return V.rec("LocatorClass", "M54", V.CONFIRMED, {"rva": key, "kind": "DATA_ACK_CONSTANT_16B", "callable": false})
	if key == FACTS.R62_copy_call.lea_rva:
		return V.rec("LocatorClass", "M62", V.CONFIRMED, {"rva": key, "kind": "LEA_RDX_RSP_40", "callable": false})
	if key == FACTS.R62_copy_call.virtual0_copy_call_rva:
		return V.rec("LocatorClass", "M62", V.CONFIRMED, {"rva": key, "kind": "CALL_QWORD_PTR_RAX_VIRTUAL0_COPY", "callable": false})
	if key == FACTS.R63_entry.entry_rva:
		return V.rec("LocatorClass", "M63", V.CONFIRMED, {"rva": key, "kind": "FUNCTION_ENTRY", "callable": true})
	if key == FACTS.R63_entry.internal_locator_rva:
		return V.rec("LocatorClass", "M63", V.CONFIRMED, {"rva": key, "kind": "INTERNAL_LOCATOR_NOT_ENTRY", "callable": false})
	if key == FACTS.R80_arrow_tag.superseded:
		return V.rec("LocatorClass", "M80", V.REJECTED, {"rva": key, "kind": "SUPERSEDED_NOT_INSTRUCTION_START", "use_instead": FACTS.R80_arrow_tag.arrow_tag_write})
	if key == FACTS.R80_arrow_tag.arrow_tag_write:
		return V.rec("LocatorClass", "M80", V.CONFIRMED, {"rva": key, "kind": "UNGUARDED_TAG_WRITE_MOV_RSI28_1234567"})
	return V.rec("LocatorClass", "", V.UNKNOWN, {"rva": key, "kind": "NOT_IN_CORRECTED_FACTS"})

## R53: INT3 after RET or an unconditional JMP is padding; INT3 after a no-return CALL is a code
## terminal that stays in the CFG.
static func classify_int3(previous_instruction: String) -> String:
	match previous_instruction:
		"RET", "JMP_UNCONDITIONAL":
			return "PADDING"
		"CALL_NO_RETURN":
			return "CODE_TERMINAL_KEEP_IN_CFG"
	return V.UNKNOWN

## R64: an address inside a function's .pdata range can still be DATA (switch table). Range ends
## are exclusive.
static func classify_in_pdata(rva: int, pdata_begin: int, pdata_end: int, data_ranges: Array) -> Dictionary:
	var inside: bool = rva >= pdata_begin and rva < pdata_end
	for r: Variant in data_ranges:
		if rva >= int(r[0]) and rva < int(r[1]):
			return {"inside_pdata": inside, "kind": "DATA", "pdata_implies_code": false}
	return {"inside_pdata": inside, "kind": "CODE_OR_UNCLASSIFIED" if inside else "OUTSIDE", "pdata_implies_code": false}

## R49: a helper CFG inventory is complete only when it carries the corrected source row.
static func helper_cfg_inventory(source_rvas: Array) -> Dictionary:
	var fact: Dictionary = FACTS.R49_helper_cfg
	var has_tail: bool = fact.must_include_source_rva in source_rvas
	var ok: bool = has_tail and source_rvas.size() == int(fact.transfer_source_rows)
	return V.rec("HelperCfgInventory", "M49", V.CONFIRMED if ok else V.REJECTED, {"rows": source_rvas.size(), "includes_01CBFC5F": has_tail, "complete": ok})
