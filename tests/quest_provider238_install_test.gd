extends SceneTree
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE = preload("res://scripts/quests/source_quest523.gd")
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("QUEST_PROVIDER_INSTALL_FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var items: String="";var quests: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--quest-item-pack="):items=arg.trim_prefix("--quest-item-pack=")
		if arg.begins_with("--quest-pack="):quests=arg.trim_prefix("--quest-pack=")
	check(FileAccess.get_sha256(items)=="fb2a4de030b7d302fd7d8d2c541ca3cc8d1fbe246cf67ef574d812d3ccb6fc8d","exact authenticated existing PR238 ZIP")
	check(D.install_zip(items).get("ok",false),"shared production installer verifies and installs136 sidecars and root")
	check(D.pack_identity().get("sha256")==D.DATA_SHA and D.DATA_SHA=="38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27","actual production loader uses the pinned received BIN")
	check(D.definition_count()==34743,"full catalog available; effect readiness remains separate")
	check(SOURCE.install_zip(quests).ok,"unchanged approved quest v1 installs")
	var source:=SOURCE.new();check(source.load_pack() and source.quests.size()==3621,"same full quest input consumed")
	for id: int in [859,1281]:
		var original: Dictionary={}
		for row: Dictionary in source.quests:
			for reward: Dictionary in source.full(row).source_rewards:
				if reward.type_name=="Item" and int(reward.RewardClassID)==id:original=reward.source_item
		var definition: Dictionary=D.definition_id(str(id))
		check(not original.is_empty() and definition.get("original_item")==original,"full ItemClass row matches both independently pinned inputs: "+str(id))
		check(definition.get("native_record",{}).get("source_use_spec",{}).get("activation_status")=="unrestricted","producer declares supported original behavior: "+str(id))
	check(not D.install_zip(quests).get("ok",false) and D.pack_identity().get("sha256")==D.DATA_SHA,"wrong pack kind preserves installed provider")
	print("QUEST_PROVIDER_INSTALL_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"provider_sha256":D.pack_identity().get("sha256"),"source_items":34743,"reviewed_item_ids":[859,1281]}))
	quit(0 if failures.is_empty() else 1)
