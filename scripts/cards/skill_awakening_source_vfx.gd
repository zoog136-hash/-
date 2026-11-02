extends RefCounted
## Optional PR217 source compositor. No name aliases or replacement artwork.
## Placement follows the existing local hit integration, not recovered server timing.
const FIELDS={"cast":"CasterEffectSpriteID","effect":"EffectSpriteID","impact":"EffectExplosionSpriteID","success":"SuccessEffectSpriteID"}
var last_result: Dictionary={}

static func property(object: Object,key: String,fallback: Variant=null) -> Variant:
	if object==null or not is_instance_valid(object):return fallback
	for entry: Dictionary in object.get_property_list():
		if str(entry.name)==key:return object.get(key)
	return fallback

func emit_spell(world: Node,spell: Dictionary,target: Node) -> Dictionary:
	var requested: Array[String]=[]
	for stage: String in FIELDS:
		if int(spell.get(FIELDS[stage],0))>0:requested.append(stage)
	last_result={"spell_id":int(spell.get("ID",0)),"requested":requested,"played":[],"unavailable":[],"status":"unavailable"}
	var player: Node=property(world,"player")
	var preview: Node=property(player,"original_source_preview")
	if not player is Node2D or not target is Node2D or preview==null or not preview.has_method("notify_source_spell_event"):
		last_result.reason="source_compositor_unavailable";return last_result.duplicate(true)
	var manifest: String=str(property(player,"original_source_manifest",""))
	if manifest.is_empty():
		last_result.reason="source_manifest_unavailable";return last_result.duplicate(true)
	var facing: int=int(property(property(player,"motion"),"facing8",0))
	# Copy points before damage can kill/recycle the target. No delayed target reference.
	var caster_point: Vector2=player.global_position
	var impact_point: Vector2=target.global_position
	for stage: String in requested:
		var point: Vector2=caster_point if stage=="cast" else impact_point
		var played: bool=preview.notify_source_spell_event(int(spell.ID),stage,point,facing,manifest)
		last_result["played" if played else "unavailable"].append(stage)
	last_result.status="played" if last_result.played.size()==requested.size() else "partial" if not last_result.played.is_empty() else "unavailable"
	return last_result.duplicate(true)
