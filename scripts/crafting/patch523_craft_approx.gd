extends RefCounted
## TWILIGHT 근사 2026-11-16 — the original 523 crafts that the tables alone
## cannot admit, opened with researched approximations (user policy "원본
## 데이터에 없는 건 검색 후 근사치로 적용", "근사치로 다 넣어"). Original values
## win wherever present; every rule here is listed in
## docs/PATCH523_CRAFTING_EQUIPMENT.md ("TWILIGHT 근사 2026-11-16 — 남은 제작식").
## Shared by the projection (patch523_rules_projection.gd), the frozen cold-bake
## reference (tests/fixtures/rules_cold_legacy/legacy_projection.gd) and the
## runtime contract (patch523_rules.gd).
const DATE = "2026-11-16"

## ── 성공 페이백 (ItemCraftOutputTypeID 12) ──────────────────────────────────
## TWILIGHT 근사 (근거 약함): output rows of type 12 carry Probability 0 and the
## original output DescID 973942 "성공 페이백"; 22/32/42 are "실패 페이백",
## "페이백", "대성공 페이백" (DescData_Korean). No public page states the
## payout; on a guaranteed craft the payback is given with the result on every
## success (the main result always + the payback item, e.g. 각성서 제작 →
## 상급 축복의 가루 N). Search: https://www.inven.co.kr/board/lineagem/5019/736148
## (no rule found). Only type 12 on an AlwaysSuccess craft is opened.
const PAYBACK_TYPE = 12

## {core: rows without payback, payback: [type-12 rows]} of a guaranteed
## craft's outputs; payback stays empty unless exactly one success row of
## Probability 1,000,000 remains and every other row is a type-12 row of
## Probability 0 without clan fields.
static func payback_split(outs: Array) -> Dictionary:
	var core: Array = []; var payback: Array = []
	for row: Dictionary in outs:
		if int(row.get("ItemCraftOutputTypeID",-1)) == PAYBACK_TYPE and int(row.get("Probability",-1)) == 0 and int(row.get("ClanItemClassID",0)) == 0 and int(row.get("ClanAmount",0)) == 0: payback.append(row)
		else: core.append(row)
	if payback.is_empty() or core.size() != 1 or int(core[0].get("ItemCraftOutputTypeID",-1)) != 1 or int(core[0].get("Probability",-1)) != 1000000: return {"core":outs,"payback":[]}
	return {"core":core,"payback":payback}

## ── 혈맹 결과 (ClanItemClassID / ClanAmount) ────────────────────────────────
## TWILIGHT 근사: in the live game the clan fields are paid into the crafter's
## clan; TWILIGHT is single player and clan523 has no clan storage
## (scripts/clan523/clan523.gd: creation, donation, buff only), so the clan
## share is given to the player with the result ("혈맹 몫 · 본인 지급").
## ClanItemBlessCodeID 0 is given as normal (1).
static func clan_rows(outs: Array) -> Array:
	var result: Array = []
	for row: Dictionary in outs:
		if int(row.get("ClanItemClassID",0)) == 0 and int(row.get("ClanAmount",0)) == 0: continue
		var bless: int = int(row.get("ClanItemBlessCodeID",1))
		result.append({"ID":row.get("ID"),"ItemClassID":row.get("ClanItemClassID"),"Amount":row.get("ClanAmount"),"Enchant":row.get("ClanEnchant",0),
			"ItemBlessCodeID":float(bless if bless in [1,2] else 1),"ItemHoningEpithetID":0.0,"twilight_clan_row":true})
	return result

## A bonus output (payback / clan share) of a recipe, as the runtime grants it.
static func bonus(row: Dictionary, record: Dictionary, kind: String, physical: bool) -> Dictionary:
	return {"item":record.name,"source_id":str(int(row.ItemClassID)),"quantity":int(row.Amount),"level":int(row.Enchant),"bless_code":int(row.ItemBlessCodeID),
		"physical":physical,"kind":kind,"source_row_id":int(row.ID),"label":"성공 페이백" if kind == "payback" else "혈맹 몫 · 본인 지급"}

## ── ServerLimit 행이 없는 서버 세트 ───────────────────────────────────────────
## TWILIGHT 근사: a ServerLimitSetID with no ServerLimit row at all (set 274 in
## 523) names no server; it is treated as the KR 1 offline profile. Sets whose
## rows name only other servers stay deleted (사용자 결정 2026-11-16).
static func empty_server_set_allows(profile: Dictionary) -> bool:
	return str(profile.get("ServiceRegionCode","")) == "KR" and int(profile.get("WorldNo",-1)) == 1

