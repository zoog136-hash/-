extends SceneTree
## Read-only audit of actual registration and shared bag action/owners.
## No Main instances, gameplay saves, grants, random draws or asset material.
## Usage:
##   godot --headless --path . --script res://tools/audit_item_runtime_matrix523.gd \
##       -- /absolute/original-523.zip /absolute/report.jsonl
const SRC=preload("res://scripts/resources/current523_definition_rows.gd")
const DROPS=preload("res://scripts/loot/patch523_monster_drops.gd")
const DTO=preload("res://scripts/loot/current523_native_item_projection.gd")
const FIELDS=preload("res://scripts/loot/current523_native_fields.gd")
const OWNER=preload("res://scripts/loot/current523_native_stack.gd")
const BAG=preload("res://scripts/ui/renewal_inventory.gd")
const RET=preload("res://scripts/loot/retired_enhancement_items523.gd")
const DUMMY=preload("res://scripts/quests/source_dummy523.gd")
const TICKETS=preload("res://scripts/shop/source523_inventory_tickets.gd")
const TICKET_INPUT=preload("res://scripts/shop/current523_ticket_input.gd")
const MILEAGE=preload("res://scripts/shop/source523_permanent_mileage_tickets.gd")
const RETURN=preload("res://scripts/quickslots/regional_return.gd")
const SMELT=preload("res://scripts/equipment523/native_smelt_input.gd")
const TJ_SOURCE=preload("res://scripts/tj/source523.gd")
const TJ_WINDOW=preload("res://scripts/ui/original_ui/source_main_tj_retry_window.gd")
const ENHANCEMENT=preload("res://scripts/crafting/patch523_enhance_source_book.gd")
const ELEMENT_MANAGEMENT=preload("res://scripts/equipment523/element_management.gd")
const NATIVE_SMITH=preload("res://scripts/equipment523/native_elemental_smith.gd")
const GACHA_CRAFT=preload("res://scripts/crafting/patch523_gacha_craft.gd")
const SLOT_EXPANDERS=preload("res://scripts/loot/source_slot_expanders523.gd")
const ACCOUNT=preload("res://scripts/characters/account_store.gd")
const DOLL_UNLOCK=preload("res://scripts/cards/native_doll_unlock_item.gd")
const RELIC_UNLOCK=preload("res://scripts/cards/native_relic_unlock_item.gd")
const SPECIAL_ENCHANT=["ScrollEnchant","ScrollElementalEnchant","ScrollElementalConversion","ScrollElementalRemover","ScrollBless"]
const CONFIRMED_GAPS := {
	1185: "source_account_slot_increase_without_consumer",
	146412: "source_base_stat_cap_without_consumer",
	146422: "source_rune_slot_unlock_without_consumer",
	146552: "source_permanent_auto_extra_healing_for_item_237_without_consumer",
	147152: "source_base_stat_cap_and_point_without_consumer",
	200753: "source_permanent_auto_extra_healing_for_item_236_without_consumer",
	245748: "source_buff_73838_auto_registration_item_236_without_consumer_acquisition_unverified",
}
const PVP_LEVEL_MANUALS := [146562,146572,146582,146592,146602,146612,146622,146632]
const KNOWN_HOLDS := {
	170214: "numeric_experience_disagrees_with_original_description",
	164643: "complex_reward_graph_not_present_in_pinned_tables",
	292582: "quest_destination_not_established",
}
const LINKED_ROUTES := [
	"equipment_requires_equip_slot_and_class", "internal_ammo_consumer_not_bag",
	"not_direct_item_material_owner", "not_direct_wallet",
	"original_trial_tower_land_and_cell_required", "ready_owner_resolver_not_tapped",
	"regional_return_owner_requires_map", "smelt_requires_exact_material_and_equipped_target",
	"ticket_original_full_pool_model_not_tapped", "ticket_permanent_card_and_mileage_live_tested",
	"tj_physical_requires_history_context_and_eligibility",
]
const VERIFIED={
	203402:"actual_original_bag_reusable_random_teleport_save_failure_and_reload_navigation_fixture",
	295494:"actual_original_bag_legacy_stock_reusable_random_teleport_and_reload_navigation_fixture",
	139581:"actual_bag_atomic_recharge_fault_retry_reload",
	307971:"actual_bag_4_exact_choices_fault_retry_reload",
	307931:"actual_child_bag_original_weighted_wallet_reward",
	19372:"actual_both_bags_level_and_map_refusal_retained",
	122424:"actual_both_bags_level_and_map_refusal_retained",
	200742:"actual_both_bags_no_action_craft_only",
	261738:"actual_cast_original_outbound_visual_only",
	170184:"actual_original_EXPreward_fault_reload_growth",
	170194:"actual_original_EXPreward_fault_reload_growth",
	170204:"actual_original_EXPreward_fault_reload_growth",
	181273:"actual_original_EXPreward_fault_reload_growth",
	234598:"actual_original_EXPreward_fault_reload_growth",
	2501:"actual_bag_MPrestoration_exact_reuse_fault_retry_reload",
	183493:"actual_bag_MPrestoration_exact_reuse_reload",
	189834:"actual_UI_source_selection_open_and_claim_expiry_gate",
	353592:"actual_UI_source_selection_open_and_claim_expiry_gate",
	258463:"actual_growth_potion_debit_and_NPC_adena_fault_reload",
	306601:"actual_growth_potion_nonstacked_debit_and_NPC_adena_reload",
	342064:"actual_bag_selected_receipt_original_5_results_fault_reload",
	200408:"actual_bag_1_original_doll_plus_240_mileage_fault_reload",
	200458:"actual_bag_10_original_dolls_plus_2400_mileage_reload",
	19473:"actual_bag_and_auto_quickslot_original_hp_dice_reload",
	310:"actual_bag_poison_only_debit_fault_retry_reload",
	263901:"actual_bag_HP6000_separate_900s_reuse_fault_retry_reload",
	146402:"actual_main_bonus_point_only_physical_debit_refusal_and_reload",
	146412:"actual_original_bag_base_stat_cap_only_physical_debit_and_reload",
	146422:"actual_original_bag_second_rune_unlock_growth_claim_fault_retry_equip_reload_unequip",
	146552:"actual_original_bag_and_growth_whisper_exact_237_auto_registration_death_and_reload",
	147152:"actual_original_bag_base_stat_cap_and_point_physical_and_growth_stock_fault_retry_reload",
	200753:"actual_original_bag_and_version0_growth_vow_exact_236_auto_registration_death_and_reload",
	1185:"actual_original_bag_fixed_thirteen_slot_policy_refusal_one_physical_item_retained",
	186024:"actual_main_half_elixir_reset_cancel_fault_retry_and_physical_debit",
	190754:"actual_main_half_elixir_reset_event_physical_debit",
	146442:"actual_bag_touch_and_fusion_reward_touch_fault_reload",
	146452:"actual_bag_dispatch_one_point_exact_fusion_lane",
	146462:"actual_bag_dispatch_one_point_exact_fusion_lane",
	146472:"actual_bag_dispatch_one_point_exact_fusion_lane",
	172251:"actual_bag_dispatch_one_point_exact_fusion_lane",
	172261:"actual_bag_dispatch_one_point_exact_fusion_lane",
	267911:"actual_bag_dispatch_one_point_exact_fusion_lane",
	267921:"actual_bag_dispatch_one_point_exact_fusion_lane",
	137513:"actual_bag_rank1_exact_source_coordinate_fixture_live_map_entry_unverified",
	137523:"actual_bag_rank2_exact_source_coordinate_fixture_live_map_entry_unverified",
	137533:"actual_bag_rank3_exact_source_coordinate_fixture_live_map_entry_unverified",
}
func _initialize()->void:run.call_deferred()
func run()->void:
	var args:PackedStringArray=OS.get_cmdline_user_args()
	if args.size()!=2 or not args[1].ends_with(".jsonl"):
		printerr("ITEM_AUDIT requires original zip and JSONL output");quit(1);return
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",args[0]);SRC.reset()
	if SRC.identity().get("source_sha256")!=SRC.SOURCE_SHA:
		printerr("ITEM_AUDIT pinned raw source missing");quit(2);return
	var catalog:Dictionary={"아이템":[]}
	var reg:Dictionary=DTO.register(DROPS,catalog,DROPS.data())
	if not reg.get("ok",false):
		printerr("ITEM_AUDIT native registration refused ",reg.get("reason",""));quit(3);return
	var by_id:Dictionary={}
	for record:Dictionary in catalog["아이템"]:
		var item_id:int=int(record.get("source_item_class_id",0))
		if record.get("source_bless_raw")==1 and not by_id.has(item_id):by_id[item_id]=record
	var class_categories:Dictionary={}
	for row:Dictionary in SRC.rows("ItemCategory"):class_categories[int(row.ID)]=str(row.Name)
	var old_view:bool=SRC.approximate_test_items
	SRC.approximate_test_items=false
	var original: Array[Dictionary]=SRC.rows("ItemClass")
	SRC.approximate_test_items=old_view
	if original.size()!=34743:
		printerr("ITEM_AUDIT unexpected ItemClass denominator ",original.size());quit(4);return
	var f:FileAccess=FileAccess.open(args[1],FileAccess.WRITE)
	if f==null:quit(5);return
	var ticket_inputs=TICKET_INPUT.new()
	var ticket_model:Dictionary=ticket_inputs.build()
	if ticket_model.is_empty():
		printerr("ITEM_AUDIT ticket production model refused ",ticket_inputs.problem);quit(7);return
	var supported_tickets:Dictionary=ticket_model.tickets
	var blocked_tickets:Dictionary=ticket_model.unsupported
	var tj: Dictionary=TJ_SOURCE.load_zip(args[0])
	if tj.is_empty():
		printerr("ITEM_AUDIT original TJ source refused ",TJ_SOURCE.problem);quit(8);return
	var counts:Dictionary={}
	var accepted:int=0
	var accepted_counts:Dictionary={}
	var enhancement_routes:Dictionary={}
	var dispositions: Dictionary = {}
	var audit_now: int=int(Time.get_unix_time_from_system())
	for raw:Dictionary in original:
		var id:int=int(raw.ID)
		var category:String=class_categories.get(int(raw.CategoryID),"")
		var record:Dictionary=by_id.get(id,{})
		var entry:Dictionary={"id":id,"category":category,"raw_test":raw.TestItem,"name":str(raw.Name),"projected":not record.is_empty(),"icon_declared":int(raw.get("IconID",0))>0,"icon_verified_on_bag":false}
		var route:String=""
		if RET.item(id):
			route="user_retired_quest_only" if RET.QUEST_ONLY.item(id) else "user_retired_exact_other"
		elif raw.TestItem==true:
			route="raw_test_existing_exact_exception" if not record.is_empty() else "raw_test_default_excluded"
		else:
			accepted+=1
			if record.is_empty():
				route="internal_ammo_consumer_not_bag" if category in ["Arrow","Sting","Bullet"] else "absent_requires_source_reason"
		if route.is_empty():
			var full:Dictionary=FIELDS.full(record)
			entry["name"]=str(full.get("source_display_name",raw.Name))
			entry["slot"]=record.get("slot")
			entry["bag_action"]=BAG.action_for_record(record,str(record.name))
			entry["guards"]=full.get("source_condition_pending",[])
			entry["deadline"]=DROPS.deadline_problem(full)
			var spec:Dictionary=full.get("source_use_spec",{})
			entry["source_contract"]=spec.get("kind","")
			entry["source_blockers"]=spec.get("blocked_reasons",[])
			var dummy:String=DUMMY.reason(full)
			if not dummy.is_empty():
				entry["dummy"]=dummy;route="source_declared_dummy"
			elif not entry.guards.is_empty() or not str(entry.deadline).is_empty():route="conditional_guard_before_use"
			elif category=="LinMarketProduct":
				var ticket_key:String=str(id)
				if supported_tickets.has(ticket_key) and TICKETS.claims(record):
					route="ticket_original_full_pool_model_not_tapped"
					entry["ticket_original_grants"]=supported_tickets[ticket_key].grants
				elif MILEAGE.VARIANTS.has(id) and not MILEAGE.spec(id,raw).is_empty():
					route="ticket_permanent_card_and_mileage_live_tested"
					entry["original_mileage"]=MILEAGE.VARIANTS[id][7]
				elif blocked_tickets.has(ticket_key):
					route="ticket_original_model_refusal"
					entry["ticket_original_blocker"]=blocked_tickets[ticket_key]
				else:route="market_package_not_direct_bag"
			elif tj.coupons.has(str(id)):
				var retry: Dictionary=TJ_WINDOW.physical_route(tj.coupons[str(id)])
				entry["coupon_ui"]=retry
				route="tj_physical_requires_history_context_and_eligibility" if not retry.is_empty() else "tj_policy_present_original_adapter_unavailable"
			elif category=="ScrollSmelt" and SMELT.known(id) and not SMELT.kind(record).is_empty():
				route="smelt_requires_exact_material_and_equipped_target"
			elif id == SLOT_EXPANDERS.CHARACTER_SEAL and ACCOUNT.MAX_CHARACTERS == 13 \
					and SLOT_EXPANDERS.character_seal(DROPS.item_definition(record)):
				route = "character_slots_already_available_under_current_account_policy"
			elif category in SPECIAL_ENCHANT:
				route="enhancement_target_and_original_rule_required"
				var owner: String="no_original_direct_owner_found"
				if category=="ScrollElementalEnchant":
					if not ENHANCEMENT.scroll_element(record).is_empty():owner="elemental_enhancement_group"
					else:
						var smith: Dictionary=NATIVE_SMITH.input(record)
						if not smith.is_empty():
							owner="elemental_smith" if NATIVE_SMITH.period_error(smith,audit_now,540).is_empty() else "elemental_smith_expired"
				elif category in ["ScrollElementalConversion","ScrollElementalRemover"]:
					var management: String=ELEMENT_MANAGEMENT.kind(record)
					if not management.is_empty():owner=management
				elif ENHANCEMENT.declares_scroll(record):owner="enhancement_group"
				elif category=="ScrollBless" and OWNER.profile(record).get("kind")=="bless":owner="blessing_target_picker"
				entry["enhancement_route"]=owner
				if raw.TestItem==false:
					var group: Dictionary=enhancement_routes.get(category,{})
					group[owner]=int(group.get(owner,0))+1
					enhancement_routes[category]=group
			elif DROPS.equipment(record):route="equipment_requires_equip_slot_and_class"
			else:
				var profile:Dictionary=OWNER.profile(record)
				if not profile.is_empty():
					entry["owner_profile"]=profile.get("kind")
					route="original_trial_tower_land_and_cell_required" if profile.get("spec",{}).has("source_trial_tower_territory_id") else "ready_owner_resolver_not_tapped"
				elif RETURN.supported(str(record.name),record):route="regional_return_owner_requires_map"
				elif category=="ScrollBuffCardRetry" and not OWNER.mystery_card_rule(record).is_empty():route="mystery_card_requires_verified_pool"
				else:
					var supply:Dictionary=OWNER.supply_profile(record)
					entry["supply"]=supply.get("kind","")
					if entry.supply in ["craft_material","spell_material"]:route="not_direct_item_material_owner"
					elif str(entry.slot)=="currency":route="not_direct_wallet"
					elif entry.bag_action=="사용":route="bag_action_visible_owner_unconfirmed"
					else:route="bag_action_absent_owner_unconfirmed"
		counts[route]=int(counts.get(route,0))+1
		if raw.TestItem==false and not RET.item(id):
			accepted_counts[route]=int(accepted_counts.get(route,0))+1
		entry["resolution"]=route
		var classified := disposition(entry, raw)
		entry["connection"] = classified[0]
		entry["connection_evidence"] = classified[1]
		dispositions[classified[0]] = int(dispositions.get(classified[0], 0)) + 1
		entry["actual_transaction_evidence"]=str(VERIFIED.get(id,"none"))
		if DTO.EXACT_CARD_BOX_ROOTS.has(id):entry["actual_transaction_evidence"]="actual_bag_original_selection_each_option_one_debit_and_reload"
		if id==323211:entry["actual_transaction_evidence"]="actual_original_focused_tj_one_bag_debit_saved_reload"
		if id in OWNER.DATED_FIREWORKS or OWNER.DIRECT_FIREWORKS.has(id):
			entry["actual_transaction_evidence"]="actual_bag_firework_original_overlay_one_debit"
		f.store_line(JSON.stringify(entry))
	f.close()
	print("ITEM_AUDIT_RESULT ",JSON.stringify({"source":SRC.SOURCE_SHA,"raw":original.size(),"normal_eligible_before_unresolved":accepted,"counts":counts,"eligible_routes":accepted_counts,"connections":dispositions,"enhancement_routes":enhancement_routes,"ticket_pools":ticket_model.pools.size(),"mode":"production_registration_and_unworn_action_only; physical transaction evidence enumerated"}))
	quit(0 if accepted==30098 else 6)


