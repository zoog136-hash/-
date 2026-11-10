extends SceneTree
const Data=preload("res://scripts/cards/patch523_slot_data.gd")
const API=preload("res://scripts/lineagem_base508.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Unlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
var checks: int=0
var errors: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func run() -> void:
	var expected_missing: bool="--expect-missing" in OS.get_cmdline_user_args()
	check(Data.installed()!=expected_missing,"explicit verified support pack availability")
	var catalog: Dictionary=API.apply_catalog({});var total: int=0
	for category: String in Cards.CATEGORIES:total+=catalog[category].size()
	check(total==720,"missing/invalid optional support never removes the720 catalog")
	var core=Cards.new();core.configure(catalog)
	check(core.owned.values().all(func(rows: Dictionary) -> bool:return rows.is_empty()),"reading pack never grants ownership")
	check(core.spare.values().all(func(rows: Dictionary) -> bool:return rows.is_empty()),"reading pack never grants duplicates")
	if expected_missing:
		check(not Data.problem.is_empty() and Unlock.record().is_empty(),"missing/wrong hash exposes reason and installs no unlock item")
		check(not Unlock.source_rules_valid(),"unavailable data cannot authorize a source item consumption")
		var service=preload("res://scripts/cards/option_awakening_service.gd").new()
		var adapted: Dictionary=preload("res://scripts/cards/native_option_awakening.gd").adapt(JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/option_awakening_cards.json")),catalog)
		check(service.configure(adapted,JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/option_awakening_policy.json")),catalog),"existing option runtime remains configured without optional pack")
		var saved: Dictionary=service.fresh_state();saved["native_relic_subslot_identity"]="source:m508:98:20578"
		var before: int=hash(saved)
		check(service.validate_state(saved).contains(Data.problem) and hash(saved)==before,"missing optional source protects an existing selected-slot save without rewriting it")
	else:
		check(Data.new_cards.skill_cards.size()==16 and Data.relic_card_keys().size()==147,"only reviewed support profiles and147 exact relic keys")
		check(Unlock.source_rules_valid(),"verified typed unlock contract loaded")
	print("PATCH523_SLOT_PACK ",JSON.stringify({"checks":checks,"errors":errors,"missing_fixture":expected_missing}));quit(0 if errors.is_empty() else 1)
