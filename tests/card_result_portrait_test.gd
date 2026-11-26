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

func catalog_detail(world: Node, rows: Array[Dictionary]) -> void:
	var hud: Node = world.hud
	var owned: Dictionary = world.card_draw_fusion.owned["변신"]
	var original := owned.duplicate()
	for row: Dictionary in rows:
		owned[Rules.card_id(row)] = true
	world._update_hud()
	hud.open_catalog("변신")
	await process_frame
	var view: RefCounted = hud.original_main_ui_controller._change_window
	if check(view != null and view.is_open(),"open original transformation catalog"):
		for row: Dictionary in rows:
			var id := int(row.source_card_id)
			if id not in [11152,18722]: continue
			var identity := Rules.card_id(row)
			for cell: Node in view._card_scenes.values():
				if cell.get_meta("source_change_card",{}).get("id") != identity or view._selected == identity: continue
				for node: Node2D in cell.source_nodes.values():
					if not node.has_meta("source_checkbox"): continue
					var area: Control = node.get_meta("source_checkbox")._input_area
					var point: Vector2 = area.get_global_transform_with_canvas() * (area.size*0.5)
					for down: bool in [true,false]:
						var event := InputEventScreenTouch.new()
						event.index=53
						event.position=point
						event.pressed=down
						root.push_input(event,true)
						await process_frame
					break
				break
			var target: Node2D = view._detail.source_nodes[Change.SAMPLE]
			var sprite: Sprite2D = target.get_meta("source_sprite")
			var path: String = Source.canonical(row).source_ui_assets.IllustrationAssetID.path
			check(view._selected == identity and sprite.is_visible_in_tree() and pixels_match(sprite.texture,path,true),"catalog detail touch displays large illustration %d" % id)
	hud._close_workspace()
	owned.assign(original)
	world._update_hud()
	await process_frame

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
		for row: Dictionary in hud.catalog_data.get("변신",[]):
			var id := int(row.get("source_card_id",0))
			if not AWARDS.has(id): continue
			rows.append(row)
			var detail: Dictionary = Presentation.detail(row,true,true)
			check(detail.get("role") == "IllustrationAssetID" and int(detail.get("source_asset_id",0)) == int(AWARDS[id][1]) and pixels_match(detail.get("texture"),Source.canonical(row).source_ui_assets.IllustrationAssetID.path),"catalog detail retains original illustration %d" % id)
		var native := args.has("--expect-native")
		if native and rows.size() == AWARDS.size() and check(is_instance_valid(hud.original_main_ui_controller)
				and hud.original_main_ui_controller._pack != null
				and hud.original_main_ui_controller._pack.manifest_sha256 == "5263d92594e8f44248ad799d6b56ba7816fc5f30bdc4ead0bafaf0bf2dd0b94c",
				"original catalog and results use UI44"):
			await catalog_detail(world,rows)
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
	print("CARD_RESULT_PORTRAIT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples}))
	quit(0 if failures.is_empty() else 1)
