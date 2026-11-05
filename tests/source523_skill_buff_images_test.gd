extends SceneTree
## Exact source joins and real private image bytes; no generated image fixtures.
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const ICONS = preload("res://scripts/ui/source523_skill_buff_images.gd")
const SOURCE = preload("res://scripts/skills/player_skills523.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("SOURCE523_SKILL_IMAGE_FAIL: " + label)

func run() -> void:
	var request: Dictionary = IMAGES.selection(OS.get_cmdline_user_args(),OS.get_environment("TWILIGHT_SOURCE523_IMAGES"),OS.get_environment("TWILIGHT_SOURCE523_IMAGES_SHA256"))
	IMAGES.clear_selection()
	check(not ICONS.describe_skill({"id":"unknown"}).handled,"unselected image pack preserves host policy")
	check(bool(request.get("selected",false)) and not request.has("error"),"explicit real private image pack required")
	if not bool(request.get("selected",false)) or request.has("error"): finish(); return
	var opened: Dictionary = IMAGES.configure(str(request.root),str(request.sha256))
	check(bool(opened.get("ok",false)),"real pinned image pack opens")
	if not bool(opened.get("ok",false)): finish(); return
	check(ICONS.describe_skill({"id":"unknown"}).texture == null,"unknown host ID has no filename or name fallback")
	check(ICONS.describe_skill({"id":"unknown"},"invented").reason == "unsupported_skill_icon_role","explicit source roles only")
	var bindings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE.BINDINGS_PATH))
	var linked: int = 0
	var unresolved: Dictionary = {}
	var example: String = ""
	for host_id: String in bindings.skills:
		var record: Dictionary = {"id":host_id}
		var before: String = JSON.stringify(record)
		var result: Dictionary = ICONS.describe_skill(record)
		check(result.handled and result.source_field == "IconID","host skill uses its explicit normal icon role")
		check(JSON.stringify(record) == before,"image resolution preserves host skill record")
		if result.status == "original_linked":
			linked += 1
			example = host_id
			check(result.texture is Texture2D and result.original_bytes_unchanged,"native skill image is an unchanged original texture")
			check(result.provenance.source_row_canonical_sha256 == bindings.skills[host_id].row_sha256,"source SpellClass row matches public host binding")
			check(result.actual_game_consumption_observed == false,"texture resolution is not full game-use evidence")
		else:
			unresolved[result.reason] = int(unresolved.get(result.reason,0)) + 1
			check(result.texture == null,"unresolved source icon never returns host artwork")
	check(linked > 0,"real host skill bindings resolve to original pixels")
	if not example.is_empty():
		var saved: Dictionary = ICONS._bindings[example].duplicate(true)
		ICONS._bindings[example]["row_sha256"] = "0".repeat(64)
		check(ICONS.describe_skill({"id":example}).texture == null,"wrong host source-row hash fails closed")
		ICONS._bindings[example] = saved
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(request.root).path_join("manifest.json")))
	var source_buffs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(request.root).path_join(str(manifest.source_tables.BuffClass.path))))
	var buff_found: bool = false
	for buff: Dictionary in source_buffs.rows:
		if int(buff.ID) <= 0: continue
		var effect: Dictionary = {"source_snapshot":"patch523","source_buff_class":buff}
		var original: String = JSON.stringify(effect)
		var result: Dictionary = ICONS.describe_buff(effect,"OnIconID")
		if result.status != "original_linked": continue
		buff_found = true
		check(result.texture is Texture2D and result.provenance.source_field == "OnIconID","active native buff uses the source ON role")
		check(JSON.stringify(effect) == original,"native buff identity remains unchanged")
		check(ICONS.describe_buff(effect,"invented").texture == null,"no inferred buff role")
		if int(buff.OffIconID) == 0:
			check(ICONS.describe_buff(effect,"OffIconID").texture == null,"zero OFF does not borrow ON pixels")
		break
	check(buff_found,"actual native buff source row resolves an original image")
	check(ICONS.describe_buff({"source_snapshot":"base508","source_buff_class":{"ID":1}},"OnIconID").texture == null,"wrong buff source snapshot fails closed")
	check(ICONS.describe_buff({"skill_id":"unknown"},"OnIconID").texture == null,"unknown host buff does not borrow rune art")
	var source := SOURCE.new()
	var path: String = OS.get_environment("SOURCE523_SKILL_TEST_PACK")
	var fingerprint: String = OS.get_environment("SOURCE523_SKILL_TEST_SHA256")
	if not path.is_empty() or not fingerprint.is_empty():
		check(source.load_pack(path,fingerprint),"original existing skill evidence pack loads")
		var direct_found: bool = false
		for host_id: String in bindings.skills:
			var result: Dictionary = ICONS.describe_buff({"skill_id":host_id},"OnIconID",source,{"id":host_id})
			if result.status != "original_linked": continue
			direct_found = true
			check(result.provenance.identity_basis == "verified_unconditional_main_buff_relation","host buff uses a unique original main relation")
			check(ICONS.describe_buff({"skill_id":host_id},"OnIconID",source,{"id":host_id,"local_design":true}).texture == null,"local effect variant is not promoted to native buff identity")
			break
		check(direct_found,"at least one exact loaded host-to-native buff relation resolves")
	print("SOURCE523_SKILL_IMAGE_COVERAGE ",JSON.stringify({"linked_host_icons":linked,"unresolved":unresolved,"scope":"SOURCE_REFERENCE_AND_TEXTURE_CHECKS_ONLY"}))
	finish()

func finish() -> void:
	IMAGES.clear_selection()
	print("SOURCE523_SKILL_IMAGES_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_game_use_observed":false,"images_generated":false}))
	quit(0 if failures.is_empty() else 1)
