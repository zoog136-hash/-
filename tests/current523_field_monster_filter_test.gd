extends SceneTree
## Aden field monsters in the original NpcClass mostly carry Exp 0
## ("rn bugbear", "rn orc", wild boar). They are hunting targets and must
## spawn; passive villagers and bracket-labelled staged actors stay out.
## Synthetic rows only.
const SPAWNS = preload("res://scripts/maps/current523_source_spawns.gd")
var failures: Array[String] = []

class FakeCatalog extends RefCounted:
	func context_rows(table: String) -> Array:
		if table != "NpcCategory": return []
		return [{"ID":1,"Name":"Npc","IsAttackable":true}, {"ID":2,"Name":"Orc","IsAttackable":true},
			{"ID":15,"Name":"Guard","IsAttackable":true}, {"ID":20,"Name":"torch","IsAttackable":false}]

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func npc(name: String, category: int, exp: int, tendency: int, test: bool = false) -> Dictionary:
	return {"Name":name, "Category":category, "Exp":exp, "Tendency":tendency, "TestNPC":test}

func _initialize() -> void:
	var catalog := FakeCatalog.new()
	check(SPAWNS._enemy(catalog, npc("rn bugbear", 1, 0, 3)), "Exp 0 field monster spawns")
	check(SPAWNS._enemy(catalog, npc("rn orc", 2, 0, 3)), "Exp 0 orc spawns")
	check(SPAWNS._enemy(catalog, npc("wild boar", 1, 0, 3)), "Exp 0 animal spawns")
	check(SPAWNS._enemy(catalog, npc("dark knight", 1, 120, 2)), "Exp > 0 monster spawns")
	check(not SPAWNS._enemy(catalog, npc("north orc peasant", 2, 0, 1)), "passive villager stays out")
	check(not SPAWNS._enemy(catalog, npc("[공성전][군단소환] 엘모어 병사", 1, 0, 2)), "staged siege actor stays out")
	check(not SPAWNS._enemy(catalog, npc("[경비병] guard", 15, 1, 3)), "guards stay out")
	check(not SPAWNS._enemy(catalog, npc("wall torch", 20, 0, 0)), "torches stay out")
	check(not SPAWNS._enemy(catalog, npc("rn test", 1, 0, 3, true)), "test NPC stays out")
	check(not SPAWNS._enemy(catalog, {}), "missing class stays out")
	print("CURRENT523_FIELD_MONSTER_FILTER_RESULT ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