## ── 품목 조건: TestItem 재료·결과 ─────────────────────────────────────────────
## TWILIGHT 근사: an original craft row naming a TestItem=true item (that no
## source can ever give offline) uses the non-test item of the same display
## name and ItemCategory instead. "exact": same display name; "variant" (근거
## 약함): the same name without/with a 각인·이벤트·시련의 탑 suffix. Computed
## from DescData_Korean/ItemClass (523) — the original test row stays in the
## source and every craft is joined again with this table at quote/execute.
const TEST_ITEM_SUBSTITUTES := {
	113892:549,     # 드래곤의 다이아몬드 (각인) → 드래곤의 다이아몬드 (variant)
	289922:549,     # 드래곤의 다이아몬드 (각인) → 드래곤의 다이아몬드 (variant)
	113902:124342,  # 드래곤의 고급 다이아몬드 (각인) (exact)
	123563:134742,  # 판금 제작 재료 상자 (exact)
	1034:268222,    # [변신 카드] 천상의 기사 (exact)
	982:268252,     # [마법인형 카드] 사이클롭스 (exact)
	232332:230692,  # [마법인형 카드] 골렘 수호자 (exact)
	1057:167723,    # [변신 카드] 다이노스 타자 → (이벤트) (variant)
	1058:167733,    # [변신 카드] 다이노스 투수 → (이벤트) (variant)
	122122:136144,  # 수호의 인장 교환 증서 → (시련의 탑) (variant)
	131621:138921,  # 인장 교환 증서 → (이벤트) (variant)
	265778:226121,  # 드래곤의 다이아몬드 상자 → (이벤트) (variant)
}

## {original id: substitute id} for the rows' TestItem items with a valid
## substitute (original TestItem true, substitute TestItem false, same
## CategoryID). `row_of` returns the ItemClass row of an id ({} if none).
static func substitutes_for(rows: Array, row_of: Callable) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		var id: int = int(row.get("ItemClassID",0))
		if not TEST_ITEM_SUBSTITUTES.has(id) or result.has(id): continue
		var original: Dictionary = row_of.call(id)
		var substitute: Dictionary = row_of.call(int(TEST_ITEM_SUBSTITUTES[id]))
		if original.get("TestItem") == true and substitute.get("TestItem") == false and not substitute.is_empty() and int(original.get("CategoryID",-1)) == int(substitute.get("CategoryID",-2)):
			result[id] = int(TEST_ITEM_SUBSTITUTES[id])
	return result

## Copies of `rows` with substituted ItemClassIDs (numbers keep their type).
static func substitute_rows(rows: Array, substitutes: Dictionary) -> Array:
	if substitutes.is_empty(): return rows
	var result: Array = []
	for row: Dictionary in rows:
		var id: int = int(row.get("ItemClassID",0))
		if substitutes.has(id):
			var copy: Dictionary = row.duplicate()
			copy.ItemClassID = float(substitutes[id]) if typeof(row.ItemClassID) == TYPE_FLOAT else int(substitutes[id])
			result.append(copy)
		else: result.append(row)
	return result

## ── 품목 조건·상태 (행 보정) ─────────────────────────────────────────────────
## TWILIGHT 근사, applied to the original rows of one craft until no row of the
## kinds below blocks it (each recorded as row_overrides, joined again at
## quote/execute):
##   test_input_dropped      a TestItem input without substitute (no source
##                           gives it offline) is left out — only when another
##                           input remains ("TestItem 무시"). A test result
##                           keeps the craft out (the item cannot exist).
##   honing_epithet_ignored  an input's ItemHoningEpithetID (연마 칭호) is not
##                           required (근거 약함).
##   stack_state_normal      a stack/non-equipment row with Enchant > 0, or a
##                           blessed/cursed stack whose variant is not in the
##                           catalog, is used as the normal +0 stack (근거 약함:
##                           a blessed scroll result is given as normal).
## ClassID 0 in ItemClassLimit (망자의 혼) is read as "every class".
const OVERRIDE_FIELDS := {"Enchant":0,"ItemBlessCodeID":1,"ItemHoningEpithetID":0}

static func _tuple(row: Dictionary) -> Array:
	return [int(row.get("ItemClassID",0)),int(row.get("Amount",0)),int(row.get("Enchant",0)),int(row.get("ItemBlessCodeID",0))]

static func _with_fields(row: Dictionary, fields: Dictionary) -> Dictionary:
	var copy: Dictionary = row.duplicate()
	for key: String in fields: copy[key] = float(fields[key]) if typeof(row.get(key)) == TYPE_FLOAT else fields[key]
	return copy

