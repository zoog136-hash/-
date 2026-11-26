extends SceneTree
## Independent exact original-book path. Input is an audit matrix of
## target/scroll/level/blessing entries and numeric original outcome rows.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const DROPS=preload("res://scripts/loot/patch523_monster_drops.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const BOOK=preload("res://scripts/crafting/patch523_enhance_source_book.gd")
const ENHANCE=preload("res://scripts/crafting/patch523_enhancement.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",OS.get_environment("TWILIGHT_TEST_ENHANCE_SOURCE"))
	SOURCE.reset()
	var matrix: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TWILIGHT_TEST_ENHANCE_MATRIX")))
	if SOURCE.identity().is_empty() or not matrix is Dictionary or matrix.is_empty():
		printerr("Authenticated ZIP and exact audit matrix required");quit(2);return
	var passed: int=0
	var failures: Array=[]
	var physical_groups: int=0
	var numeric_only: Array=[]
	for group: String in matrix:
		var accepted: bool=false
		var physical: bool=false
		var storage_only_targets: Dictionary={}
		var why: Dictionary={}
		for fixture: Dictionary in matrix[group]:
			var target_id: String=str(int(fixture.target))
			var scroll_id: String=str(int(fixture.scroll))
			var definition: Dictionary=DROPS.definition_id(target_id)
			var target: Dictionary=definition.get("native_record",{})
			var scroll: Dictionary=DROPS.definition_id(scroll_id).get("native_record",{})
			if target.is_empty() or scroll.is_empty():continue
			if int(fixture.scroll_bless)==2:scroll=DROPS.variant_item(scroll,2)
			if not BOOK.declares_scroll(scroll):continue
			var book: RefCounted=BOOK.new()
			if not book.bind(target,target_id,scroll,scroll_id,null):continue
			var rule: Dictionary=ENHANCE.rule(book,target,scroll_id,int(fixture.level),int(fixture.target_bless),int(fixture.scroll_bless))
			why=rule
			if int(rule.get("group",-1))==int(group) and int(rule.get("cost",-1))==int(fixture.cost) and int(rule.get("count",-1))==int(fixture.count) 				and is_equal_approx(float(rule.get("success",-1)),float(fixture.success)/10000.0) and is_equal_approx(float(rule.get("destroy",-1)),float(fixture.destroy)/10000.0) 				and is_equal_approx(float(rule.get("no_change",-1)),float(fixture.remain)/10000.0) and is_equal_approx(float(rule.get("decrease",-1)),float(fixture.side)/10000.0):
				accepted=true
				if DROPS.equipment(target) and not STACK.supply_profile(scroll).is_empty():
					physical=true
					break
				if definition.get("equip_rows",[]).is_empty():storage_only_targets[target_id]=true
		if accepted:passed+=1
		else:failures.append({"group":group,"reason":why})
		if physical:physical_groups+=1
		elif accepted:numeric_only.append({"group":int(group),"targets_without_original_equip_slot":storage_only_targets.keys()})
	print("PATCH523_ENHANCEMENT_FAMILY_RESULT ",JSON.stringify({"groups":matrix.size(),"numeric_passed":passed,"physical_groups":physical_groups,"numeric_only":numeric_only,"failures":failures}))
	quit(0 if failures.is_empty() and physical_groups==50 and numeric_only.size()==21 and numeric_only.all(func(row:Dictionary)->bool: return not row.targets_without_original_equip_slot.is_empty()) else 1)
