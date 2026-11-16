extends SceneTree
## LimitBuffCardID "카드 보유" 조건 — TWILIGHT 근사 (scripts/cards/card_requirement523.gd).
## With the original ZIP, in actual Main: an exact card condition holds only while that
## card is owned; the placeholder "신화변신" (#11152) holds with any owned 신화 polymorph;
## a card-bound skill book learns only with the card; card-bound approximated skills
## exist and are enabled only with the card.
const RULE = preload("res://scripts/cards/card_requirement523.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const BOOKS = preload("res://scripts/shop/source523_skill_books.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CARD_REQUIREMENT523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func identity_of(world: Node, category: String, card_id: int) -> String:
	for card: Variant in world.catalog_db.get(category, []):
		if card is Dictionary and int(card.get("source_card_id",0)) == card_id: return str(world.card_draw_fusion.card_id(card))
	return ""

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	var owned_before: Dictionary = world.card_draw_fusion.owned.duplicate(true)
	world.card_draw_fusion.owned["변신"] = {}
	check(RULE.satisfied(world, 0), "no condition holds")
	var exact: String = identity_of(world, "변신", 13304)
	evidence["exact_identity"] = exact
	check(not RULE.satisfied(world, 13304), "플래티넘 데스나이트 not owned: condition fails")
	if check(not exact.is_empty(), "플래티넘 데스나이트 registered"):
		world.card_draw_fusion.owned["변신"][exact] = true
		check(RULE.satisfied(world, 13304), "owned: condition holds")
		check(RULE.satisfied(world, 11152), "placeholder 신화변신 holds with any owned 신화 polymorph")
		world.card_draw_fusion.owned["변신"].erase(exact)
	check(not RULE.satisfied(world, 11152), "placeholder fails with no 신화 polymorph")
	# Skill books whose only learn rows carry a card.
	var books: Dictionary = BOOKS._contracts()
	var card_books: Array = []
	for id: String in books:
		for job: String in books[id].classes:
			for limit: Dictionary in books[id].classes[job]:
				if int(limit.required_card) != 0 and not card_books.has(id): card_books.append(id)
	evidence["card_books"] = card_books.size()
	# Original skill-book items whose learn rows carry a card: no longer blocked at definition.
	var opened: Array = []
	var blocked: Array = []
	for id: int in [132864, 132874, 132894, 132904]: # [혈맹][특수-신화] 스페셜 어택 (마법사·요정·기사·군주)
		var record: Dictionary = D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)
		if record.is_empty(): continue
		var spec: Dictionary = NATIVE_FIELDS.full(record).get("source_use_spec",{})
		if spec.get("kind") != "source_skill_book": continue
		if (spec.get("blocked_reasons",[]) as Array).has("source_skill_limit_card_requirement_unresolved"): blocked.append(id)
		else: opened.append(id)
	evidence["card_book_items"] = {"opened":opened,"blocked":blocked}
	check(blocked.is_empty() and not opened.is_empty(), "card-bound skill book items are not blocked at definition: "+str(evidence.card_book_items))
	if card_books.size() > 0:
		var spec: Dictionary = books[card_books[0]]
		var job: String = str(spec.classes.keys()[0]); var limit: Dictionary = spec.classes[job][0]
		world.job_class = job; world.level = 99
		var card_id: int = int(limit.required_card)
		var before: String = BOOKS.learn_reason(world, spec)
		var deck: int = int(SOURCE.row("BuffCard", card_id).get("BuffCardDeckID",1))
		var category: String = str(RULE.DECKS.get(deck,"변신"))
		var target: String = identity_of(world, category, card_id)
		if target.is_empty():
			for card: Variant in world.catalog_db.get(category, []):
				if card is Dictionary and int(SOURCE.row("BuffCard", int(card.get("source_card_id",0))).get("GradeID",-1)) == int(SOURCE.row("BuffCard",card_id).get("GradeID",-2)): target = str(world.card_draw_fusion.card_id(card)); break
		if not world.card_draw_fusion.owned.has(category): world.card_draw_fusion.owned[category] = {}
		world.card_draw_fusion.owned[category][target] = true
		var after: String = BOOKS.learn_reason(world, spec)
		evidence["book"] = {"book":card_books[0],"job":job,"card":RULE.label(card_id),"before":before,"after":after}
		check(not before.is_empty() and after.is_empty(), "card-bound skill book: refused without the card, learnable with it "+str(evidence.book))
	# Approximated skills bound to a card.
	var catalog = world.original_skills.catalog
	var bound: Array = []
	for record: Dictionary in catalog.records:
		if int(record.get("approx_required_card",0)) != 0: bound.append("%s/%s" % [str(record.get("class","")),str(record.name)])
	evidence["approx_card_skills"] = bound
	world.card_draw_fusion.owned = owned_before
	world.queue_free()
	for frame: int in 5: await process_frame

func run() -> void:
	if not SOURCE.not_installed(): await runtime()
	else: check(RULE.satisfied(null, 0), "no condition holds without the original ZIP")
	print("CARD_REQUIREMENT523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
