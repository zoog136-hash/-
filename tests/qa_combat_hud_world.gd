extends TwilightWorld

## Test-only counters: production combat keeps its original stat formulas.
var full_hud_refreshes: int = 0
var equipment_syncs: int = 0
var character_snapshots: int = 0
var max_hp_queries: int = 0
var max_mp_queries: int = 0
var force_monster_hits: bool = false

func reset_hud_counts() -> void:
	full_hud_refreshes = 0
	equipment_syncs = 0
	character_snapshots = 0
	max_hp_queries = 0
	max_mp_queries = 0

func hud_counts() -> Dictionary:
	return {"full_hud_refreshes":full_hud_refreshes, "equipment_syncs":equipment_syncs,
		"character_snapshots":character_snapshots, "max_hp_queries":max_hp_queries, "max_mp_queries":max_mp_queries}

func _update_hud() -> void:
	full_hud_refreshes += 1
	super._update_hud()

func _sync_item_instances() -> void:
	equipment_syncs += 1
	super._sync_item_instances()

func _character_stats_snapshot() -> Dictionary:
	character_snapshots += 1
	return super._character_stats_snapshot()

func _effective_max_hp() -> int:
	max_hp_queries += 1
	return super._effective_max_hp()

func _effective_max_mp() -> int:
	max_mp_queries += 1
	return super._effective_max_mp()

func _roll_monster_hit(attacker: TwilightMonster, attack_type: String = "melee") -> bool:
	return true if force_monster_hits else super._roll_monster_hit(attacker, attack_type)
