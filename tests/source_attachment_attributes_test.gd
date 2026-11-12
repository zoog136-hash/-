extends SceneTree
## Native contract regressions: last own104 wins, &511, no alias inheritance.
## Pure metadata fixtures prove no native execution, original pixels or Android.
const ATTRIBUTES = preload("res://scripts/animation/source_attachment_attributes.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func directive(body: String, line: int = 1) -> Dictionary:
	return {"code":104,"body":body,"line":line}

func declaration(id: int, alias: Variant, attributes: Array) -> Dictionary:
	var directives: Array = []
	for index: int in range(attributes.size()): directives.append(directive(attributes[index],index+1))
	return {"sprite_id":id,"alias_target":alias,"literal_attribute_directives":directives}

func _initialize() -> void:
	var empty: Dictionary = ATTRIBUTES.resolve([])
	check(empty.ok and empty.flags == 0 and not empty.present and empty.origin == "absent_own_104_default_zero","absent own104 is explicit zero metadata default")
	for value: int in [0,1,5,8,12,128,256,511,512,520,1025]:
		var result: Dictionary = ATTRIBUTES.resolve([str(value)])
		check(result.ok and result.present and result.flags == (value & 511),"own104 masked %d" % value)
	var trace: Array = ["128","8","  +005 "]
	var trace_before: String = JSON.stringify(trace)
	var duplicate: Dictionary = ATTRIBUTES.resolve(trace)
	check(duplicate.ok and duplicate.flags == 5 and duplicate.origin == "last_own_104_decimal_low9","later104 replaces earlier values instead of OR")
	check(JSON.stringify(trace) == trace_before,"resolve preserves raw order, whitespace and multiplicity")
	check(ATTRIBUTES.resolve(["-1"]).flags == 511 and ATTRIBUTES.resolve(["-520"]).flags == 504,"signed decimal retains two-complement low9")
	check(ATTRIBUTES.resolve(["18446744073709551624"]).flags == 8,"decimal low9 projection avoids int64 conversion overflow")
	for malformed: Array in [[8],[""],[" "],["+"],["-"],["8.0"],["0x80"],["8 128"],["8x"],["1e2"],["８"],["8","invalid","128"],[null]]:
		var rejected: Dictionary = ATTRIBUTES.resolve(malformed)
		check(not rejected.ok and rejected.flags == 0 and rejected.origin == "unresolved_own_104","reject malformed own104 %s" % JSON.stringify(malformed))

	# Whole-file alias/body frame owner does not supply the actor's default104.
	var body: Array = [declaration(4258,796,["128","5"]),declaration(796,null,["8"])]
	var body_before: String = JSON.stringify(body)
	var body_flags: Dictionary = ATTRIBUTES.resolve_own_path(body,4258)
	check(body_flags.ok and body_flags.flags == 5 and body_flags.owner_sprite_id == 4258 and body_flags.owner_path_index == 0,"body chooses requested actor own last104")
	check(JSON.stringify(body) == body_before,"all alias raw104 evidence remains unchanged")
	check(not ATTRIBUTES.resolve_own_path(body,796).ok,"physical alias owner cannot impersonate requested body")
	var absent_body: Array = [declaration(4258,796,[]),declaration(796,null,["8"])]
	var absent_projection: Dictionary = ATTRIBUTES.resolve_own_path(absent_body,4258)
	check(absent_projection.ok and absent_projection.flags == 0 and not absent_projection.present,"alias104 cannot fill absent requested104")

	# A clothes request mapped to another file still uses the requested ID104.
	var clothes: Array = [declaration(200,205,["128"]),declaration(205,null,["8"])]
	check(ATTRIBUTES.resolve_own_path(clothes,200).flags == 128,"clothes uses requested target, never mapped file104")
	var alternate_role: Array = [declaration(202,null,["256"])]
	check(ATTRIBUTES.resolve_own_path(alternate_role,202).flags == 256 and not ATTRIBUTES.resolve_own_path(alternate_role,200).ok,"alternate role actor requires its own explicit ID")
	var ignored_alias_syntax: Array = [declaration(200,205,["12"]),declaration(205,null,["unknown alias syntax"])]
	check(ATTRIBUTES.resolve_own_path(ignored_alias_syntax,200).flags == 12,"unused alias104 syntax does not become inherited metadata")
	var malformed_own: Array = [declaration(200,205,["invalid"]),declaration(205,null,["8"])]
	check(not ATTRIBUTES.resolve_own_path(malformed_own,200).ok,"valid alias104 cannot repair malformed own104")
	for broken: Array in [[],[declaration(200,205,[])],[declaration(200,206,[]),declaration(205,null,[])],[declaration(200,205,[]),declaration(205,200,[]),declaration(200,null,[])],[{"sprite_id":200,"literal_attribute_directives":[]}],[{"sprite_id":200,"alias_target":null,"literal_attribute_directives":[{"code":105,"body":"8","line":1}]}],[{"sprite_id":200,"alias_target":null,"literal_attribute_directives":[{"code":104,"body":"8","line":0}]}]]:
		check(not ATTRIBUTES.resolve_own_path(broken,200).ok,"reject missing, cyclic or invalid owner proof %s" % JSON.stringify(broken))
	print("SOURCE_ATTACHMENT_ATTRIBUTES " + JSON.stringify({"checks":checks,"failures":failures,"scope":"static metadata projection; no original rendering or dynamic actor flags"}))
	quit(0 if failures.is_empty() else 1)
