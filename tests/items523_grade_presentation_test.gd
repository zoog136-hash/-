extends SceneTree
## Original 523 item grade presentation from the tables:
## - name color Grade.ColorID -> ColorTable (inventory/tooltip/shop names through
##   RenewalTheme.grade / the bag's _grade_color, the floor label and pickup line);
## - floor drop effect UIItemDropEffect / Grade.DropItemEffectSpriteID played as the
##   original SP2 action 3 instead of the procedural TWILIGHT beam.
## Without the original definition ZIP only the static fallbacks are checked.
const GRADE = preload("res://scripts/loot/current523_item_grade.gd")
const THEME = preload("res://scripts/ui/renewal_theme.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const F = preload("res://scripts/loot/current523_native_fields.gd")
## Original table values (Grade -> ColorTable / DropItemEffectSpriteID).
const EXPECTED := {"일반":["ffffff",0],"고급":["00dc15",0],"희귀":["00a2ff",23195],"영웅":["ff0000",23197],"전설":["d44fff",23200],"신화":["ffde00",23203],"유일":["18f4b0",23206],"특수":["ff7522",0]}
const GRADE_IDS := {"일반":1,"고급":2,"희귀":3,"영웅":4,"전설":5,"신화":32,"유일":52,"특수":42}
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEMS523_GRADE_PRESENTATION_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func icon_setter_rules() -> void:
	var ICONS = preload("res://scripts/ui/source523_original_ui_icons.gd")
	var spec: Dictionary = {"clip":"normal","repeat":true,"original_repeat_declared":true,"original_policy_confirmed":true,
		"policy_source":"LineageM_1.10.22.0 static analysis (UI CSB stage 6): common icon setter 0x00C381A0 attaches the AssetType101 CSB to the slot Sprite and calls timeline.play(\"normal\", true) at 0x00C386B1"}
	var slot: Dictionary = {"ui_target_declared_by_original":true,"registration_space":"authored_sprite_anchor","fit_or_offset_inferred":false}
	var target: Dictionary = {"member":"UI/CommonUi/Common_Slot.csb","source_sha256":"a".repeat(64),"manifest_sha256":"b".repeat(64),"node_offset":15012}
	var made: Variant = ICONS.common_icon_setter_registration(spec,slot,target)
	check(made is Array and made.size()==1 and made[0].registration.target==target and made[0].registration.original_registration_confirmed==true and made[0].playback.clip=="normal" and made[0].playback.repeat==true and made[0].bindings.is_empty(), "CSB icon registers on the original slot Sprite from the common icon setter evidence")
	var other: Dictionary = spec.duplicate(); other.policy_source = "estimated host"
	check(ICONS.common_icon_setter_registration(other,slot,target)==null, "no registration without the client setter evidence")
	var undeclared: Dictionary = slot.duplicate(); undeclared.ui_target_declared_by_original = false
	check(ICONS.common_icon_setter_registration(spec,undeclared,target)==null, "no registration on a slot the original scene does not declare")

func rules() -> void:
	icon_setter_rules()
	if SOURCE.not_installed():
		check(GRADE.color("신화",Color.RED)==Color.RED, "without the 523 tables the caller's own color stays")
		check(not GRADE.drop_effect({"ID":1,"GradeID":32}).get("ok",true), "without the 523 tables no drop effect is selected")
		check(THEME.grade("신화")==THEME.GRADES["신화"], "theme keeps its palette without the tables")
		return
	var colors: Dictionary = {}
	for label: String in EXPECTED:
		var info: Dictionary = GRADE.color_info(label)
		colors[label] = info.get("hex","")
		check(info.get("ok",false) and info.hex==EXPECTED[label][0] and info.grade_id==GRADE_IDS[label], "%s -> ColorTable %s (%s)" % [label,EXPECTED[label][0],JSON.stringify(info)])
		check(THEME.grade(label).to_html(false)==EXPECTED[label][0], "theme name color of %s is the original" % label)
		var effect: Dictionary = GRADE.drop_effect({"ID":999999999,"GradeID":GRADE_IDS[label]})
		if int(EXPECTED[label][1])>0: check(effect.get("ok",false) and int(effect.sprite_id)==int(EXPECTED[label][1]) and effect.basis=="Grade.DropItemEffectSpriteID", "%s floor effect sprite %d" % [label,int(EXPECTED[label][1])])
		else: check(not effect.get("ok",true) and effect.get("reason")=="source_grade_has_no_drop_effect", "%s has no original floor effect" % label)
	evidence["colors"] = colors
	check(GRADE.grade_id("일반")==1, "'일반' is the item-info grade (Grade1), not the None row")
	var own: Dictionary = GRADE.drop_effect(SOURCE.row("ItemClass",162121))
	check(own.get("ok",false) and int(own.sprite_id)==23206 and own.basis=="UIItemDropEffect", "UIItemDropEffect overrides the grade effect (#162121 -> 23206): %s" % JSON.stringify(own))

func pick(world: Node, grade_id: int) -> Dictionary:
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if record.get("source_m_native_item")==true and int(F.field(record,"source_grade_id",-1))==grade_id and int(F.full(record).get("source_sprite_id",0))>0: return record
	return {}

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	# Let map entry finish (its first frames rebuild the floor views).
	for frame: int in range(30): await process_frame
	var shown: Dictionary = {}
	for label: String in ["고급","희귀","신화","유일"]:
		var record: Dictionary = pick(world,GRADE_IDS[label])
		if not check(not record.is_empty(), "a native %s item with a floor sprite" % label): continue
		var view: Button = world.ground_loot.spawn(str(record.name),world.player.global_position,1,"",{"item_record":record})
		if not check(view != null, "%s item drops" % label): continue
		var ground_id: String = str(view.get_meta("id"))
		await process_frame
		view = world.ground_loot.views.get(ground_id)
		if not check(is_instance_valid(view), "%s ground view stays after a frame" % label): continue
		var effect: Dictionary = view.get_meta("source_drop_effect",{})
		var color: Dictionary = view.get_meta("source_name_color",{})
		var label_node: Label = view.get("source_name_label")
		check(view.visual.procedural_beam==false, "%s: no procedural beam on a native item" % label)
		check(color.get("hex","")==EXPECTED[label][0] and label_node != null and label_node.visible and label_node.text==str(F.field(record,"source_display_name","")) and label_node.get_theme_color("font_color").to_html(false)==EXPECTED[label][0], "%s: floor name label in the original color" % label)
		if int(EXPECTED[label][1])>0:
			check(effect.get("ok",false) and int(effect.sprite_id)==int(EXPECTED[label][1]) and effect.get("status")=="playing_original", "%s: original floor effect %d plays (%s)" % [label,int(EXPECTED[label][1]),JSON.stringify(effect).left(300)])
			for frame: int in range(4): await process_frame
			view = world.ground_loot.views.get(ground_id)
			check(is_instance_valid(view) and view.source_drop_effect.status.get("ok",false), "%s: effect keeps playing" % label)
			if not is_instance_valid(view): continue
		else:
			check(not effect.get("ok",true) and view.source_drop_effect.visual == null, "%s: no floor effect (none in the original)" % label)
		shown[label] = {"id":int(record.source_item_class_id),"effect":effect.get("sprite_id",0),"color":color.get("hex","")}
		world.loot_pickup.select(view)
		check(world.loot_pickup.info.get_theme_color("font_color").to_html(false)==EXPECTED[label][0] and not world.loot_pickup.info.text.contains("원본#"), "%s: pickup line uses the original name and color" % label)
		world.loot_pickup.cancel()
		world._clear_drops()
	evidence["ground"] = shown
	# 가이아의 격노 (#461): ItemClass.SpriteID 14440 has no static picture; the SPR
	# declares action 3, played as the floor body.
	var gaia: Dictionary = world._catalog_item_from_source_id("m523:item:461")
	if check(not gaia.is_empty(), "#461 native record"):
		var body_view: Button = world.ground_loot.spawn(str(gaia.name),world.player.global_position,1,"",{"item_record":gaia})
		var body_id: String = str(body_view.get_meta("id")) if body_view != null else ""
		await process_frame
		body_view = world.ground_loot.views.get(body_id)
		check(is_instance_valid(body_view) and body_view.source_ground_status.get("status")=="selected_body_action" and int(body_view.source_ground_status.get("sprite_id",0))==14440, "#461 floor body plays its SPR action 3 (%s)" % (JSON.stringify(body_view.source_ground_status).left(300) if is_instance_valid(body_view) else "no view"))
		world._clear_drops()
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed(): await runtime()
	print("ITEMS523_GRADE_PRESENTATION_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
