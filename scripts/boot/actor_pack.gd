extends Node
## Retired: the separate actor art pack (twilight_actor_pack.pck, 3.35 GB of
## pre-523 actor sheets under res://assets/actors/).
##
## With the 523 resource pack installed, the player, monsters, NPCs and cards
## draw from the original 523 SP2 bank, so the APK no longer ships or asks
## for the old pack. A copy installed by an earlier build is deleted at start
## to give its storage back; nothing else is touched.
const PACK_PATH := "user://twilight_actor_pack.pck"

var mounted: bool = false
## Kept for callers that ask; the old pack is never required.
var needed: bool = false
var removed: bool = false

func _init() -> void:
	if not OS.has_feature("template"): return
	if FileAccess.file_exists(PACK_PATH):
		removed = DirAccess.remove_absolute(PACK_PATH) == OK