func disposition(entry: Dictionary, raw: Dictionary) -> Array[String]:
	var route: String = entry.resolution
	if route in ["raw_test_default_excluded", "source_declared_dummy", "user_retired_quest_only", "user_retired_exact_other"]:
		return ["intentionally_excluded", route]
	if route == "character_slots_already_available_under_current_account_policy":
		return ["intentionally_excluded", route]
	if route in LINKED_ROUTES:
		return ["linked", route]
	if route == "enhancement_target_and_original_rule_required":
		var target_route: String = entry.enhancement_route
		if target_route == "elemental_smith_expired":
			return ["intentionally_excluded", target_route]
		if target_route != "no_original_direct_owner_found":
			return ["linked", target_route]
		return ["needs_source_or_condition", target_route]
	if route in ["bag_action_absent_owner_unconfirmed", "bag_action_visible_owner_unconfirmed"]:
		# This is a Main dispatcher outside the native-stack use owner.
		if entry.category == "ScrollGachaCraft" and entry.bag_action == "사용" \
				and entry.get("supply") == "storage" and not GACHA_CRAFT.spec(entry.id).is_empty():
			return ["linked", "existing_main_gacha_craft_dispatch"]
		if (entry.id == DOLL_UNLOCK.ITEM and DOLL_UNLOCK.source_rules_valid()) \
				or (entry.id == RELIC_UNLOCK.ITEM and RELIC_UNLOCK.source_rules_valid()):
			return ["linked", "existing_main_native_awakening_subslot_unlock"]
		# Each pinned item grants only the saved PVPSpellByLevelAdditionLevel buff.
		if entry.id in PVP_LEVEL_MANUALS:
			return ["intentionally_excluded", "source_pvp_level_spell_manual"]
		var exclusion: String = OWNER.storage_exclusion(raw)
		if not exclusion.is_empty() and entry.get("supply") == "":
			return ["intentionally_excluded", exclusion]
		if CONFIRMED_GAPS.has(entry.id):
			return ["confirmed_missing", CONFIRMED_GAPS[entry.id]]
		if KNOWN_HOLDS.has(entry.id):
			return ["needs_source_or_condition", KNOWN_HOLDS[entry.id]]
	return ["needs_source_or_condition", route]
