extends RefCounted
## 원본 `LimitBuffCardID` (SpellLearnLimit / MerchantGoods) — "이 카드를 보유" 조건. TWILIGHT 근사,
## 지시 2026-11-16. docs/clan523_missing_rules.md 9·10, docs/skill523_source_hold_report.md.
## The tables name the card but not the check. Approximation (근거 약함): the condition holds
## while the player OWNS that original card (card_draw_fusion.owned, any copy). Six cards are
## used by the 523 learn rows; "신화변신" (#11152) is a placeholder card no player can own, so
## a placeholder card (one with no registered collection card) is read as "own any card of the
## same deck and grade" (신화 변신 카드 하나). Nothing is consumed.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const ENABLED := true
const DECKS := {1:"변신", 2:"마법인형", 98:"성물"}
## Placeholder cards (원본 이름 "신화변신"): any owned card of the same deck and grade.
const PLACEHOLDER_CARDS := [11152]

static func _identity_card(identity: String) -> Array:
	# "source:m508:<deck>:<card id>" (or m523).
	var parts: PackedStringArray = identity.split(":")
	if parts.size() < 4 or not parts[parts.size()-1].is_valid_int() or not parts[parts.size()-2].is_valid_int(): return []
	return [int(parts[parts.size()-2]), int(parts[parts.size()-1])]

static func _registered(world: Node, category: String, card_id: int) -> bool:
	for card: Variant in world.catalog_db.get(category, []):
		if card is Dictionary and int(card.get("source_card_id",0)) == card_id: return true
	return false

## True when the original card condition `card_id` holds (0 = no condition).
static func satisfied(world: Node, card_id: int) -> bool:
	if card_id == 0: return true
	if not ENABLED or world == null or world.get("card_draw_fusion") == null: return false
	var card: Dictionary = SOURCE.row("BuffCard", card_id)
	if card.is_empty(): return false
	var deck: int = int(card.get("BuffCardDeckID",0))
	if not DECKS.has(deck): return false
	var category: String = str(DECKS[deck])
	var owned: Dictionary = world.card_draw_fusion.owned.get(category, {})
	var placeholder: bool = card_id in PLACEHOLDER_CARDS or not _registered(world, category, card_id)
	for identity: Variant in owned:
		if owned[identity] != true: continue
		var pair: Array = _identity_card(str(identity))
		if pair.is_empty() or int(pair[0]) != deck: continue
		if int(pair[1]) == card_id: return true
		if placeholder and int(SOURCE.row("BuffCard", int(pair[1])).get("GradeID",-1)) == int(card.get("GradeID",-2)): return true
	return false

static func label(card_id: int) -> String:
	return str(SOURCE.row("BuffCard", card_id).get("Name", "#%d" % card_id))
