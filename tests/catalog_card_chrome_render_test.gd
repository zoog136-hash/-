extends SceneTree

const QA=preload("res://tests/qa_class_selection.gd")
const Chrome=preload("res://scripts/ui/catalog_card_chrome.gd")
const UI=preload("res://scripts/ui/renewal_theme.gd")
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void:call_deferred("run")
func frames(count: int=5) -> void:
	for i: int in range(count):await process_frame
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("CARD_CHROME_FAIL ",message)
func tap(control: Control) -> void:
	var at: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	for down: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=561;event.position=at;event.pressed=down;root.push_input(event,true)
func preview_pixels(hud: Node) -> PackedByteArray:
	await RenderingServer.frame_post_draw
	# Match the captured framebuffer, including the project's viewport stretch.
	var transform: Transform2D=root.get_final_transform()*hud.catalog_preview.get_global_transform_with_canvas()
	var rect: Rect2=transform*hud.catalog_card_chrome._preview_rect()
	var image: Image=root.get_texture().get_image()
	check(Rect2(Vector2.ZERO,image.get_size()).encloses(rect),"rendered preview remains in the physical framebuffer")
	return image.get_region(Rect2i(rect)).get_data()
func compare_aura_masks() -> void:
	# Render the same shared slot materials over transparency. Alpha/radius
	# comparisons exclude hue and source illustrations, so color alone cannot pass.
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(96,128)
	viewport.transparent_bg=true
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var patch:=ColorRect.new()
	patch.size=Vector2(96,128)
	viewport.add_child(patch)
	var previous_energy: float=-1.0
	var previous_radius: float=-1.0
	for rank: int in range(Chrome.GRADES.size()):
		patch.material=Chrome.material_for(rank,true,false,true)
		await frames(2);await RenderingServer.frame_post_draw
		var image: Image=viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		var pixels: PackedByteArray=image.get_data()
		var energy: float=0.0
		var radius_energy: float=0.0
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				var alpha: float=float(pixels[(y*image.get_width()+x)*4+3])
				var point:=Vector2((x+.5)/image.get_width()*2-1,(y+.5)/image.get_height()*2-1)
				energy+=alpha
				radius_energy+=alpha*point.length()
		var radius: float=radius_energy/maxf(1,energy)
		check(energy>previous_energy,"rendered aura brightness/coverage rises independently of hue "+Chrome.GRADES[rank])
		check(radius>previous_radius,"rendered aura range rises independently of hue "+Chrome.GRADES[rank])
		previous_energy=energy;previous_radius=radius
		patch.material=Chrome.material_for(rank,true)
		await frames(2);await RenderingServer.frame_post_draw
		var first: PackedByteArray=viewport.get_texture().get_image().get_data()
		await create_timer(.3).timeout;await RenderingServer.frame_post_draw
		var later: PackedByteArray=viewport.get_texture().get_image().get_data()
		check(first!=later if rank>=2 else first==later,"actual tier motion matches its static/flowing rule "+Chrome.GRADES[rank])
	viewport.queue_free();await frames()
