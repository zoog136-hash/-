extends SceneTree
## Only the new precedence guard; no PR217 art or701-card verification is repeated.
const ACTOR = preload("res://scripts/resources/current523_identity_actor.gd")
const ORIGINAL = preload("res://scripts/animation/original_source_preview.gd")
class Host extends Node2D:
	var transform_active: bool = true
	var original_source_preview: Node
	var adapter: Node
	var refreshes: int = 0
	func _refresh_visual_visibility() -> void:
		refreshes += 1
		original_source_preview.visible = transform_active and original_source_preview.installed() and not adapter.is_player_override_active()
var checks: int = 0
var failures: Array[String] = []
func check(value: bool,caption: String) -> void:
	checks += 1
	if not value: failures.append(caption)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host := Host.new()
	host.original_source_preview = ORIGINAL.new()
	host.adapter = ACTOR.new()
	root.add_child(host)
	host.add_child(host.original_source_preview)
	host.add_child(host.adapter)
	host.adapter.set_process(false)
	# The original consumer's installed() predicate is nonempty parsed record.
	# This is a lifecycle fixture only, without invented native pixels or a pack claim.
	host.original_source_preview._record = {"precedence_fixture_only":true}
	host.original_source_preview._clock = 1.25
	host.original_source_preview._sequence = 8
	check(host.adapter._existing_source_active(),"installed original transformation wins")
	host.adapter._overriding_host = true
	host.adapter.visible = true
	host.original_source_preview.visible = false
	host.adapter._process(0.1)
	check(not host.adapter.is_player_override_active() and not host.adapter.visible,"automatic estimate yields to existing native consumer")
	check(host.original_source_preview.visible,"current original visibility restored")
	check(host.original_source_preview._clock == 1.25 and host.original_source_preview._sequence == 8,"original playback clocks and sequence unchanged")
	check(host.adapter.status_details().native_pack_preferred,"status reports existing original preference")
	host.adapter._overriding_host = true
	host.adapter.advance_motion(0.1,"attack",4,99,true)
	check(not host.adapter.is_player_override_active(),"direct presentation calls cannot replace original actor")
	check(host.original_source_preview._clock == 1.25 and host.original_source_preview._sequence == 8,"direct call never advances existing native state")
	host.transform_active = false
	check(not host.adapter._existing_source_active(),"unequipped native record is not an active original")
	host.transform_active = true
	host.original_source_preview._record.clear()
	check(not host.adapter._existing_source_active(),"missing native record is not claimed installed")
	host.original_source_preview._record = {"precedence_fixture_only":true}
	host.adapter.clear()
	check(host.original_source_preview._record.has("precedence_fixture_only"),"clearing comparison preserves existing original data")
	check(host.original_source_preview._clock == 1.25,"comparison clear preserves existing original clock")
	host.queue_free()
	await process_frame
	print("CURRENT523_NATIVE_PRECEDENCE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"PRECEDENCE_GUARD_ONLY; NOT_NATIVE701_ART_REVALIDATION"}))
	quit(0 if failures.is_empty() else 1)
