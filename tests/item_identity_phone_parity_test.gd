extends SceneTree
## Phone report 2026-11-20 (screenshots): empty bag slots (legacy name rows
## such as "각인 장비 상자", held "[원본 보상]" rewards), a "◆" mark and the
## internal key "[원본 보상] [방어구-망토] 마법 망토 (각인)" in the tap name,
## "공성 포인트 · 원본#195371 ×1 습득" in the log, "검증된 장비 수치 입력
## 미설치" when a quest cloak was tapped, and developer lines/tools in the
## item book.
## Always: internal markers are stripped, Korean particles, no ◆, developer
## gating and the held-gear conversion are wired, the icon status line.
## With the 523 tables (+ image pack): original ItemClass identity by ID and by
## exact original name, original names, original acquisition text, and the
## original icon of a legacy name row.
##   godot --headless --path <repo> --script res://tests/item_identity_phone_parity_test.gd
const IDENTITY = preload("res://scripts/ui/source523_item_identity.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const ICON_STATUS = preload("res://scripts/ui/item_icon_resource_status.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const BAG = preload("res://scripts/ui/lineage_inventory_ui.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("ITEM_IDENTITY_PHONE_FAIL: " + label)

func _initialize() -> void:
	synthetic()
	sources()
	installed()
	print("ITEM_IDENTITY_PHONE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)

func synthetic() -> void:
	check(IDENTITY.plain_text("공성 포인트 · 원본#195371") == "공성 포인트", "the native key suffix is not shown")
	check(IDENTITY.plain_text("[원본 보상] 각인 장비 상자@@@0123abcd") == "각인 장비 상자", "the held prefix and instance id are not shown")
	check(IDENTITY.clean_message("공성 포인트 · 원본#195371 ×1 습득") == "공성 포인트 ×1 습득", "logs lose the internal ID")
	check(IDENTITY.clean_message("[원본 보상] 마법 망토 (각인) 획득") == "마법 망토 (각인) 획득", "messages lose the held prefix")
	check(IDENTITY.clean_message("평범한 문장") == "평범한 문장", "other text is unchanged")
	check(IDENTITY.screen_text("검증된 장비 수치 입력 미설치", true) == "검증된 장비 수치 입력 미설치", "developer builds keep developer text")
	var release: String = IDENTITY.screen_text("검증된 장비 수치 입력 미설치", false)
	check(not release.contains("검증") and not release.is_empty(), "release screens get the original generic notice (%s)" % release)
	check(IDENTITY.screen_text("망토 장착: 마법 망토 (각인)", false) == "망토 장착: 마법 망토 (각인)", "ordinary messages are unchanged")
	check(IDENTITY.particles("%s(을)(를) 획득" % "물약", "물약") == "물약을 획득", "batchim takes 을")
	check(IDENTITY.particles("%s(을)(를) 획득" % "상자", "상자") == "상자를 획득", "no batchim takes 를")
	check(IDENTITY.item_class_id({"source_item_class_id":305}) == 305, "explicit ItemClass ID")
	check(IDENTITY.item_class_id({"sourceId":"m523:item:6161"}) == 6161, "m523 source id")
	check(IDENTITY.item_class_id({}, "공성 포인트 · 원본#195371@@@ab") == 195371, "the key suffix names the ItemClass")
	var bag: Control = BAG.new()
	check(bag._status_badges({"engraved":true}, "체력 회복제 (각인)") == "", "no ◆ mark before engraved names")
	bag.free()
	var missing: Dictionary = ICON_STATUS.check(false, {"root":"/nonexistent/images","sha256":"0".repeat(64)})
	check(not missing.ok and ICON_STATUS.label(missing) == "아이템 아이콘 리소스 없음(팩 재설치 필요)", "a missing icon pack is announced")
	check(not ICON_STATUS.check(false, {"root":"","sha256":""}).ok, "no image selection is not ok")

func sources() -> void:
	var hud: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	# The grant tools stay on the phone's playtest APK (user 2026-11-20 "검수용
	# 아이템지급 버튼은 일단 살려"); only verification text is developer-only.
	check(hud.contains("catalog_test_toggle.visible = category == \"아이템\" and catalog_grant_tools_visible()") and hud.contains("func catalog_grant_tools_visible() -> bool:\n\treturn playtest_tools_enabled()\n"), "the 검수용 지급 도구 button follows the playtest APK, not developer UI")
	for gate: String in ["catalog_test_tools.visible = enabled and catalog_grant_tools_visible()", "if catalog_grant_tools_visible(): playtest_catalog_grant_requested.emit(grant_name,10)", "if not catalog_grant_tools_visible() or catalog_category != \"아이템\"", "if catalog_grant_tools_visible(): playtest_aden_grant_requested.emit()"]:
		check(hud.contains(gate), "grant tool gate: " + gate)
	check(hud.contains("if developer: catalog_detail.text += \"\\n\\n\" + UI.safe(preload(\"res://scripts/loot/patch523_monster_drops.gd\").source_text("), "drop-source lines are developer-only")
	var flags: String = FileAccess.get_file_as_string("res://scripts/boot/build_flags.gd")
	check(flags.contains("static func developer_ui() -> bool:\n\treturn OS.is_debug_build() or OS.has_feature(DEV_UI_FEATURE)"), "the playtest feature alone does not show developer UI")
	var gear: String = FileAccess.get_file_as_string("res://scripts/quests/quest_equipment523.gd")
	check(gear.contains("var converted: Dictionary=convert_held(world,id)") and gear.contains("static func convert_held("), "held quest gear without the view becomes the ordinary original item")
	var world: String = FileAccess.get_file_as_string("res://scripts/world.gd")
	check(world.contains("acquire_text(shown_name, quantity)") and not world.contains("hud.append_log(\"%s ×%d 습득\" % [item_name, quantity])"), "pickups use the original acquisition text")
	var loading: String = FileAccess.get_file_as_string("res://scripts/boot/loading_screen.gd")
	var option: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_option_window.gd")
	check(loading.contains("ICON_STATUS.check(false)") and option.contains("item_icon_resource_status.gd\").check(true)"), "loading screen and 설정 정보 show the icon resource status")
	var floor: String = FileAccess.get_file_as_string("res://scripts/loot/ground_loot.gd")
	check(not floor.contains("\"원본 지면 표시 대기\"") and not floor.contains("523 드랍원"), "no developer text on floor items")

func installed() -> void:
	if SOURCE.not_installed():
		evidence["tables"] = "523 tables not installed: identity part skipped"
		return
	evidence["tables"] = "installed"
	check(IDENTITY.item_class_id({"name":"각인 장비 상자"}) == 6161, "a legacy name row finds its original ItemClass (각인 장비 상자 #6161)")
	check(IDENTITY.item_class_id({}, "공성 포인트") == 195371, "공성 포인트 by original name")
	check(IDENTITY.item_class_id({"name":"마법 망토 (각인)"}) > 0, "several rows with one picture still resolve")
	check(IDENTITY.item_class_id({"name":"존재하지 않는 아이템 이름"}) == -1, "an unknown name has no identity")
	check(IDENTITY.original_name(305) == "마법 망토 (각인)", "original DescData name of #305")
	var held: Dictionary = {"name":"[원본 보상] [방어구-망토] 마법 망토 (각인)","source_item_class_id":305,"source_display_name":"[방어구-망토] 마법 망토 (각인)"}
	check(IDENTITY.display_name(held, "[원본 보상] [방어구-망토] 마법 망토 (각인)") == "마법 망토 (각인)", "a held reward shows its original name, not ItemClass.Name")
	var text: String = IDENTITY.acquire_text("각인 장비 상자", 1)
	evidence["acquire"] = [text, IDENTITY.acquire_text("공성 포인트 · 원본#195371", 3)]
	check(text == "각인 장비 상자를 획득하였습니다.", "original UITextData 16771 acquisition text")
	check(IDENTITY.acquire_text("공성 포인트 · 원본#195371", 3) == "공성 포인트 3개를 획득하였습니다.", "original UITextData 16781 with the count")
	if not IMAGES.selected():
		evidence["images"] = "image pack not selected: icon part skipped"
		return
	for name: String in ["각인 장비 상자", "공성 포인트"]:
		var info: Dictionary = IMAGES.describe_item({"name":name,"grade":"일반","type":"기타","slot":"other"}, name)
		evidence[name] = {"status":str(info.get("status","")),"reason":str(info.get("reason","")),"path":str(info.get("path","")),"id":int(info.get("item_class_id",-1))}
		check(IMAGES.handles_item({"name":name}) and info.get("status") == "original_linked" and info.get("texture") is Texture2D, "%s (legacy name row) draws its original icon" % name)
	var reward: Dictionary = IMAGES.describe_item(held, held.name)
	evidence["held"] = {"status":str(reward.get("status","")),"reason":str(reward.get("reason",""))}
	check(reward.get("status") == "original_linked", "a held quest reward draws its original icon")
