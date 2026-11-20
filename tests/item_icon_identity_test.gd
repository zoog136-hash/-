extends SceneTree
## Phone report 2026-11-20: bag slots stayed empty for names that are not an
## original Korean item name — 108 legacy catalog rows (드래곤의 다이아몬드
## 상자, 영웅급 스킬 상자(기사) ...), TWILIGHT-local crafting materials and
## gear (철 광석, 가죽 조각, 강철 활 ...) — and "다이아" showed as a bag slot.
## data/ui/item_icon_identity.json maps each name to one original ItemClass
## icon ("approx" = TWILIGHT 근사, kept as evidence only). Diamonds/mileage stay
## in the wallet.
##   godot --headless --path <repo> --script res://tests/item_icon_identity_test.gd [-- --source523-pack=<root>]
const IDENTITY = preload("res://scripts/ui/source523_item_identity.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const BAG = preload("res://scripts/ui/lineage_inventory_ui.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("ITEM_ICON_IDENTITY_FAIL: " + label)

func _initialize() -> void:
	synthetic()
	installed()
	print("ITEM_ICON_IDENTITY_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)

func _map() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(IDENTITY.ICON_IDENTITY_PATH))
	return parsed if parsed is Dictionary else {}

func synthetic() -> void:
	var map: Dictionary = _map()
	check(map.get("schema") == "twilight-item-icon-identity-v1", "the icon identity map loads")
	var exact: Dictionary = map.get("exact", {})
	var approx: Dictionary = map.get("approx", {})
	evidence["map"] = {"exact":exact.size(), "approx":approx.size()}
	for name: String in ["드래곤의 다이아몬드 상자", "고급 드래곤의 다이아몬드 상자", "영웅급 스킬 상자", "영웅급 스킬 상자(기사)", "전설급 스킬 상자(요정)", "힘의 카탈리스트", "빙령의 장갑", "조각난 힘의 룬", "기르타스의 검"]:
		check(exact.has(name), "%s has its own original item" % name)
	for name: String in ["철 광석", "동 광석", "가죽 조각", "약초", "천 조각", "정제된 목재", "마력 결정", "연마석", "미스릴 원석", "정령의 가루", "강철 활", "낡은 장검", "HP 물약", "용기의 수정"]:
		check(approx.has(name), "%s has a TWILIGHT 근사 original icon" % name)
	check(not exact.has("각인 장비 상자") and not approx.has("공성 포인트"), "names with an original Korean name keep that identity")
	var entry: Dictionary = IDENTITY.icon_identity({"name":"철 광석"})
	check(entry.get("approximation") == true and int(entry.get("item_class_id", 0)) == 379, "철 광석 -> original 철 (#379), marked as an approximation")
	check(IDENTITY.icon_identity({}, "드래곤의 다이아몬드 상자 · 축복").get("approximation") == false, "bless suffix and exact entries")
	check(IDENTITY.icon_identity({"source_item_class_id":305}, "철 광석").is_empty(), "an explicit original identity wins over the map")
	var bag: Control = BAG.new()
	bag.inventory = {"다이아":10000, "마일리지":5, "철 광석":36}
	bag.character_state = {"item_instances":{}}
	var names: Array = []
	for row: Dictionary in bag._inventory_entries(): names.append(row.name)
	evidence["bag"] = names
	check(names == ["철 광석"], "diamonds and mileage are wallet values, not bag slots")
	bag.free()

func installed() -> void:
	if SOURCE.not_installed() or not IMAGES.selected():
		evidence["images"] = "523 tables/image pack not selected: icon part skipped"
		return
	var map: Dictionary = _map()
	var missing: Array = []
	var linked: int = 0
	for group: String in ["exact", "approx"]:
		for name: String in map.get(group, {}):
			var info: Dictionary = IMAGES.describe_item({"name":name}, name)
			var ok: bool = IMAGES.handles_item({"name":name}) and (info.get("status") == "original_linked" and info.get("texture") is Texture2D or info.get("reason") == "unsupported_csb")
			if ok:
				linked += 1
				check(info.get("twilight_approximation") == (group == "approx"), "%s approximation mark" % name)
			elif missing.size() < 20: missing.append("%s:%s" % [name, info.get("reason", "")])
	evidence["linked"] = linked
	evidence["missing"] = missing
	check(missing.is_empty(), "every mapped name draws an original icon")
	var steel: Dictionary = IMAGES.describe_item({"name":"강철 활","grade":"고급","slot":"weapon"}, "강철 활")
	check(steel.get("status") == "original_linked" and steel.get("source_record_kind") == "item_icon_identity", "local gear draws an original icon")
	var girtas: Dictionary = IMAGES.describe_item({"name":"기르타스의 검"}, "기르타스의 검")
	check(girtas.get("reason") == "unsupported_csb", "an animated original icon goes to the original icon scene")
