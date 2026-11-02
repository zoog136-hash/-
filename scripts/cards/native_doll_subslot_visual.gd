extends Node2D
## Reuses PR217's exact source actor compositor; never synthesizes a fallback.
const Cards=preload("res://scripts/card_draw_fusion.gd")
var source_aura: Node2D
var aura_signature: String=""
var actor: Node2D
var binding: String=""
var status: String="inactive"
func clear() -> void:
	if is_instance_valid(source_aura):source_aura.deactivate()
	aura_signature=""
	if is_instance_valid(actor):actor.clear()
	binding="";status="inactive";hide()
func update_source(delta: float,world: Node,record: Dictionary) -> void:
	if record.is_empty() or int(world.hp)<=0:clear();return
	var path: String="res://scripts/animation/original_source_preview.gd"
	if not ResourceLoader.exists(path):status="source_engine_unavailable";hide();return
	var player: Node2D=world.player
	var manifest: String="";var context: Dictionary={}
	for property: Dictionary in player.get_property_list():
		if property.name=="original_source_manifest":manifest=str(player.get(property.name))
		if property.name=="source_visual_context":context=player.get(property.name)
	var key: String=Cards.card_id(record)+"|"+manifest+"|"+str(hash(context))
	if key!=binding:
		if is_instance_valid(source_aura):source_aura.deactivate()
		aura_signature=""
		if not is_instance_valid(actor):actor=load(path).new();add_child(actor)
		actor.clear();binding=key
		if not actor.configure("doll:"+str(record.sourceId),manifest,context):status="source_asset_pending";hide();return
		global_position=player.global_position+Vector2(54,24)
		status="source_native"
	if status!="source_native":return
	show()
	var previous: Vector2=global_position
	var point: Vector2=player.global_position+Vector2(54,24)
	global_position=point if previous.distance_to(point)>900 else previous.move_toward(point,minf(maxf(300,player.velocity.length()*1.35),previous.distance_to(point)*7)*maxf(0,delta))
	sync_existing_source_aura(world,record,manifest)
	actor.advance_source(delta,"walk" if previous.distance_to(global_position)>.1 else "idle",player.motion.facing8,player.motion.sequence,false)

func sync_existing_source_aura(world: Node,record: Dictionary,manifest: String) -> void:
	var path: String="res://scripts/animation/source_awakening_aura.gd"
	if not ResourceLoader.exists(path):return
	var awake: bool=world.option_awakening.source_subslot_visual_awakened(record)
	var key: String=binding+":"+str(awake)+":"+str(hash(world.presentation_settings))
	if key==aura_signature:return
	aura_signature=key
	if not awake and not is_instance_valid(source_aura):return
	if not is_instance_valid(source_aura):source_aura=load(path).new();add_child(source_aura)
	source_aura.configure("마법인형",record,awake,actor,manifest,world.presentation_settings)
