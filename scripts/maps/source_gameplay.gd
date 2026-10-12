extends RefCounted
## Explicit offline adaptations, never presented as original server behavior.
## A3 spawnlist_boss row 21 supplies the Kurtz area, but isYN is false.
## TWILIGHT enables one local encounter there with its existing combat record.
static func apply(field: OriginalPlayableField) -> void:
	if int(field.definition.source_map_id) != 4: return
	var box := Rect2i(32638-40,32601-40,81,81)
	var center: Vector2 = field.coordinates.to_world(Vector2(32638,32601))
	field.data.monster_spawn.push_front({"id":"offline_kurtz","boss_id":"offline_kurtz",
		"mode":"boss","max_count":1,"monster_types":["커츠"],"source_rect":box,
		"rect":[center.x-1944,center.y-972,3888,1944],"respawn_time":900.0,
		"roaming_radius":160.0,"provenance":"TWILIGHT_OFFLINE_OVERRIDE",
		"variants":{"커츠":{"name":"커츠 · 임시 오프라인 보스"}}})
	field.data["adaptations"] = "보스 출현·전투 수치와 NPC 상점은 TWILIGHT 임시 연결"
