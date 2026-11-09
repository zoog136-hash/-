extends "res://tests/original_client_test_base.gd"
## C18 - C22 acceptance tests (design-level; the original binary is never executed).
const UI = preload("res://scripts/original_client/ui_tree_cache.gd")
const MAPP = preload("res://scripts/original_client/map_presentation.gd")
const INV = preload("res://scripts/original_client/inventory_view_model.gd")
const SPELL = preload("res://scripts/original_client/spell_ui_numeric.gd")
const HEALTH = preload("res://scripts/original_client/health_display.gd")

func run() -> void:
	# C18
	var tree := {"name": "root", "type": "Node", "children": [
		{"name": "a", "type": "Node", "children": []},
		{"name": "ref", "type": "ProjectNode", "ref_path": "sub.csb", "referenced": {"name": "subroot", "type": "Node", "children": [{"name": "sub_ref", "type": "ProjectNode", "ref_path": "sub.csb", "referenced": null}]}}]}
	var cache = UI.new()
	var first: Dictionary = cache.load_tree("main.csb", tree, ["sub.csb"], false, false)
	check("C18-T01", first.tree.children.size() == 1 and first.cache_hit == false, "excluded ProjectNode reference becomes null and is dropped")
	var second: Dictionary = cache.load_tree("main.csb", tree, [], false, false)
	check("C18-T01", second.cache_hit == true and second.tree.children.size() == 1, "a different exclusion set still hits the older parse (not part of the key)")
	var cb: Dictionary = cache.load_tree("main.csb", tree, [], true, false)
	check("C18-T01", cb.cache_hit == false and UI.cache_key("main.csb", true, false) == null, "non-null callback bypasses the cache")
	check("C18-T01", UI.cache_key("a", false, true) != UI.cache_key("a", false, false), "prototype mode is part of the key")
	var open_cache = UI.new()
	var open_tree: Dictionary = open_cache.load_tree("main.csb", tree, [], false, false)
	var nested = open_tree.tree.children[1].children[0]
	check("C18-T02", nested.children[0].type == "Node" and nested.children[0].get("fallback") == "empty_node", "nested, different CSB with unloadable reference becomes an empty Node, not null")
	var hide: Dictionary = UI.lifetime_operation("hide")
	check("C18-T03", hide.visible == false and hide.attached and not hide.destructed and not hide.unsubscribed and not hide.input_capture_released, "hide is not detach, destruct, unsubscribe or input release")
	check("C18-T03", UI.lifetime_operation("destruct").input_capture_released and UI.lifetime_operation("detach").attached == false, "destruct releases; detach detaches")
	var swept: Dictionary = UI.sweep({"a": {"refcount": 1}, "b": {"refcount": 2}})
	check("C18-T04", swept.removed == ["a"] and swept.kept.has("b"), "sweep reclaims refcount==1 only")

	# C19
	check("C19-T01", MAPP.party_node_names() == ["PARTY1", "PARTY2", "PARTY3", "PARTY4"] and MAPP.PARTY_CONTAINER == "ICON_NODE_PARTY" and MAPP.party_node_name(5) == null, "PARTY1-4 nodes, container name kept")
	check("C19-T01", MAPP.party_capacity_from_sprite_loop().capacity == null, "sprite reuse loop does not define party capacity")
	var st: Dictionary = MAPP.make_state("World", 1, "k")
	var mini: Dictionary = MAPP.apply_minimap_local_1cb(st, {"map": 4, "channel": 1, "x": 10, "y": 20})
	check("C19-T02", mini.minimap.source == "local_1cb_payload" and mini.minimap.waited_for_big_map_timer == false and mini.view_generation == 0, "minimap reads local 1CB without the big-map timer")
	var timed: Dictionary = MAPP.big_map_timer_refresh(st, [1, 2])
	check("C19-T02", timed.view_generation == 1 and timed.minimap == st.minimap, "big-map timer refresh is independent of the minimap")
	var hidden: Dictionary = MAPP.hide_view(st)
	check("C19-T03", hidden.visible == false and hidden.subscribed and not hidden.destructed, "hide does not destruct or unsubscribe")
	check("C19-T03", MAPP.destruct_view(st).subscribed == false, "destruct unsubscribes")

	# C20
	check("C20-T01", INV.korean_quantity_mode1(19999) == {"text": "1만", "visible": true}, "V12")
	check("C20-T01", INV.korean_quantity_mode1(99999999) == {"text": "9,999만", "visible": true}, "V13")
	check("C20-T01", INV.korean_quantity_mode1(100000000).text == "1억" and INV.korean_quantity_mode1(1).visible == false and INV.korean_quantity_mode1(999).text == "999" and INV.korean_quantity_mode1(1234).text == "1,234", "eok, hide at 1, grouping")
	var slot: Dictionary = INV.set_quantity(INV.make_slot(), 5000)
	var one: Dictionary = INV.set_quantity(slot, 1)
	check("C20-T02", one.visible_flags.quantity == false and one.old_text == "5,000", "quantity<=1 only hides, stored text kept")
	var b1: Dictionary = INV.apply_badge(INV.make_slot(), "t1", "assetA", true)
	check("C20-T03", INV.apply_badge(b1, "t1", "assetB", false).badges.asset == "assetA" and INV.apply_badge(b1, "t1", "assetB", false).badges.visible == false, "same tag changes visibility only")
	check("C20-T03", INV.apply_badge(b1, "t2", "assetC", false).badges.tag == "t1", "different tag with visible=false does nothing")
	check("C20-T03", INV.apply_badge(b1, "t2", "assetC", true).badges.asset == "assetC", "different tag with visible=true applies")
	var cached: Dictionary = INV.refresh_slot(INV.make_slot(), true, 3, 2, null, null, false)
	check("C20-T04", cached.icon_cache_hit and cached.quantity_i64 == 3 and cached.visible_flags.enchant, "icon cache hit still refreshes quantity and enchant")
	check("C20-T04", INV.resolve_failed(slot) == slot and INV.grade_color(null) == "BLACK", "failed resolve keeps the slot; default colour BLACK")

	# C21
	var v14: Dictionary = SPELL.duration_seconds_bits((0x80000080 << 32) | 1)
	check("C21-T01", v14.u24_bits == "5F000001" and v14.duration_bits == "5A031270", "V14 got %s" % str(v14))
	var rem: int = int("3697547247084070")
	var total: int = int("9593810773161135784")
	check("C21-T02", SPELL.cooldown_percent_bits(rem, total).percent_f32_bits == "3D1DDD22", "V15")
	check("C21-T02", SPELL.cooldown_percent_bits_multiply_first(rem, total) == "3D1DDD21", "multiply-first differs (documents why order matters)")
	check("C21-T03", SPELL.remaining_after(0x100000005, 0x3).signed_low32 == 2 and SPELL.remaining_after(5, 0x100000003).signed_low32 == 2 and SPELL.remaining_after(3, 5).expired, "signed low32 compare")
	var ins: Dictionary = SPELL.active_insert({}, 1, 100, 7)
	var dup: Dictionary = SPELL.active_insert(ins.active, 1, 999, 8)
	check("C21-T04", dup.inserted == false and dup.active[1].timeout == 100 and dup.active[1].icon == 7, "duplicate insert overwrites nothing")
	var tp: Dictionary = SPELL.timeout_pass({1: {}, 2: {}}, [1])
	check("C21-T04", tp.events_published_before_erase.size() == 1 and not tp.active.has(1) and tp.active.has(2), "timeout publishes then erases")
	check("C21-T04", SPELL.explicit_remove({3: {}}, 3).order == ["erase", "event"], "explicit removal erases first")
	var tr: Dictionary = SPELL.progress_transition("OtherAction", 0, 10, true, true, true, true, false)
	check("C21-T05", tr.stop_by_tag_called == false and tr.new_action_created and tr.show, "V16")
	check("C21-T05", SPELL.progress_transition("ProgressFromTo", 20, 10, true, true, true, true, false).returned_early, "existing progress with >= remaining returns early")
	check("C21-T05", SPELL.progress_transition("ProgressFromTo", 5, 10, true, true, true, true, false).stop_by_tag_called, "shorter existing progress is stopped")
	check("C21-T05", SPELL.progress_transition("None", 0, 10, true, true, false, true, false).show == false, "missing node: no show")

	# C22
	check("C22-T01", HEALTH.raw_percent(50, 101).percent == 49, "V17")
	check("C22-T01", HEALTH.npc_hp_percent(100, 100, 0).hp_percent == 0, "V18")
	check("C22-T01", HEALTH.raw_percent(1, 0).status == "ZERO_MAX_REJECTED_DESIGN", "zero max refused")
	check("C22-T01", HEALTH.raw_percent(-50, 101).percent == -49, "negative truncates toward zero")
	var disp: Dictionary = HEALTH.display_percent(-49)
	check("C22-T02", disp.display == 100.0 and disp.signed_clamp_would_be == 0.0, "negative raw percent zero-extends and clamps to 100")
	var ov: Dictionary = HEALTH.overhead_update({}, 50, false)
	var again: Dictionary = HEALTH.overhead_update(ov, 50, true)
	check("C22-T03", ov.lookup_performed and again.lookup_performed == false and again.node_presence == false, "same raw percent skips the node lookup")
	finish("ORIGINAL_CLIENT_P5_RESULT")
