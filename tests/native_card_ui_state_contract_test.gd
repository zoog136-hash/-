extends SceneTree
const CARDS = preload("res://scripts/card_draw_fusion.gd")
const SOURCE = preload("res://scripts/lineagem_base508.gd")
const COLLECTIONS = preload("res://scripts/cards/collection_runtime.gd")
const AWAKEN = preload("res://scripts/cards/option_awakening_runtime.gd")
const AURA = preload("res://scripts/animation/source_awakening_aura.gd")
class Host extends Node:
	var catalog_db: Dictionary = SOURCE.cards()
	var card_draw_fusion = CARDS.new()
	func save_path() -> String: return "user://native-contract-not-written.json"
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1;push_error(label)
func _initialize() -> void:
	var host := Host.new()
	host.card_draw_fusion.configure(host.catalog_db)
	var collections := COLLECTIONS.new()
	check(collections.configure(host), "native collection runtime configures")
	var awake := AWAKEN.new()
	check(awake.configure(host), "existing awakening runtime configures")
	var card: Dictionary = {}
	for record: Dictionary in host.catalog_db.catalog["성물"]:
		if int(record.source_card_id) == 21518: card = record
	var identity: String = CARDS.card_id(card)
	check(identity == "source:m508:98:21518", "same exact UI/ownership/awakening identity")
	host.card_draw_fusion.owned["성물"][identity] = true
	collections.invalidate()
	var before: Dictionary = collections.totals.duplicate(true)
	var record_before: Dictionary = collections.stat_record().duplicate(true)
	var save: Dictionary = {"card_option_awakening":awake.export_state(), "card_draw_fusion":host.card_draw_fusion.export_state()}
	save.card_option_awakening.cards["성물"][identity] = AWAKEN.Core.fresh_card()
	save.card_option_awakening.cards["성물"][identity].awakened = true
	check(awake.prepare_load(save) and awake.accept_load(save), "exact native awakened flag restores through real save API")
	check(awake.source_visual_awakened("성물", card) and int(AURA.rule("성물",card).sprite_id) == 24748, "UI identity resolves conditional source VFX")
	collections.invalidate();collections.stat_record()
	check(collections.stat_record() == record_before, "native VFX flag does not fabricate blocked collection or legacy awakening bonus")
	var once: Dictionary = collections.stat_record().duplicate(true)
	collections.invalidate();collections.stat_record()
	check(collections.stat_record() == once, "repeated UI collection reads do not stack effects")
	check(host.card_draw_fusion.export_state() == save.card_draw_fusion, "collection/awakening readers preserve ledger")
	host.free()
	print("NATIVE_CARD_UI_STATE_CONTRACT failures=", failures)
	quit(0 if failures == 0 else 1)
