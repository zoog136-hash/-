extends SceneTree
## TWILIGHT 근사 passive contract (data/skills/source_approx523.json,
## docs/skill523_source_hold_report.md "근사 적용 2026-11-16").
## Unit part (always): level-threshold replacement, weapon sets, receivers,
## prerequisites and the policy file shape.
## Real part (only with the private original archive, absent in CI): held
## reference count before/after, original skill-book owners, and actual Main
## learn -> stat / prerequisite / weapon / invoke / save-load checks.
const QA = preload("res://tests/qa_class_selection.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const ADAPTER = preload("res://scripts/skills/player_skills523.gd")
const SERVICE = preload("res://scripts/skills/skill_service.gd")
var checks: int = 0
var failures: Array[String] = []
var real: Dictionary = {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void: call_deferred("run")

func unit() -> void:
	var policy: Dictionary = ADAPTER.new().approx_rules()
	check(int(policy.get("schema",0)) == 1 and str(policy.get("label","")) == "TWILIGHT 근사", "policy file loads with the TWILIGHT 근사 label")
	for key: String in policy.get("sources",{}):
		check(str(policy.sources[key].get("url","")).begins_with("https://") and not str(policy.sources[key].get("checked","")).is_empty(), "source has url and date: "+key)
	for key: String in policy.get("rules",{}):
		check(not str(policy.rules[key].get("value","")).is_empty() and not str(policy.rules[key].get("why","")).is_empty(), "rule documented: "+key)
	# Level thresholds: highest CharacterLevel <= level replaces lower rows.
	var rows: Array = [{"type":"RangeHit","stat":"rangedHit","value":5.0,"level":0,"weapons":[]},
		{"type":"RangeHit","stat":"rangedHit","value":6.0,"level":73,"weapons":[]},
		{"type":"RangeHit","stat":"rangedHit","value":10.0,"level":85,"weapons":[]},
		{"type":"LargeSwordDamageBonus","stat":"meleeDamage","value":5.0,"level":0,"weapons":[7]}]
	var spec: Dictionary = {"rows":rows,"weapons":[]}
	check(ADAPTER.approx_values(spec, 60, 7) == {"rangedHit":5.0,"meleeDamage":5.0}, "below every threshold uses level-0 row: "+str(ADAPTER.approx_values(spec,60,7)))
	check(ADAPTER.approx_values(spec, 80, 1) == {"rangedHit":6.0}, "level 80 uses 73 row, weapon row needs its weapon")
	check(ADAPTER.approx_values(spec, 90, 7) == {"rangedHit":10.0,"meleeDamage":5.0}, "level 90 uses 85 row (replacement, not sum)")
	spec.weapons = [3]
	check(ADAPTER.approx_values(spec, 90, 7).is_empty() and not ADAPTER.approx_values(spec, 90, 3).is_empty(), "spell weapon set gates every row")
	# Invoke rows use the same threshold rule.
	var invokes: Array = [{"option_type":"Attack_DamageScaleAfterReduction","attack_kinds":["melee"],"by_spell":false,"chance":0.05,"level":1},
		{"option_type":"Attack_DamageScaleAfterReduction","attack_kinds":["melee"],"by_spell":false,"chance":0.15,"level":84}]
	var picked: Array = ADAPTER.approx_level_rows(invokes, 90, 0, [])
	check(picked.size() == 1 and is_equal_approx(float(picked[0].chance), 0.15), "invoke chance follows the level threshold")
	check(SERVICE.approx_invoke_matches({"attack_kinds":["melee"],"by_spell":false},{"attack_type":"melee","by_spell":false}), "melee normal attack matches")
	check(not SERVICE.approx_invoke_matches({"attack_kinds":["melee"],"by_spell":false},{"attack_type":"melee","by_spell":true}), "spell attack does not match a normal-attack invoke")
	check(not SERVICE.approx_invoke_matches({"attack_kinds":["ranged"],"by_spell":false},{"attack_type":"melee","by_spell":false}), "attack kind must match")
	# Contract on a synthetic profile (no archive needed for these rows).
	var adapter = ADAPTER.new()
	adapter.bindings = {"class_ids":{"기사":1},"skills":{"lm_base":{"spell_id":83}}}
	var entry := func(name: String, value: float, unit: String, link: Dictionary = {}, at: float = 0.0, tg: float = 0.0) -> Dictionary:
		var l: Dictionary = {"MinSpellLevel":0.0,"CharacterLevel":0.0,"CharacterClass":0.0}; l.merge(link,true)
		return {"link":l,"bonus":{"Value":value,"BonusApplicationTypeID":at,"BonusApplicationTargetID":tg},"type":{"Name":name},"unit":{"Name":unit}}
	var profile: Dictionary = {"row":{"ID":55674.0,"SpellTypeID":3.0,"SpellCompositionNode":0.0,"SpellMaterialItemAmount":0.0,"MPCost":0.0,"HPCost":0.0},"costs":[],
		"bonuses":[entry.call("BuffClassID",9.0,"BuffClassID"),entry.call("RequiredSpellClassID",83.0,"SpellClassID")],
		"buffs":[{"row":{"ID":9.0,"IsBuffGroup":false},"bonuses":[entry.call("ArmorClass",10.0,"Value"),entry.call("PVEDamageReduction",8.0,"Value",{"CharacterLevel":89.0}),
			entry.call("SpecialResistance",50000.0,"Percentage",{},2.0,6.0),entry.call("PVPDamageReduction",3.0,"Value"),entry.call("IgnoreCounterBarrierProbability",1.0,"Percentage",{},10.0,861.0)]}],
		"learn_limits":[{"ClassID":1.0,"IsTutorialSpell":false,"CharacterMinLevel":70.0,"CharacterPolymorphGradeID":0.0,"LimitBuffCardID":0.0}]}
	adapter.profiles = {"lmref_v":profile}
	var opened: Dictionary = adapter.source_approx_passive("lmref_v","기사")
	check(opened.get("requires",[]) == ["lm_base"] and int(opened.get("minimum_level",-1)) == 70, "prerequisite mapped to its bound record, learn level kept: "+str(opened))
	check(ADAPTER.approx_values(opened, 90, 0) == {"def":10.0,"pveDamageReduction":8.0,"stunResistance":5.0}, "receivers + level row + stun resistance: "+str(ADAPTER.approx_values(opened,90,0)))
	check(opened.get("ignored",{}).has("PVPDamageReduction") and opened.get("ignored",{}).has("IgnoreCounterBarrierProbability"), "unreceived rows listed, not applied")
	profile.bonuses.append(entry.call("PassiveCastSpell",1.0,"Value"))
	check(adapter.source_approx_passive("lmref_v","기사").has("reason"), "unsupported spell bonus still holds")

func book_owners(catalog, bound: Dictionary) -> Dictionary:
	var spells: Dictionary = {}
	for link: Dictionary in DEF.rows("ItemBonus"):
		var bonus: Dictionary = DEF.row("Bonus",int(link.get("BonusID",-1)))
		if bonus.is_empty() or str(DEF.row("BonusType",int(bonus.BonusTypeID)).get("Name","")) != "BuffCardID": continue
		var item: Dictionary = DEF.row("ItemClass",int(link.ItemClassID))
		if item.is_empty() or item.get("TestItem") != false: continue
		var spell: int = int(DEF.row("BuffCard",int(bonus.Value)).get("SpellClassID",0))
		if bound.has(spell): spells[int(item.ID)] = spell
	var blocked: int = 0; var open: int = 0; var approx: int = 0
	for item_id: int in spells:
		var record: Dictionary = catalog.record_for(str(bound[spells[item_id]]))
		if record.get("runtime_blocked",true): blocked += 1
		else:
			open += 1
			if record.has("source_approx523"): approx += 1
	return {"bound_books":spells.size(),"blocked":blocked,"open":open,"open_by_approx":approx}

func attack_spells(world, catalog, adapter) -> Dictionary:
	var out: Dictionary = {"kinds":{}}
	var picks: Dictionary = {}
	var saved: Array = [catalog.learned.duplicate(true), world.job_class, world.level]
	for key: String in adapter.profiles:
		var record: Dictionary = catalog.record_for(key)
		var spec: Dictionary = record.get("source_approx523",{})
		if spec.is_empty(): continue
		for invoke: Dictionary in spec.get("invokes",[]):
			if str(invoke.get("kind","")) != "spell": continue
			var effect: String = str(invoke.spell.effect)
			out.kinds[effect] = int(out.kinds.get(effect,0)) + 1
			if not picks.has(effect) and spec.get("weapons",[]).is_empty() and spec.get("requires",[]).is_empty() and invoke.get("weapons",[]).is_empty() and "melee" in invoke.attack_kinds and not bool(invoke.by_spell) and float(invoke.chance) >= 0.03:
				picks[effect] = {"id":key,"name":str(record.name),"class":str(record["class"]),"invoke":invoke}
	check(out.kinds.has("damage") and out.kinds.has("debuff"), "Attack_Spell children open as damage and debuff: "+str(out.kinds))
	# Explicit runtime test fixture (never an original spawn record), next to the player.
	var target: TwilightMonster = preload("res://scenes/Monster.tscn").instantiate()
	target.position = world.monsters_root.to_local(world.player.global_position + Vector2(24, 0))
	world.monsters_root.add_child(target)
	out["fixture_setup"] = target.setup({"name":"approx523_proc_fixture","hp":1000000000,"lv":1,"atk":0}, world.player, world, null)
	target.set_physics_process(false)
	out["target"] = str(target.get("monster_name")) if target != null else ""
	check(target != null, "a real field monster for the proc check")
	if target == null:
		catalog.learned = saved[0]; world.job_class = saved[1]; world.level = saved[2]; catalog.revision += 1
		return out
	for effect: String in ["damage","debuff"]:
		if not picks.has(effect): continue
		var pick: Dictionary = picks[effect]
		world.job_class = str(pick["class"]); world.level = 90
		catalog.learned.clear(); catalog.learned[str(pick.id)] = 1; catalog.revision += 1
		var context: Dictionary = world.original_skills.attack_context("melee", false, true)
		var key: String = "approx_spell:" + str(pick.id)
		world.original_skills.event_counts.erase(key)
		var hp_lost: int = 0
		for _i: int in 1000:
			target.hp = 1000000000
			var before: int = target.hp
			world.original_skills.trigger("on_hit", target, {}, context)
			hp_lost += maxi(0, before - target.hp)
		var fired: int = int(world.original_skills.event_counts.get(key,0))
		var expected: float = float(pick.invoke.chance) * 1000.0 * (float(pick.invoke.spell.get("hit_chance",1.0)) if effect == "debuff" else 1.0)
		var row: Dictionary = {"name":pick.name,"chance":pick.invoke.chance,"spell":pick.invoke.spell.get("name",""),"fired_of_1000":fired,"expected":expected,"hp_lost":hp_lost}
		if effect == "debuff":
			var mods: Dictionary = pick.invoke.spell.modifiers
			var first: String = str(mods.keys()[0])
			row["modifier"] = [first, world.original_skills.status.modifier(target, first), mods[first]]
			check(fired > 0 and is_equal_approx(float(row.modifier[1]), float(mods[first])), "debuff child applied to the target: "+str(row))
		else:
			check(fired > 0 and hp_lost > 0, "damage child hits the target: "+str(row))
		check(float(fired) > expected * 0.4 and float(fired) < expected * 1.8 + 5.0, "proc rate near the original chance: "+str(row))
		out[effect] = row
	catalog.learned = saved[0]; world.job_class = saved[1]; world.level = saved[2]; catalog.revision += 1
	if is_instance_valid(target): target.queue_free()
	return out

func run() -> void:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--source523-pack="):
			var base: String = value.trim_prefix("--source523-pack=")
			var pack: Script = load("res://scripts/boot/source523_pack.gd")
			var read: Dictionary = pack.read_descriptor(base.path_join("source523_pack.json"))
			pack.apply(pack.selections(base, read.descriptor, pack.read_addons(base)))
	unit()
	real["archive"] = not DEF.identity().is_empty()
	if real.archive:
		var world = load("res://Main.tscn").instantiate()
		root.add_child(world)
		world.set_process(false)
		world.save_timer = -100000.0
		check(QA.enter_game(world, "기사"), "actual Main class confirmation (기사)")
		var catalog = world.original_skills.catalog
		var adapter = catalog.source523
		var public: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ADAPTER.BINDINGS_PATH))
		var bound: Dictionary = {}
		for id: String in public.skills: bound[int(public.skills[id].spell_id)] = id
		var blocked: int = 0; var refs: int = 0; var approx: Array = []; var passive_blocked: int = 0; var holds: Dictionary = {}
		for key: String in adapter.profiles:
			if not key.begins_with("lmref_"): continue
			refs += 1
			var record: Dictionary = catalog.record_for(key)
			if record.has("source_approx523"): approx.append("%s/%s" % [str(record["class"]),str(record.name)])
			if record.get("runtime_blocked",false):
				blocked += 1
				if int(adapter.profiles[key].row.SpellTypeID) == 3:
					passive_blocked += 1
					var why: String = str(record.get("source_direct523_hold",["",""])[-1]).replace("근사 규칙: ","").split("(")[0].split(" ")[0]
					holds[why] = int(holds.get(why,0)) + 1
		real.merge({"bound_references":refs,"blocked_after":blocked,"blocked_before":blocked + approx.size(),"opened_by_approx":approx.size(),"passive_blocked_after":passive_blocked,"approx_names":approx,"passive_hold_heads":holds}, true)
		check(approx.size() > 0 and blocked + approx.size() == 294, "held references 294 -> %d (approx %d)" % [blocked, approx.size()])
		real["books"] = book_owners(catalog, bound)
		# 1) Level threshold: 이글 아이 (요정) RangeHit 5 @ level 0 ... 10 @ 85.
		world.job_class = "요정"
		var eagle: Dictionary = catalog.record_for("lmref_a28607c239d343da")
		world.level = 69
		var hit0: float = world.original_skills.stat("rangedHit")
		catalog.learned[str(eagle.id)] = 1; catalog.revision += 1
		var hit69: float = world.original_skills.stat("rangedHit") - hit0
		world.level = 85
		var hit85: float = world.original_skills.stat("rangedHit") - hit0
		real["eagle_eye"] = {"name":str(eagle.get("name","")),"approx":eagle.has("source_approx523"),"lv69":hit69,"lv85":hit85}
		check(eagle.has("source_approx523") and is_equal_approx(hit69, 5.0) and is_equal_approx(hit85, 10.0), "이글 아이 원거리 명중 Lv69 +5 / Lv85 +10: %s" % str(real.eagle_eye))
		catalog.learned.erase(str(eagle.id)); catalog.revision += 1
		# 2) Prerequisite: 리덕션 아머(베테랑) needs 리덕션 아머.
		world.job_class = "기사"
		world.level = 90
		var veteran: Dictionary = catalog.record_for("lmref_619e3c051faa2633")
		var base_id: String = str(veteran.get("source_approx523",{}).get("requires",[""])[0])
		catalog.learned.erase(base_id); catalog.revision += 1
		world.inventory[str(veteran.get("book_name","x"))] = 1
		var refused: String = catalog.reason(veteran)
		var stun0: float = world.original_skills.stat("stunResistance")
		var pve0: float = world.original_skills.stat("pveDamageReduction")
		catalog.learned[str(veteran.id)] = 1; catalog.revision += 1
		var without_base: float = world.original_skills.stat("pveDamageReduction") - pve0
		catalog.learned[base_id] = 1; catalog.revision += 1
		var pve: float = world.original_skills.stat("pveDamageReduction") - pve0
		var stun: float = world.original_skills.stat("stunResistance") - stun0
		real["reduction_veteran"] = {"requires":base_id,"refused":refused,"without_base":without_base,"pve_lv90":pve,"stun":stun}
		check(refused.contains("선행 스킬 필요") and is_zero_approx(without_base), "prerequisite: refused and inactive without 리덕션 아머: "+refused)
		check(is_equal_approx(pve, 8.0) and is_equal_approx(stun, 5.0), "리덕션 아머(베테랑) Lv90: PVE 리덕션 +8, 스턴 내성 +5 (인벤 DB와 같음): "+str(real.reduction_veteran))
		# 3) Weapon-bound row: 바운스 어택 양손검 추가 대미지 +5 only with a two-handed sword.
		var bounce: Dictionary = catalog.record_for("lmref_c6eb5c1e8d5bae54")
		var saved_weapon: Variant = world.equipped_items.get("weapon",{})
		world.equipped_items["weapon"] = {}
		var dmg0: float = world.original_skills.stat("meleeDamage"); var hitm0: float = world.original_skills.stat("meleeHit")
		catalog.learned[str(bounce.id)] = 1; catalog.revision += 1
		var unarmed: Array = [world.original_skills.stat("meleeHit") - hitm0, world.original_skills.stat("meleeDamage") - dmg0]
		world.equipped_items["weapon"] = {"name":"근사 시험 양손검","type":"양손검","slot":"weapon"}
		var weapon_id: int = catalog.source_weapon_type_id()
		var armed: Array = [world.original_skills.stat("meleeHit") - hitm0, world.original_skills.stat("meleeDamage") - dmg0]
		real["bounce_attack"] = {"weapon_type_id":weapon_id,"unarmed":unarmed,"two_hand":armed}
		check(is_equal_approx(float(unarmed[0]),7.0) and is_zero_approx(float(unarmed[1])), "바운스 어택 무기 없이: 명중 +7만: "+str(unarmed))
		check(weapon_id == 7 and is_equal_approx(float(armed[1]),5.0), "바운스 어택 양손검: 대미지 +5: "+str(real.bounce_attack))
		# 4) Invoke amplify: 블로우 어택 (Lv84 15%, x3) on normal melee hits.
		var blow: Dictionary = catalog.record_for("lmref_" + ("기사:블로우 어택").sha256_text().substr(0,16))
		world.level = 84
		catalog.learned[str(blow.id)] = 1; catalog.revision += 1
		var list: Array = catalog.approx_invoke_list().filter(func(entry: Dictionary) -> bool: return str(entry.skill_id) == str(blow.id))
		var amplified: int = 0
		var context: Dictionary = world.original_skills.attack_context("melee", false, true)
		for _i: int in 2000:
			if world.original_skills.outgoing_damage(100, context) >= 250: amplified += 1
		var spell_hits: int = 0
		for _i: int in 500:
			if world.original_skills.outgoing_damage(100, world.original_skills.attack_context("melee", true, true)) >= 250: spell_hits += 1
		real["blow_attack"] = {"approx":blow.has("source_approx523"),"invokes":list,"amplified_of_2000":amplified,"spell_amplified_of_500":spell_hits}
		check(list.size() == 1 and is_equal_approx(float(list[0].chance),0.15) and is_equal_approx(float(list[0].multiplier),3.0), "블로우 어택 Lv84 발동 15% x3: "+str(list))
		check(amplified > 200 and amplified < 420, "블로우 어택 실제 일반 근접 2000회 중 약 15%% 증폭: %d" % amplified)
		world.equipped_items["weapon"] = saved_weapon
		# 4b) Attack_Spell child spells (TWILIGHT 근사): one damage and one debuff
		# passive without weapon/prerequisite conditions, on a real monster.
		real["attack_spell"] = await attack_spells(world, catalog, adapter)
		# 5) Save/load keeps learned approximated passives and their stats.
		var before: float = world.original_skills.stat("pveDamageReduction")
		check(world._save_game(true) == OK, "save with approximated passives learned")
		var text: String = FileAccess.get_file_as_string(world.SAVE_PATH)
		check(not text.contains("source_approx523") and not text.contains("row_json"), "save holds no original rows or approx specs")
		catalog.learned.erase(str(veteran.id)); catalog.revision += 1
		world._load_game(true)
		real["after_load"] = {"veteran_learned":int(catalog.learned.get(str(veteran.id),0)),"pve":world.original_skills.stat("pveDamageReduction"),"pve_before":before}
		check(int(catalog.learned.get(str(veteran.id),0)) == 1, "learned approximated passive survives save/load")
	print("SKILL523_APPROX_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "real":real}))
	quit(0 if failures.is_empty() else 1)
