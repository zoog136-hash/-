extends SceneTree
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
const SOURCE = preload("res://scripts/lineagem_base508.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var pack: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--addon="): pack = arg.trim_prefix("--addon=")
	assert(not pack.is_empty())
	var installer := INSTALL.new()
	root.add_child(installer)
	var before: String = INSTALL.active_root()
	var result: Dictionary = await installer.install_zip(pack)
	assert(result.ok, str(result))
	assert(INSTALL.active_root() == before)
	INSTALL._session_root = ""
	var selected: String = INSTALL.active_root()
	assert(selected == result.root)
	var actor := preload("res://scripts/animation/original_source_preview.gd").new()
	root.add_child(actor)
	assert(actor.configure("transform:267", selected.path_join("manifest.json")))
	actor.advance_source(0.1, "walk", 2, 0, false)
	assert(actor.last_source_frame >= 0)
	for sid: int in [20889,28559,28583,6082]:
		assert(actor.spawn_source_overlay(sid, 2))
		var overlay: Node2D = actor._overlay_nodes[-1]
		assert(overlay._effect_nodes.size() == (1 if sid in [20889,6082] else 3))
		assert(overlay.attachment_status().active_compatibility_layers == overlay._effect_nodes.size())
		print("SOURCE_EFFECT_ADDON_LOADED sprite=", sid, " original_clothes=", overlay._effect_nodes.size())
	# One existing collectible body itself has104.attr8; it must not be dropped
	# or incorrectly applied to the separate native shadow.
	assert(actor.configure("sprite:15759", selected.path_join("manifest.json")))
	actor.advance_source(0.0, "idle", 2, 0, false)
	var body_flag_used: bool = false
	for layer: Sprite2D in actor._layers:
		if int(layer.get_meta("source_layer_id", -1)) == 15759:
			assert(layer.material != null and layer.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
			body_flag_used = true
		else: assert(layer.material == null)
	assert(body_flag_used)
	print("SOURCE_BODY_ATTR_RETAINED sprite=15759 attr8_compatibility_only=true shadow_unchanged=true")
	var icon: bool = false
	for row: Dictionary in SOURCE.cards().catalog["변신"]:
		if SOURCE.icon(row) != null: icon = true; break
	assert(icon)
	var host := Node2D.new()
	root.add_child(host)
	var player = load("res://scenes/Player.tscn").instantiate()
	host.add_child(player)
	player.set_physics_process(false)
	await process_frame
	var card: Dictionary = {}
	for row: Dictionary in SOURCE.cards().catalog["변신"]:
		if row.source_card_id == 18722: card = row; break
	assert(not card.is_empty())
	var profile = preload("res://scripts/animation/animation_catalog.gd").for_record("transform", card)
	player.set_transform_visual("", 1.0, profile)
	assert(player.original_source_preview.installed())
	assert(player.original_source_preview._overlay_nodes.size() == 1)
	var transition = player.original_source_preview._overlay_nodes[0]
	assert(transition._record.source_sprite_id == 6082)
	player.original_source_preview.advance_source(0.15, "walk", 2, 0, false)
	var clock: float = player.original_source_preview._clock
	player.set_transform_visual("", 1.0, profile)
	assert(player.original_source_preview._clock == clock)
	assert(is_instance_valid(transition))
	assert(player.original_source_preview._overlay_nodes.size() == 1)
	print("SOURCE_POLYMORPH_APPLY_TRIGGER sprite=6082 repeat_apply_preserves_clock=true icon_base_fallback=true native_pixels=true android=false")
	host.free()
	quit()
