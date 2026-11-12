extends SceneTree
const CATALOG = preload("res://scripts/characters/class_catalog.gd")
const LOBBY = preload("res://scripts/characters/character_lobby.gd")
var failures: Array[String] = []
var checks: int = 0

class MemoryStore extends RefCounted:
	var characters: Array[Dictionary] = []
	var creates: int = 0
	var selected: String = ""
	var selects: int = 0
	var migrations: int = 0
	var upgrades: int = 0
	var upgrade: bool = false
	var legacy: bool = false
	var upgrade_result: Dictionary = {"ok": false, "problem": "injected upgrade backup failure"}
	func open() -> Dictionary: return {"ok":true,"characters":characters,"selected":selected,"legacy":legacy,"upgrade":upgrade}
	func create_character(name: String, id: int, gender: int, _catalog: RefCounted) -> Dictionary:
		creates += 1
		characters.append({"id":"fixture","name":name,"class_id":id,"gender_id":gender})
		return {"ok":true,"id":"fixture"}
	func select_character(id: String) -> Dictionary:
		selects += 1
		selected = id
		return {"ok":false,"problem":"injected write failure"}
	func migrate_legacy() -> Dictionary:
		migrations += 1
		return {"ok":false,"problem":"injected backup failure"}
	func upgrade_account() -> Dictionary:
		upgrades += 1
		if upgrade_result.get("ok", false): upgrade = false
		return upgrade_result.duplicate(true)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("CHARACTER_LOBBY_FAIL ",label)

