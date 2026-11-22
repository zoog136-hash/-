extends RefCounted
class_name TwilightRelicMotion

const ORIGINAL = preload("res://scripts/animation/original_source_preview.gd")
const SOURCE = preload("res://scripts/lineagem_base508.gd")
var native_actor = ORIGINAL.new()
var native_enabled: bool = false
var source_only: bool = false
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const GLOW = preload("res://assets/effects/relic_glow.gdshader")
var enabled: bool = false
var opacity: float = 0.0
var clock: float = 0.0
var reaction: float = 0.0
var previous_sequence: int = -1
var state: String = "despawn"
var base_scale: Vector2 = Vector2.ONE
var profile: TwilightAnimationProfile
var material: ShaderMaterial
const PLACEMENT = preload("res://scripts/animation/companion_placement.gd")
## Current screen offset from the owner: behind its head (lifted), never in front.
var follow_offset: Vector2 = PLACEMENT.relic_offset(2)
var placement = PLACEMENT.new()
## Y-sort key of the original relic actor. World sorts children by their y, so
## the holder stays just above the owner's foot line while the actor itself is
## offset to the floating point: the relic is drawn behind the character in all
## eight facings (facing N its point is south of the owner).
var sort_anchor: Node2D
## Smoothed visual point (global) of the relic, independent of its sort key.
var visual_position: Vector2 = Vector2.ZERO
## Carries the visual point under sort_anchor; the actor's own position stays
## with its walk root-motion cancel.
var lift_point: Node2D
var motion: TwilightActorMotion = MOTION.new()
var appear_speed: float = 4.0
var disappear_speed: float = 4.0

func _init() -> void:
	native_actor.use_companion_frame_plans()
	# As follower_motion.gd: the original walk frames' step is cancelled.
	native_actor.cancel_walk_root_motion = true
	native_actor.root_motion_endpoint_fit = true

func _place_now(player: TwilightPlayer) -> void:
	placement.reset(player.motion.facing8)
	follow_offset = PLACEMENT.relic_offset(player.motion.facing8)
	visual_position = player.global_position + follow_offset

func _follow_target(delta: float, player: TwilightPlayer) -> Vector2:
	var point: Vector2 = placement.follow(delta, player.global_position, player.velocity, player.motion.facing8, true)
	follow_offset = point - player.global_position
	return point

static func sort_y(player: Node2D) -> float:
	return player.global_position.y - PLACEMENT.RELIC_SORT_BEHIND

func _attach_native(world: Node) -> void:
	if not is_instance_valid(sort_anchor):
		sort_anchor = Node2D.new()
		sort_anchor.name = "RelicSortAnchor"
	if sort_anchor.get_parent() != world:
		if sort_anchor.get_parent() != null: sort_anchor.get_parent().remove_child(sort_anchor)
		world.add_child(sort_anchor)
	if not is_instance_valid(lift_point):
		lift_point = Node2D.new()
		lift_point.name = "RelicPoint"
	if lift_point.get_parent() != sort_anchor:
		if lift_point.get_parent() != null: lift_point.get_parent().remove_child(lift_point)
		sort_anchor.add_child(lift_point)
	if native_actor.get_parent() != lift_point:
		if native_actor.get_parent() != null: native_actor.get_parent().remove_child(native_actor)
		lift_point.add_child(native_actor)

## Visual point and sort key are separate: see sort_anchor.
func _apply_native_position(player: TwilightPlayer) -> void:
	sort_anchor.global_position = Vector2(visual_position.x, sort_y(player))
	lift_point.global_position = visual_position

## Moves the original relic actor toward its point behind the owner's head;
## returns "walk" while it travels, else "idle".
func follow_native(delta: float, player: TwilightPlayer) -> String:
	native_actor.root_motion_cell_steps = player.original_source_preview.root_motion_cell_steps
	var old: Vector2 = visual_position
	visual_position = _follow_target(delta, player)
	_apply_native_position(player)
	return "walk" if old.distance_to(visual_position)>0.1 else "idle"

