extends SceneTree
## The original 523 획득 가능 아이템 window (source_main_box_probability_window)
## for a lucky bag's original rows. Without arguments (no original files):
## only bag records qualify, rows follow the character's class, Probability
## is raw / 10,000,000 (else the class total), IsGiven rows show 확정, and the
## inventory's 확률 button opens it. Real input: -- --pack=<private original
## main UI pack directory>: Probability_All mounts one row per reward.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_box_probability_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

static func bag(denominator: bool=true) -> Dictionary:
	var spec: Dictionary={"kind":"mixed_rewards_bag","class_probability_totals":{"1":4000000,"3":5000000},"rewards":[
		{"item_class_id":0,"amount":3,"bless_raw":2,"enchant":0,"class_ids":[],"entity_type_id":0,"probability_raw":2500000},
		{"item_class_id":0,"amount":1,"bless_raw":1,"enchant":7,"class_ids":[3],"entity_type_id":0,"probability_raw":1000000},
		{"item_class_id":0,"amount":1,"bless_raw":3,"enchant":0,"class_ids":[],"entity_type_id":1,"probability_raw":0},
		{"item_class_id":0,"amount":1,"bless_raw":1,"enchant":0,"class_ids":[],"entity_type_id":0,"probability_raw":0}]}
	if denominator:spec["source_probability_denominator"]=10000000
	return {"name":"상자","source_use_spec":spec}

func _run() -> void:
	check(WINDOW.is_bag(bag()) and not WINDOW.is_bag({"name":"물약"}),"only lucky bags qualify")
	var rows: Array=WINDOW.bag_rows(bag(),1)
	check(rows.size()==2 and is_equal_approx(float(rows[0].percent),25.0) and rows[0].name.begins_with("축복받은 ") and int(rows[0].amount)==3,"class 1: the shared rows, raw / 10,000,000: "+str(rows))
	check(float(rows[1].percent)<0.0 and WINDOW.percent_text(rows[1].percent)=="확정" and rows[1].name.begins_with("저주받은 "),"an IsGiven row shows 확정")
	var mage: Array=WINDOW.bag_rows(bag(),3)
	check(mage.size()==3 and mage[1].name.begins_with("+7 ") and WINDOW.percent_text(mage[1].percent)=="10.000000%","class 3 also sees its own row")
	check(is_equal_approx(float(WINDOW.bag_rows(bag(false),1)[0].percent),62.5),"without a source denominator: over the class total")
	var inventory: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_inventory.gd")
	check(inventory.contains("try_open_feature_window(\"box_probability\",[item,class_id])") and inventory.contains("BOX_PROBABILITY.is_bag(item)"),"the inventory's 확률 button opens the window")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	print("ORIGINAL_UI_BOX_PROBABILITY_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var host:=Node.new()
	var hud:=Node.new()
	host.add_child(hud)
	root.add_child(host)
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,hud).get("ok",false),"window configures")
	var opened: Dictionary=window.open(parent,bag(),3)
	check(opened.get("handled",false) and int(opened.filled.rows)==3,"Probability_All mounts one row per reward: "+str(opened).left(300))
	window.close()
	await process_frame
	parent.queue_free()
	host.queue_free()
