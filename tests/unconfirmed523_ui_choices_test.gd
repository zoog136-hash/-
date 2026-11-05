extends SceneTree
## Nonvisual DTO tests. Synthetic tables exercise the unchanged source planner.
const EVENTS = preload("res://scripts/unconfirmed523/events_domain.gd")
var failures: Array[String] = []
var checks: int = 0

class ChoiceSource extends "res://scripts/unconfirmed523/source523.gd":
	var tables: Dictionary = {}
	var resolve_calls: int = 0
	func rows(table: String) -> Array: return tables.get(table,[])
	func row(table: String, id: int) -> Dictionary:
		for value: Dictionary in rows(table):
			if int(value.get("ID",0)) == id: return value
		return {}
	func resolve_reward(_reward_id: int, _context: Dictionary, _selection: Dictionary = {}, _rng: RandomNumberGenerator = null) -> Dictionary:
		resolve_calls += 1
		return {"ok":false,"error":"preview_must_not_resolve"}
	func item_eligibility(_id: int, _context: Dictionary = {}) -> Dictionary: return {"ok":true}

class TableSource extends RefCounted:
	var tables: Dictionary = {}
	func rows(table: String) -> Array: return tables.get(table,[])
	func row(table: String, id: int) -> Dictionary:
		for value: Dictionary in rows(table):
			if int(value.get("ID",0)) == id: return value
		return {}

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("UI_CHOICES_FAIL: "+label)
func keys(planned: Dictionary) -> Array:
	return planned.get("choices",[]).map(func(choice: Dictionary): return choice.key)
func fixture() -> Dictionary:
	var source := ChoiceSource.new()
	source.tables = {
		"ItemClass":[{"ID":1,"Name":"First"},{"ID":2,"Name":"Second"},{"ID":1000,"Name":"Selection box","CategoryID":10381},{"ID":1001,"Name":"Invalid box","CategoryID":10381},{"ID":1002,"Name":"Complex box","CategoryID":10394}],
		"ItemCategory":[{"ID":10381,"IsConsumable":true},{"ID":10394,"IsConsumable":true}],
		"ItemBonus":[{"ItemClassID":1000,"BonusID":1},{"ItemClassID":1001,"BonusID":2},{"ItemClassID":1002,"BonusID":3}],
		"Bonus":[{"ID":1,"BonusTypeID":5031,"Value":100},{"ID":2,"BonusTypeID":5031,"Value":600},{"ID":3,"BonusTypeID":5774,"Value":400}],
		"Reward":[{"ID":1,"RewardTypeID":2,"RewardClassID":1,"Amount":2},{"ID":2,"RewardTypeID":2,"RewardClassID":2,"Amount":3},{"ID":100,"RewardTypeID":111,"RewardClassID":10},{"ID":200,"RewardTypeID":111,"RewardClassID":20},{"ID":300,"RewardTypeID":101,"RewardClassID":30},{"ID":400,"RewardTypeID":124,"RewardClassID":40},{"ID":500,"RewardTypeID":124,"RewardClassID":50},{"ID":600,"RewardTypeID":111,"RewardClassID":60}],
		"SelectReward":[{"ID":10,"SelectMaxCount":1},{"ID":20,"SelectMaxCount":1}],
		"SelectRewardEntity":[{"ID":101,"SelectRewardID":10,"RewardID":200},{"ID":102,"SelectRewardID":10,"RewardID":1},{"ID":201,"SelectRewardID":20,"RewardID":2},{"ID":202,"SelectRewardID":20,"RewardID":300}],
		"RandomReward":[{"ID":30}],"RandomRewardEntityView":[{"RandomRewardID":30,"RewardID":200}],
		"ComplexRewardGroup":[{"ID":40},{"ID":50}],
		"ComplexReward":[{"ID":401,"ComplexRewardGroupID":40,"ComplexRewardTypeID":4,"MaxCount":1},{"ID":402,"ComplexRewardGroupID":40,"ComplexRewardTypeID":14,"MaxCount":1},{"ID":501,"ComplexRewardGroupID":50,"ComplexRewardTypeID":24,"MaxCount":1}],
		"ComplexRewardEntity":[{"ID":411,"ComplexRewardID":401,"RewardID":1},{"ID":421,"ComplexRewardID":402,"RewardID":200},{"ID":422,"ComplexRewardID":402,"RewardID":2},{"ID":511,"ComplexRewardID":501,"RewardID":200,"Probability":1000000}]
	}
	var domain := EVENTS.new(); domain.setup(source)
	return {"source":source,"domain":domain,"context":{"now":1793780000,"level":90,"class_id":1,"region":"KR","service_region":"KR","world_no":1,"owned":{"1000":1,"1001":1,"1002":1},"twilight_policy":{}},"state":domain.initial_state()}

