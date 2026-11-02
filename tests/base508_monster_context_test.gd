extends SceneTree
const CONTEXT = preload("res://scripts/monsters/base508_monster_context.gd")
var errors: Array[String] = []
func check(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
func _initialize() -> void:
	var slime: Dictionary = CONTEXT.context(90, 762, 558)
	check(bool(slime.ok), "valid slime source context did not join")
	if bool(slime.ok):
		check(int(slime.npc.Sprite) == 31, "NpcClass Sprite must bind exact original ID")
		check(int(slime.land.ID) == 4 and str(slime.land.AssetPath) == "Aden/", "LandID was confused with AssetPath")
		check(int(slime.spawn_view.NpcLevel) == 4, "level must come from this spawn view")
	var another: Dictionary = CONTEXT.context(90, 544562, 200232)
	check(bool(another.ok) and int(another.get("spawn_view", {}).get("NpcLevel", -1)) == 1, "same NPC has a distinct level in another exact spawn context")
	check(CONTEXT.context(90, 766, 558).get("reason") == "spawn_view_npc_mismatch", "wrong variant context accepted")
	check(CONTEXT.context(90, 762, 87).get("reason") == "territory_link_pack_mismatch", "wrong source territory pack accepted")
	check(not bool(CONTEXT.context(999999999, 762, 558).ok), "non-source NPC accepted")
	var curtz: Dictionary = CONTEXT.context(60303, 3520, 1410)
	check(bool(curtz.ok) and int(curtz.get("spawn_view", {}).get("NpcLevel", -1)) == 83, "field-boss renewal Curtz context must retain level 83")
	if bool(curtz.ok):
		check(int(curtz.land.ID) == 0 and int(curtz.territory.ID) == 142, "boss land/territory mismatch")
	var local: Dictionary = {"sourceId":"45001", "source_npc_id":"45001", "visual":{"atlas":0}, "image_path":"res://old.png", "drop":["invented source loot"], "gold":9999, "lv":999, "atk":8, "source_m_spawn_npc_level":999}
	var record: Dictionary = CONTEXT.record(90, 762, 558, local)
	check(not record.is_empty(), "valid source runtime record missing")
	if not record.is_empty():
		check(int(record.hp) == 30 and int(record.mp) == 13 and int(record.ac) == -3 and int(record.mr) == 7 and int(record.xp) == 0, "native zero XP or native stats changed")
		check(int(record.lv) == 4, "unverified supplied level overrode source spawn context")
		check(str(record.sourceId).begins_with("lineagem_base508:npc:90:"), "legacy source ID reused")
		check(not record.has("visual") and not record.has("image_path") and not record.has("source_npc_id"), "old appearance/source3 identity leaked")
		check(record.drop.is_empty() and int(record.gold) == 0 and bool(record.catalog_only), "loot or world-spawn activation was invented")
		check(int(local.lv) == 999 and int(local.gold) == 9999, "caller/save dictionary mutated")
	check(CONTEXT.record(90, 766, 558).is_empty(), "invalid join produced a runtime actor")
	var sprite: Dictionary = CONTEXT.motion(31)
	check(sprite.get("status", "") == "source_declaration_resolved", "slime motion declaration not linked")
	check(not sprite.get("actions", {}).is_empty(), "original actions missing")
	check(CONTEXT.map_bindings().is_empty(), "an unreviewed world map binding was activated")
	if errors.is_empty():
		print("BASE508_MONSTER_CONTEXT_OK ", JSON.stringify(CONTEXT.counts()))
		quit(0)
	else:
		for message: String in errors: push_error(message)
		quit(1)
