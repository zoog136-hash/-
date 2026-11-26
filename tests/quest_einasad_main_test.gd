extends SceneTree
## CI: fixture rows from the original Reward relation. With --quest-pack the
## production loader + actual source quest eligibility and Main receipt are used.
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[];var checks:=0
func ck(v: bool,m: String)->void:
	checks+=1
	if not v:failures.append(m);printerr("QUEST_EINASAD_FAIL ",m)
func _initialize()->void:run.call_deferred()
func disk(w: Node)->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
func run()->void:
	var sample: Dictionary={"ID":111133,"RewardTypeID":5,"type_name":"Einasad","RewardClassID":7049,"Amount":100,"RewardGetTimeTypeID":2,"CharacterClassID":0,"UseImmediately":false,"ClanOnly":false,"RewardEnhancementTypeID":1}
	var q: Dictionary={"source_rewards":[sample],"enhancements":[]};var src:=SOURCE.new()
	ck(src.reward_plan(q,{}).get("blessing")==100,"normal base reward")
	for pair: Array in [["RewardTypeID",2],["UseImmediately",true],["RewardGetTimeTypeID",1],["RewardClassID",0],["Amount",0]]:
		var bad:=sample.duplicate();bad[pair[0]]=pair[1]
		ck(not src.reward_plan({"source_rewards":[bad],"enhancements":[]},{}).ok,"unsupported timing, class or raw type refused")
	var window=preload("res://scripts/ui/original_ui/source_main_quest_window.gd").new()
	var page: Dictionary=window._page_bindings({"title":"원본 보상","source_rewards":[sample]},false)
	ck(page.bindings[window.STORY_TEXT].text.contains("아인하사드의 축복 +100") and page.reward_owners.is_empty(),"actual quest detail binding shows points, not fake item")
	var pack: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--quest-pack="):pack=arg.trim_prefix("--quest-pack=")
	var may_run:=not pack.is_empty()
	if may_run:
		for n: String in DirAccess.get_files_at("user://"):
			if n.begins_with("twilight_v20_save"):printerr("isolated profile required");quit(2);return
		ck(SOURCE.install_zip(pack).ok,"real original pack accepted")
		var w: Node=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false)
		ck(QA.enter_game(w),"real Main class selection")
		w.field_population.set_process(false);w.player.auto_enabled=false
		var s=w.quest_service;var runner=w.quest_auto
		var id1: String="m523:quest:75391";var id2: String="m523:quest:80958";var id3: String="m523:quest:78343";var id4: String="m523:quest:78353"
		w.level=1;w.ain_service.blessing=150
		ck(not runner.claim(w,id1) and not s.claimed.has(id1),"level prerequisite not bypassed")
		w.level=60;ck(w._save_game(true)==OK,"level-60 fixture durable")
		runner.refresh_context(w)
		var n:=0
		for raw: Dictionary in s.source.quests:
			var r: Dictionary=s.source.full(raw)
			for rw: Dictionary in r.source_rewards:
				if rw.type_name=="Einasad":
					n+=1
					var raw_plan: Dictionary=s.source.reward_plan({"source_rewards":[rw],"enhancements":[]},runner.context)
					ck(raw_plan.get("blessing")==int(rw.Amount),"exact grant for original row "+str(rw.ID)+": "+str(raw_plan.get("error","")))
		ck(n==38,"all original quest-reward links preserved")
		var before:=FileAccess.get_sha256(w.save_path())
		w.equipment_collections.test_save_writer=func(_a: String,_b: Dictionary)->Error:return ERR_CANT_CREATE
		ck(not runner.claim(w,id1) and w.ain_service.blessing==150 and not s.claimed.has(id1) and before==FileAccess.get_sha256(w.save_path()),"failed write no debit, credit or receipt")
		w.equipment_collections.test_save_writer=Callable();runner.retry_at=0
		ck(runner.claim(w,id1) and w.ain_service.blessing==350 and disk(w).ainhasad_state.blessing==350 and disk(w).quest_state.claimed.has(id1),"manual claim stores balance and marker atomically")
		ck(not runner.claim(w,id1) and w.ain_service.blessing==350,"no duplicate same period")
		w.equipment_collections.test_save_writer=func(path: String,data: Dictionary)->Error:return ERR_FILE_CANT_WRITE if WRITER.write(path,data)==OK else FAILED
		ck(runner.claim(w,id2) and w.ain_service.blessing==850 and disk(w).ainhasad_state.blessing==850,"post-write error verified; class 1859 and amount 500")
		w.equipment_collections.test_save_writer=Callable()
		w.ain_service.blessing=0;w._load_game(true)
		ck(w.ain_service.blessing==850 and s.claimed.has(id1) and s.claimed.has(id2),"actual reload restores both, never credits twice")
		w.ain_service.blessing=w.ain_service.charge_cap()-49
		ck(w._save_game(true)==OK,"near-cap seed")
		before=FileAccess.get_sha256(w.save_path())
		ck(not runner.claim(w,id3) and not s.claimed.has(id3) and before==FileAccess.get_sha256(w.save_path()) and w.hud.message_label.text.contains("상한"),"cap rejects entire award with useful feedback")
		w.ain_service.blessing=w.ain_service.charge_cap()-50
		ck(runner.complete(w,[id3,id4] as Array[String]) and s.claimed.has(id3) and not s.claimed.has(id4) and w.ain_service.blessing==w.ain_service.charge_cap(),"mixed batch uses remaining headroom without losing second quest")
		w.queue_free();await process_frame
	print("QUEST_EINASAD_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"original_pack_checked":may_run}))
	quit(0 if failures.is_empty() else 1)