func run() -> void:
	var f: Dictionary = fixture()
	var domain = f.domain
	var source = f.source
	var context_before: Dictionary = f.context.duplicate(true)
	var state_before: Dictionary = f.state.duplicate(true)
	var tables_before: Dictionary = source.tables.duplicate(true)
	var action: Dictionary = domain._reward_action("Source claim",{"action":"attendance_claim","version_id":9,"index":1},100,f.context)
	check(action.reward_root_ids == [100] and action.choice_plan.ok and keys(action.choice_plan) == ["selection.100"],"reward action carries its authoritative root and only the unanswered parent selection")
	check(action.required_choices[0].min_count == 1 and action.required_choices[0].max_count == 1 and action.required_choices[0].value_shape == "array","source reward choice cardinality and array shape are explicit")
	var parent: Dictionary = {"100":[101]}
	var planned: Dictionary = domain.presentation_choices(action,f.context,parent)
	check(planned.ok and keys(planned) == ["selection.200"],"selected parent branch reveals its nested requirement without requesting its parent again")
	check(planned.choices[0].options[0].label == "Second ×3","nested option label comes from the selected source reward")
	planned = domain.presentation_choices(action,f.context,{"100":[101],"200":[201]})
	check(planned.ok and planned.choices.is_empty(),"explicitly answered source branch reaches a choice-free confirmation")
	planned = domain.presentation_choices(action,f.context,{"100":[102]})
	check(planned.ok and planned.choices.is_empty(),"unselected nested branch never requests a choice")
	for selection: Dictionary in [{"100":[101,101]},{"100":[999]},{"100":[101.5]},{"100":"101"}]:
		check(not domain.presentation_choices(action,f.context,selection).ok,"source planner rejects duplicate foreign fractional or wrongly typed selection")
	var retained: Dictionary = action.duplicate(true)
	retained.required_choices.append({"key":"instance_id","options":[{"label":"Owned","value":"physical-A"}],"count":1})
	retained.required_choices.append({"key":"luckybag_selection","options":[{"value":900}],"count":1})
	var retained_before: Dictionary = retained.duplicate(true)
	planned = domain.presentation_choices(retained,f.context,parent)
	check(keys(planned) == ["instance_id","luckybag_selection","selection.200"] and planned.choices[0].value_shape == "scalar" and planned.choices[1].value_shape == "array","native physical selection remains scalar while luckybag and reward choices remain arrays")
	check(retained == retained_before and parent == {"100":[101]},"dynamic planner never edits action or selected request data")
	planned = domain.presentation_choices({"reward_root_ids":[300]},f.context)
	check(planned.ok and planned.choices.is_empty() and planned.deferred_random.size() == 1 and planned.deferred_random[0].candidate_reward_ids == [200],"random nested branch stays deferred without choosing or resolving a reward")
	planned = domain.presentation_choices({"reward_root_ids":[500]},f.context)
	check(planned.ok and planned.choices.is_empty() and planned.deferred_random[0].complex_reward_id == 501,"weighted complex branch stays deferred without implicit nested choices")
	planned = domain.presentation_choices({"reward_root_ids":[400]},f.context)
	check(planned.ok and keys(planned) == ["selection.402"],"complex root presents its authoritative source group")
	planned = domain.presentation_choices({"reward_root_ids":[400]},f.context,{"402":[421]})
	check(planned.ok and keys(planned) == ["selection.200"],"complex selected branch delegates its next source selection")
	planned = domain.presentation_choices({"reward_root_ids":[100,500]},f.context)
	check(planned.ok and keys(planned) == ["selection.100"] and planned.deferred_random.size() == 1,"multiple exact roots preserve both unanswered and deferred metadata")
	for roots: Variant in [[100,100],[0],[100.5],"100"]:
		check(not domain.presentation_choices({"reward_root_ids":roots},f.context).ok,"malformed or duplicate root metadata fails closed")
	var invalid: Dictionary = domain._reward_action("Invalid",{},600,f.context)
	check(invalid.disabled and not invalid.choice_plan.ok and invalid.choice_error == "selection_definition_missing","source planning failure is explicit disabled metadata rather than an empty successful choice list")
	var container_actions: Dictionary = {}
	for row: Dictionary in domain.view(f.context,f.state).rows:
		if str(row.id).begins_with("container:") and not row.actions.is_empty(): container_actions[row.id] = row.actions[0]
	check(container_actions["container:1000"].reward_root_ids == [100] and container_actions["container:1002"].reward_root_ids == [400],"actual selection and complex container DTOs expose source root IDs without label parsing")
	check(container_actions["container:1001"].disabled and container_actions["container:1001"].choice_error == "selection_definition_missing","container source planning error reaches its offered action")
	var bare := TableSource.new(); bare.tables = source.tables
	var fixture_domain := EVENTS.new(); fixture_domain.setup(bare)
	planned = fixture_domain.presentation_choices(action,f.context,parent)
	check(planned.ok and keys(planned) == ["selection.200"],"minimal table fixtures reuse the exact production choice planner for nested requests")
	check(source.resolve_calls == 0 and f.context == context_before and f.state == state_before and source.tables == tables_before,"all choice previews preserve source context state ownership and RNG without any resolver call")
	if failures.is_empty(): print("UNCONFIRMED523_UI_CHOICES_OK: %d assertions" % checks); quit(0)
	else: printerr("UNCONFIRMED523_UI_CHOICES_FAILED: "+", ".join(failures)); quit(1)
