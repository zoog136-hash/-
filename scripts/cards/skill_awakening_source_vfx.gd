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
	last_result={"spell_id":int(spell.get("ID",0)),"requested":requested,"played":[],"unavailable":[],"status":"unavailable","source_visual_complete":false,"incomplete_sources":[]}
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
	var readiness: Dictionary={}
	if FileAccess.file_exists(manifest):
		var index: Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest))
		if index is Dictionary:readiness=index.get("card_skill_effect_readiness",{})
	# PR217 keeps completed one-shots as freed Object handles until its next emit.
	# Prune without a typed lambda: Godot cannot cast a freed handle to Node2D.
	var overlays: Variant=property(preview,"_overlay_nodes")
	if overlays is Array:
		var valid: Array[Node2D]=[]
		for overlay: Variant in overlays:
			if is_instance_valid(overlay) and overlay is Node2D:valid.append(overlay)
		preview.set("_overlay_nodes",valid)
	for stage: String in requested:
		var point: Vector2=caster_point if stage=="cast" else impact_point
		var played: bool=preview.notify_source_spell_event(int(spell.ID),stage,point,facing,manifest)
		if not played:
			# Partial SP2 direction domains cannot pass the actor compositor's all8
			# guard. Reuse its source blend/clock policy in a bounded sparse adapter.
			if not is_instance_valid(partial_effects):
				partial_effects=preload("res://scripts/cards/skill_awakening_partial_effects.gd").new()
				partial_effects.name="CardSkillPartialSourceEffects";world.add_child(partial_effects)
			played=partial_effects.play_source(manifest,int(spell[FIELDS[stage]]),facing,point)
		last_result["played" if played else "unavailable"].append(stage)
		var declaration: Dictionary=readiness.get(str(int(spell[FIELDS[stage]])),{})
		if not declaration.is_empty() and not bool(declaration.get("source_visual_complete",false)):
			last_result.incomplete_sources.append({"stage":stage,"sprite_id":int(spell[FIELDS[stage]]),"status":str(declaration.status)})
	last_result.status="played" if last_result.played.size()==requested.size() else "partial" if not last_result.played.is_empty() else "unavailable"
	last_result.source_visual_complete=last_result.status=="played" and last_result.incomplete_sources.is_empty()
	return last_result.duplicate(true)
