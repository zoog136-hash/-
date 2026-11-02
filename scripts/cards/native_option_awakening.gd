extends RefCounted
const DATA = preload("res://data/cards/base508_option_awakening.json")
const Native = preload("res://scripts/cards/native_collection_rules.gd")
static func adapt(legacy: Dictionary, catalog: Dictionary) -> Dictionary:
	if not Native.accepts_catalog(catalog): return legacy
	var result: Dictionary=legacy.duplicate(true)
	result.native_mode=true
	result.native_server_limits=DATA.data.source_server_limits
	result.cards.append_array(DATA.data.definitions)
	return result