func fixture() -> Dictionary:
	# Synthetic relations, not copied original resources or runtime defaults.
	var classes: Array = []
	var assets: Array = []
	for id: int in CATALOG.JOB_NAMES:
		var row: Dictionary = {"ID":id,"Name":"fixture","CanCreateClient":true,"MaleSpriteID":101,"FemaleSpriteID":102}
		for field: String in CATALOG.STAT_FIELDS.values(): row[field] = 1
		classes.append(row)
		assets.append({"ClassID":id,"GenderID":1,"LobbySpineID":100})
		if id != 142: assets.append({"ClassID":id,"GenderID":2,"LobbySpineID":101})
	return {"Class":classes,"ClassAssets":assets,"Gender":[{"ID":1},{"ID":2}],"AccountSlot":[{"ID":1,"AccountSlotTypeID":1,"Value":2}],"BuffCardDeck":[{"ID":1,"CharacterBased":false},{"ID":2,"CharacterBased":false},{"ID":98,"CharacterBased":false},{"ID":41,"CharacterBased":true}]}

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var catalog = CATALOG.new()
	var rows: Dictionary = fixture()
	check(catalog._configure_rows(rows),"synthetic source relations accepted")
	check(catalog.classes.size() == 13,"13 eligible classes independent from account slot fixture value 2")
	check(not catalog.profile(1,2).is_empty(),"explicit class gender relation")
	check(catalog.profile(142,2).is_empty(),"missing class gender pair refused")
	check(catalog.profile(1,0).is_empty(),"unspecified gender refused")
	var duplicate: Dictionary = rows.duplicate(true)
	duplicate.ClassAssets.append(duplicate.ClassAssets[0])
	check(not catalog._configure_rows(duplicate) and catalog.classes.is_empty(),"ambiguous assets fail closed")
	var wrong_scope: Dictionary = rows.duplicate(true)
	wrong_scope.BuffCardDeck[3].CharacterBased = false
	check(not catalog._configure_rows(wrong_scope),"skill character scope mismatch refused")
	check(catalog._configure_rows(rows),"valid catalog restored")
	var store := MemoryStore.new()
	var lobby = LOBBY.new()
	lobby.catalog = catalog
	lobby.store = store
	var injected_resolutions: Dictionary = {"calls": 0}
	lobby.profile_resolver = func() -> Dictionary:
		injected_resolutions.calls += 1
		return {"ok": false, "problem": "injected store must keep its explicit path"}
	root.add_child(lobby)
	await process_frame
	check(lobby.find_child("NewCharacter",true,false) != null,"creation entry visible")
	check(injected_resolutions.calls == 0,"explicit injected store never resolves another profile")
	lobby._show_creation()
	check(lobby.create_button.disabled,"no implicit class gender or name")
	lobby._choose_class(1)
	lobby.name_input.text = "시험기사"
	lobby._choose_gender(2)
	check(not lobby.create_button.disabled,"explicit valid creation enabled")
	check(is_instance_valid(lobby.source_presentation),"creation mounts original presentation consumer")
	check(not lobby.source_presentation.presentation_status().get("rendered",true),"missing original art never claims rendered delivery")
	check(not lobby.create_button.disabled,"optional original presentation does not block valid character creation")
	lobby._show_roster()
	check(lobby.source_presentation == null,"cancel releases original presentation selection")
	lobby._choose_class(1)
	lobby._choose_gender(1)
	check(lobby.source_presentation == null and lobby.name_input == null,"stale presentation callbacks cannot recreate cancelled form")
	check(store.creates == 0,"cancel does not create")
	lobby._show_creation()
	lobby._choose_class(142)
	check(lobby.selected_gender == 1,"only source declared gender selected")
	lobby.name_input.text = "시험마검"
	lobby._refresh_create()
	lobby._create()
	lobby._create()
	check(store.creates == 1,"repeated create after completed form does not duplicate")
	check(lobby.selected_id == "fixture","created character selected for review")
	lobby._enter()
	check(not lobby.busy and lobby.status.text == "injected write failure","failed selection stays in lobby")
	for index: int in 12: store.characters.append({"id":str(index),"name":"열두글자이름검증캐릭%02d"%index,"class_id":1,"gender_id":1})
	lobby._show_roster()
	check((lobby.find_child("NewCharacter",true,false) as Button).disabled,"13 filled slots disable creation")
	root.size = Vector2i(360,640)
	root.content_scale_size = Vector2i(360,640)
	await process_frame
	await process_frame
	check(lobby.scroll.size.x <= 360 and lobby.scroll.size.y > 0,"narrow window keeps roster in scroll area")
	var horizontal_fit: bool = true
	var two_line_names: bool = true
	var scroll_rect: Rect2 = lobby.scroll.get_global_rect()
	for child: Node in lobby.content.get_children():
		if child is Button and child.name.begins_with("Character_"):
			var bounds: Rect2 = child.get_global_rect()
			horizontal_fit = horizontal_fit and bounds.position.x >= scroll_rect.position.x - 1 and bounds.end.x <= scroll_rect.end.x + 1
			two_line_names = two_line_names and child.text.contains("\n")
	check(horizontal_fit and two_line_names,"12-character names and class fit as separate lines at 360px")
	var first: Button = lobby.content.get_child(1) as Button
	first.finger = 3
	first.touch_origin = Vector2(100,300)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = Vector2(100,200)
	drag.relative = Vector2(0,-100)
	first._input(drag)
	check(lobby.scroll.scroll_vertical > 0 and first.moved,"drag over a button scrolls without selecting")
	lobby.scroll.scroll_vertical = int(ceil(lobby.content.size.y))
	await process_frame
	await process_frame
	var enter: Button = lobby.find_child("EnterCharacter", true, false) as Button
	check(lobby.scroll.get_global_rect().encloses(enter.get_global_rect()), "entry action remains reachable at end of narrow roster")
	lobby.queue_free()
	await process_frame
	await profile_route_test(catalog)
	await upgrade_test(catalog)
	await legacy_guard_test(catalog)
	print("CHARACTER_LOBBY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"SYNTHETIC_RELATION_AND_UI_INPUT_NOT_ORIGINAL_ART"}))
	quit(0 if failures.is_empty() else 1)

func profile_route_test(catalog: RefCounted) -> void:
	const ACCOUNT = preload("res://scripts/characters/account_store.gd")
	var default_before: String = FileAccess.get_sha256(ACCOUNT.DEFAULT_PATH) if FileAccess.file_exists(ACCOUNT.DEFAULT_PATH) else ""
	var target: String = "user://lobby-route-test-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"
	var route: Dictionary = {"calls": 0, "result": {"ok": false, "problem": "injected damaged migration pointer"}}
	var view = LOBBY.new()
	view.catalog = catalog
	view.profile_resolver = func() -> Dictionary:
		route.calls += 1
		return route.result.duplicate(true)
	root.add_child(view)
	await process_frame
	check(route.calls == 1 and view.status.text == "injected damaged migration pointer", "managed default profile resolution error is visible")
	check(view.find_child("RetryRoster", true, false) != null and view.find_child("NewCharacter", true, false) == null, "profile error offers retry without creation")
	view._show_creation()
	view.selected_id = "stale-selection"
	view._enter()
	view._migrate()
	view._upgrade()
	check(view.create_button == null and not view.busy and not FileAccess.file_exists(target), "profile error blocks stale creation, entry, migration and upgrade actions")
	check((FileAccess.get_sha256(ACCOUNT.DEFAULT_PATH) if FileAccess.file_exists(ACCOUNT.DEFAULT_PATH) else "") == default_before, "profile failure never changes the fallback base save")
	route.result = {"ok": true, "path": target}
	view._show_roster()
	check(route.calls == 2 and view.store.path == target and view.find_child("NewCharacter", true, false) != null, "retry resolves the recovered authoritative profile")
	route.result = {"ok": true, "path": ""}
	view._show_roster()
	check(route.calls == 3 and view.find_child("NewCharacter", true, false) == null and not view.status.text.is_empty(), "empty resolved path remains blocked")
	check(not FileAccess.file_exists(target), "read-only profile retries never create a save")
	view.queue_free()
	await process_frame

func upgrade_test(catalog: RefCounted) -> void:
	var store := MemoryStore.new()
	store.upgrade = true
	store.characters.append({"id": "old-v1", "name": "기존캐릭터", "class_id": 1, "gender_id": 1})
	var view = LOBBY.new()
	view.catalog = catalog
	view.store = store
	root.add_child(view)
	await process_frame
	check(view.find_child("UpgradeAccount", true, false) != null and view.find_child("EnterCharacter", true, false) == null and view.find_child("NewCharacter", true, false) == null, "v1 account offers explicit upgrade before roster actions")
	view._show_creation()
	view._select("old-v1")
	view.selected_id = "old-v1"
	view._enter()
	view._migrate()
	check(view.create_button == null and store.selects == 0 and store.migrations == 0 and not view.busy, "pending account upgrade blocks stale form, selection, entry and legacy migration")
	view._upgrade()
	check(store.upgrades == 1 and store.upgrade and view.status.text == "injected upgrade backup failure" and not view.busy, "failed upgrade stays on original account and shows exact error")
	store.upgrade_result = {"ok": true, "backup": "fixture-backup", "unresolved_timers": 2}
	view._upgrade()
	check(store.upgrades == 2 and not store.upgrade and view.find_child("EnterCharacter", true, false) != null, "successful explicit upgrade opens roster")
	check(view.status.text.contains("2") and view.status.text.contains("소환 주문서"), "upgrade reports unresolved individual relic deadlines without inventing remaining time")
	view._upgrade()
	check(store.upgrades == 2, "completed upgrade cannot run twice from stale action")
	view.queue_free()
	await process_frame

func legacy_guard_test(catalog: RefCounted) -> void:
	var store := MemoryStore.new()
	store.legacy = true
	var view = LOBBY.new()
	view.catalog = catalog
	view.store = store
	root.add_child(view)
	await process_frame
	view._show_creation()
	view.selected_id = "stale-selection"
	view._enter()
	view._upgrade()
	check(view.find_child("MigrateLegacy", true, false) != null and view.create_button == null and store.selects == 0 and store.upgrades == 0, "legacy save requires its explicit migration action")
	view._migrate()
	check(store.migrations == 1 and view.status.text == "injected backup failure" and not view.busy, "legacy backup failure remains recoverable in lobby")
	view.queue_free()
	await process_frame
