extends RefCounted
## Optional PR217 source compositor. No name aliases or replacement artwork.
## Placement follows the existing local hit integration, not recovered server timing.
const FIELDS={"cast":"CasterEffectSpriteID","effect":"EffectSpriteID","impact":"EffectExplosionSpriteID","success":"SuccessEffectSpriteID"}
var last_result: Dictionary={}
var partial_effects: Node2D

static func property(object: Object,key: String,fallback: Variant=null) -> Variant:
	if object==null or not is_instance_valid(object):return fallback
	for entry: Dictionary in object.get_property_list():
		if str(entry.name)==key:return object.get(key)
	return fallback

func emit_spell(world: Node,spell: Dictionary,target: Node) -> Dictionary:
	var requested: Array[String]=[]
	for stage: String in FIELDS:
		if int(spell.get(FIELDS[stage],0))>0:requested.append(stage)
	last_result={"spell_id":int(spell.get("ID",0)),"requested":requested,"played":[],"unavailable":[],"status":"unavailable","source_visual_complete":false,"incomplete_sources":[],"input":"current523_source_bank_only"}
	var player: Node=property(world,"player")
	var preview: Node=property(player,"original_source_preview")
	if not player is Node2D or not target is Node2D or preview==null:
		last_result.reason="current523_source_compositor_unavailable";return last_result.duplicate(true)
	var facing: int=int(property(property(player,"motion"),"facing8",0))
	var caster_point: Vector2=player.global_position;var impact_point: Vector2=target.global_position
	if not is_instance_valid(partial_effects):
		partial_effects=preload("res://scripts/cards/skill_awakening_partial_effects.gd").new()
		partial_effects.name="CardSkillCurrentSourceEffects";world.add_child(partial_effects)
	for stage: String in requested:
		var point: Vector2=caster_point if stage=="cast" else impact_point
		var played: bool=partial_effects.play_current_source(preview,int(spell[FIELDS[stage]]),facing,point)
		last_result["played" if played else "unavailable"].append(stage)
		if not played:last_result.incomplete_sources.append({"stage":stage,"sprite_id":int(spell[FIELDS[stage]]),"status":"current_source_effect_action_binding_unavailable"})
	last_result.status="played" if not requested.is_empty() and last_result.played.size()==requested.size() else "partial" if not last_result.played.is_empty() else "unavailable"
	last_result.source_visual_complete=last_result.status=="played" and last_result.incomplete_sources.is_empty()
	return last_result.duplicate(true)
