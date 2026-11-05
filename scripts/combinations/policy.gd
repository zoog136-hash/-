extends RefCounted
## TWILIGHT execution policy, not recovered original transaction/server rules.
static func defaults() -> Dictionary:
	return {"selection_fee_adena":0,"inventory_candidates_are_alternatives":true,"distinct_equipment_per_slot":true,"legacy_exact_catalog_bridge":true,"condition_loss":"suspend_keep_selection","regen_interval_seconds":30.0}
