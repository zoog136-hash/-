extends "res://tests/integrated_ui_test.gd"

# Real skill-book transactions on an isolated starter save. The only equipment
# fixture is acquired through the existing test-catalog command, as documented
# in README; no learned flags, skill costs or wallet values are fabricated.
func _run() -> void:
	root.size = Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(8)
	hud = world.hud
	check(CLASS_QA.enter_game(world),"starter enters world")
	world.save_timer = -100000
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	var catalog: TwilightOriginalSkillCatalog = world.original_skills.catalog
	var record: Dictionary = catalog.record_for("카운터 배리어")
	check(not record.is_empty() and not catalog.owned(record),"real class skill starts unlearned")
	var weapon: Dictionary = {}
	for item: Dictionary in world.catalog_db.get("아이템",[]):
		if item.get("type","") == "양손검": weapon = item; break
	check(not weapon.is_empty(),"catalog contains required two-handed equipment")
	world._equip_or_acquire_item(weapon,true)
	hud.open_skills()
	await frames()
	var view: Node = hud.skills_view
	view.search.text = str(record.name)
	view.search.text_changed.emit(view.search.text)
	for index: int in view.filtered.size():
		if view.filtered[index].id == record.id: view.select(index); break
	await click(view.cards.get_parent().get_parent().tabs.get_child(1))
	check(view.quick_button.disabled and view.use_button.disabled and view.learn_button.disabled,"unlearned skill cannot cast or register without a book")
	check(not view.book_button.disabled,"eligible starter can buy its real book")
	var before_gold: int = world.gold
	var before_books: int = int(world.inventory.get(str(record.book_name),0))
	await click(view.book_button)
	check(world.gold == before_gold-int(record.book_cost) and int(world.inventory.get(str(record.book_name),0)) == before_books+1,"native book purchase debits exact price and adds one book")
	check(not view.learn_button.disabled,"purchase enables learning in the same detail view")
	await touch(view.learn_button)
	check(catalog.owned(record) and int(world.inventory.get(str(record.book_name),0)) == before_books,"native touch learns and consumes exactly one book")
	check(str(view.selected.id) == str(record.id) and not view.cards.get_item_text(view.cards.get_selected_items()[0]).contains("🔒"),"learning preserves selection and refreshes ownership icon")
	check(view.learn_button.disabled and view.book_button.disabled and not view.quick_button.disabled,"learned state disables duplicate acquisition and enables registration")
	await click(view.quick_button)
	var assign: Control = named("AssignQuickslot_23")
	(assign.get_parent().get_parent().get_parent().get_parent() as ScrollContainer).ensure_control_visible(assign)
	await frames()
	await click(assign)
	check(world.quickslots[23].get("skill_id","") == record.id and world.quickslots[23].get("id","") == record.name,"last slot on third page stores stable ID and display name")
	check(hud.active_section == "skills" and hud.skills_view.search.text == record.name and hud.skills_view.selected.id == record.id and hud.skills_view.quick_button.is_visible_in_tree(),"registration returns to the filtered skill detail")
	hud._close_workspace()
	hud._change_quick_page(1,2)
	var before_mp: int = world.mp
	await click(hud.v20_quickslot_buttons[7])
	var resolved: Dictionary = catalog.resolve(record)
	check(world.mp == before_mp-int(resolved.mp) and world.active_skill_buffs.has(str(record.name)),"learned skill casts from third page and spends exact MP")
	check(is_equal_approx(float(world.skill_cooldowns.get(str(record.name),0)),world.original_skills.cooldown_seconds(resolved)),"HUD cooldown uses the same card and equipment modifiers as casting")
	check(hud.quickslot_auto_badges[7].text.contains("L1") and hud.v20_quickslot_buttons[7].tooltip_text.contains("Lv.1"),"slot renders authoritative learned level")
	check(hud.quickslot_icons[7].texture.resource_path == str(record.icon),"slot reuses the catalog skill icon")
	await click(hud.v20_quickslot_buttons[7])
	check(world.mp == before_mp-int(resolved.mp),"cooldown blocks a repeated native click without extra cost")
	world._edit_quickslot(23,"auto")
	check(bool(world.quickslots[23].get("auto",false)),"learned buff supports explicit auto setting")
	check(world._save_game(true),"atomic save accepts the integrated skill state")
	world._load_game(true)
	await frames()
	check(world.quickslots.size() == 24 and world.quickslots[23].get("skill_id","") == record.id and bool(world.quickslots[23].get("auto",false)) and catalog.owned(record),"reload preserves learned book, stable ID, slot 24 and auto setting")
	var saved_slots: Array = world.quickslots.duplicate(true)
	world._on_job_class_selected("요정")
	world._on_job_class_selected("기사")
	check(world.quickslots == saved_slots,"class roundtrip restores the complete 24-slot layout")
	for index: int in world.quickslots.size(): world._edit_quickslot(index,"clear")
	world._on_job_class_selected("요정")
	world._on_job_class_selected("기사")
	check(world.quickslots.size() == 24 and world.quickslots.all(func(entry: Dictionary) -> bool: return entry.is_empty()),"intentionally empty class layout is not reseeded")
	world.queue_free()
	await frames()
	print("SKILL_DRAWER_LEARNING_OK: %d checks" % checks.size() if failures.is_empty() else "SKILL_DRAWER_LEARNING_FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
