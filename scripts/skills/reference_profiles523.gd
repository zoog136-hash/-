extends RefCounted
## Publicly described skills use the ordinary TWILIGHT execution modes.
## This catalog only fills a missing runtime. A bound native profile still
## supplies its own verified learning conditions, material count and identity.
const DATA = preload("res://scripts/resources/built_in_startup_data.gd")
const PATH := "res://data/skills/reference_profiles523.json"
const MODES := ["attack", "status", "buff", "counter", "stealth", "detect", "heal",
	"convert", "teleport", "taunt", "toggle_proc", "summon", "stats", "proc", "upgrade"]
## Reviewed 523 TargetKindID 52 (PCButMe) bindings for fallback candidates
## and their bases. Canonical IDs also apply with the definition pack absent.
const OTHER_PLAYER_REFERENCE523 := {
	"lmref_d8b163f67b016204":53972, "lmref_118e8fcbce796ace":87448,
	"lmref_63985e6f425023b4":55594, "lmref_ef01381b531dbca0":45132,
	"lmref_8ae2c6ee03a988e5":343, "lmref_16336f795d95bd55":91,
	"lmref_cabe1f7751a9de94":337, "lmref_0f6716fc637ac929":47422,
	"lmref_40b6a0c2b8afe497":47392, "lmref_dfbd818ce40011d7":6641,
	"lmref_7589512308d91630":6223, "lmref_c92955afa1bfc843":34912,
	"lmref_096abac2369747bf":89152, "lmref_5ec0d0d5b9ca30cc":41531,
	"lmref_449b0ee31564e7cd":118114, "lmref_8a6f583a9b442edd":41641,
	"lmref_58505159dcc7cb3f":48671, "lmref_624f29271aa2d434":62674,
	"lmref_7f058dc15efcccd3":95192,
	# Existing Side Grab remains playable through its approved route. The
	# separate Requiem fallback must not extend it without the original pack.
	"lm_ad6488f0cedbc544":62684,
}
const LOCAL_REAGENT_PRICES := {"영혼석":75, "명예 코인":110, "신성석":85, "마력의 돌":80,
	"정령옥":65, "흑요석":75, "정제석":65, "정제석 조각":40, "인장석":75, "혈정석":75,
	"흑마법 결정체":80, "번개석":80, "에테르 결정체":80}

static func profiles() -> Dictionary:
	var value: Variant = DATA.read_json(PATH)
	return value.get("skills", {}) if value is Dictionary and value.get("schema") == 1 else {}

static func install(record: Dictionary, entry: Dictionary, catalog) -> void:
	if entry.is_empty():
		if record.id == "lm_86d332ddfb0de110":
			record["reference_visual523"] = {"shape":"scythe","color":"#e0b4ff"}
		elif bool(record.get("local_design", false)):
			var shape: String = {"aqua_heal":"heal","prison":"bind","guardian":"rune","pride":"guard",
				"berserk":"guard","wings":"guard","bloody":"scythe","shooting":"round","dignity":"bolt"}.get(str(record.get("local_kind","")), "guard")
			record["reference_visual523"] = {"shape":shape,
				"color":str({"heal":"#9becc0","guard":"#ecd581","bind":"#7bb5ff","rune":"#77dbea","scythe":"#eb8c96","round":"#ecbc74","bolt":"#87b8f7"}.get(shape, "#81c7e8"))}
		return
	var id: String = str(record.id)
	var source: Dictionary = catalog.source523.profiles.get(id, {})
	var required: String = str(entry.get("requires", ""))
	var blocked: bool = bool(record.get("runtime_blocked", false))
	if _other_player_target(id, source):
		if blocked: record["reference_offline_hold523"] = "원본은 다른 플레이어 대상입니다."
		return
	if entry.get("runtime", {}).get("mode") == "upgrade" and not required.is_empty():
		if _other_player_target(required, catalog.source523.profiles.get(required, {})):
			if blocked: record["reference_offline_hold523"] = "다른 플레이어 대상인 선행 스킬을 강화합니다."
			return
	record["reference_visual523"] = entry.get("visual", {})
	if not blocked: return
	var runtime: Dictionary = entry.get("runtime", {}).duplicate(true)
	if not MODES.has(str(runtime.get("mode", ""))) or int(entry.get("level", 0)) <= 0: return
	for key: String in ["mp","hp","cooldown","duration"]:
		if not runtime.has(key): runtime[key] = 0
	if required == id or (not required.is_empty() and not catalog.by_id.has(required)): return
	if runtime.mode == "upgrade" and required.is_empty(): return
	if not _apply_verified_cost(runtime, source, catalog.source523): return
	var relation: Dictionary = catalog.relations.get(id, {}).duplicate(true)
	if not required.is_empty(): relation["requires_skill"] = [required]
	if runtime.mode == "upgrade":
		relation["upgrades_from"] = required
		relation["patch"] = entry.get("upgrade", {}).duplicate(true)
	if not relation.is_empty(): catalog.relations[id] = relation
	record.merge(runtime, true)
	record["reference_approx523"] = true
	record["runtime_blocked"] = false
	record["minimum_level"] = int(entry.level)
	record["activation"] = "passive" if runtime.mode in ["stats", "proc", "upgrade"] else "active"
	record["local_kind"] = "reference_approx523"
	record["origin"] = "LINEAGEM_CURRENT_LOCAL_20261029"
	record["desc"] = "TWILIGHT 근사 · " + str(entry.get("summary", ""))
	record["runtime_desc"] = record.desc
	record["book_name"] = "스킬 교본 · %s (%s)" % [str(record.name), str(record["class"])]
	record["book_cost"] = 1000 + 450 * int(entry.level)
	record["class_costs"] = {}
	record["class_learning_levels"] = {}
	record["class_references"] = {}
	for fact: Dictionary in record.get("class_observations", []):
		var job: String = str(fact.get("class", ""))
		var label: String = str(fact.get("level_display", ""))
		if job.is_empty() or not label.is_valid_int() or int(label) <= 0: continue
		record.class_learning_levels[job] = int(label)
		record.class_references[job] = fact
		if not source.is_empty() or record.activation == "passive": continue
		var costs: Dictionary = {}
		for field: String in ["mp", "hp"]:
			var shown: String = str(fact.get(field + "_display", ""))
			if shown.is_valid_int(): costs[field] = maxi(0, int(shown))
		if not costs.is_empty(): record.class_costs[job] = costs
	record.erase("source_direct523_hold")

