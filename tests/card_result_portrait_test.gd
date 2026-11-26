extends SceneTree
## Run with the pinned definition, image and UI packs to check the actual
## settled sprites. A base pack without the UI add-on exercises the fallback.
const QA = preload("res://tests/qa_class_selection.gd")
const Rules = preload("res://scripts/card_draw_fusion.gd")
const Source = preload("res://scripts/lineagem_base508.gd")
const Presentation = preload("res://scripts/ui/source_card_presentation.gd")
const PMA = preload("res://scripts/ui/original_ui/cocos_premultiply_pixels.gd")
const Stage = preload("res://scripts/ui/card_reveal_stage.gd")
const Change = preload("res://scripts/ui/original_ui/source_main_change_window.gd")
# Patch523 transform cards for the isolated male knight. BuffCard 11152
# resolves its role IDs through the original BuffCardByClass row 91.
const AWARDS = {11152:[214653,181701],12243:[193443,193473],13304:[235204,224084],
	18112:[254963,224064],24784:[398854,400884],18722:[275958,268772],24504:[391784,390994]}
var checks := 0
var failures: Array[String] = []
var samples: Array = []
var catalog_samples: Array = []
var image_root: String

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("RESULT_PORTRAIT_FAIL ",label)
	return ok

func pixels_match(texture: Texture2D, relative: String, premultiplied: bool = false) -> bool:
	if texture == null or relative.is_empty(): return false
	var expected := Image.new()
	if expected.load_png_from_buffer(FileAccess.get_file_as_bytes(image_root.path_join("originals").path_join(relative))) != OK: return false
	var drawn := texture.get_image()
	if drawn == null or drawn.get_size() != expected.get_size(): return false
	expected.convert(Image.FORMAT_RGBA8)
	drawn.convert(Image.FORMAT_RGBA8)
	if premultiplied: expected = PMA.convert(expected)
	return drawn.get_data() == expected.get_data()

func fallback(result: Node, rows: Array[Dictionary]) -> void:
	if not check(result is Stage and result.cards.size() == rows.size(),"HUD opened the whole-window reveal for every award"): return
	result.skip_to_result()
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		var face: Control = result.cards[index].face
		var evidence: Dictionary = face.get_meta("original_card_asset")
		var base: Dictionary = Source.canonical(row).source_ui_assets.DisplayBaseAssetID
		var id := int(row.source_card_id)
		samples.append([id,evidence.get("source_asset_id",0),str(face.artwork.get_size()) if face.artwork else "missing"])
		check(int(evidence.get("source_asset_id",0)) == int(AWARDS[id][0]) and evidence.get("role") == "DisplayBaseAssetID","settled fallback portrait ID %d" % id)
		check(face.is_visible_in_tree() and face.elapsed >= face.duration and pixels_match(face.artwork,base.path),"settled fallback pixels %d" % id)
	result.close_reveal()

func authored(view: RefCounted, rows: Array[Dictionary], fusion: bool) -> void:
	if not check(view != null and view.is_open(),"HUD opened the authored result"): return
	if not fusion: view.open_all()
	var reels: Array = view._scene.find_children("CardRevealEffect","Control",true,false)
	if not check(reels.size() == rows.size(),"each authored result has its own reel"): return
	for reel: Control in reels:
		var row: Dictionary = reel.record
		var base: Dictionary = Source.canonical(row).source_ui_assets.DisplayBaseAssetID
		check(pixels_match(reel.face.artwork,base.path),"authored reel ends on portrait %d" % int(row.source_card_id))
	await create_timer(reels[0].reveal_at()+0.4).timeout
	var faces: Array = view._scene.find_children("SourceAwardFace","Node2D",true,false)
	check(faces.size() == rows.size(),"all original grade-prefab faces settled")
	for index: int in mini(faces.size(), rows.size()):
		var row: Dictionary = rows[index]
		var id := int(row.source_card_id)
		var face: Node2D = faces[index]
		var base: Dictionary = Source.canonical(row).source_ui_assets.DisplayBaseAssetID
		var matched := false
		for node: Node2D in face.source_nodes.values():
			if not node.has_meta("source523_original_asset"): continue
			var evidence: Dictionary = node.get_meta("source523_original_asset")
			var sprite: Sprite2D = node.get_meta("source_sprite")
			if evidence.get("role") == "DisplayBaseAssetID" and int(evidence.get("source_asset_id",0)) == int(AWARDS[id][0]):
				matched = sprite.is_visible_in_tree() and pixels_match(sprite.texture,base.path,true)
				samples.append([id,evidence.source_asset_id,str(sprite.texture.get_size()) if sprite.texture else "missing"])
		check(matched,"visible settled authored CardSample matches original upload %d" % id)
	view.close()

