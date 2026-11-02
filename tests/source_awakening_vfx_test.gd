extends SceneTree
const RUNTIME = preload("res://scripts/cards/option_awakening_runtime.gd")
const CORE = preload("res://scripts/cards/option_awakening_service.gd")
const AURA = preload("res://scripts/animation/source_awakening_aura.gd")
const VIEW = preload("res://scripts/animation/original_source_preview.gd")
const SOURCE = preload("res://scripts/lineagem_base508.gd")
class Ownership extends RefCounted:
	var state: Dictionary = {"owned": {"성물": {}}}
	func export_state() -> Dictionary: return state.duplicate(true)
class Host extends Node:
	var card_draw_fusion = Ownership.new()
	var catalog_db: Dictionary = SOURCE.cards()
	func save_path() -> String: return "user://awakening-fixture-never-written.json"
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var manifest: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--awakening-manifest="): manifest = arg.trim_prefix("--awakening-manifest=")
	var host := Host.new()
	root.add_child(host)
	var runtime := RUNTIME.new()
	check(runtime.configure(host), "existing awakening API config")
	var card: Dictionary = {}
	for entry: Dictionary in SOURCE.cards().catalog["성물"]:
		if int(entry.source_card_id) == 21518: card = entry
	check(not card.is_empty(), "canonical relic identity")
	var identity: String = "source:" + str(card.sourceId)
	host.card_draw_fusion.state.owned["성물"][identity] = true
	check(not runtime.source_visual_awakened("성물", card), "ownership is not awakening")
	var saved: Dictionary = runtime.export_state()
	saved.cards["성물"][identity] = CORE.fresh_card()
	saved.cards["성물"][identity].awakened = true
	var envelope: Dictionary = {"card_option_awakening": saved, "card_draw_fusion": host.card_draw_fusion.export_state()}
	check(runtime.prepare_load(envelope) and runtime.accept_load(envelope), "existing save restore accepts exact explicit native state")
	check(runtime.source_visual_awakened("성물", card), "owned explicitly awakened restored card")
	var before: String = JSON.stringify(runtime.export_state())
	check(not runtime.source_visual_awakened("변신", card), "category isolation")
	host.card_draw_fusion.state.owned["성물"].erase(identity)
	check(not runtime.source_visual_awakened("성물", card), "unowned native awakening suppressed")
	host.card_draw_fusion.state.owned["성물"][identity] = true
	check(int(AURA.rule("성물", card).get("sprite_id", 0)) == 24748, "exact source chain")
	var forged: Dictionary = card.duplicate(true)
	forged.source_grade_id = 52
	check(int(AURA.rule("성물", forged).get("sprite_id", 0)) == 24748, "canonical grade prevents forged binding")
	for sid: int in [20542,20540,20459,24763,22147,22148,22149,25908,24747,24713,24748,26711]:
		var probe := VIEW.new()
		root.add_child(probe)
		probe.playback_mode_override = "compatible"
		check(probe.configure("sprite:" + str(sid), manifest), "available awakening source profile %d" % sid)
		for facing: int in range(8):
			probe.advance_source(1.0 / 30.0, "idle", facing, 0, false)
			check(probe.last_source_frame >= 0, "idle source frame %d/%d" % [sid, facing])
			probe.advance_source(1.0 / 30.0, "walk", facing, 0, false)
			check(probe.source_role() == "walk" and probe.last_source_frame >= 0, "source walk loaded")
		check(float(probe._playback_tracks.idle.fps) == 24.0, "explicit source idle FPS")
		probe.free()
	var target := VIEW.new()
	root.add_child(target)
	# Real native host, same source preview renderer as the equipped card.
	target.playback_mode_override = "compatible"
	check(target.configure("sprite:24748", manifest), "source host loaded")
	var aura := AURA.new()
	root.add_child(aura)
	aura.configure("성물", card, runtime.source_visual_awakened("성물", card), target, manifest.get_base_dir().path_join("../manifest.json"), {})
	# The normal resolver looks for awakening/ under the main pack root.
	check(aura.visual.installed(), "conditional source effect installed")
	aura._process(1.0 / 30.0)
	check(aura.visible and aura.visual.last_source_frame >= 0, "actual 30fps source effect sampled")
	var clock: float = aura.visual._clock
	aura.configure("성물", card, true, target, manifest.get_base_dir().path_join("../manifest.json"), {})
	check(aura.visual._clock == clock, "repeat sync preserves effect clock")
	aura.configure("성물", {}, false, target, "", {})
	check(not aura.visual.installed() and not aura.visible, "unequip/removal clears pixels")
	target.playback_mode_override = "strict"
	target.configure("sprite:24748", manifest)
	aura.configure("성물", card, true, target, manifest.get_base_dir().path_join("../manifest.json"), {})
	check(aura.status == "strict_unverified_composition" and not aura.visual.installed(), "strict preserves unverified composition guard")
	check(JSON.stringify(runtime.export_state()) == before, "VFX reads never mutate awakening state/RNG/progression")
	aura.free();target.free();host.free()
	print("SOURCE_AWAKENING_CONDITIONAL failures=", failures)
	quit(0 if failures == 0 else 1)
