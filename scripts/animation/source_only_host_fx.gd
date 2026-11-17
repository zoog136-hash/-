extends RefCounted
## TWILIGHT-made combat/light presentation (swing crescents, runtime glow
## halos, invented hit polygons, the generated passive light) has no original
## sprite behind it. While the 523 original-only presentation is active
## (the same rule skill_vfx.gd source_only_policy already applies to authored
## skill art) it is not drawn; original effects come only from the SP2 paths.
## Damage numbers and other text are not part of this rule.

static var _frame: int = -1
static var _player_id: int = 0
static var _value: bool = false

static func active(player: Object) -> bool:
	if not is_instance_valid(player): return false
	var frame: int = Engine.get_process_frames()
	if frame == _frame and player.get_instance_id() == _player_id: return _value
	_frame = frame
	_player_id = player.get_instance_id()
	var preview: Variant = player.get("original_source_preview")
	_value = preview is Object and is_instance_valid(preview) and (preview as Object).has_method("current523_source_only_presentation") and bool((preview as Object).call("current523_source_only_presentation"))
	return _value

## For nodes owned by the world: the world's player decides.
static func active_for_world(world: Object) -> bool:
	if not is_instance_valid(world): return false
	var player: Variant = world.get("player")
	return player is Object and active(player)
