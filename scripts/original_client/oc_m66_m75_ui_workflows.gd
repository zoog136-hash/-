extends RefCounted
## M66 v2, M67 v2, M69 v2, M70 v2, M71 v2, M73 v2, M75 v2 (C17 and R66/R67/R69/R70/R71/R73/R75).
## DESIGN_NOT_RECOVERED_API. Guard and caller-continuation traces of selected UI workflows. A
## helper's early return is never widened into the caller's return; nothing done before a failed
## guard is rolled back. Request preparation is not a send/ACK; server trade/reward rules are not here.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

# ---- M66 craft --------------------------------------------------------------------------
const EVENT_213 := 213

## null slot vector vs present-empty vector are different. Present-empty goes to event213 and an
## empty-list request preparation. The null branch's outcome is not in this package.
static func craft_submit(slot_vector: Variant) -> Dictionary:
	if slot_vector == null:
		return V.rec("CraftSubmit", "M66", V.NOT_DESCRIBED, {"path": "NULL_SLOT_VECTOR", "events": [], "request": null})
	var items: Array = slot_vector
	var evidence: String = V.CONFIRMED if items.is_empty() else V.CONDITIONAL
	return V.rec("CraftSubmit", "M66", evidence, {"path": "PRESENT_VECTOR", "events": [EVENT_213], "request": {"items": items.duplicate(), "sent": false}})

# ---- M67 quest --------------------------------------------------------------------------
## missing Goal/Table ends refreshGoals (callee return). A valid parent detail continues to
## reward/story after that. The local147 goals-only consumer has no parent processing.
static func refresh_goals(goal_row: Variant, table_row: Variant) -> Dictionary:
	if goal_row == null or table_row == null:
		return {"steps": ["refreshGoals_end_missing"], "ended_early": true}
	return {"steps": ["refreshGoals_rows"], "ended_early": false}

static func quest_parent_detail(goal_row: Variant, table_row: Variant) -> Dictionary:
	var g: Dictionary = refresh_goals(goal_row, table_row)
	var steps: Array = g.steps.duplicate()
	steps.append_array(["reward", "story"])
	return V.rec("QuestParentDetail", "M67", V.CONFIRMED, {"steps": steps, "refresh_goals_ended_early": g.ended_early})

static func quest_goals_only_local147(goal_row: Variant, table_row: Variant) -> Dictionary:
	return V.rec("QuestGoalsOnly", "M67", V.CONFIRMED, {"steps": refresh_goals(goal_row, table_row).steps})

# ---- M69 chat ---------------------------------------------------------------------------
static func chat_row(dynamic_map_message: String) -> Dictionary:
	return {"dynamic_map": {"message": dynamic_map_message}, "cache730": null, "rich": null, "rich_builds": 0, "dirty": false}

## The retained DynamicMap message changes FIRST, then the formatter runs. An empty formatter result
## skips the rich rebuild only: +730 (first message cache) and the existing dirty state stay.
static func chat_update(row: Dictionary, message: String, formatter: Callable) -> Dictionary:
	var out: Dictionary = row.duplicate(true)
	out.dynamic_map.message = message
	var observed_by_formatter: String = ""
	var formatted: String = formatter.call(out)
	observed_by_formatter = str(out.dynamic_map.message)
	if out.cache730 == null:
		out["cache730"] = message
	if formatted != "":
		out["rich"] = formatted
		out["rich_builds"] = int(out.rich_builds) + 1
	return V.rec("ChatUpdate", "M69", V.CONFIRMED, {"row": out, "formatter_saw_message": observed_by_formatter, "rich_rebuilt": formatted != ""})

# ---- M70 card expedition ----------------------------------------------------------------
## spotID 0: helper 01FFC090 skips map/01FB7270/01FF25D0, but caller 024017F0 still runs per-card F9/FA.
static func expedition_refresh(spot_id: int, cards: Array) -> Dictionary:
	var trace: Array = []
	if spot_id != 0:
		trace.append_array(["helper_map", "helper_01FB7270", "helper_01FF25D0"])
	else:
		trace.append("helper_skipped_spot0")
	for c: Variant in cards:
		trace.append("card_%s_F9" % str(c))
		trace.append("card_%s_FA" % str(c))
	return V.rec("ExpeditionRefresh", "M70", V.CONFIRMED, {"trace": trace})

