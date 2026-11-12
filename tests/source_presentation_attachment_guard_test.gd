extends SceneTree
## Existing source-only policy must also cover authored actor-attached lights.
## No original SP2/potion restoration or new art is used by this regression.
const FEEDBACK = preload("res://scripts/animation/potion_feedback.gd")
const WORLD = preload("res://scripts/potion_feedback_world.gd")
const PLAYER = preload("res://scripts/player.gd")
var checks: int = 0
var failures: Array[String] = []

class SourcePolicy extends RefCounted:
	var source_only: bool = false
	func current523_source_only_presentation() -> bool: return source_only

class PolicyActor extends Node2D:
	var original_source_preview: RefCounted = SourcePolicy.new()

class Context extends Node:
	var hp: int = 100
	var combat_generation: int = 0
	var presentation_settings: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var context := Context.new()
	var actor := PolicyActor.new()
	root.add_child(context)
	context.add_child(actor)
	var feedback: Node2D = FEEDBACK.new()
	actor.add_child(feedback)
	feedback.setup(context, actor)
	check(FEEDBACK.allowed_for_actor(actor), "legacy presentation permits its existing authored light")
	check(feedback.play("health_strong") and feedback.active.size() == 1, "legacy accepted use retains one light")
	var emitted: int = feedback.emitted
	actor.original_source_preview.source_only = true
	check(not FEEDBACK.allowed_for_actor(actor), "source-only presentation rejects the authored fallback")
	check(not feedback.play("health_strong") and feedback.emitted == emitted, "source mode cannot refresh or emit an authored halo")
	feedback._process(0.01)
	check(feedback.active.is_empty() and not feedback.is_processing(), "entering source mode clears an already active light")
	check(context.hp == 100 and context.combat_generation == 0, "presentation guard leaves gameplay state unchanged")
	actor.original_source_preview.source_only = false
	check(feedback.play("mana"), "leaving source mode permits the existing legacy path again")
	context.free()

	# Exercise the actual Main subclass adapter without booting or loading a
	# save. Player's original preview policy is the real production object.
	var world: Node = WORLD.new()
	var player: Node2D = PLAYER.new()
	world.player = player
	world.hp = 100
	player.original_source_preview._current523_source_only = true
	world._show_potion_feedback("강력 HP 물약", "hp")
	check(not is_instance_valid(world.potion_feedback), "source-only Main adapter does not allocate authored feedback")
	player.original_source_preview._current523_source_only = false
	world._show_potion_feedback("강력 HP 물약", "hp")
	check(is_instance_valid(world.potion_feedback) and world.potion_feedback.emitted == 1, "legacy Main adapter still emits once")
	player.original_source_preview._current523_source_only = true
	world._show_potion_feedback("강력 HP 물약", "hp")
	check(world.potion_feedback.emitted == 1 and world.potion_feedback.active.is_empty(), "source policy clears retained legacy feedback without a second emission")
	player.free()
	world.free()
	print("SOURCE_PRESENTATION_ATTACHMENT_GUARD " + JSON.stringify({"checks":checks,"failures":failures,"scope":"existing source-only presentation policy; no original-pixel proof"}))
	quit(0 if failures.is_empty() else 1)
