extends SceneTree
const Source = preload("res://scripts/death/source_rules.gd")
var failures: Array[String] = []
var checks: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	var rules = Source.new()
	check(rules.item_exemption_level() == 30 and rules.item_exemption_origin() == "TWILIGHT_REVIEWED_DEFAULT","uninstalled rules preserve the reviewed local item boundary")
	check(rules.exp_loss(29,50000,100000) == 0 and rules.exp_loss(30,50000,100000) == 5000,"uninstalled XP policy keeps its independent level30 boundary")
	# Synthetic schema cases prove the scalar is parsed, never a source fixture
	# or authorization to install modified source archives.
	var valid: Dictionary = {"ID":11071,"Name":"NoDeathPenaltyLevel","Type":1,"Value":"21"}
	check(Source.read_item_exemption_level([valid],160) == 21,"typed scalar value comes from its field")
	for invalid: Array in [
		[],[valid,valid],
		[{"ID":11071,"Name":"NoDeathPenaltyLevel","Type":1,"Value":30}],
		[{"ID":11071,"Name":"NoDeathPenaltyLevel","Type":true,"Value":"30"}],
		[{"ID":11071.5,"Name":"NoDeathPenaltyLevel","Type":1,"Value":"30"}],
		[{"ID":11071,"Name":"NoDeathPenaltyLevel","Type":2,"Value":"30"}],
		[{"ID":11071,"Name":"NoDeathPenaltyLevel","Type":1,"Value":"30.5"}],
		[{"ID":11071,"Name":"NoDeathPenaltyLevel","Type":1,"Value":"-1"}],
		[{"ID":11071,"Name":"NoDeathPenaltyLevel","Type":1,"Value":"161"}],
		[{"ID":11071,"Name":"NoDeathPenaltyLevel","Type":1,"Value":"9223372036854775808"}],
		[{"ID":11071,"Name":"NoDeathPenaltyLevel","Type":1,"Value":"030"}],
		[{"ID":11072,"Name":"NoDeathPenaltyLevel","Type":1,"Value":"30"}],
		[{"ID":11071,"Name":"UnverifiedName","Type":1,"Value":"30"}]
	]:
		check(Source.read_item_exemption_level(invalid,160) == -1,"missing duplicate malformed or unverified source constant rejected")
	var source_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--death523-source="): source_path = argument.trim_prefix("--death523-source=")
	if not rules.load_pack(source_path):
		check(false,"actual pinned523 source archive is required")
	else:
		check(rules.item_exemption_level() == 30 and rules.item_exemption_origin() == "SOURCE_CONSTANT_APPLIED_TO_LOCAL_ITEM_POLICY","original constant is validated before publishing source rules")
		check(int(rules.row(30).DropRate) == 0 and int(rules.row(31).DropRate) == 5,"native item loss rows retain30vs31 boundary")
		check(rules.exp_loss(30,50000,100000) == 4999,"native XP loss at30 is unchanged by the item-only scalar")
		var wrong := FileAccess.open("user://wrong-item-exemption523.zip",FileAccess.WRITE)
		wrong.store_string("invalid source replacement")
		wrong.close()
		check(not rules.load_pack("user://wrong-item-exemption523.zip") and rules.ready and rules.item_exemption_level() == 30,"rejected archive leaves active rules and constant unchanged")
		check(not rules.install("user://wrong-item-exemption523.zip").is_empty() and rules.ready and rules.item_exemption_origin() == "SOURCE_CONSTANT_APPLIED_TO_LOCAL_ITEM_POLICY","rejected installer replacement retains active source provenance")
	print("DEATH523_SOURCE_CONSTANT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"PINNED_SOURCE_SCALAR; synthetic malformed-schema cases; item-only local application, independent XP policy"}))
	quit(0 if failures.is_empty() else 1)
