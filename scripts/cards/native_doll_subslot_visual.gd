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
const PLACEMENT=preload("res://scripts/animation/companion_placement.gd")
## The second doll/relic stands on the other side of the owner (mirrored
## placement); a relic keeps its sort key on the owner's foot line so it is
## drawn behind the character in all facings (see relic_motion.gd).
var follow_offset: Vector2=PLACEMENT.doll_offset(2,true)
var placement=PLACEMENT.new()
var visual_position: Vector2=Vector2.ZERO
## Carries the visual point; the actor's own position stays with its walk
## root-motion cancel (as follower_motion.gd / relic_motion.gd).
var point_node: Node2D
func _follow(delta: float,player: Node2D) -> Vector2:
	var point: Vector2=placement.follow(delta,player.global_position,player.velocity,player.motion.facing8,category=="성물",true)
	follow_offset=point-player.global_position
	return point
func _apply_position(player: Node2D) -> void:
	if category=="성물":global_position=Vector2(visual_position.x,player.global_position.y-PLACEMENT.RELIC_SORT_BEHIND)
	else:global_position=visual_position
	if is_instance_valid(point_node):point_node.global_position=visual_position
var _next_source_check_msec: int=0
var _next_aura_check_msec: int=0
var _requested_aura_signature: String=""
func _deactivate_source_aura() -> void:
	if is_instance_valid(source_aura):source_aura.deactivate()
	aura_signature=""
	_requested_aura_signature=""
	_next_aura_check_msec=0
func clear() -> void:
	if status=="inactive" and not visible and _requested_aura_signature.is_empty():return
	_deactivate_source_aura()
	if is_instance_valid(actor):actor.clear()
	_next_source_check_msec=0
	binding="";status="inactive";hide()
func update_source(delta: float,world: Node,record: Dictionary) -> void:
	if record.is_empty() or int(world.hp)<=0:clear();return
	var path: String="res://scripts/animation/original_source_preview.gd"
	if not preload("res://scripts/resources/retired_assets.gd").usable(path):status="source_engine_unavailable";hide();return
	if not is_instance_valid(actor):
		actor=load(path).new()
		actor.use_companion_frame_plans()
		actor.cancel_walk_root_motion=true;actor.root_motion_endpoint_fit=true
		point_node=Node2D.new();point_node.name="FollowerPoint";add_child(point_node)
		point_node.add_child(actor)
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
	var manifest_value: Variant=player.get("original_source_manifest")
	var manifest: String=str(manifest_value) if manifest_value!=null else ""
	var context_value: Variant=player.get("source_visual_context")
	var context: Dictionary=context_value if context_value is Dictionary else {}
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
		placement.reset(player.motion.facing8)
		visual_position=_follow(0.0,player)
		_apply_position(player)
		status="source_native"
	if source_only and not actor.installed():
		_deactivate_source_aura()
		actor.hide();status="source_asset_pending";hide();return
	if status!="source_native":return
	show()
	var owner_preview: Variant=player.get("original_source_preview")
	if owner_preview is Object:actor.root_motion_cell_steps=owner_preview.root_motion_cell_steps
	var previous: Vector2=visual_position
	visual_position=_follow(maxf(0,delta),player)
	_apply_position(player)
	sync_existing_source_aura(world,record,manifest)
	var native_state: String="walk" if previous.distance_to(visual_position)>.1 else "idle"
	if native_state=="walk" and player.motion.state=="run" and actor.current523_role_available("run"):native_state="run"
	actor.advance_source(delta,native_state,player.motion.facing8,player.motion.sequence,false)

func sync_existing_source_aura(world: Node,record: Dictionary,manifest: String) -> void:
	var path: String="res://scripts/animation/source_awakening_aura.gd"
	if not preload("res://scripts/resources/retired_assets.gd").usable(path):return
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
