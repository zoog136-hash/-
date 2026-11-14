extends SceneTree
## User decision 2026-11-14: original Exp 0 field monsters give
## 18 x NpcLevel + 30 (min 10); original Exp > 0 stays. Synthetic records.
const XP = preload("res://scripts/monsters/current523_kill_experience.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func rec(xp: int, level: int, final: bool = true, origin: String = XP.LEVEL_ORIGIN) -> Dictionary:
	return {"xp":xp, "lv":level, "source_m_spawn_npc_level":level, "source_m_current523_final":final, "source_m_level_origin":origin}

func _initialize() -> void:
	check(XP.reward(rec(0, 3)) == 84, "Lv.3 Exp 0 -> 84: %d" % XP.reward(rec(0, 3)))
	check(XP.reward(rec(0, 45)) == 840, "Lv.45 Exp 0 -> 840")
	check(XP.reward(rec(0, 1)) == 48, "Lv.1 Exp 0 -> 48")
	check(XP.level_rule(-5) == 10, "minimum 10")
	check(XP.reward(rec(1200, 45)) == 1200, "original Exp > 0 unchanged")
	check(XP.reward(rec(1, 30)) == 1, "original Exp 1 unchanged")
	check(XP.reward(rec(0, 3, false)) == 0, "non-current523 record not changed")
	check(XP.reward(rec(0, 3, true, "local_compatibility_only_native_level_unknown")) == 0, "unknown spawn level not guessed")
	check(XP.reward(rec(0, 0)) == 0, "level 0 not guessed")
	print("CURRENT523_KILL_EXPERIENCE_RESULT ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
