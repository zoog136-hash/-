extends SceneTree

const UI = preload("res://scripts/ui/renewal_theme.gd")
const EFFECT = preload("res://scripts/ui/item_visual.gd")
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
const SCROLLS: Array[String] = [
	"축복 부여 주문서", "축복받은 무기 마법 주문서",
	"축복받은 갑옷 마법 주문서", "축복받은 오림의 장신구 마법 주문서"
]
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		printerr("BLESSED_SCROLL_VISUAL_FAIL: " + detail)

func _run() -> void:
	for item_name: String in SCROLLS:
		for variant: String in [item_name, item_name + " (각인)", item_name + "(각인)", item_name.replace(" ", ""), "\t" + item_name + " ( 각인 )\n"]:
			var record: Dictionary = {"name":variant, "slot":"consumable", "grade":"희귀", "price":250000, "bless":0}
			var original: String = JSON.stringify(record)
			check(EFFECT.is_blessed_scroll(record), "target identity: " + variant)
			check(EFFECT.animation_rank(record) == 3, "reuse hero sheen: " + variant)
			check(JSON.stringify(record) == original, "classification cannot change data")
	for grade: String in EFFECT.GRADES:
		for item_name: String in ["무기 마법 주문서", "갑옷 마법 주문서 (각인)", "장인의 무기 마법 주문서", "오림의 장신구 마법 주문서", "축복받은 HP 물약", "축복받은 무기", "축복 부여 주문서 조각"]:
			var record: Dictionary = {"name":item_name, "slot":"consumable", "grade":grade, "blessed":true}
			check(not EFFECT.is_blessed_scroll(record), "non-scroll/ordinary item excluded: " + item_name)
			check(EFFECT.animation_rank(record) == EFFECT.GRADES.find(grade), "unrelated grade unchanged")
	check(EFFECT.animation_rank({"grade":"희귀"}, "축복부여주문서(각인)") == 3, "missing name uses explicit icon identity")
	check(EFFECT.animation_rank({"name":"무기 마법 주문서", "grade":"희귀"}, "축복 부여 주문서") == 2, "record identity wins over display text")
	check(EFFECT.animation_rank({"name":"축복 부여 주문서", "slot":"weapon", "grade":"일반"}) == 0, "equipment is never reclassified")
	check(EFFECT.animation_rank({}) == 0, "empty record is static")

	var clip := Control.new()
	clip.clip_contents = true
	clip.size = Vector2(180, 180)
	root.add_child(clip)
	var view := TextureRect.new()
	view.size = Vector2(64, 64)
	clip.add_child(view)
	var record: Dictionary = {"name":"축복 부여 주문서 (각인)", "slot":"consumable", "grade":"희귀", "price":250000}
	var original: String = JSON.stringify(record)
	UI.apply_item_visual(view, record, record.name)
	await process_frame
	await process_frame
	var effect: Node = view.get_node("ItemVisual")
	var scheduler: Node = effect.scheduler
	check(effect.rank == 3 and view.material != null, "production helper attaches hero sheen")
	check(view.material == EFFECT.shared_material(3, effect.phase_group), "same cached material as hero equipment")
	check(view.texture == RESOLVER.texture(record, record.name), "original icon pixels retained")
	check(JSON.stringify(record) == original, "real apply leaves grade/price/name untouched")
	check(view.rotation == 0.0 and view.scale == Vector2.ONE, "no spin or slot transform")
	check(not effect.is_processing(), "no per-slot frame loop")
	var child_count: int = view.get_child_count()
	for index: int in range(100): UI.apply_item_visual(view, record, record.name)
	check(view.get_child_count() == child_count, "reconfiguration cannot duplicate nodes")
	check(scheduler.clients.size() == 1, "reconfiguration cannot duplicate scheduler clients")
	clip.hide()
	check(view.material == null, "hidden ancestor disables sheen")
	clip.show()
	effect.refresh_visibility()
	check(view.material != null, "visible icon resumes sheen")
	view.position = Vector2(300, 0)
	effect.refresh_visibility()
	check(view.material == null, "scroll clipping still disables sheen")
	view.position = Vector2.ZERO
	EFFECT.set_reduced_motion(true)
	effect.refresh_visibility()
	check(view.material == null, "reduced motion still disables sheen")
	EFFECT.set_reduced_motion(false)
	for usage: String in ["slot", "detail", "equipment", "enhancement"]:
		UI.apply_item_visual(view, record, record.name, {}, usage)
		check(view.material == EFFECT.shared_material(3, effect.phase_group), "shared animated context: " + usage)
	for usage: String in ["quickslot", "list", "drag", "ground"]:
		UI.apply_item_visual(view, record, record.name, {}, usage)
		check(view.material == null and scheduler.clients.is_empty(), "existing static context retained: " + usage)
	UI.apply_item_visual(view, record, record.name)
	var plain: Dictionary = {"name":"무기 마법 주문서", "slot":"consumable", "grade":"희귀"}
	UI.apply_item_visual(view, plain, plain.name)
	check(view.material == null and scheduler.clients.is_empty(), "recycled view removes blessed sheen")
	UI.apply_item_visual(view, record, record.name)
	EFFECT.clear(view)
	check(view.material == null and scheduler.clients.is_empty(), "clear removes effect")
	check(EFFECT.materials.size() <= 32, "existing shared material cap retained")
	UI.apply_item_visual(view, record, record.name)
	clip.queue_free()
	await process_frame
	check(scheduler.clients.is_empty(), "freeing view releases registrations")
	if failures.is_empty(): print("BLESSED_SCROLL_ITEM_VISUAL_OK checks=%d refreshes=100" % checks)
	quit(0 if failures.is_empty() else 1)
