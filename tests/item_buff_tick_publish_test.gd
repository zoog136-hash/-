extends SceneTree

const QA := preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func run() -> void:
	var world := load("res://Main.tscn").instantiate() as TwilightWorld
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual Main startup")
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.active_item_buffs["recovery_fixture"] = {"remaining":10.0,"tick_interval":1.0,"mp_regen_tick":2,"mp_flat":13}
	world.mp = 0
	world._publish_timed_buff_hud()
	var before: Dictionary = world.hud_publish_counts.duplicate()
	var change: int = world._tick_item_buffs(1.0, false)
	check(change==world.ItemBuffTick.VITALS and world.mp==2 and world.hud_publish_counts==before,"muted recovery advances only the live MP and timer")
	world._publish_item_buff_tick(change)
	check(world.hud.character_state.mp==2 and world.hud_publish_counts.vitals==before.vitals+1 and world.hud_publish_counts.stat_snapshots==before.stat_snapshots,"original HUD gets the new MP with no full stat snapshot")
	world.mp = world._effective_max_mp()
	before = world.hud_publish_counts.duplicate()
	check(world._tick_item_buffs(1.0)==world.ItemBuffTick.NONE and world.hud_publish_counts==before,"full MP and unchanged options need no HUD publication")
	world.mp = 0
	before = world.hud_publish_counts.duplicate()
	var buffed_mp: int = world._effective_max_mp()
	check(world._tick_item_buffs(8.0)==world.ItemBuffTick.EFFECTS and world.mp==16 and not world.active_item_buffs.has("recovery_fixture"),"the final scheduled recovery and expiry both take effect")
	check(world._effective_max_mp()==buffed_mp-13 and world.hud.character_state.max_mp==world._effective_max_mp() and world.hud_publish_counts.stat_snapshots==before.stat_snapshots+1,"expiry publishes the changed max MP and its character values")
	var catalog: TwilightOriginalSkillCatalog = world.original_skills.catalog
	var base_signature: String = catalog._projection_signature()
	var old_mr: float = world.original_skills.stat("mr")
	world._stat_memo_begin()
	world._stat_memo_begin()
	check(world.original_skills.stat("mr")==old_mr and catalog._stat_read_signature==base_signature,"scoped reads use the same stat and full lineage signature")
	world._stat_memo_end()
	check(catalog._stat_read_signature==base_signature,"nested reads retain the shared lineage signature")
	world._stat_memo_end()
	catalog.revision += 1
	check(catalog._stat_read_signature.is_empty() and catalog._projection_signature()!=base_signature,"a new skill change outside the scope is read live")
	print("ITEM_BUFF_TICK_PUBLISH_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	world.queue_free()
	await process_frame
	quit(1 if not failures.is_empty() else 0)
