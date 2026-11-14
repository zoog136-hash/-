extends RefCounted
## Kill experience of a current523 original monster.
## User decision 2026-11-14: original NpcClass rows with Exp 0 (most Aden field
## monsters: rn bugbear, rn orc, wild boar ...) give 18 x NpcLevel + 30, at
## least 10, where NpcLevel is the spawn level of the original
## NpcSpawnPackNpcClassView row. Original Exp > 0 is used unchanged.
const PER_LEVEL: int = 18
const BASE: int = 30
const MINIMUM: int = 10
const POLICY: String = "USER_DECISION_20261114_EXP0_18xNPCLEVEL_PLUS30_MIN10"
const LEVEL_ORIGIN: String = "NpcSpawnPackNpcClassView.NpcLevel_explicit_context"

static func level_rule(npc_level: int) -> int:
	return maxi(MINIMUM, PER_LEVEL * npc_level + BASE)

## Experience for an original (source_m_original) monster record.
static func reward(record: Dictionary) -> int:
	var original: int = int(record.get("xp", 0))
	if original > 0: return original
	if record.get("source_m_current523_final") != true or str(record.get("source_m_level_origin", "")) != LEVEL_ORIGIN: return maxi(0, original)
	var npc_level: int = int(record.get("source_m_spawn_npc_level", record.get("lv", 0)))
	if npc_level <= 0: return maxi(0, original)
	return level_rule(npc_level)
