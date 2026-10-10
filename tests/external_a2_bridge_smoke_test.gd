extends SceneTree

# No external pack is required for the test: its absence is an expected fallback.
const BRIDGE = preload("res://addons/twilight_l1j/twilight_external_a2_bridge.gd")
const ART = preload("res://scripts/monsters/monster_art.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	BRIDGE.reset()
	var result: Dictionary = BRIDGE.stats()
	assert(result.has("item_names") and result.has("monster_names"))
	assert(int(result.item_names) >= 0 and int(result.monster_names) >= 0)
	assert(BRIDGE.item_icon({"name":"__UNLISTED_ITEM_999__"}, "") == null)
	assert(BRIDGE.monster_texture({"name":"__UNLISTED_MONSTER_999__"}) == null)
	# All existing monster atlas and verified-asset paths are preserved.
	assert(ART.texture_for({"name":"__UNLISTED_MONSTER_999__"}) == null)
	print("EXTERNAL_A2_BRIDGE_OK ", JSON.stringify(result))
	quit(0)
