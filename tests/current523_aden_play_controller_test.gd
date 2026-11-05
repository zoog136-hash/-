extends SceneTree
const CONTROLLER = preload("res://scripts/maps/current523_aden_play_controller.gd")
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
var checks: int = 0
var failures: Array[String] = []

class DisplayProbe extends FieldRenderer:
	var accept: bool = false
	var problem: String = "unsupported display correction"
	var delta := Vector2.ZERO
	var attempts: Array[Vector2] = []
	func set_visual_delta(value: Vector2) -> bool:
		attempts.append(value)
		if not accept: return false
		delta = value
		return true

class ProviderProbe extends RefCounted:
	var context: Dictionary={"Portal":{"ID":1101,"SourceLandID":1,"SourceX":32668,"SourceY":32803,"AssetID":0,"TargetTerritoryID":173094},"TargetTerritory":{"ID":173094,"DescID":0,"LandID":0,"StartX":32477,"StartY":32855,"EndX":32477,"EndY":32855},"SourceLand":{"ID":1,"AssetPath":"1/"},"TargetLand":{"ID":0,"AssetPath":"0/"}}
	func portal_evidence_for_land(land_id: int,asset: String) -> Array:
		return [{"ID":1101}] if land_id==1 and asset=="1/" else []
	func portal_context_for_land(land_id: int,asset: String,id: int) -> Dictionary:
		return context if land_id==1 and asset=="1/" and id==1101 else {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	if FileAccess.file_exists(OPTIONS.PATH):
		push_error("Controller guard requires an empty isolated user profile")
		quit(1)
		return
	# Normalized form, including the explicit own map policy defaults.
	var options: Dictionary = OPTIONS.validate({"enabled":true,"navigation_profile":OPTIONS.LEGACY,"offset_x":0,"offset_y":0,"raw_root":"/fixture/raw","tile_root":"/fixture/tiles"})
	check(not options.is_empty(), "fixture profile is a valid explicit local profile")
	check(OPTIONS.write(options) == OK, "explicit local profile baseline saved")
	var before: String = FileAccess.get_sha256(OPTIONS.PATH)
	var display := DisplayProbe.new()
	var controller = CONTROLLER.new()
	controller.active = true
	controller.settings = options.duplicate(true)
	controller.set("_renderer", display)
	var changed: Dictionary = options.duplicate(true)
	changed.offset_y = 12
	check(not controller.apply_options(changed), "renderer rejection propagates to API result")
	check(FileAccess.get_sha256(OPTIONS.PATH) == before and OPTIONS.read() == options, "failed renderer application preserves all configuration bytes")
	check(controller.settings == options and display.delta == Vector2.ZERO, "failed application retains prior accepted settings")
	check(not controller.problem.is_empty(), "failed renderer application exposes a reason")
	display.accept = true
	check(controller.apply_options(changed), "successful correction applies and persists")
	check(OPTIONS.read().offset_y == 12 and display.delta == Vector2(0, 12), "saved correction matches actual accepted renderer state")
	check(controller.problem.is_empty(), "successful correction clears an earlier error")
	controller.active = false
	controller.set("_renderer", null)
	display.free()
	DirAccess.remove_absolute(OPTIONS.PATH)
	var generic=CONTROLLER.new()
	generic.source_owned=true; generic.active=true
	generic.settings={"navigation_profile":OPTIONS.GENERIC,"native_land_id":1}
	check(generic.portal_evidence().is_empty() and generic.portal_context(1101).is_empty(),"generic portals remain unavailable without native definition provider")
	check(not generic.use_source_portal(1101),"missing source portal provider preserves runtime")
	var provider=ProviderProbe.new()
	# 38f8993: a live generic source session must end before its definition
	# provider changes, so binding is exercised with the session inactive.
	check(not generic.bind_source_portal_provider(provider,CONTROLLER.DEFINITION_PACK_SHA256) and generic.get("_source_portal_provider")==null,"active source session refuses a provider change")
	generic.active=false
	check(not generic.bind_source_portal_provider(provider,"0".repeat(64)),"unverified definition manifest pin rejects provider")
	check(not generic.bind_source_portal_provider(RefCounted.new(),CONTROLLER.DEFINITION_PACK_SHA256),"missing provider methods rejects before activation")
	check(generic.bind_source_portal_provider(provider,CONTROLLER.DEFINITION_PACK_SHA256),"explicit verified caller can bind definition provider contract")
	generic.active=true
	var script: Script=load("res://scripts/maps/current523_source_field.gd")
	var source=script.new(); source.source_asset="1/"
	generic.set("_source_field",source)
	var context: Dictionary=generic.portal_context(1101)
	check(context.get("Portal") is Dictionary,"bound provider yields a portal context")
	if context.get("Portal") is Dictionary:context.Portal.SourceLandID=4
	check(generic.portal_context(1101).get("Portal",{}).get("SourceLandID")==1,"returned portal context cannot mutate provider rows")
	check(generic.portal_evidence().size()==1 and not generic.portal_evidence()[0].activation_candidate if generic.portal_evidence().size()==1 else false,"native row presence does not assert manual endpoint admission or original trigger")
	var original_context: Dictionary=provider.context.duplicate(true)
	for malformed: Dictionary in [{"Portal":[]},{"Portal":{"ID":NAN}},{"TargetTerritory":{}},{"TargetLand":{"ID":0.5,"AssetPath":"0/"}}]:
		provider.context=original_context.duplicate(true); provider.context.merge(malformed,true)
		check(generic.portal_context(1101).is_empty() and generic.portal_evidence().is_empty(),"malformed provider context safely rejects before projection/conversion")
	provider.context=original_context
	check(not generic.use_source_portal(1101),"provider binding without a live world cannot move actors")
	check(not generic.bind_source_portal_provider(null,""),"active source session refuses provider detach")
	generic.active=false
	check(generic.bind_source_portal_provider(null,"") and generic.portal_evidence().is_empty(),"provider can detach without changing source field")
	source.close()
	print("CURRENT523_ADEN_PLAY_CONTROLLER_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true}))
	quit(0 if failures.is_empty() else 1)
