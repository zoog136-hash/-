extends SceneTree

const QA=preload("res://tests/qa_class_selection.gd")
const Rules=preload("res://scripts/card_draw_fusion.gd")
const Tickets=preload("res://scripts/card_pack_items.gd")
const Chrome=preload("res://scripts/ui/catalog_card_chrome.gd")
const Card=preload("res://scripts/ui/card_reveal_card.gd")
var world: TwilightWorld
var failures: Array[String]=[]
var checks: int=0
var finished_count: int=0
func _initialize() -> void:call_deferred("run")
func frames(count: int=4) -> void:
	for i: int in range(count):await process_frame
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures.append(why);printerr("REVEAL_CATALOG_FAIL ",why)
func tap(control: Control) -> void:
	var at: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	for down: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=759;event.position=at;event.pressed=down;root.push_input(event,true)
func copies(state: Dictionary,category: String) -> int:
	var count: int=(state.get("owned",{}).get(category,{}) as Dictionary).size()
	for value: Variant in (state.get("spare",{}).get(category,{}) as Dictionary).values():count+=int(value)
	return count
func verify_cards(stage: Control, category: String) -> void:
	var catalog: Dictionary={}
	for record: Dictionary in world.hud.catalog_data[category]:catalog[Rules.card_id(record)]=record
	for card: Control in stage.cards:
		var identity: String=str(card.record.get("id",""))
		var expected: Dictionary=catalog.get(identity,{})
		check(not expected.is_empty(),"awarded ID belongs to category "+category+identity)
		if expected.is_empty():continue
		check(card.grade==str(expected.grade) and card.name_label.text==str(expected.name),"grade/name match awarded stable ID "+identity)
		check(not card.art_missing and card.face.artwork!=null and card.face.artwork.resource_path==str(expected.image_path),"revealed art is exact current catalog PNG "+category+identity)
		check(card.confirmed_chrome.visible and card.get_node("MetalRim").visible,"internal aura and original card rim remain visible after confirmation")
		var rank: int=maxi(0,Chrome.GRADES.find(card.grade))
		var low: bool=card.detail_scale<.8
		check(card.confirmed_chrome.rank==rank and card.confirmed_chrome.glow.material==Chrome.material_for(rank,true,false,card.reduced_motion,low),"same cached rarity aura as catalog "+category+identity)
		check(card.confirmed_chrome.find_children("PaintedCardBorder","",true,false).is_empty(),"revealed/result cards never add the catalog's decorative border")
		check(card.confirmed_chrome.size==card.size and not card.confirmed_chrome.is_processing(),"existing card geometry and bounded presentation lifetime")