func configure(record: Dictionary, sprite: Sprite2D, player: TwilightPlayer, grade_color: Color) -> void:
	native_actor.clear()
	native_enabled = false
	_place_now(player)
	var source_key: String = "relic:" + str(record.get("sourceId",""))
	source_only = native_actor.current523_source_required(source_key)
	if SOURCE.native(record) or source_only:
		_attach_native(sprite.get_parent())
		if source_only:
			sprite.texture = null
			sprite.material = null
		native_enabled = native_actor.configure(source_key, player.original_source_manifest, player.source_visual_context)
		enabled = native_enabled
		sprite.hide()
		_apply_native_position(player)
		native_actor.advance_source(0.0, "idle", player.motion.facing8, player.motion.sequence, false)
		if source_only and not native_actor.installed():
			native_enabled = false
			enabled = false
			native_actor.hide()
		state = "source_native" if native_enabled else "source_asset_pending"
		return
	var path: String = str(record.get("image_path", ""))
	if record.is_empty():
		enabled = false
		state = "despawn"
		return
	profile = CATALOG.for_record("relic", record, path)
	motion = MOTION.new()
	motion.profile = profile
	var frames: SpriteFrames = CATALOG.frames_for_profile(profile, path)
	appear_speed = 1.0 / MOTION.presentation_seconds(frames, "equip", 0.25)
	disappear_speed = 1.0 / MOTION.presentation_seconds(frames, "unequip", 0.25)
	var texture: Texture2D = CATALOG.first_texture(frames)
	if texture == null:
		enabled = false
		state = "despawn"
		return
	# Reuse the float/glow/foot sorting while sharing the native frame sampler.
	motion.frame_source = frames
	sprite.texture = texture
	base_scale = Vector2.ONE * (34.0 / maxf(1.0, maxf(sprite.texture.get_width(), sprite.texture.get_height())))
	if material == null:
		material = ShaderMaterial.new()
		material.shader = GLOW
	material.set_shader_parameter("aura_color", grade_color)
	sprite.material = material
	sprite.z_index = 0 # root position is the foot; texture offset carries the elevation
	visual_position = player.global_position + follow_offset
	sprite.global_position = Vector2(visual_position.x, sort_y(player))
	sprite.visible = true
	opacity = 0.0
	clock = 0.0
	reaction = 0.0
	previous_sequence = player.motion.sequence
	enabled = true
	state = "summon"
	update(0.0, sprite, player)

func update(delta: float, sprite: Sprite2D, player: TwilightPlayer) -> void:
	if source_only and (not native_enabled or not native_actor.installed()):
		native_enabled = false
		enabled = false
		state = "source_asset_pending"
		sprite.hide()
		sprite.texture = null
		sprite.material = null
		native_actor.hide()
		return
	if native_enabled:
		var native_state: String = follow_native(delta, player)
		if native_state == "walk" and player.motion.state == "run" and native_actor.current523_role_available("run"): native_state = "run"
		native_actor.advance_source(delta, native_state, player.motion.facing8, player.motion.sequence, false)
		return
	if not enabled and not sprite.visible: return
	opacity = move_toward(opacity, 1.0 if enabled else 0.0, delta * (appear_speed if enabled else disappear_speed))
	if absf(opacity - (1.0 if enabled else 0.0)) < 0.00001:
		opacity = 1.0 if enabled else 0.0
	if not enabled and opacity <= 0.001:
		opacity = 0.0
		sprite.visible = false
		sprite.texture = null
		return
	clock += delta
	var previous: Vector2 = visual_position
	var target: Vector2 = _follow_target(delta, player)
	if previous.distance_to(target) > 900.0: opacity = 0.0
	visual_position = target
	sprite.global_position = Vector2(visual_position.x, sort_y(player))
	var real_velocity: Vector2 = (visual_position - previous) / maxf(delta, 0.001)
	if previous.distance_to(target) > 900.0: real_velocity = Vector2.ZERO
	var prior_state: String = motion.state
	var prior_clock: float = motion.state_clock
	motion.advance(delta, real_velocity)
	if player.motion.sequence != previous_sequence:
		previous_sequence = player.motion.sequence
		reaction = 0.28
	reaction = maxf(0.0, reaction - delta)
	# A relic uses body/energy/equip tracks, never humanoid walking poses.
	var pose: String = "float"
	if not enabled: pose = "unequip"
	elif opacity < 1.0: pose = "equip"
	elif reaction > 0.0: pose = "activate"
	motion.state_clock = prior_clock + delta if prior_state == pose else 0.0
	motion.state = pose
	motion.apply_frames(sprite)
	var elevation: float = profile.sprite_offset.y if profile != null else -64.0
	sprite.scale = base_scale * (1.0 + reaction * 0.16)
	var sort_lift: float = visual_position.y - sprite.global_position.y
	sprite.offset = Vector2(0, sort_lift + elevation + sin(clock * 2.4) * 3.5) / sprite.scale
	sprite.rotation = sin(clock * 1.6) * 0.045
	sprite.modulate.a = opacity
	if material != null: material.set_shader_parameter("strength", 0.18 + sin(clock * 2.1) * 0.035 + reaction)
	state = "despawn" if not enabled else ("summon" if opacity < 1.0 else ("combat_reaction" if reaction > 0.0 else "float"))

func _notification(what: int) -> void:
	# Source views are constructed before equipment selection. If never attached,
	# the motion owner must release them; attached nodes belong to the scene tree.
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(native_actor) and native_actor.get_parent() == null: native_actor.free()
		if is_instance_valid(sort_anchor) and sort_anchor.get_parent() == null: sort_anchor.free()
