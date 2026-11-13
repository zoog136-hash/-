extends SceneTree
## Opening settings must stay light: heavy/legacy panels (old LineageM pack,
## 523 SP2 viewer and identity pack, map source review, drop/skill/source
## optimisation panels, SPX) are foldouts built only when opened. Android
## closed the app while settings was being built (2026-11-13). Synthetic host:
## no Main, no pack, no original resource.
const SETTINGS = preload("res://scripts/ui/renewal_settings.gd")
const VIEWER = preload("res://scripts/ui/current523_sp2_viewer.gd")
const HEAVY := ["Current523SP2Viewer","Current523PackSettings","Current523IdentitySettings","InstallLineageMOfflinePack",
	"Current523AdenReviewSettings","Patch523DropSettings","SkillRecovery523Settings","SkillProgression523Settings",
	"SourceOptimizationSettings","ExternalSPXActorMode","SPXTransformPreview142"]
var failures: Array[String] = []
var checks: int = 0

class FakeWorld:
	extends Node
	signal regional_return_settings_updated
	var active_map_id: String = "synthetic"
	var active_map: Dictionary = {"name":"합성 지역"}
	var presentation_global_settings: Dictionary = {}
	func get_regional_return_enabled() -> bool: return false
	func set_regional_return_enabled(_value: bool) -> void: pass
	func regional_return_status() -> String: return ""
	func get_consumable_auto_settings() -> Dictionary: return {}
	# Source map play is active on a phone with the pack: listing its portals
	# evaluates every declaration and must wait for the player's request.
	var current523_aden_play_active: bool = true
	var portal_calls: int = 0
	func current523_aden_source_portals() -> Array:
		portal_calls += 1
		return []

class FakeHud:
	extends Node
	signal save_pressed
	signal load_pressed
	var log_label: Label
	var coordinates_readout: Label
	func _navigate(_section: String) -> void: pass

func check(ok: bool, label_text: String) -> void:
	checks += 1
	if not ok:
		failures.append(label_text)
		printerr("SETTINGS_LAZY_SECTIONS_FAIL: ", label_text)

func _initialize() -> void:
	call_deferred("run")

func _named(node: Node, wanted: String) -> Node:
	return node.find_child(wanted, true, false)

func _count(node: Node, type_name: String) -> int:
	return node.find_children("*", type_name, true, false).size()

func run() -> void:
	var world := FakeWorld.new()
	world.name = "World"
	root.add_child(world)
	var hud := FakeHud.new()
	hud.name = "HUD"
	hud.log_label = Label.new()
	hud.coordinates_readout = Label.new()
	hud.add_child(hud.log_label)
	hud.add_child(hud.coordinates_readout)
	var hud_root := Control.new()
	hud_root.name = "Root"
	hud.add_child(hud_root)
	world.add_child(hud)
	var settings: VBoxContainer = SETTINGS.new()
	hud_root.add_child(settings)
	var started: int = Time.get_ticks_usec()
	settings.configure(hud)
	var elapsed_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	await process_frame
	for wanted: String in HEAVY:
		check(_named(settings, wanted) == null, "opening settings does not build " + wanted)
	check(_count(settings, "FileDialog") == 0, "opening settings creates no file picker")
	var decoded: int = 0
	for view: Node in settings.find_children("*", "TextureRect", true, false):
		if (view as TextureRect).texture is ImageTexture: decoded += 1
	check(decoded == 0, "opening settings shows no runtime-decoded image")
	var nodes: int = settings.find_children("*", "", true, false).size()
	check(nodes < 260, "opening settings stays small (%d nodes)" % nodes)
	for id: String in ["drops","skills523","source_optimization","advanced"]:
		check(settings.lazy_sections.has(id) and not settings.is_section_built(id), "foldout registered but not built: " + id)
		check(_named(settings, "SettingsSection_" + id) is Button, "foldout button shown: " + id)
	check(not settings.lazy_sections.has("legacy_lineagem"), "legacy pack foldout sits inside the collapsed 고급/개발 foldout")
	check(_named(settings, "MasterVolume") != null and _named(settings, "RegionalReturnEnabled") != null and _named(settings, "CombatLogToggle") != null and _named(settings, "ImpactIntensity") != null, "everyday settings stay immediate")
	var pack_status: Node = _named(settings, "SourcePackStatus")
	if pack_status != null:
		var first_foldout: Node = _named(settings, "SettingsSection_drops")
		check(first_foldout != null and first_foldout.get_parent() == pack_status.get_parent() and pack_status.get_index() < first_foldout.get_index(), "pack status stays at the top")
	# Opening 고급/개발 only lists its foldouts.
	check(settings.expand_section("advanced"), "advanced foldout opens")
	await process_frame
	for id: String in ["legacy_lineagem","aden_review","spx"]:
		check(settings.lazy_sections.has(id) and not settings.is_section_built(id), "nested foldout not built yet: " + id)
	check(_named(settings, "Current523SP2Viewer") == null and _named(settings, "Current523AdenReviewSettings") == null and _count(settings, "FileDialog") == 0, "opening 고급/개발 builds no legacy panel")
	check(settings.expand_section("aden_review"), "map review foldout opens on request")
	var review: Node = _named(settings, "Current523AdenReviewSettings")
	check(review != null and world.portal_calls == 0, "building the map review panel does not evaluate source portals")
	var list_button: Button = _named(settings, "ListAdenSourcePortalsButton") as Button
	check(list_button != null, "portal list has an explicit read button")
	if list_button != null:
		list_button.pressed.emit()
		check(world.portal_calls == 1, "portal list is read when asked")
	settings.collapse_section("aden_review")
	settings.collapse_section("advanced")
	var advanced: Dictionary = settings.lazy_sections.get("advanced", {})
	check(not advanced.is_empty() and not (advanced.body as Control).visible and settings.is_section_built("advanced"), "collapse hides without rebuilding")
	# The SP2 picker never lists the whole 989-file bundle.
	var viewer: VBoxContainer = VIEWER.new()
	root.add_child(viewer)
	await process_frame
	for index: int in range(989):
		viewer._member_rows.append({"member":"Sprite/%d-0.sp2" % index})
	viewer._refresh_member_picker()
	check(viewer.member_picker.item_count <= VIEWER.PICKER_LIMIT + 2, "SP2 picker capped (%d rows)" % viewer.member_picker.item_count)
	viewer.member_search.text = "Sprite/98"
	viewer._refresh_member_picker()
	check(viewer.member_picker.item_count >= 10 and viewer.member_picker.item_count <= VIEWER.PICKER_LIMIT + 2, "search still finds narrowed names")
	viewer.queue_free()
	settings.queue_free()
	world.queue_free()
	await process_frame
	print("SETTINGS_LAZY_SECTIONS_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"configure_ms":snappedf(elapsed_ms,0.1),"nodes":nodes}))
	quit(0 if failures.is_empty() else 1)