## state0 skips the setter; state3 reads the snapshot count as signed32.
static func expedition_state(state: int, raw_count: int) -> Dictionary:
	if state == 0:
		return {"setter_called": false}
	if state == 3:
		var n: int = V.i32(raw_count)
		return {"setter_called": true, "snapshot_count_i32": n, "iterations": maxi(n, 0)}
	return {"setter_called": V.NOT_DESCRIBED}

# ---- M71 card collection ----------------------------------------------------------------
## candidates: [{"id", "node_present": bool, "nd_card_present": bool, "grade_widget": bool}]
## Outer rows always push. Nd_Card missing or grade widget null skips only inner
## asset/style/addChild/radio. Name/colour/owned setters run when the node exists. Radio index 0 is
## the first CREATED radio, not the first row.
static func collection_rows(candidates: Array) -> Dictionary:
	var rows: Array = []
	var radios: Array = []
	var setters: Array = []
	for c: Dictionary in candidates:
		if bool(c.get("node_present", true)):
			setters.append(c.id)
		if bool(c.get("nd_card_present", true)) and bool(c.get("grade_widget", true)):
			radios.append(c.id)
		rows.append(c.id)
	return V.rec("CollectionRows", "M71", V.CONFIRMED, {"rows": rows, "radios": radios, "setters": setters,
		"first_radio_callback": radios[0] if not radios.is_empty() else null})

## 0338C360 is the createTimeline wrapper (not a popup Node factory). The frame-event callback is
## registered only for a non-null return with bool true. The constructor stores the return at root+50.
static func timeline_factory(return_nonnull: bool, bool_true: bool) -> Dictionary:
	return V.rec("TimelineFactory_0338C360", "M71", V.CONFIRMED, {"frame_event_callback_registered": return_nonnull and bool_true,
		"root50": "TIMELINE" if return_nonnull else null, "is_popup_node_factory": false})

## The destructor reads root+50 fresh at destruction time.
static func collection_destructor(root: Dictionary) -> Dictionary:
	return {"released": root.get("root50")}

# ---- M73 post parcel --------------------------------------------------------------------
## The expiry null guard sits AFTER retain, row lookup and string cleanup. Item/unread and the last
## direct visibility have their own guards. Only the guarded step is skipped.
static func parcel_row(expiry: Variant, item: Variant, visibility_target: Variant) -> Dictionary:
	var steps: Array = ["retain", "row_lookup", "string_cleanup"]
	steps.append("expiry_text" if expiry != null else "expiry_guard_skip")
	steps.append("item_unread" if item != null else "item_guard_skip")
	steps.append("direct_visibility" if visibility_target != null else "visibility_guard_skip")
	return V.rec("ParcelRow", "M73", V.CONDITIONAL, {"steps": steps, "order_after_cleanup_authoritative": false})

# ---- M75 market sale registration -------------------------------------------------------
## texts: 5 typed Text nodes (null allowed). All five present -> 4 clears, NcTrade getter, fee
## callback, local870. Otherwise those are skipped, but ready=0, show attempt and incoming shared
## cleanup still run. primary+10 is read without a guard: a null primary is rejected by the design
## layer, not silently skipped. optional +18/+20 are guarded. P+118 gates the animation.
static func market_register(texts: Array, primary: Variant, opt18: Variant, opt20: Variant, p118: bool) -> Dictionary:
	if primary == null:
		return V.rec("MarketRegister", "M75", V.REJECTED, {"reason": "primary+10 is read unguarded by the original"})
	var trace: Array = ["read_primary+10"]
	var all_text: bool = texts.size() == 5 and not texts.has(null)
	if all_text:
		trace.append_array(["clear_1", "clear_2", "clear_3", "clear_4", "NcTrade_getter", "fee_callback_register", "local870"])
	if opt18 != null:
		trace.append("optional+18")
	if opt20 != null:
		trace.append("optional+20")
	if p118:
		trace.append("animation")
	trace.append_array(["ready=0", "show_attempt", "incoming_shared_cleanup"])
	return V.rec("MarketRegister", "M75", V.CONFIRMED, {"trace": trace, "existing_slot_cleared": false, "earlier_request_cancelled": false,
		"trace_order_authoritative": false})