## Applies {"in:<ID>"|"out:<ID>": {"drop":true} | {field: value}} to the rows.
## Views that showed an overridden result row follow it. {} when an override
## is not of an allowed form (the caller refuses the craft).
static func apply_overrides(views: Array, ins: Array, outs: Array, overrides: Dictionary, item_row: Callable) -> Dictionary:
	var result: Dictionary = {"views":views.duplicate(),"ins":[],"outs":[]}
	for key: String in overrides:
		var change: Variant = overrides[key]
		if not change is Dictionary or change.is_empty() or not (key.begins_with("in:") or key.begins_with("out:")): return {}
		for field: String in change:
			if field == "drop":
				if change.size() != 1 or change.drop != true or not key.begins_with("in:"): return {}
			elif not OVERRIDE_FIELDS.has(field) or int(change[field]) != int(OVERRIDE_FIELDS[field]): return {}
	var seen: int = 0
	for pair: Array in [["in:",ins,"ins"],["out:",outs,"outs"]]:
		for row: Dictionary in pair[1]:
			var key: String = str(pair[0])+str(int(row.get("ID",0)))
			if not overrides.has(key): result[pair[2]].append(row); continue
			seen += 1
			var change: Dictionary = overrides[key]
			if change.has("drop"):
				if item_row.call(int(row.ItemClassID)).get("TestItem") != true: return {}
				continue
			var copy: Dictionary = _with_fields(row,change)
			if pair[2] == "outs":
				for index: int in result.views.size():
					if _tuple(result.views[index]) == _tuple(row): result.views[index] = _with_fields(result.views[index],change)
			result[pair[2]].append(copy)
	if seen != overrides.size(): return {}
	return result

## Fixes the blocking rows (kinds above) one at a time with the projection's
## own item check. Returns {views, ins, outs, overrides, kinds}.
static func fix_rows(views: Array, ins: Array, outs: Array, item_reason: Callable, item_row: Callable) -> Dictionary:
	var overrides: Dictionary = {}; var kinds: Dictionary = {}
	var state: Dictionary = {"views":views,"ins":ins,"outs":outs}
	for attempt: int in 64:
		var found: Dictionary = item_reason.call(state.ins,state.outs)
		if found.is_empty(): break
		var id: int = int(found.get("item_id",0))
		var reason: String = str(found.get("reason",""))
		# The first row of the blocking item that is not fixed yet (else the first).
		var row: Dictionary = {}; var prefix: String = ""; var fallback: Array = []
		for pair: Array in [["in:",state.ins],["out:",state.outs]]:
			for candidate: Dictionary in pair[1]:
				if int(candidate.get("ItemClassID",0)) != id: continue
				if fallback.is_empty(): fallback = [candidate,pair[0]]
				if row.is_empty() and not overrides.has(str(pair[0])+str(int(candidate.get("ID",0)))): row = candidate; prefix = pair[0]
		if row.is_empty() and not fallback.is_empty(): row = fallback[0]; prefix = fallback[1]
		if row.is_empty() or int(row.get("ID",0)) <= 0: break
		var change: Dictionary = {}
		if reason == "unresolved_item_state" and int(row.get("ItemHoningEpithetID",0)) != 0 and prefix == "in:":
			change = {"ItemHoningEpithetID":0}; kinds["honing_epithet_ignored"] = true
		elif reason == "unresolved_item_condition" and prefix == "in:" and item_row.call(id).get("TestItem") == true:
			var others: int = 0
			for candidate: Dictionary in state.ins:
				if candidate != row and int(candidate.get("ItemClassID",0)) != 26 and item_row.call(int(candidate.ItemClassID)).get("TestItem") == false: others += 1
			if others == 0: break
			change = {"drop":true}; kinds["test_input_dropped"] = true
		elif reason in ["stack_state_cannot_be_represented","non_equipment_state_unrepresented"] and (int(row.get("Enchant",0)) != 0 or int(row.get("ItemBlessCodeID",1)) != 1):
			change = {"Enchant":0,"ItemBlessCodeID":1}; kinds["stack_state_normal"] = true
		else: break
		var key: String = prefix+str(int(row.ID))
		var merged: Dictionary = overrides.get(key,{}).duplicate()
		var before: int = merged.size()
		merged.merge(change,true)
		if overrides.has(key) and (merged.size() == before or merged.has("drop")): break # nothing new: stop
		var next: Dictionary = apply_overrides(views,ins,outs,_merged(overrides,key,merged),item_row)
		if next.is_empty(): break
		overrides = _merged(overrides,key,merged); state = next
	return {"views":state.views,"ins":state.ins,"outs":state.outs,"overrides":overrides,"kinds":kinds.keys()}

static func _merged(overrides: Dictionary, key: String, change: Dictionary) -> Dictionary:
	var result: Dictionary = overrides.duplicate(true)
	result[key] = change
	return result

## ── 카탈로그 정체 (다른 소유자 기록) ─────────────────────────────────────────
## TWILIGHT 근사: 3252 마법인형 제작 코인 is paid from / credited to its coin
## wallet like 아데나 (the wallet already exists: patch523_item_inventory
## COIN_WALLETS, data/crafting/patch523_crafting_policy.json
## source_currency_bindings "3252").
const WALLET_MATERIALS := {3252:"마법인형 제작 코인"}
const WALLET_ORIGIN := "TWILIGHT 근사 2026-11-16: 원본 #3252를 마법인형 제작 코인 지갑으로 정산"
