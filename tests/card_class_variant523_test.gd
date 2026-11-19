extends SceneTree
## 보고서2 R2: BuffCardByClass (ClassifiedByClass cards). The card the player
## owns keeps its saved identity; the row of the character's class/gender gives
## the bonuses, the polymorph chain and the screen assets. Without the original
## definition ZIP only the row selection runs on supplied rows.
const CATALOG = preload("res://scripts/cards/current523_card_catalog.gd")
const BASE = preload("res://scripts/lineagem_base508.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const IDENTITIES = preload("res://scripts/cards/current523_card_identity.gd")
const BANK = preload("res://scripts/resources/current523_source_bank.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); printerr("CARD_CLASS_VARIANT523_FAIL: ",label)

func _initialize() -> void: call_deferred("run")

func selection() -> void:
	var rows: Array = [
		{"ID":91,"BuffCardID":7,"ClassID":1,"Gender":1,"BuffClassID":52982,"DisplaySpriteID":19082},
		{"ID":101,"BuffCardID":7,"ClassID":1,"Gender":2,"BuffClassID":52982,"DisplaySpriteID":18942},
		{"ID":191,"BuffCardID":7,"ClassID":8,"Gender":1,"BuffClassID":53212,"DisplaySpriteID":25247}]
	var record: Dictionary = {"source_original_card":{"ID":7,"ClassifiedByClass":true,"BuffClassID":53212},"source_class_variants":rows}
	check(int(CATALOG.variant_row(record,1,1).get("ID",0))==91 and int(CATALOG.variant_row(record,1,2).get("ID",0))==101, "class+gender pick the exact BuffCardByClass row")
	check(int(CATALOG.variant_row(record,8,1).get("BuffClassID",0))==53212 and CATALOG.variant_row(record,8,2).is_empty(), "a class without that gender's row keeps the base card")
	var unknown: Dictionary = CATALOG.variant_row(record,1,0)
	check(unknown.get("_bonus_only",false) and int(unknown.BuffClassID)==52982, "gender unknown: the class's single BuffClassID only (no display swap)")
	check(CATALOG.variant_row(record,0,1).is_empty() and CATALOG.variant_row(record,52,1).is_empty(), "no class / no row -> base card")
	var plain: Dictionary = record.duplicate(true); plain.source_original_card.ClassifiedByClass = false
	check(CATALOG.variant_row(plain,1,1).is_empty(), "only ClassifiedByClass cards switch")
	var other: Dictionary = record.duplicate(true); other.source_class_variants[0].BuffCardID = 8; other.source_class_variants[1].BuffCardID = 8
	check(CATALOG.variant_row(other,1,1).is_empty(), "a row of another BuffCardID is never used")

func source() -> void:
	var source_id: String = IDENTITIES.source_id(1,11152)
	check(not source_id.is_empty(), "신화변신 11152 has a saved identity")
	BASE.set_character_context(0,0)
	var base: Dictionary = BASE.canonical({"source":"lineagem_base508","sourceId":source_id})
	check(not base.is_empty() and int(base.source_display_sprite_id)==16274 and int(base.source_original_card.BuffClassID)==53212 and not base.has("source_class_variant"), "no character context: the base card (DisplaySprite 16274, BuffClass 53212)")
	var base_bonus: Dictionary = bonus_types(base)
	BASE.set_character_context(1,1)
	var knight: Dictionary = BASE.canonical({"source":"lineagem_base508","sourceId":source_id})
	var variant: Dictionary = knight.get("source_class_variant",{})
	evidence["knight_male"] = variant
	check(int(variant.get("buff_class_id",0))==52982 and int(knight.source_display_sprite_id)==19082 and int(variant.get("row_id",0))==91, "기사-남: BuffClass 53212 -> 52982, DisplaySprite 16274 -> 19082")
	check(str(knight.sourceId)==source_id and int(knight.source_card_id)==11152 and str(knight.name)==str(base.name) and knight.source_original_card==base.source_original_card, "saved identity, name and original card row unchanged")
	var knight_bonus: Dictionary = bonus_types(knight)
	evidence["bonus_types"] = {"base":base_bonus.keys(),"knight":knight_bonus.keys()}
	check(knight_bonus.has("LargeSwordDamageBonus") and not base_bonus.has("LargeSwordDamageBonus") and base_bonus.has("SpearDamageBonus") and not knight_bonus.has("SpearDamageBonus"), "bonuses come from the variant BuffClass (52982 대검, 53212 창)")
	check(BASE.flat_bonus(knight,"PVPDamageReduction")==BASE.flat_bonus(base,"PVPDamageReduction") and int(knight.source_ui_assets.get("DisplayBaseAssetID",{}).get("asset_id",0))==214653, "screen asset is the variant's DisplayBaseAssetID 214653")
	BASE.set_character_context(1,2)
	var knight_female: Dictionary = BASE.canonical({"source":"lineagem_base508","sourceId":source_id})
	check(int(knight_female.source_display_sprite_id)==18942 and int(knight_female.source_class_variant.buff_class_id)==52982, "기사-여: DisplaySprite 18942, same BuffClass")
	BASE.set_character_context(1,0)
	var unknown: Dictionary = BASE.canonical({"source":"lineagem_base508","sourceId":source_id})
	check(int(unknown.source_display_sprite_id)==16274 and int(unknown.source_class_variant.buff_class_id)==52982, "gender unknown: bonuses of 기사, base screen")
	BASE.set_character_context(142,2)
	check(not BASE.canonical({"source":"lineagem_base508","sourceId":source_id}).has("source_class_variant"), "마검사-여 (no row) keeps the base card")
	var switched: int = 0; var cards: int = 0
	for row: Dictionary in SOURCE.rows("BuffCardByClass"):
		BASE.set_character_context(int(row.ClassID),int(row.Gender))
		var sid: String = IDENTITIES.source_id(1,int(row.BuffCardID))
		if sid.is_empty(): continue
		cards += 1
		var card: Dictionary = BASE.canonical({"source":"lineagem_base508","sourceId":sid})
		if int(card.get("source_class_variant",{}).get("row_id",0))==int(row.ID) and card.get("source_display_sprite_id")==row.DisplaySpriteID: switched += 1
	evidence["rows"] = {"rows":SOURCE.row_count("BuffCardByClass"),"with_identity":cards,"switched":switched}
	check(cards>0 and switched==cards, "every BuffCardByClass row with a saved card resolves to itself %s" % str(evidence.rows))
	BASE.set_character_context(0,0)

func bonus_types(record: Dictionary) -> Dictionary:
	var found: Dictionary = {}
	for detail: Dictionary in record.get("source_bonuses",[]): found[str(detail.bonus_type.get("Name",""))] = true
	return found

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world,"기사"), "actual Main entry as 기사")
	if world.source_gender_id not in [1,2]: world.set_source_character_gender(1)
	var gender: int = int(world.source_gender_id)
	check(BASE.character_class_id==BASE.source_class_id("기사") and BASE.character_class_id==1 and BASE.character_gender_id==gender, "the world publishes 기사 + gender %d" % gender)
	var source_id: String = IDENTITIES.source_id(1,11152)
	var probe: Dictionary = {"source":"lineagem_base508","sourceId":source_id}
	world.card_draw_fusion.owned["변신"] = world.card_draw_fusion.owned.get("변신",{})
	world.card_draw_fusion.owned["변신"][world.CARD_DRAW_FUSION.card_id(BASE.canonical(probe))] = true
	var record: Dictionary = world._verified_catalog_record("변신",probe)
	evidence["world_record"] = {"variant":record.get("source_class_variant",{}).get("buff_class_id",0),"empty":record.is_empty()}
	if record.is_empty(): record = BASE.canonical(probe)
	check(int(record.get("source_class_variant",{}).get("buff_class_id",0))==52982 and str(record.get("sourceId",""))==source_id, "the world's card record (stats owner) is the 기사 variant %s" % str(evidence.world_record))
	if BANK.options(world._source_visual_context()).get("enabled",false):
		var selected: Dictionary = BANK.select_card("transform:"+source_id,world._source_visual_context())
		var tables: Array = []
		for chain: Variant in selected.get("typed_chains",[]):
			if chain is Dictionary:
				for step: Variant in chain.get("path",[]): if step is Dictionary: tables.append(str(step.get("table","")))
		evidence["select_card"] = {"ok":selected.get("ok",false),"error":selected.get("error",""),"tables":tables,"sprite":selected.get("sprite_id",0)}
		check(selected.get("ok",false) and "BuffCardByClass" in tables, "the polymorph chain walks the BuffCardByClass row %s" % str(evidence.select_card))
	world.queue_free()
	await process_frame
	BASE.set_character_context(0,0)

func run() -> void:
	selection()
	if not SOURCE.not_installed():
		source()
		await runtime()
	print("CARD_CLASS_VARIANT523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