static func _other_player_target(id: String, source: Dictionary) -> bool:
	return (OTHER_PLAYER_REFERENCE523.has(id)
		or int(source.get("row", {}).get("TargetKindID", 0)) == 52
		or str(source.get("target_kind", {}).get("Name", "")) in ["PCButMe", "PCButCompany"])

static func _apply_verified_cost(runtime: Dictionary, source: Dictionary, adapter) -> bool:
	if source.is_empty() or str(runtime.mode) in ["stats", "proc", "upgrade"]: return true
	var row: Dictionary = source.get("row", {})
	if bool(row.get("TestSpell", true)): return false
	# Keep valid absolute costs. Conditional fees still use the documented
	# public self/target approximation and are never converted into native rows.
	if int(row.get("MPCostUnit", 0)) == 1: runtime["mp"] = maxi(0, int(row.get("MPCost", 0)))
	runtime["hp"] = maxi(0, int(row.get("HPCost", 0)))
	if int(row.get("CastDelay", 0)) > 0: runtime["cooldown"] = float(row.CastDelay) / 1000.0
	var count: int = int(row.get("SpellMaterialItemAmount", 0))
	if count <= 0:
		if runtime.mode != "toggle_proc" and source.get("costs", []).is_empty():
			var items: Dictionary = runtime.get("items", {})
			for key: String in items.keys():
				if LOCAL_REAGENT_PRICES.has(key): items.erase(key)
		return true
	var material_type := str(int(row.get("SpellMaterialTypeID", 0)))
	var bridge: Dictionary = adapter.bindings.get("material_inventory_keys", {}).get(material_type, {})
	var item: String = str(bridge.get("inventory_key", ""))
	if item.is_empty() or adapter.material_holds.has(material_type): return false
	var field := "proc_items" if runtime.mode == "toggle_proc" else "items"
	if not runtime.has(field): runtime[field] = {}
	runtime[field][item] = count
	runtime["reference_native_material"] = material_type
	return true

static func local_item_name(skill: Dictionary, item: String) -> String:
	if not bool(skill.get("reference_approx523", false)) or skill.has("reference_native_material"): return item
	if not LOCAL_REAGENT_PRICES.has(item): return item
	return "스킬 재료 · " + item

static func local_reagent_quote(skill: Dictionary) -> Dictionary:
	var cost: Dictionary = skill.get("proc_items", {}) if skill.get("mode") == "toggle_proc" else skill.get("items", {})
	var items: Dictionary = {}
	var price := 0
	for item: String in cost:
		var key := local_item_name(skill, item)
		if key == item: continue
		var count := int(cost[item]) * 10
		items[key] = count
		price += count * int(LOCAL_REAGENT_PRICES[item])
	return {"items":items, "price":price}

static func buy_reagents(catalog, record: Dictionary) -> bool:
	if not catalog.permitted(record) or catalog.level_locked(record): return false
	var world: Node = catalog.world
	var quote := local_reagent_quote(catalog.resolve(record))
	if quote.items.is_empty() or world.gold < int(quote.price): return false
	var previous: Dictionary = {}
	for key: String in quote.items:
		previous[key] = int(world.inventory.get(key, 0))
		world.inventory[key] = int(previous[key]) + int(quote.items[key])
	world.gold -= int(quote.price)
	if world._save_game(true) != OK:
		world.gold += int(quote.price)
		for key: String in previous:
			if int(previous[key]) > 0: world.inventory[key] = previous[key]
			else: world.inventory.erase(key)
		world.hud.show_message("스킬 재료 구입 저장 실패")
		return false
	world._update_hud()
	world.hud.show_message("스킬 재료 구입")
	return true