func run() -> void:
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);await frames(8)
	check(QA.enter_game(world),"class selection")
	world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	var hud: Node=world.hud
	var inventory: Dictionary=world.inventory.duplicate(true)
	var cards: Dictionary=world.card_draw_fusion.export_state().duplicate(true)
	var gold: int=world.gold
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		for category: String in ["변신","마법인형","성물"]:
			hud.open_catalog(category);await frames()
			var chrome: Node=hud.catalog_card_chrome
			check(chrome.active and chrome.slots.is_visible_in_tree(),"native catalog chrome active "+category+str(extent))
			check(not chrome.is_processing() and chrome.slots.get_child_count()==15 and not chrome.quantities.is_processing() and chrome.quantities.mouse_filter==Control.MOUSE_FILTER_IGNORE,"fourteen batched art layers plus one passive quantity layer, without per-frame CPU updates or input capture")
			for index: int in range(hud.catalog_list.item_count):
				var native: Rect2=hud.catalog_list.get_item_rect(index,false)
				native.position.y-=hud.catalog_list.get_v_scroll_bar().value
				if Rect2(Vector2.ZERO,hud.catalog_list.size).intersects(native):
					check(chrome.visible_cards.any(func(card: Dictionary) -> bool:return card.index==index and native.grow(-1).encloses(card.rect) and card.rect.position.is_equal_approx(native.position+Vector2.ONE) and is_equal_approx(card.rect.size.x,native.size.x-2)),"each visible native cell has an aligned frame "+category+str(extent)+str(index))
			for grade: String in Chrome.GRADES:
				if hud.catalog_grade_column.is_visible_in_tree():tap(hud.catalog_grade_buttons[grade])
				else:
					hud.rarity_filter.select(["전체","일반","고급","희귀","영웅","전설","신화","유일"].find(grade))
					hud.rarity_filter.item_selected.emit(hud.rarity_filter.selected)
				await frames()
				check(hud.catalog_results.size()>0 and str(hud.selected_catalog_record.grade)==grade,"actual grade filter "+category+grade+str(extent))
				var rank: int=Chrome.GRADES.find(grade)
				check(chrome.selected_rank==rank and chrome.frame_layers[rank].visible and chrome.aura_layers[rank].visible,"slot/detail grade linked "+category+grade)
				check(chrome.preview_frame.material.get_shader_parameter("grade_color")==UI.grade(grade),"existing palette preserved "+grade)
				check(hud.catalog_preview.texture.resource_path==str(hud.selected_catalog_record.image_path),"original selected PNG unchanged "+category+grade)
				check(chrome.frame_layers[rank].material==Chrome.material_for(rank,false),"metal material reused across catalogs and detail")
				check(chrome.aura_layers[rank].material==Chrome.material_for(rank,true) and chrome.preview_aura.material==Chrome.material_for(rank,true,true),"same grade aura rules drive slots/details in every catalog")
				check(chrome.visible_cards.all(func(card: Dictionary) -> bool:return card.rect.size.x<=hud.catalog_list.fixed_column_width+hud.catalog_list.get_theme_constant("h_separation")),"painted frames stay within native columns "+category+str(extent))
			if category!="성물" and hud.catalog_details_tab.is_visible_in_tree():tap(hud.catalog_details_tab);await frames()
			check(chrome.preview_frame.is_visible_in_tree(),"selected detail remains reachable on small screen "+category)
			# Compare real framebuffer pixels, not only effect uniforms.
			var moving: PackedByteArray=await preview_pixels(hud)
			await create_timer(.45).timeout
			var next: PackedByteArray=await preview_pixels(hud)
			check(moving!=next,"high-grade aura actually animates "+category+str(extent))
			world.presentation_settings.reduced_motion=true
			chrome.refresh();await frames()
			var still: PackedByteArray=await preview_pixels(hud)
			await create_timer(.45).timeout
			check(still==await preview_pixels(hud),"reduced-motion aura stays still "+category+str(extent))
			world.presentation_settings.reduced_motion=false
			chrome.refresh();await frames()
			hud.open_catalog("아이템");await frames()
			check(not chrome.active and not chrome.slots.is_visible_in_tree() and not chrome.preview.visible,"card chrome removed from item catalog")
			hud._close_workspace()
			chrome.refresh();await frames()
			check(not chrome.pending_layout and not chrome.slots.is_visible_in_tree() and not chrome.preview_aura.is_visible_in_tree(),"closed catalogs schedule no aura update or rendering")
	check(world.inventory==inventory and world.gold==gold and world.card_draw_fusion.export_state()==cards,"presentation never mutates items, currency, owned cards or fusion rules")
	for rank: int in range(7):
		var image: Image=Chrome.texture_for(rank).get_image()
		check(image.get_pixel(image.get_width()/2,image.get_height()/2).a==0,"painted frame keeps transparent art window "+str(rank))
	await compare_aura_masks()
	world.queue_free();await frames()
	print("CARD_CHROME_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
