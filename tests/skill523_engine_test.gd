extends SceneTree
## 523 reference-skill execution holds (docs/skill523_source_hold_report.md).
## Unit part (always): the table-direct passive contract opens only fully
## declared passives; CastDelay(ms) is the reuse delay (user decision 2026-11-12).
## Real part (only with the private original archive, absent in CI): measured
## CastDelay/tooltip cross-check, clan-merchant acquisition, follow-up spells,
## opened reference skills, and an actual book learn + save/load in Main.
const QA = preload("res://tests/qa_class_selection.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const ADAPTER = preload("res://scripts/skills/player_skills523.gd")
const CURRENT = preload("res://scripts/skills/current_official_skills.gd")
const BOOKS = preload("res://scripts/shop/source523_skill_books.gd")
var checks: int = 0
var failures: Array[String] = []
var real: Dictionary = {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void: call_deferred("run")

func entry(name: String, value: float, unit: String, link: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {"MinSpellLevel":0.0,"CharacterLevel":0.0,"CharacterClass":0.0}
	row.merge(link, true)
	return {"link":row,"bonus":{"Value":value,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0},"type":{"Name":name},"unit":{"Name":unit}}

func passive_profile(buff_rows: Array, spell_extra: Array = [], buff_row: Dictionary = {}) -> Dictionary:
	var bonuses: Array = [entry("BuffClassID",77.0,"BuffClassID"), entry("BuffClassID",78.0,"BuffClassID",{"MinSpellLevel":1.0})]
	bonuses.append_array(spell_extra)
	var row: Dictionary = {"ID":77.0,"IsBuffGroup":false,"BuffGroupID":5.0,"IsEraseOnTimeEnd":false}
	row.merge(buff_row, true)
	return {"row":{"ID":9.0,"SpellTypeID":3.0,"SpellCompositionNode":0.0,"SpellMaterialItemAmount":0.0,"MPCost":0.0,"HPCost":0.0,"CastDelay":0.0},
		"costs":[],"bonuses":bonuses,"buffs":[{"row":row,"bonuses":buff_rows}],
		"learn_limits":[{"ClassID":2.0,"IsTutorialSpell":false,"CharacterMinLevel":50.0,"CharacterPolymorphGradeID":0.0,"LimitBuffCardID":0.0}]}

func unit() -> void:
	var adapter = ADAPTER.new()
	adapter.bindings = {"class_ids":{"요정":2}}
	var base_rows: Array = [entry("DamageReduction",2.0,"Value"), entry("PVPDamageReduction",2.0,"Value"), entry("DamageReduction",5.0,"Value",{"MinSpellLevel":1.0})]
	adapter.profiles = {"lmref_ok":passive_profile(base_rows)}
	var ok: Dictionary = adapter.source_direct_passive("lmref_ok","요정")
	check(ok.get("stats",{}) == {"damageReduction":2}, "base-level flat DR opens, upper levels ignored: "+str(ok))
	check(ok.get("ignored_pvp",[]) == ["PVPDamageReduction"] and int(ok.get("minimum_level",-1)) == 50, "PvP row kept as data, learn level from SpellLearnLimit")
	check(adapter.source_direct_passive("lmref_ok","기사").has("reason"), "no learn row for the class holds")
	var holds: Dictionary = {
		"cond":passive_profile([entry("MeleeHit",3.0,"Value",{"CharacterLevel":60.0})]),
		"unit":passive_profile([entry("DamageReduction",2.0,"Percentage")]),
		"unknown":passive_profile([entry("MeleeCritical",15.0,"ValuePercent")]),
		"spell":passive_profile(base_rows,[entry("RequiredSpellClassID",34.0,"SpellClassID")]),
		"erase":passive_profile(base_rows,[],{"IsEraseOnSpellAttacked":true}),
		"pvp_only":passive_profile([entry("PVPDamageReduction",2.0,"Value")])}
	if DEF.identity().is_empty(): holds["group_unread"] = passive_profile(base_rows,[],{"IsBuffGroup":true})
	for key: String in holds:
		adapter.profiles = {"lmref_h":holds[key]}
		check(adapter.source_direct_passive("lmref_h","요정").has("reason"), "contract holds "+key)
	# Load-time projection keeps the shared record identity and only opens refs.
	adapter.profiles = {"lmref_ok":passive_profile(base_rows),"lm_x":passive_profile(base_rows)}
	var record: Dictionary = {"id":"lmref_ok","class":"요정","runtime_blocked":true,"activation":"passive","mode":"official_pending"}
	adapter.prepare_source_direct(record)
	check(not record.runtime_blocked and record.mode == "stats" and record.stats == {"damageReduction":2} and record.source_direct523.kind == "passive_stats", "reference passive opened on the shared record")
	var host: Dictionary = {"id":"lm_x","class":"요정","runtime_blocked":true}
	adapter.prepare_source_direct(host)
	check(host.runtime_blocked and not host.has("source_direct523"), "non-reference records untouched")
	adapter.profiles = {"lmref_h":holds.unit}
	var held: Dictionary = {"id":"lmref_h","class":"요정","runtime_blocked":true,"activation":"active","cooldown":null,"name":"x"}
	adapter.prepare_source_direct(held)
	check(held.runtime_blocked and held.source523_cast_delay_ms == 0 and not held.get("source_direct523_hold",[]).is_empty(), "held reference keeps its hold reason")
	check(held.cooldown == 0.0, "held active reference shows its original reuse delay")
	var text: String = CURRENT.blocked_reason(held)
	check(not text.contains("재사용 시간") and text.contains("원본 표 직접 실행 불가"), "reuse delay is no longer a hold reason: "+text)
	# Castable source-bound actives take CastDelay(ms) as their cooldown.
	var cast_adapter = ADAPTER.new()
	cast_adapter.bindings = {"class_ids":{"기사":1},"material_inventory_keys":{},"retained_host_items":[],"skills":{}}
	cast_adapter.profiles = {"c":{"row":{"ID":5.0,"SpellTypeID":1.0,"SpellCompositionNode":0.0,"SpellCategoryID":2.0,"MPCostUnit":1.0,"VPCost":0.0,"HPCost":0.0,"MPCost":10.0,
		"SpellMaterialTypeID":0.0,"SpellMaterialItemAmount":0.0,"TargettingTypeID":1.0,"TargetKindID":2.0,"TargetAreaRadius":0.0,"CastRange":0.0,"MinCastRange":0.0,"CastDelay":3000.0,"CastGroupID":1.0,"TargetLimitCount":0.0},
		"learn_limits":[{"ClassID":1.0,"IsTutorialSpell":false}],"bonuses":[],"buffs":[],"costs":[],"cast_groups":[],"target_kind":{"Name":"All"},"targeting_type":{"Name":"Self"}}}
	var casted: Dictionary = cast_adapter.apply_to({"id":"c","activation":"active","mode":"buff","cooldown":2.0,"class":"기사"},"기사",false)
	check(is_equal_approx(float(casted.get("cooldown",-1)), 3.0) and casted.source523.applied.has("cooldown") and casted.source523.time_policy == "SOURCE523_CASTDELAY_MS" and casted.source523.host_cooldown_before == 2.0, "CastDelay 3000ms -> cooldown 3s: "+str(casted.get("cooldown")))

func seconds_in(text: String, pattern: RegEx) -> Array:
	var result: Array = []
	for m: RegExMatch in pattern.search_all(text):
		result.append(float(m.get_string(2)) * {"초":1.0,"분":60.0,"시간":3600.0}[m.get_string(3)])
	return result

func cast_delay_evidence(bound: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var declared: Dictionary = {}
	for id: int in [8738, 9412, 12102, 144]:
		var type: Dictionary = DEF.row("BonusType", id)
		declared[str(id)] = {"name":str(type.get("Name","")),"unit":str(DEF.row("Unit",int(type.get("UnitID",-1))).get("Name","")),"desc":str(DEF.row("DescData_Korean",int(type.get("DescID",-1))).get("Description",""))}
	out["declared"] = declared
	var pattern := RegEx.new()
	pattern.compile("(재사용(?:\\s*대기)?\\s*(?:시간|쿨타임)?|쿨\\s*타임|대기\\s*시간)\\s*[:：]?\\s*\\(?\\s*([0-9]+(?:\\.[0-9]+)?)\\s*(초|분|시간)")
	var pairs: Dictionary = {} # spell id -> Array of seconds
	var text_of := func(id: Variant) -> String: return str(DEF.row("DescData_Korean",int(id)).get("Description","")) if int(id) > 0 else ""
	for spell: Dictionary in DEF.rows("SpellClass"):
		for field: String in ["DescID","EffectDescID"]:
			for value: float in seconds_in(text_of.call(spell.get(field,0)), pattern):
				if not pairs.has(int(spell.ID)): pairs[int(spell.ID)] = []
				pairs[int(spell.ID)].append(value)
	var items: int = 0
	var item_spells: Dictionary = {}
	for link: Dictionary in DEF.rows("ItemBonus"):
		var bonus: Dictionary = DEF.row("Bonus",int(link.get("BonusID",-1)))
		if bonus.is_empty() or str(DEF.row("BonusType",int(bonus.BonusTypeID)).get("Name","")) != "SpellClassID": continue
		var item_id: int = int(link.ItemClassID)
		if not item_spells.has(item_id): item_spells[item_id] = {}
		item_spells[item_id][int(bonus.Value)] = true
	for item_id: int in item_spells:
		if item_spells[item_id].size() != 1: continue
		var item: Dictionary = DEF.row("ItemClass", item_id)
		if item.is_empty(): continue
		var text: String = ""
		for field: String in ["DescID","IdentifiedDescID","UseDescID","StoryDescID","ProductDescID"]: text += " " + text_of.call(item.get(field,0))
		var found: Dictionary = {}
		for value: float in seconds_in(text, pattern): found[value] = true
		if found.size() != 1: continue
		items += 1
		var spell_id: int = int(item_spells[item_id].keys()[0])
		if not pairs.has(spell_id): pairs[spell_id] = []
		pairs[spell_id].append(found.keys()[0])
	var matched: Dictionary = {}; var mismatched: Dictionary = {}
	var rows_match: int = 0; var rows_mismatch: int = 0
	for spell_id: int in pairs:
		var delay: float = float(DEF.row("SpellClass", spell_id).get("CastDelay", -1))
		for value: float in pairs[spell_id]:
			if is_equal_approx(delay, value * 1000.0): rows_match += 1; matched[spell_id] = delay
			else: rows_mismatch += 1; mismatched[spell_id] = delay
	var bound_text: int = 0
	for spell_id: int in pairs:
		if bound.has(spell_id): bound_text += 1
	out.merge({"compared_spells":pairs.size(),"items_with_one_time":items,"text_rows_match":rows_match,"text_rows_mismatch":rows_mismatch,
		"matched_spells":matched.keys(),"mismatched_spells":mismatched.keys(),"bound_player_spells_with_time_text":bound_text}, true)
	return out

func clan_merchants(bound: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for merchant: int in [10, 91, 833, 1164]:
		var names: Array = []
		for unit_row: Dictionary in DEF.rows("EarthObjectUnit"):
			if int(unit_row.get("UnitID",-1)) == 25 and int(unit_row.get("Value",-1)) == merchant:
				names.append(str(DEF.row("EarthObjectClass",int(unit_row.EarthObjectClassID)).get("Name","")))
		var goods: int = 0; var clan_gated: int = 0; var bound_books: Dictionary = {}
		for sale: Dictionary in DEF.related("MerchantGoods","MerchantsID",merchant):
			goods += 1
			if int(sale.get("ClanLevelMin",0)) > 0 or int(sale.get("LimitMinClanLevel",0)) > 0: clan_gated += 1
			var spell: int = int(DEF.row("BuffCard",int(sale.get("LimitRepeatedBuyCardID",-1))).get("SpellClassID",0))
			if bound.has(spell): bound_books[spell] = true
		out[str(merchant)] = {"objects":names,"goods":goods,"clan_level_gated":clan_gated,"bound_spells":bound_books.size()}
	return out

func run() -> void:
	unit()
	real["archive"] = not DEF.identity().is_empty()
	if real.archive:
		var world = load("res://Main.tscn").instantiate()
		root.add_child(world)
		world.set_process(false)
		world.save_timer = -100000.0
		check(QA.enter_game(world, "요정"), "actual Main class confirmation (요정)")
		var catalog = world.original_skills.catalog
		var adapter = catalog.source523
		var public: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ADAPTER.BINDINGS_PATH))
		var bound: Dictionary = {}
		for id: String in public.skills: bound[int(public.skills[id].spell_id)] = id
		var evidence: Dictionary = cast_delay_evidence(bound)
		real["cast_delay"] = evidence
		check(evidence.declared["8738"].name == "SpellCastDelayDecreasePercent" and evidence.declared["8738"].desc == "스킬 쿨타임 감소", "BonusType declares CastDelay as skill cooldown")
		check(evidence.declared["9412"].unit == "MilliSeconds", "absolute CastDelay adjustment declared in MilliSeconds")
		check(int(evidence.text_rows_mismatch) > 0, "tooltip mismatches recorded (no longer a hold, user decision)")
		check(int(evidence.bound_player_spells_with_time_text) == 0, "no bound player spell states a cooldown in its tooltip")
		real["merchants"] = clan_merchants(bound)
		for merchant: String in ["91","833","1164"]:
			var shop: Dictionary = real.merchants[merchant]
			check(shop.objects.size() == 1 and str(shop.objects[0]).contains("혈맹 상인"), "merchant %s is a clan merchant" % merchant)
		# Follow-up spells of bound references at base level, by application type.
		var follow: Dictionary = {}
		for key: String in adapter.profiles:
			if not key.begins_with("lmref_"): continue
			for item: Dictionary in adapter.profiles[key].bonuses:
				if str(item.type.Name) in ["NextSpellClassID","SuccessChangeSpellClassID","ActiveComboSpell","AdditionalSpellClassID"] and int(item.link.MinSpellLevel) == 0:
					var tag: String = "%s@%d/%d" % [str(item.type.Name), int(item.bonus.BonusApplicationTypeID), int(item.bonus.BonusApplicationTargetID)]
					follow[tag] = int(follow.get(tag,0)) + 1
		real["follow_up"] = follow
		var opened: Array = []; var blocked: int = 0; var bound_refs: int = 0; var holds: Dictionary = {}
		for key: String in adapter.profiles:
			if not key.begins_with("lmref_"): continue
			bound_refs += 1
			var record: Dictionary = catalog.record_for(key)
			if record.get("source_direct523",{}).get("kind","") == "passive_stats": opened.append(str(record.name))
			if record.get("runtime_blocked",false):
				blocked += 1
				for reason: Variant in record.get("source_direct523_hold",[]):
					var head: String = str(reason).split(" ")[0]
					holds[head] = int(holds.get(head,0)) + 1
		real.merge({"bound_references":bound_refs,"blocked_references":blocked,"opened":opened}, true)
		check(opened == ["엘리멘탈 실드"], "only the fully declared reference passive opens: "+str(opened))
		# Actual game flow: magic-shop book → bag use → learned passive → DR, save/load.
		var shield: Dictionary = {}
		for record: Dictionary in catalog.records:
			if record.get("source_direct523",{}).get("spell_id",-1) == 37233: shield = record
		var spec: Dictionary = BOOKS.contract(177812)
		real["book"] = {"name":spec.get("name",""),"skill":spec.get("skill_id","")}
		check(not shield.is_empty() and spec.get("skill_id","") == shield.get("id","?"), "original book 177812 (merchant 10) binds to the opened passive")
		if shield.is_empty():
			print("SKILL523_ENGINE_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "real":real}))
			quit(1);return
		check(BOOKS.registered(world, str(spec.get("name","")), str(shield.get("id",""))), "book registered for the existing magic shop")
		world.level = 49
		var before: float = world.original_skills.stat("damageReduction")
		world.inventory[str(spec.name)] = 1
		world._on_inventory_item_activated(str(spec.name))
		check(int(catalog.learned.get(str(shield.id),0)) == 0 and int(world.inventory.get(str(spec.name),0)) == 1, "Lv.49 cannot learn (SpellLearnLimit 50), book kept")
		world.level = 50
		world._on_inventory_item_activated(str(spec.name))
		var after: float = world.original_skills.stat("damageReduction")
		real["learn"] = {"learned":int(catalog.learned.get(str(shield.id),0)),"book_left":int(world.inventory.get(str(spec.name),0)),"dr_before":before,"dr_after":after}
		check(int(catalog.learned.get(str(shield.id),0)) == 1 and int(world.inventory.get(str(spec.name),0)) == 0, "Lv.50 learns through the bag, book consumed")
		check(is_equal_approx(after - before, 2.0), "learned passive adds original DamageReduction 2")
		check(world._save_game(true) == OK, "save after learning")
		var text: String = FileAccess.get_file_as_string(world.SAVE_PATH)
		check(not text.contains("row_json") and not text.contains("source_direct523"), "save holds no original rows")
		catalog.learned.erase(str(shield.id)); catalog.revision += 1
		world._load_game(true)
		check(int(catalog.learned.get(str(shield.id),0)) == 1 and is_equal_approx(world.original_skills.stat("damageReduction") - before, 2.0), "learned passive and DR survive save/load")
		real["after_load_dr"] = world.original_skills.stat("damageReduction")
		# A held reference (뇌신 플래시, CastDelay 9000) still refuses to cast,
		# spends nothing and shows the raw original CastDelay.
		var flash: Dictionary = catalog.record_for("lmref_f7afaf54afcbb439")
		var mp_before: int = world.mp
		var cast: bool = world.original_skills.cast(flash)
		var reason: String = CURRENT.blocked_reason(flash)
		real["flash_hold"] = {"cast":cast,"mp_before":mp_before,"mp_after":world.mp,"reason":reason}
		check(not cast and world.mp == mp_before and not reason.contains("재사용 시간") and is_equal_approx(float(flash.get("cooldown",-1)), 9.0), "held reference refuses cast, no MP spent, reuse delay 9s shown")
		# Opened-by-CastDelay re-judgement: every bound reference active still
		# has another hold (sub-spells, follow-up conditions, PC-only, ...).
		var reopened: Array = []
		for key: String in adapter.profiles:
			var ref: Dictionary = catalog.record_for(key)
			if key.begins_with("lmref_") and str(ref.get("activation","")) != "passive" and not ref.get("runtime_blocked",true) and not ref.has("estimated523") and not bool(ref.get("local_design",false)): reopened.append(str(ref.name))
		real["opened_active_references"] = reopened
		# Castable source-bound actives: cooldown now CastDelay(ms)/1000.
		var applied: Array = []
		for record: Dictionary in catalog.records:
			if record.get("runtime_blocked",false) or not adapter.profiles.has(str(record.id)) or str(record.get("activation","")) != "active": continue
			var job: String = str(record.get("class",""))
			world.job_class = "기사" if job == "공용" else job
			var resolved: Dictionary = catalog.resolve(record)
			if resolved.get("source523",{}).get("applied",[]).has("cooldown"): applied.append([str(record.name), resolved.source523.get("host_cooldown_before"), resolved.cooldown])
		real["cooldown_applied"] = applied
		check(applied.size() > 0, "castable source-bound actives take CastDelay cooldown")
		# Actual cast: the first self-buff whose own class can cast it now
		# (no weapon/target needed) and whose CastDelay is at least 1s.
		world.level = 90
		var barrier: Dictionary = {}
		var tried: Array = []
		for record: Dictionary in catalog.records:
			if record.get("runtime_blocked",false) or not adapter.profiles.has(str(record.id)) or str(record.get("mode","")) not in ["buff","counter","stealth"]: continue
			world.job_class = "마법사" if str(record.get("class","")) == "공용" else str(record.get("class",""))
			catalog.learned[str(record.id)] = 1; catalog.revision += 1
			var probe: Dictionary = catalog.resolve(record)
			world.mp = world._effective_max_mp(); world.skill_cooldowns.clear(); world.skill_global_cooldown = 0.0
			var why: String = "" if world.original_skills.ready(record) else ("not_enabled" if not catalog.enabled(record) else world.original_skills.cost_reason(probe))
			tried.append([str(record.name), probe.get("cooldown"), why])
			if why.is_empty() and probe.get("source523",{}).get("applied",[]).has("cooldown") and float(probe.cooldown) >= 1.0:
				barrier = record; break
			catalog.learned.erase(str(record.id)); catalog.revision += 1
		real["cast_candidates"] = tried
		check(not barrier.is_empty(), "a castable CastDelay self-buff exists")
		if barrier.is_empty(): barrier = catalog.record_for("lm_11ab17290e72e63f")
		var resolved_barrier: Dictionary = catalog.resolve(barrier)
		var mp0: int = world.mp
		var first: bool = world.original_skills.cast(barrier)
		var mp1: int = world.mp
		var remaining: float = float(world.skill_cooldowns.get(str(barrier.name), 0.0))
		world.skill_global_cooldown = 0.0
		var again: bool = world.original_skills.ready(barrier)
		check(world._save_game(true) == OK, "save during cooldown")
		world.skill_cooldowns.clear()
		world._load_game(true)
		var loaded_remaining: float = float(world.skill_cooldowns.get(str(barrier.name), 0.0))
		world.skill_global_cooldown = 0.0
		var after_load: bool = world.original_skills.ready(barrier)
		world._tick_skill_cooldowns(remaining + 0.05)
		world.mp = world._effective_max_mp()
		var mp2: int = world.mp
		var third: bool = world.original_skills.cast(barrier)
		real["barrier"] = {"name":str(barrier.get("name","")),"class":world.job_class,"cooldown":resolved_barrier.get("cooldown"),"host_before":resolved_barrier.get("source523",{}).get("host_cooldown_before"),"mp_cost":resolved_barrier.get("mp"),"first":first,"mp":[mp0,mp1],"remaining":remaining,"ready_during":again,"loaded_remaining":loaded_remaining,"ready_after_load":after_load,"third":third,"mp_third":[mp2,world.mp],"factor":world._skill_cooldown_factor()}
		check(first and mp0 - mp1 == int(resolved_barrier.mp) and is_equal_approx(float(resolved_barrier.cooldown), float(resolved_barrier.source523_cast_delay_ms if resolved_barrier.has("source523_cast_delay_ms") else resolved_barrier.source523.cast_delay_raw) / 1000.0), "cast spends original MP, cooldown = CastDelay/1000")
		check(is_equal_approx(remaining, float(resolved_barrier.cooldown) * world._skill_cooldown_factor()) and not again, "recast refused during CastDelay cooldown")
		check(is_equal_approx(loaded_remaining, remaining) and not after_load, "cooldown survives save/load")
		check(third and mp2 - world.mp == int(resolved_barrier.mp), "recast succeeds after the cooldown")
	print("SKILL523_ENGINE_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "real":real}))
	quit(0 if failures.is_empty() else 1)