func catalog_tap(point: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 53
		event.position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func authored_card_point(view: RefCounted, identity: String) -> Vector2:
	for cell: Node in view._card_scenes.values():
		if cell.get_meta("source_change_card",{}).get("id") != identity: continue
		for node: Node2D in cell.source_nodes.values():
			if node.has_meta("source_checkbox"):
				var area: Control = node.get_meta("source_checkbox")._input_area
				return area.get_global_transform_with_canvas() * (area.size * 0.5)
	return Vector2.INF

func fallback_card_point(list: ItemList, identity: String) -> Vector2:
	for index: int in list.item_count:
		if list.get_item_metadata(index) != identity: continue
		var center := list.get_item_rect(index, false).get_center()
		center.y -= list.get_v_scroll_bar().value
		if Rect2(Vector2.ZERO, list.size).has_point(center):
			return list.get_global_transform_with_canvas() * center
	return Vector2.INF

func source_text(scene: Node2D, offset: int) -> String:
	return str(scene.source_nodes[offset].get_meta("source_text").original_options.text)

func catalog_detail(world: Node, rows: Array[Dictionary], native: bool) -> void:
	var hud: Node = world.hud
	var owned: Dictionary = world.card_draw_fusion.owned["변신"]
	var original := owned.duplicate()
	for row: Dictionary in rows: owned[Rules.card_id(row)] = true
	world._update_hud()
	hud.open_catalog("변신")
	for frame: int in 3: await process_frame
	var view: RefCounted = hud.original_main_ui_controller._change_window if native and is_instance_valid(hud.original_main_ui_controller) else null
	var mounted: bool = view != null and view.is_open() if native else hud.catalog_list.is_visible_in_tree() and hud.catalog_list.can_process()
	if check(mounted, "open interactive transformation catalog"): await check_catalog_cells(hud,view,rows,native)
	hud._close_workspace()
	owned.assign(original)
	world._update_hud()
	await process_frame

func check_catalog_cells(hud: Node, view: RefCounted, rows: Array[Dictionary], native: bool) -> void:
	var initial: String = view._selected if native else Rules.card_id(hud.selected_catalog_record)
	var ordered := rows.duplicate()
	# A second tap on the already-selected authored card requests equip.
	for row: Dictionary in rows:
		if Rules.card_id(row) == initial:
			ordered.erase(row)
			ordered.append(row)
			break
	for row: Dictionary in ordered:
		var id := int(row.source_card_id)
		var identity := Rules.card_id(row)
		var point := authored_card_point(view, identity) if native else fallback_card_point(hud.catalog_list, identity)
		if not check(point.is_finite(), "reachable catalog cell %d" % id): continue
		await catalog_tap(point)
		var selected: String = view._selected if native else Rules.card_id(hud.selected_catalog_record)
		if not check(selected == identity, "touch selects exact card %d" % id): continue
		var visual: CanvasItem
		var art: Texture2D
		var evidence: Dictionary
		var options := PackedStringArray()
		var panel: CanvasItem
		var title: String
		var grade_text: String
		if native:
			var target: Node2D = view._detail.source_nodes[Change.SAMPLE]
			var sprite: Sprite2D = target.get_meta("source_sprite")
			visual = sprite
			art = sprite.texture
			evidence = target.get_meta("source523_original_asset", {})
			panel = view._detail.source_nodes[Change.SAMPLE_PANEL]
			title = source_text(view._info, Change.INFO_CARD.name)
			grade_text = source_text(view._info, Change.INFO_CARD.grade)
			for child: Node2D in view._option_content.get_children():
				options.append(source_text(child, Change.OPTION_DESC) + source_text(child, Change.OPTION_VALUE))
		else:
			visual = hud.catalog_preview
			art = hud.catalog_preview.texture
			evidence = hud.catalog_preview.get_meta("original_card_asset", {})
			panel = hud.catalog_preview
			title = hud.companion_detail_view.name_label.text
			grade_text = hud.companion_detail_view.grade_label.text
			for label: Label in hud.companion_detail_view.options.get_children():
				options.append(label.text)
		# The original Change_DetailView CardSample shows every card front
		# (user list 2026-11-26 #16); the fallback HUD preview keeps Atun's
		# legendary illustration.
		var expected_role := "DisplayBaseAssetID" if AWARDS.has(id) or native else "IllustrationAssetID"
		var expected_id := int(AWARDS[id][0]) if AWARDS.has(id) else (157604 if native else 181031) # Legendary Atun
		var asset_id := int(evidence.get("provenance",{}).get("asset_id",0))
		var role := str(evidence.get("role",""))
		var declared: Dictionary = Source.canonical(row).source_ui_assets.get(role,{})
		var matches := asset_id == int(declared.get("asset_id",-1)) and pixels_match(art,str(declared.get("path","")),native)
		catalog_samples.append([id,role,asset_id,matches,options.size(),"\n".join(options).sha256_text(),str(panel.get_global_transform_with_canvas())])
		check(visual.is_visible_in_tree() and title == row.name and grade_text.begins_with(row.grade)
			and not options.is_empty(), "selected picture, name, grade and options %d" % id)
		check(matches, "visible catalog pixels match their declared original %d" % id)
		check(role == expected_role and asset_id == expected_id, "catalog selection uses %s %d" % [expected_role,id])

func run() -> void:
	var args := OS.get_cmdline_user_args()
	image_root = OS.get_environment("TWILIGHT_SOURCE523_IMAGES")
	if not args.has("--expect-native") and not args.has("--expect-fallback"):
		var stage := Stage.new()
		root.add_child(stage)
		var unknown: Array[Dictionary] = [{"grade":"신화","name":"식별 불가"}]
		stage.present(unknown,[],"변신")
		stage.skip_to_result()
		check(stage.cards[0].art_missing and stage.cards[0].face.artwork == null,"missing source identity never invents a portrait")
		stage.close_reveal()
	elif OS.get_environment("TWILIGHT_CARD_PORTRAIT_TEST_ISOLATED") != "1":
		check(false,"the Main fixture requires an isolated test user directory")
	else:
		root.size=Vector2i(2048,919)
		var world: Node = load("res://Main.tscn").instantiate()
		root.add_child(world)
		current_scene=world
		await process_frame
		check(QA.enter_game(world),"enter actual Main")
		world.set_process(false)
		world.player.set_physics_process(false)
		world.field_population.set_process(false)
		world.save_timer=-100000
		var hud: Node = world.hud
		check(Source.CURRENT_DEFINITIONS.identity().get("source_sha256") == Source.CURRENT_DEFINITIONS.SOURCE_SHA,
			"production selector opened the pinned patch523 definitions")
		check(FileAccess.get_sha256(image_root.path_join("manifest.json")) == "db51444bcd65d89c8775b67f321db0c1aa6bcb801f5e4375f6d50a0de2d3cb1f",
			"independent original PNGs come from the pinned image pack")
		var rows: Array[Dictionary]=[]
		var catalog_rows: Array[Dictionary]=[]
		for row: Dictionary in hud.catalog_data.get("변신",[]):
			var id := int(row.get("source_card_id",0))
			if id == 10541 or AWARDS.has(id): catalog_rows.append(row)
			if not AWARDS.has(id): continue
			rows.append(row)
			var detail: Dictionary = Presentation.detail(row,true,true)
			check(detail.get("role") == "IllustrationAssetID" and int(detail.get("source_asset_id",0)) == int(AWARDS[id][1]) and pixels_match(detail.get("texture"),Source.canonical(row).source_ui_assets.IllustrationAssetID.path),"explicit detail illustration available for comparison %d" % id)
		var native := args.has("--expect-native")
		if native:
			check(is_instance_valid(hud.original_main_ui_controller)
				and hud.original_main_ui_controller._pack != null
				and hud.original_main_ui_controller._pack.manifest_sha256 == "5263d92594e8f44248ad799d6b56ba7816fc5f30bdc4ead0bafaf0bf2dd0b94c",
				"original catalog and results use UI44")
		if check(catalog_rows.size() == AWARDS.size()+1, "seven Myth/Sole cards and Legendary Atun from the original catalog"):
			await catalog_detail(world,catalog_rows,native)
		var before: Dictionary = world.card_draw_fusion.export_state().duplicate(true)
		var rng: int = world.card_draw_fusion.rng.state
		if check(rows.size() == AWARDS.size(),"verified all seven real Myth/Sole transformation identities"):
			for fusion: bool in [false,true]:
				var awards: Array[Dictionary]=[]
				for row: Dictionary in rows: awards.append({"id":Rules.card_id(row)})
				hud.present_card_reveal("변신",{"ok":true,"results":awards,"batch":true,"success":true},fusion)
				if native:
					var controller: Node=hud.original_main_ui_controller
					var key := "fusion_result" if fusion else "card_gacha_result"
					if check(is_instance_valid(controller),"original UI controller present"):
						await authored(controller.feature_window(key),rows,fusion)
				else:
					fallback(hud.card_reveal_stage,rows)
				await process_frame
				check(not hud.is_card_reveal_busy(),"result close releases the HUD")
		check(before == world.card_draw_fusion.export_state() and rng == world.card_draw_fusion.rng.state,"viewing results never changes ownership or award RNG")
		hud._close_workspace()
		await create_timer(1.4).timeout
		world.queue_free()
	await process_frame
	await process_frame
	print("CARD_RESULT_PORTRAIT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"catalog":catalog_samples}))
	quit(0 if failures.is_empty() else 1)
