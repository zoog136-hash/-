extends Node2D
## Reuses PR217's exact source actor compositor; never synthesizes a fallback.
const Cards=preload("res://scripts/card_draw_fusion.gd")
# Local connection polling only; not an original animation/effect timing value.
const HOST_RETRY_INTERVAL_MSEC: int=1000
const AURA_READY_STATUS: String="compatible_native_anchor_unverified_M_placement_and_blend"
var source_aura: Node2D
var aura_signature: String=""
var actor: Node2D
var binding: String=""
var status: String="inactive"
var category: String="마법인형"
var follow_offset: Vector2=Vector2(54,24)
var _next_source_check_msec: int=0
var _next_aura_check_msec: int=0
var _requested_aura_signature: String=""
func _deactivate_source_aura() -> void:
	if is_instance_valid(source_aura):source_aura.deactivate()
	aura_signature=""
	_requested_aura_signature=""
	_next_aura_check_msec=0
func clear() -> void:
	_deactivate_source_aura()
	if is_instance_valid(actor):actor.clear()
	_next_source_check_msec=0
	binding="";status="inactive";hide()
func update_source(delta: float,world: Node,record: Dictionary) -> void:
	if record.is_empty() or int(world.hp)<=0:clear();return
	var path: String="res://scripts/animation/original_source_preview.gd"
	if not ResourceLoader.exists(path):status="source_engine_unavailable";hide();return
	if not is_instance_valid(actor):actor=load(path).new();add_child(actor)
	var source_key: String=("relic:" if category=="성물" else "doll:")+str(record.get("sourceId",""))
	var source_only: bool=actor.current523_source_required(source_key)
	if not source_only:
		if record.get("source_snapshot","")=="patch523":clear();status="patch523_original_pack_required";return
		var source_binding: Dictionary
		if category=="성물":source_binding=preload("res://scripts/cards/native_relic_subslot.gd").definition(Cards.card_id(record)).get("summon_binding",{})
		else:source_binding=preload("res://data/cards/base508_option_extensions.json").data.subslot_npc_bindings.get(Cards.card_id(record),{})
		if not bool(source_binding.get("display_sprite_verified",false)) or int(source_binding.get("sprite_id",0))!=int(record.get("source_display_sprite_id",0)):
			clear();status="source_npc_binding_unverified";return
	var player: Node2D=world.player
	var manifest: String="";var context: Dictionary={}
	for property: Dictionary in player.get_property_list():
		if property.name=="original_source_manifest":manifest=str(player.get(property.name))
		if property.name=="source_visual_context":context=player.get(property.name)
	var key: String=Cards.card_id(record)+"|"+manifest+"|"+str(hash(context))
	if source_only:key+="|current523_only"
	var now: int=Time.get_ticks_msec()
	var refresh: bool=key!=binding
	if not refresh and now>=_next_source_check_msec:
		_next_source_check_msec=now+HOST_RETRY_INTERVAL_MSEC
		refresh=status!="source_native" or not actor.installed()
		# Implicit private settings may change while the card/context key stays
		# identical. This API can read settings, so never call it every frame.
		if source_only and not refresh:refresh=not actor.current523_card_matches(source_key,context)
	if refresh:
		_next_source_check_msec=now+HOST_RETRY_INTERVAL_MSEC
		_deactivate_source_aura()
		actor.clear();binding=key
		if not actor.configure(source_key,manifest,context) or not actor.installed():status="source_asset_pending";hide();return
		global_position=player.global_position+follow_offset
		status="source_native"
	if source_only and not actor.installed():
		_deactivate_source_aura()
		actor.hide();status="source_asset_pending";hide();return
	if status!="source_native":return
	show()
	var previous: Vector2=global_position
	var point: Vector2=player.global_position+follow_offset
	global_position=point if previous.distance_to(point)>900 else previous.move_toward(point,minf(maxf(300,player.velocity.length()*1.35),previous.distance_to(point)*7)*maxf(0,delta))
	sync_existing_source_aura(world,record,manifest)
	var native_state: String="walk" if previous.distance_to(global_position)>.1 else "idle"
	if native_state=="walk" and player.motion.state=="run" and actor.current523_role_available("run"):native_state="run"
	actor.advance_source(delta,native_state,player.motion.facing8,player.motion.sequence,false)

func sync_existing_source_aura(world: Node,record: Dictionary,manifest: String) -> void:
	var path: String="res://scripts/animation/source_awakening_aura.gd"
	if not ResourceLoader.exists(path):return
	var awake: bool=world.option_awakening.source_relic_subslot_visual_awakened(record) if category=="성물" else world.option_awakening.source_subslot_visual_awakened(record)
	var key: String=binding+":"+str(awake)+":"+str(hash(world.presentation_settings))
	if key!=_requested_aura_signature:
		_requested_aura_signature=key
		_next_aura_check_msec=0
	if not awake:
		if key!=aura_signature and is_instance_valid(source_aura):source_aura.configure(category,record,false,actor,manifest,world.presentation_settings)
		aura_signature=key
		return
	if key==aura_signature and _source_aura_ready():return
	# A failed configure (or a later lost visual) is not a successful binding.
	# Retry it independently without resetting an otherwise healthy body clock.
	aura_signature=""
	var now: int=Time.get_ticks_msec()
	if now<_next_aura_check_msec:return
	_next_aura_check_msec=now+HOST_RETRY_INTERVAL_MSEC
	if not is_instance_valid(source_aura):source_aura=load(path).new();add_child(source_aura)
	source_aura.configure(category,record,true,actor,manifest,world.presentation_settings)
	if _source_aura_ready():aura_signature=key

func _source_aura_ready() -> bool:
	if not is_instance_valid(source_aura) or source_aura.get("status")!=AURA_READY_STATUS:return false
	var visual: Variant=source_aura.get("visual")
	return is_instance_valid(visual) and visual.installed()
