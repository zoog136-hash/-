extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var errors: Array[String] = []
var checks := 0
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world)
	if not QA.enter_game(world):quit(1);return
	world.set_process(false);world.player.set_auto_enabled(false);world.level=90;world.gold=10000000;world.max_mp=1000;world.mp=1000
	var catalog:=world.original_skills.catalog
	check(catalog.records.size()==143,"143 usable runtime skills")
	var master: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/master.json"))
	var balance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/balance.json"))
	check(master.records.size()==125,"base master unchanged")
	for old: Dictionary in master.records:
		var record: Dictionary=catalog.record_for(str(old.id))
		for key: String in balance.skills[str(old.id)]:check(record[key]==balance.skills[str(old.id)][key].value,"base125 balance "+str(old.id)+" "+key)
	check(catalog.record_for("엘리멘탈 애로우").id==catalog.record_for("엘리멘탈 웨폰").id,"one stable renamed skill")
	for record: Dictionary in catalog.current_official.records:
		check(not record.runtime_blocked and record.local_design,"all registered supplements enabled local design")
		check(record.official.get("cooldown_seconds")==null and record.design_provenance.cooldown.status=="local_design","official unknown and runtime design remain separate")
		if record.activation=="active":check(record.mp>0 and record.cooldown>0,"active casts have real costs and cooldowns")
	world.job_class="기사";world.equipped_items={"weapon":{"name":"검증 양손검","type":"양손검","slot":"weapon"}}
	world._update_hud();world.hud.open_skills()
	for i: int in range(2):await process_frame
	var view: Node=world.hud.skills_view;view.search.text="프라이드";view.refresh()
	check(view.records.size()==143 and view.filtered.size()==1,"real UI contains exactly143")
	view.book_button.pressed.emit();check(not view.learn_button.disabled,"UI book purchase enables learning")
	view.learn_button.pressed.emit();check(catalog.owned(view.selected),"UI actual learning")
	world.inventory["명예 코인"]=8;world.skill_global_cooldown=0;world.skill_cooldowns.clear();view.select(0)
	check(not view.use_button.disabled and view.detail.text.contains("TWILIGHT 설계"),"local action enabled with disclosed provenance")
	view.use_button.pressed.emit();check(world.mp==970 and world.inventory["명예 코인"]==0,"UI real cast charges official Pride costs")
	world.job_class="요정";world.equipped_items={"weapon":{"name":"검증 활","type":"활","slot":"weapon"}};world._update_hud()
	view.type_filter.select(3);view.search.text="슈팅 스타";view.refresh();view.book_button.pressed.emit();view.learn_button.pressed.emit()
	world.skill_global_cooldown=0;world.skill_cooldowns.clear();view.select(0)
	view.use_button.pressed.emit();check(world.original_skills.local_runtime.is_on(view.selected),"UI real toggle ON")
	var before: int=world.mp;view.use_button.pressed.emit();check(not world.original_skills.local_runtime.is_on(view.selected) and world.mp==before,"UI OFF with no cost / no cooldown refresh")
	check(preload("res://scripts/skill_rules.gd").can_auto_cast(catalog.record_for("프라이드")) and world._is_buff_skill(catalog.record_for("프라이드")),"new buff AUTO routing")
	check(catalog.record_for("아쿠아 애로우").effect=="heal","new healing AUTO routing")
	check(not preload("res://scripts/skill_rules.gd").can_auto_cast(catalog.record_for("슈팅 스타")),"toggle AUTO cannot oscillate")
	var vfx=world.original_skills.vfx
	vfx.clear()
	vfx.similar_bridge.effects.clear()
	vfx.emit_skill(str(catalog.record_for("프라이드").id),"impact",world.player.global_position)
	check(not vfx.live.is_empty() and vfx.live[0].get("layers")!=null,"new twelve retain committed authored visual fallback without private SPR pack")
	world.queue_free();await process_frame
	print("CURRENT_OFFICIAL_RUNTIME_UI_RESULT checks=%d errors=%d usable=143" % [checks,errors.size()]);quit(0 if errors.is_empty() else 1)
