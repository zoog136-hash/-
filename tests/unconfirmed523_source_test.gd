extends SceneTree

const Source = preload("res://scripts/unconfirmed523/source523.gd")
var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var directory: String = "user://source523-fixture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var tables: Dictionary = {
		"ItemClass":[{"ID":26,"Name":"fixture coin","TestItem":false},{"ID":7,"Name":"fixture dated item","TestItem":false},{"ID":8,"Name":"fixture class item","TestItem":false,"LevelLimitMin":10},{"ID":9,"Name":"fixture DateTime item","TestItem":false}],
		"ItemClassLimit":[{"ItemClassID":8,"ClassID":2}],
		"ItemBonus":[{"ID":1,"ItemClassID":7,"BonusID":8},{"ID":2,"ItemClassID":9,"BonusID":10}],
		"RewardType":[{"ID":1,"Name":"Exp"},{"ID":2,"Name":"Item"},{"ID":5,"Name":"Einasad"},{"ID":6,"Name":"Gem"},{"ID":91,"Name":"NoReward"},{"ID":101,"Name":"RandomReward"},{"ID":111,"Name":"SelectReward"},{"ID":124,"Name":"ComplexReward"},{"ID":172,"Name":"PassSystemSeasonPassExp"},{"ID":184,"Name":"Bonus"}],
		"Reward":[
			{"ID":1,"RewardTypeID":2,"RewardClassID":26,"Amount":3,"ItemBlessCodeID":2,"Enchant":4},
			{"ID":2,"RewardTypeID":5,"RewardClassID":1859,"Amount":500},
			{"ID":3,"RewardTypeID":111,"RewardClassID":11,"Amount":0},
			{"ID":4,"RewardTypeID":124,"RewardClassID":21,"Amount":0},
			{"ID":5,"RewardTypeID":101,"RewardClassID":31,"Amount":1},
			{"ID":6,"RewardTypeID":41,"RewardClassID":1,"Amount":1},
			{"ID":7,"RewardTypeID":124,"RewardClassID":22,"Amount":0},
			{"ID":8,"RewardTypeID":101,"RewardClassID":32,"Amount":1},
			{"ID":9,"RewardTypeID":101,"RewardClassID":33,"Amount":1},
			{"ID":10,"RewardTypeID":5,"RewardClassID":97121,"Amount":0},
			{"ID":11,"RewardTypeID":2,"RewardClassID":26,"Amount":1,"ClanOnly":true},
			{"ID":12,"RewardTypeID":172,"RewardClassID":12,"Amount":60},
			{"ID":13,"RewardTypeID":6,"RewardClassID":777,"Amount":7},
			{"ID":14,"RewardTypeID":1,"RewardClassID":281,"Amount":1000},
			{"ID":15,"RewardTypeID":184,"RewardClassID":1,"Amount":1},
			{"ID":16,"RewardTypeID":2,"RewardClassID":26,"Amount":1,"UseImmediately":true},
			{"ID":17,"RewardTypeID":91,"RewardClassID":26,"Amount":1},
			{"ID":18,"RewardTypeID":111,"RewardClassID":12,"Amount":0},
			{"ID":19,"RewardTypeID":101,"RewardClassID":34,"Amount":1},
			{"ID":20,"RewardTypeID":124,"RewardClassID":23,"Amount":0},
			{"ID":21,"RewardTypeID":2,"RewardClassID":26,"Amount":1,"RewardEnhancementTypeID":11}],
		"RewardAttribute":[],
		"SelectReward":[{"ID":11,"SelectMaxCount":1},{"ID":12,"SelectMaxCount":1}],
		"SelectRewardEntity":[{"ID":101,"SelectRewardID":11,"RewardID":1},{"ID":102,"SelectRewardID":11,"RewardID":2},{"ID":103,"SelectRewardID":12,"RewardID":3},{"ID":104,"SelectRewardID":12,"RewardID":1}],
		"ComplexRewardGroup":[{"ID":21},{"ID":22},{"ID":23}],
		"ComplexReward":[{"ID":201,"ComplexRewardGroupID":21,"ComplexRewardTypeID":4,"MaxCount":1},{"ID":202,"ComplexRewardGroupID":21,"ComplexRewardTypeID":14,"MaxCount":1},{"ID":203,"ComplexRewardGroupID":22,"ComplexRewardTypeID":4,"MaxCount":2},{"ID":204,"ComplexRewardGroupID":23,"ComplexRewardTypeID":24,"MaxCount":1}],
		"ComplexRewardEntity":[{"ID":301,"ComplexRewardID":201,"RewardID":1},{"ID":302,"ComplexRewardID":202,"RewardID":2},{"ID":303,"ComplexRewardID":203,"RewardID":1},{"ID":304,"ComplexRewardID":203,"RewardID":6},{"ID":305,"ComplexRewardID":204,"RewardID":3,"Probability":1000000}],
		"RandomReward":[{"ID":31},{"ID":32},{"ID":33},{"ID":34}],
		"RandomRewardEntityView":[{"RandomRewardID":31,"RewardID":1},{"RandomRewardID":31,"RewardID":2},{"RandomRewardID":32,"RewardID":8,"Probability":1000000},{"RandomRewardID":33,"RewardID":1,"Probability":0},{"RandomRewardID":34,"RewardID":3}],
		"Bonus":[{"ID":1,"BonusTypeID":1,"Value":5},{"ID":2,"BonusTypeID":133,"Value":125000},{"ID":3,"BonusTypeID":301,"Value":4},{"ID":4,"BonusTypeID":7304,"Value":9},{"ID":5,"BonusTypeID":5031,"Value":3},{"ID":6,"BonusTypeID":1,"Value":100,"BonusApplicationTypeID":2},{"ID":7,"BonusTypeID":17,"Value":25},{"ID":8,"BonusTypeID":492,"Value":2026010100},{"ID":9,"BonusTypeID":21,"Value":3},{"ID":10,"BonusTypeID":492,"Value":0,"BonusApplicationTypeID":298,"BonusApplicationTargetID":1}],
		"BonusApplicationType":[{"ID":298,"Name":"DateTime"}],
		"BonusType":[{"ID":1,"Name":"MeleeDamage","UnitID":1},{"ID":17,"Name":"HPPlus","UnitID":1},{"ID":21,"Name":"ArmorClass","UnitID":1},{"ID":133,"Name":"ExperienceAdditionPercent","UnitID":3},{"ID":301,"Name":"PVPDamageReduction","UnitID":1},{"ID":7304,"Name":"UndeadAdditionalMaxDamage","UnitID":1},{"ID":5031,"Name":"SelectRewardClassID","UnitID":10454},{"ID":492,"Name":"DeleteTime","UnitID":162}],
		"Unit":[{"ID":1,"Name":"Value"},{"ID":3,"Name":"Percentage"},{"ID":10454,"Name":"RewardID"},{"ID":162,"Name":"Time"}],
		"ServerLimit":[{"ID":1,"ServerLimitSetID":10,"WorldNo":1,"ServiceRegionCode":"KR"},{"ID":2,"ServerLimitSetID":10,"WorldNo":2,"ServiceRegionCode":"TW"}],
		"DateTimes_Korean":[{"ID":1,"Year":2026,"Month":1,"Day":1,"Hour":9,"Minute":0},{"ID":2,"Year":2026,"Month":2,"Day":30,"Hour":1,"Minute":0}],
		"Duplicate":[{"ID":1,"Value":1},{"ID":1,"Value":2},{"ID":2,"Value":3}]
	}
	tables.BonusType.append_array([{"ID":140,"Name":"CastSpeedBonus","UnitID":3},{"ID":4581,"Name":"PierceDamageReduction","UnitID":1},{"ID":5681,"Name":"IgnoreMeleeDamageReductionPercent","UnitID":3},{"ID":7818,"Name":"PVPDamageReductionPercent","UnitID":3}])
	tables.Bonus.append_array([{"ID":11,"BonusTypeID":140,"Value":100000},{"ID":12,"BonusTypeID":4581,"Value":3},{"ID":13,"BonusTypeID":5681,"Value":150000},{"ID":14,"BonusTypeID":7818,"Value":50000},{"ID":15,"BonusTypeID":7818,"Value":100000,"BonusApplicationTypeID":2}])
	for table in tables:
		var file: FileAccess = FileAccess.open(directory.path_join(str(table)+".json"),FileAccess.WRITE)
		file.store_string("\ufeff"+JSON.stringify({"rows":tables[table]}))
		file.close()
	OS.set_environment("TWILIGHT_523_ALLOW_TEST_SOURCE", "")
	var denied = Source.new()
	check(not denied.configure_directory(directory).ok,"directory source must be explicitly test gated")
	OS.set_environment("TWILIGHT_523_ALLOW_TEST_SOURCE", "1")
	var source = Source.new()
	check(source.configure_directory(directory).ok,"fixture source configured")
	check(source.is_ready() and source.status().table_count == tables.size(),"ready/status source contract")
	check(source.rows("Reward").is_read_only() and source.row("Reward",1).is_read_only(),"cached source rows remain immutable")
	check(source.row("Duplicate",1).is_empty() and source.last_error.begins_with("duplicate_id:"),"duplicate IDs fail closed")
	check(source.row("Duplicate",2).Value == 3,"unique IDs in duplicate table remain accessible")
	check(not source.load_zip("missing.zip").ok and source.last_error == "restart_required","session source cannot change")
	var context: Dictionary = {"now":0,"time_policy":{"utc_offset_minutes":540},"level":20,"class_id":2}
	check(source.timestamp(1,context) == 1767225600,"naive source datetime interpreted with explicit offset")
	check(source.row("DateTimes_Korean",1).Hour == 9,"timestamp leaves source row unchanged")
	check(source.timestamp(2,context) == -1,"invalid calendar dates are rejected")
	check(source.region_allowed(10,{"service_region":"KR","world_no":1}),"exact KR/world1 allowed")
	check(not source.region_allowed(10,{"service_region":"KR","world_no":2}),"no cross-region world wildcard")
	check(not source.region_allowed(999,{}),"unknown region set fails closed")
	check(source.can_own_item(7,context),"packed DeleteTime allows before expiration")
	check(not source.can_own_item(7,{"now":1767225600,"time_policy":{"utc_offset_minutes":0}}),"packed DeleteTime expires at exact boundary")
	check(source.can_own_item(9,context),"native DateTime298 item allowed before expiration")
	check(not source.can_own_item(9,{"now":1767225600,"time_policy":{"utc_offset_minutes":540}}),"native DateTime298 item expires at exact offset boundary")
	check(source.can_own_item(8,context),"class/level limits do not bar ownership")
	check(not source.can_own_item(8,{"enforce_item_use_limits":true,"level":1,"class_id":2}),"use limits explicitly enforce source level")
	check(not source.can_own_item(8,{"enforce_item_use_limits":true,"level":20,"class_id":1}),"use limits enforce source class namespace")
	var item: Dictionary = source.resolve_reward(1,context)
	check(item.ok and item.rewards[0].id == 26 and item.rewards[0].amount == 3 and item.rewards[0].bless_code == 2 and item.rewards[0].enchant == 4,"item leaf preserves quantity/blessing/enchant")
	var blessing: Dictionary = source.resolve_reward(2,context)
	check(blessing.ok and blessing.rewards[0].kind == "blessing" and blessing.rewards[0].amount == 500,"Einasad5 is blessing, not a nested reward")
	check(not source.resolve_reward(10,context).ok,"unknown zero-amount blessing rule rejected")
	check(not source.resolve_reward(11,context).ok,"clan rewards excluded")
	check(source.resolve_reward(12,context).rewards[0].kind == "pass_exp","pass experience leaf")
	check(source.resolve_reward(13,context).rewards[0].id == 2,"Gem6 maps currency2")
	check(source.resolve_reward(14,context).rewards[0].kind == "experience","Exp1 leaf")
	check(not source.resolve_reward(15,context).ok,"bonus reward requires an active pass")
	var pass_context: Dictionary = context.duplicate(true)
	pass_context.merge({"pass_id":12,"pass_expires_at":2000})
	var pass_bonus: Dictionary = source.resolve_reward(15,pass_context)
	check(pass_bonus.ok and pass_bonus.rewards[0].kind == "bonus" and pass_bonus.rewards[0].pass_id == 12 and pass_bonus.rewards[0].expires_at == 2000,"pass bonus leaf preserves season expiry")
	check(not source.resolve_reward(16,context).ok,"immediate-use item requires a host consumer")
	check(not source.resolve_reward(21,context).ok,"paid quest tier is never confused with equipment enchant")
	var no_reward: Dictionary = source.resolve_reward(17,context)
	check(no_reward.ok and no_reward.rewards.is_empty() and no_reward.no_reward_ids == [17],"NoReward display reference never grants its referenced item")
	var outer: Dictionary = source.reward_choices(18,context)
	check(outer.ok and outer.choices.size() == 1 and outer.choices[0].key == "selection.18","unselected nested branch asks only its outer choice")
	var selected: Dictionary = source.reward_choices(18,context,{18:[103]})
	check(selected.choices.size() == 1 and selected.choices[0].key == "selection.3","explicit branch reveals only its own nested choice")
	check(source.reward_choices(18,context,{18:[104]}).choices.is_empty(),"unselected sibling never requests a choice")
	check(not source.reward_choices(18,context,{18:[999]}).ok,"preview validates selection IDs")
	check(source.reward_choices(19,context).choices.is_empty() and source.reward_choices(19,context).deferred_random.size() == 1,"random preview defers branch-specific choices without rolling")
	check(source.reward_choices(20,context).choices.is_empty() and source.reward_choices(20,context).deferred_random.size() == 1,"weighted complex preview defers branch-specific choices")
	check(not source.resolve_reward(3,context).ok,"selection never grants every option implicitly")
	check(source.resolve_reward(3,context,{3:[102]}).rewards[0].kind == "blessing","explicit selection entity")
	check(not source.resolve_reward(3,context,{3:[101,102]}).ok,"selection maximum enforced")
	check(not source.resolve_reward(3,context,{3:[999]}).ok,"selection outside group rejected")
	check(source.resolve_reward(4,context,{202:[302]}).rewards.size() == 2,"complex guaranteed plus selected rewards")
	var partial: Dictionary = source.resolve_reward(7,context)
	check(not partial.ok and partial.rewards.is_empty(),"unsupported complex child rejects every staged reward")
	var rng := RandomNumberGenerator.new()
	rng.seed = 523
	check(not source.resolve_reward(5,context,{},rng).ok,"missing random probabilities fail by default")
	var estimated: Dictionary = context.duplicate(true)
	estimated["twilight_policy"] = {"random_reward_weight_mode":"equal_estimate"}
	var roll: Dictionary = source.resolve_reward(5,estimated,{},rng)
	check(roll.ok and roll.rewards.size() == 1 and roll.assumptions[0].policy == "TWILIGHT" and not roll.assumptions[0].official_probabilities,"explicit estimated roll records policy and source candidates")
	check(not source.resolve_reward(5,estimated).ok,"random roll needs caller-owned RNG")
	var before_rng: int = rng.state
	check(not source.resolve_reward(8,context,{},rng).ok,"recursive reward cycles are rejected")
	check(rng.state == before_rng,"failed reward resolution restores caller RNG state")
	check(source.resolve_reward(9,context,{},rng).rewards.is_empty(),"unfilled probability is retained as no reward")
	var bonuses: Dictionary = source.bonus_stats([1,2,3,4,5,6,7])
	check(bonuses.stats["melee_damage:flat"] == 5 and bonuses.stats["max_hp:flat"] == 25,"unconditional native bonus keys")
	check(bonuses.stats["experience_bonus:percent"] == 12.5,"scaled percent raw/10000 yields percentage points")
	check(source.bonus_stats([9]).stats["ac:flat"] == -3,"source AC minus-prefix maps to signed native AC")
	check(bonuses.unsupported.size() == 2 and bonuses.unsupported[0].unit == "RewardID","reward references and unresolved application contexts retain unsupported metadata")
	check(bonuses.effects.size() == 6,"conditional PvP/undead/application effects preserved without unconditional addition")
	check(bonuses.conditional_stats.pvp["pvp_damage_reduction:flat"] == 4 and bonuses.conditional_stats.undead["undead_additional_max_damage:flat"] == 9,"recognized target effects have separate conditional consumers")
	check(not bonuses.stats.has("pvp_damage_reduction:flat") and not bonuses.stats.has("undead_additional_max_damage:flat"),"target effects never enter unconditional totals")
	var combat: Dictionary = source.bonus_stats([11,12,13,14,15],{"pvp":true,"undead":true})
	check(combat.stats["cast_speed:percent"] == 10 and combat.stats["damage_reduction_ignore:flat"] == 3 and combat.stats["ignore_melee_damage_reduction:percent"] == 15,"source combat keys preserve flat and scaled percent units")
	check(combat.conditional_stats.pvp["pvp_damage_reduction:percent"] == 5 and not combat.stats.has("pvp_damage_reduction:percent"),"declared PvP context still cannot leak target stats into global totals")
	check(combat.unsupported.size() == 1 and combat.unsupported[0].bonus_id == 15,"unresolved application condition is not treated as unconditional PvP bonus")
	var invalid_zip = Source.new()
	check(not invalid_zip.load_zip(directory.path_join("Reward.json")).ok,"nonmatching ZIP size rejected")
	var actual_directory: String = OS.get_environment("TWILIGHT_523_SOURCE_DIR")
	if not actual_directory.is_empty():
		var actual = Source.new()
		check(actual.configure_directory(actual_directory).ok,"actual private source directory available")
		check(actual.rows("Reward").size() == 36038 and actual.rows("ItemClass").size() == 34743,"actual source row counts")
		var actual_blessing: Dictionary = actual.resolve_reward(307811,{})
		check(actual_blessing.ok and actual_blessing.rewards[0].kind == "blessing" and actual_blessing.rewards[0].amount == 5000,"actual source Einasad leaf")
		check(not actual.resolve_reward(74,{}).ok,"actual unresolved Einasad rule fails safely")
		check(actual.region_allowed(512,{"service_region":"KR","world_no":1}),"actual ServerLimit512 KR world1")
		var actual_bonus: Dictionary = actual.bonus_stats([22])
		check(actual_bonus.stats.get("con:flat",0) == 30,"actual Bonus22 resolves BonusType45 Constitution")
		var empty_count: int = 0
		var pass_bonus_ids: Array = []
		var actual_context: Dictionary = {"now":1793800800,"level":89,"class_id":1,"service_region":"KR","world_no":1,"pass_id":724,"pass_expires_at":1796392800,"twilight_policy":{"random_reward_weight_mode":"equal_estimate"}}
		for reward: Dictionary in actual.rows("Reward"):
			if int(reward.RewardTypeID) == 91:
				var empty_result: Dictionary = actual.resolve_reward(int(reward.ID),actual_context)
				if empty_result.ok and empty_result.rewards.is_empty(): empty_count += 1
			if int(reward.RewardTypeID) == 184: pass_bonus_ids.append(int(reward.RewardClassID))
		check(empty_count == 15,"all fifteen actual NoReward rows deliver no item, currency, or invented effect")
		var all_pass_bonuses: Dictionary = actual.bonus_stats(pass_bonus_ids)
		check(pass_bonus_ids.size() == 62 and all_pass_bonuses.unsupported.is_empty() and all_pass_bonuses.effects.size() == 62,"all sixty-two source pass bonuses resolve through native stat units")
		var planner_count: int = 0
		for reward: Dictionary in actual.rows("Reward"):
			if int(reward.RewardTypeID) in [101,111,124]:
				var plan: Dictionary = actual.reward_choices(int(reward.ID))
				if plan.ok: planner_count += 1
		check(planner_count == 1634,"whole-source nested planner accepts 1634 graphs and retains sole unknown multi-draw Test graph rejection")
		var audit_directory: String = OS.get_environment("TWILIGHT_523_AUDIT_DIR")
		if not audit_directory.is_empty():
			_write_coverage(actual,actual_context,audit_directory,"after")
			var baseline_path: String = OS.get_environment("TWILIGHT_523_BASELINE_SCRIPT")
			if not baseline_path.is_empty():
				var baseline_script: GDScript = load(baseline_path)
				var baseline = baseline_script.new()
				check(baseline.configure_directory(actual_directory).ok,"read-only frozen HEAD baseline loaded for actual before/after ID audit")
				_write_coverage(baseline,actual_context,audit_directory,"before")
	var actual_zip: String = OS.get_environment("TWILIGHT_523_SOURCE_ZIP")
	if not actual_zip.is_empty():
		var packed = Source.new()
		check(packed.load_zip(actual_zip).ok,"actual ZIP exact size/SHA/index validated")
		check(packed.status().table_count == 1065 and packed.rows("Reward").size() == 36038,"ZIP reads BOM source lazily with per-table hash")
		check(packed.row("ItemClass",26).Name == "[화폐] 아데나","actual ItemClass namespace from ZIP")
		if OS.get_environment("TWILIGHT_523_TEST_INSTALL") == "1":
			var installed = Source.new()
			check(installed.install_zip(actual_zip).ok,"verified ZIP installed atomically into isolated user data")
			check(FileAccess.get_sha256(Source.SOURCE_PATH) == Source.SOURCE_SHA256,"installed ZIP bytes preserve exact hash")
			check(not installed.install_zip(actual_zip).ok,"loaded source install requires restart")
	print("UNCONFIRMED523 SOURCE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _write_coverage(source: Object, context: Dictionary, directory: String, phase: String) -> void:
	# Read-only audit: no inventory, live ledger, or caller RNG is mutated.
	# Explicit first-option fixture selections assess the resolver; the report
	# keeps their policy separate from source-supported/no-selection outcomes.
	var choices: Dictionary = {}
	for reward: Dictionary in source.rows("Reward"):
		if int(reward.RewardTypeID) == 111:
			var entities: Array = source.find_rows("SelectRewardEntity","SelectRewardID",int(reward.RewardClassID))
			if not entities.is_empty(): choices[int(reward.ID)] = [int(entities[0].ID)]
	for group: Dictionary in source.rows("ComplexReward"):
		if int(group.ComplexRewardTypeID) == 14:
			var entities: Array = source.find_rows("ComplexRewardEntity","ComplexRewardID",int(group.ID))
			if not entities.is_empty(): choices[int(group.ID)] = [int(entities[0].ID)]
	var allowed: Array = []
	var blocked: Dictionary = {}
	var per_type: Dictionary = {}
	for reward: Dictionary in source.rows("Reward"):
		var id: int = int(reward.ID)
		var ctx: Dictionary = context.duplicate(true)
		# Source class restrictions are assessed separately, never discarded.
		if int(reward.get("CharacterClassID",0)) != 0: ctx.class_id = int(reward.CharacterClassID)
		var rng := RandomNumberGenerator.new()
		rng.seed = 523 + id
		var resolved: Dictionary = source.resolve_reward(id,ctx,choices,rng)
		var type_key: String = str(int(reward.RewardTypeID))
		if not per_type.has(type_key): per_type[type_key] = {"allowed_ids":[],"blocked_ids":[]}
		if resolved.ok:
			allowed.append(id); per_type[type_key].allowed_ids.append(id)
		else:
			var error: String = str(resolved.get("error","unknown_error"))
			if not blocked.has(error): blocked[error] = []
			blocked[error].append(id); per_type[type_key].blocked_ids.append(id)
	var file: FileAccess = FileAccess.open(directory.path_join("actual_resolver_coverage_"+phase+".json"),FileAccess.WRITE)
	check(file != null,"private actual source coverage audit writable")
	if file != null:
		file.store_string(JSON.stringify({"source_sha256":Source.SOURCE_SHA256,"phase":phase,"method":"Every Reward row, exact class context, source eligibility retained, explicit first-option fixture selection, deterministic per-root RNG, declared equal_estimate TWILIGHT policy. Resolving one selected outcome does not prove every optional/random branch claimable.","context":context,"total":source.rows("Reward").size(),"allowed_ids":allowed,"blocked_by_error":blocked,"per_type":per_type},"\t")+"\n")
		file.close()