func run() -> void:
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(8)
	check(QA.enter_game(world),"actual class confirmation")
	world.save_timer=-100000;world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	var hud: Node=world.hud
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		for pack: String in Tickets.PACKS:
			var spec: Dictionary=Tickets.definition(pack)
			var category: String=str(spec.category)
			var count: int=int(spec.count)
			var before: Dictionary=world.card_draw_fusion.export_state().duplicate(true)
			world.inventory[pack]=1
			world.card_draw_fusion.rng.seed=20261026+checks
			world._on_inventory_item_activated(pack);await frames()
			var stage: Control=hud.card_reveal_stage
			check(is_instance_valid(stage),"real inventory ticket opens presentation "+pack+str(extent))
			if not is_instance_valid(stage):continue
			stage.silent=true
			check(stage.category==category and stage.results.size()==count and stage.cards.size()==count,"native single/eleven count and category "+pack)
			var granted: Dictionary=world.card_draw_fusion.export_state().duplicate(true)
			check(copies(granted,category)-copies(before,category)==count and int(world.inventory.get(pack,0))==0,"exact award count and single ticket debit committed before screen")
			var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
			var restored=Rules.new();restored.configure(world.catalog_db);restored.import_state(saved.get("card_draw_fusion",{}))
			check(restored.export_state()==granted,"awards saved before reveal")
			var save_sha: String=FileAccess.get_sha256(world.save_path())
			var rng_state: int=world.card_draw_fusion.rng.state
			var inventory_after: Dictionary=world.inventory.duplicate(true)
			var quickslots_after: Array=world.quickslots.duplicate(true)
			var gold_after: int=world.gold
			if count==1:
				var replay: Array=stage.results.duplicate(true)
				tap(stage.board.get_node("ConfirmReveal"));await frames()
				check(not is_instance_valid(hud.card_reveal_stage) and world.card_draw_fusion.export_state()==granted and FileAccess.get_sha256(world.save_path())==save_sha,"closing before reveal preserves already saved single award")
				hud.present_card_reveal(category,{"ok":true,"results":replay},false);await frames()
				stage=hud.card_reveal_stage
				stage.silent=true
			stage.seek(0.0)
			check(stage.cards.all(func(card: Control) -> bool:return not card.confirmed_chrome.visible and not card.name_label.visible and card.face.elapsed<0),"backs precede same reveal timeline")
			tap(stage.pause_button);await frames()
			var paused: float=stage.clock
			await create_timer(.16).timeout
			check(not stage.playing and is_equal_approx(stage.clock,paused),"native pause freezes sequence")
			tap(stage.pause_button);await create_timer(.16).timeout
			check(stage.playing and stage.clock>paused,"native resume continues existing sequence")
			var first: Control=stage.cards[0]
			stage.seek(first.reveal_at()-.001)
			check(not first.confirmed_chrome.visible and not first.name_label.visible,"existing lightning/confirmation delay hides face chrome")
			stage.seek(first.reveal_at())
			check(first.confirmed_chrome.visible and first.name_label.visible and first.face.elapsed>=first.face.duration,"exact existing reveal boundary exposes true art and grade chrome")
			tap(stage.board.get_node("SkipReveal"));await frames()
			check(is_equal_approx(stage.clock,stage.duration) and not stage.playing,"native skip enters stable result")
			verify_cards(stage,category)
			stage.seek(.1)
			tap(stage.pause_button);await create_timer(.1).timeout
			check(stage.playing and stage.clock>.1,"replay/resume never needs another award")
			stage.skip_to_result()
			check(world.card_draw_fusion.export_state()==granted and world.card_draw_fusion.rng.state==rng_state and FileAccess.get_sha256(world.save_path())==save_sha,"transports never reroll, grant, consume or rewrite save")
			check(world.inventory==inventory_after and world.quickslots==quickslots_after and world.gold==gold_after,"reveal transport touches never activate underlying quickslots/items")
			finished_count=0
			stage.finished.connect(func() -> void:finished_count+=1)
			tap(stage.board.get_node("ConfirmReveal"))
			if is_instance_valid(stage):stage.close_reveal()
			await frames()
			check(finished_count==1 and not is_instance_valid(hud.card_reveal_stage),"result confirmation closes exactly once")
			check(world.card_draw_fusion.export_state()==granted,"close preserves committed ownership")
	# Canonical high-grade records exercise art and the shared seven-tier style
	# without rolling/granting synthetic higher-grade awards.
	for category: String in Rules.CATEGORIES:
		var rows: Array=[]
		for grade: String in Rules.GRADES:
			for record: Dictionary in hud.catalog_data[category]:
				if str(record.grade)==grade:rows.append({"id":Rules.card_id(record),"name":record.name,"grade":grade});break
		var snapshot: Dictionary=world.card_draw_fusion.export_state().duplicate(true)
		hud.present_card_reveal(category,{"ok":true,"results":rows},false);await frames()
		var stage: Control=hud.card_reveal_stage
		stage.silent=true;stage.skip_to_result();verify_cards(stage,category)
		stage.close_reveal();await frames()
		check(world.card_draw_fusion.export_state()==snapshot,"pure canonical replay never grants cards")
	var absent: Control=Card.new();root.add_child(absent)
	var no_candidates: Array[Texture2D]=[]
	absent.configure({"id":"","sourceId":"missing-art","name":"누락 검증","grade":"영웅","image_path":"res://assets/catalog/does-not-exist.png"},no_candidates,"변신")
	check(absent.art_missing and absent.face.artwork==null,"missing real-ID art never impersonates an unrelated authored figure")
	absent.queue_free()
	await RenderingServer.frame_post_draw
	world.queue_free();await frames()
	print("REVEAL_CATALOG_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
