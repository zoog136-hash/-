extends SceneTree
## User list 2026-11-26 #14: bag slots stayed empty for items TWILIGHT still
## issues whose 523 row is a TestItem (cash-package 빛나는 무기·갑옷 마법
## 주문서 상자 #97314/#97304, arc transform cards, " · 원본#N" keys) and for
## game-local names (화살, 귀환 주문서, 하프 엘릭서 ...). A held record shows its
## own IconID; local names get a reviewed TWILIGHT 근사 original icon. ID lists
## (rewards, NPC goods, item book) keep excluding TestItem rows.
##   godot --headless --path <repo> --script res://tests/held_item_own_icon_test.gd [-- --source523-pack=<root>]
const IDENTITY = preload("res://scripts/ui/source523_item_identity.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const LOCAL: Array[String] = ["화살", "총알", "귀환 주문서", "마나 회복 물약", "MP 회복 물약", "힘센 한우 스테이크",
	"날쌘 연어 찜", "영리한 칠면조 구이", "전투 강화의 주문서", "드래곤의 고급 다이아몬드",
	"축복받은 무기 마법 주문서 (각인)", "축복받은 갑옷 마법 주문서 (각인)", "축복받은 오림의 장신구 마법 주문서 (각인)",
	"속성 변경 주문서", "속성 초기화 주문서", "하프 엘릭서 (근거리)", "하프 엘릭서 (원거리)", "하프 엘릭서 (마법)",
	"최상급 변신 뽑기권 11회 팩", "최상급 마법인형 뽑기권 11회 팩", "최상급 성물 뽑기권", "최상급 성물 뽑기권 11회 팩"]
## Held TestItem rows from the census (cash package boxes, arc cards).
const HELD_TEST: Array[int] = [97304, 97314, 97424, 1067, 125502, 124562, 130631, 97434]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		printerr("HELD_ITEM_OWN_ICON_FAIL: " + label)
	return value

func _initialize() -> void:
	static_part()
	installed()
	print("HELD_ITEM_OWN_ICON_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)

func static_part() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(IDENTITY.ICON_IDENTITY_PATH))
	var approx: Dictionary = parsed.get("approx", {}) if parsed is Dictionary else {}
	for name: String in LOCAL:
		var entry: Variant = approx.get(name)
		check(entry is Dictionary and int(entry.get("item_class_id", 0)) > 0 and entry.get("basis") == "twilight_approx_reviewed_same_kind", "%s has a reviewed TWILIGHT 근사 icon" % name)
		check(IDENTITY.icon_identity({"name":name}).get("approximation") == true, "%s resolves as an approximation, not an original identity" % name)
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/source523_image_assets.gd")
	check(source.contains("static func describe_item(record") and source.contains("source_test_item_own_icon") and source.contains("_describe_owned_item("), "held records read their own IconID after the TestItem exclusion")

func installed() -> void:
	if SOURCE.not_installed() or not IMAGES.selected():
		evidence["installed"] = "523 tables/image pack not selected: pixel part skipped"
		return
	var shown: int = 0
	for id: int in HELD_TEST:
		var held: Dictionary = IMAGES.describe_item({"name":"검증 #%d" % id, "source_item_class_id":id, "source":"twilight-cash-package-item"}, "")
		var listed: Dictionary = IMAGES.describe_item_class(id)
		var own: Dictionary = IMAGES.resolve_consumer("ItemClass", id, "IconID")
		var ok: bool = held.get("source_test_item_own_icon") == true and (held.get("status") == "original_linked" and held.get("texture") is Texture2D and held.texture == own.get("texture") or held.get("reason") == "unsupported_csb")
		check(ok, "held #%d shows its own original IconID" % id)
		check(listed.get("reason") == "source_test_item_excluded" and listed.get("texture") == null, "ID list #%d keeps the TestItem exclusion" % id)
		if ok: shown += 1
	var local_linked: int = 0
	for name: String in LOCAL:
		var info: Dictionary = IMAGES.describe_item({"name":name}, name)
		var ok: bool = info.get("status") == "original_linked" and info.get("texture") is Texture2D and info.get("twilight_approximation") == true
		check(ok, "%s draws its TWILIGHT 근사 original icon" % name)
		if ok: local_linked += 1
	evidence["installed"] = {"held_test":shown, "local":local_linked}
