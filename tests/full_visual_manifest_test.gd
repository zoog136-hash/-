extends SceneTree

const VISUALS = preload("res://scripts/animation/visual_manifest.gd")
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const FAMILY = preload("res://scripts/monsters/monster_catalog.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
var failed: Array[String] = []
var results: Dictionary = {"transform":[], "doll":[], "relic":[], "monsters":[], "items":[]}

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failed.append(label)
		print("FULL_VISUAL_FAIL: ", label)

func _frames(frames: SpriteFrames, key: String) -> int:
	check(frames != null, "frames " + key)
	if frames == null: return 0
	var total: int = 0
	for name_value: String in frames.get_animation_names():
		var count: int = frames.get_frame_count(name_value)
		check(count >= 2, "static track " + key + "/" + name_value)
		for i: int in range(count):
			check(frames.get_frame_texture(name_value, i) != null, "missing texture " + key + "/" + name_value)
		total += count
	return total

func _run() -> void:
	var actor: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(actor)
	await process_frame
	actor.set_physics_process(false)
	actor.position = Vector2(240, 240)
	var stats: Dictionary = VISUALS.stats()
	if int(stats.catalog) == 0:
		check(not actor.select_external_spx_actor("../../evil"), "unsafe actor rejected")
		check(actor.class_sprite.sprite_frames != null, "zero-pack fallback player")
		check(VISUALS.catalog_frames("transform:393") == null, "absent pack fallback")
		actor.queue_free()
		await process_frame
		if OS.get_environment("TWILIGHT_REQUIRE_VISUAL_PACK") == "1":
			check(false, "required real resource pack absent")
		if failed.is_empty(): print("FULL_VISUAL_MANIFEST_OK art=absent fallback=true")
		quit(0 if failed.is_empty() else 1)
		return
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2(1,1), Vector2.DOWN, Vector2(-1,1), Vector2.LEFT, Vector2(-1,-1), Vector2.UP, Vector2(1,-1)]
	var anchor := Node2D.new()
	var doll := AnimatedSprite2D.new()
	root.add_child(anchor)
	anchor.add_child(doll)
	var relic := Sprite2D.new()
	root.add_child(relic)
	var follower := preload("res://scripts/animation/follower_motion.gd").new()
	var relic_motion := preload("res://scripts/animation/relic_motion.gd").new()
	for record: Dictionary in db["변신"]:
		var key: String = "transform:" + str(record.sourceId)
		var before: int = failed.size()
		var info: Dictionary = VISUALS.record(key)
		check(not info.is_empty(), "registered transform missing manifest " + key)
		actor.auto_enabled = true
		var previous: Vector2 = actor.position
		var profile: TwilightAnimationProfile = CATALOG.for_record("transform", record, record.image_path)
		actor.set_transform_visual(record.image_path, 1.0, profile)
		var frames: SpriteFrames = actor.transform_sprite.sprite_frames
		var total: int = _frames(frames, key)
		check(actor.transform_active and actor.auto_enabled and actor.position == previous, "equip preserves motion/AUTO " + key)
		for direction: Vector2 in directions:
			actor.cancel_attack()
			actor.motion.face(direction)
			actor.motion.advance(.02, direction.normalized() * 180)
			actor.motion.gait = 0.0
			actor.motion.apply(actor.transform_sprite, actor.transform_sprite.get_meta("base_scale"))
			var first: int = actor.transform_sprite.frame
			actor.motion.gait = 2.0
			actor.motion.apply_frames(actor.transform_sprite)
			check(actor.transform_sprite.frame != first, "walking frame advances " + key)
			check(str(actor.transform_sprite.animation).begins_with("walk"), "walk selects track " + key)
			actor.start_combat_attack(actor.position + direction * 100, .7, profile.motion_style)
			actor.motion.advance(.10, Vector2.ZERO)
			actor.motion.apply_frames(actor.transform_sprite)
			check(str(actor.transform_sprite.animation).begins_with("attack") or str(actor.transform_sprite.animation).begins_with("ranged_attack") or str(actor.transform_sprite.animation).begins_with("cast"), "combat selects authored pose " + key)
		actor.cancel_attack()
		actor.motion.react()
		actor.motion.advance(.01, Vector2.ZERO)
		actor.motion.apply_frames(actor.transform_sprite)
		check(str(actor.transform_sprite.animation).begins_with("hit"), "hit pose " + key)
		actor.motion.die()
		actor.motion.advance(.18, Vector2.ZERO)
		actor.motion.apply_frames(actor.transform_sprite)
		check(str(actor.transform_sprite.animation).begins_with("death"), "death pose " + key)
		actor.motion.dead = false
		actor.clear_transform_visual()
		check(actor.class_sprite.visible and not actor.transform_sprite.visible, "remove transform " + key)
		results.transform.append({"game_id":record.sourceId, "frames":total, "available_views":info.get("directions", 0), "input_directions_tested":8, "passed":failed.size()==before})
		if results.transform.size()%50==0:
			print("FULL_VISUAL_PROGRESS transforms=",results.transform.size())
			await process_frame
	for record: Dictionary in db["마법인형"]:
		var before: int = failed.size()
		var key: String = "doll:" + str(record.sourceId)
		follower.configure(record, record.image_path, anchor, doll, actor)
		var total: int = _frames(doll.sprite_frames, key)
		follower.update(.08, anchor, doll, actor)
		check(str(doll.animation).begins_with("summon"), "summon pose " + key)
		for i: int in range(20): follower.update(.05, anchor, doll, actor)
		actor.position += Vector2(50, -35)
		follower.update(.05, anchor, doll, actor)
		check(follower.state=="follow" and anchor.position.distance_to(actor.position+follower.follow_offset)<90, "follows owner " + key)
		actor.start_combat_attack(actor.position + Vector2.RIGHT*100, .7, "slash")
		follower.update(.02, anchor, doll, actor)
		check(str(doll.animation).begins_with("activate"), "buff reaction " + key)
		actor.cancel_attack()
		follower.configure({}, "", anchor, doll, actor)
		follower.update(.02, anchor, doll, actor)
		check(str(doll.animation).begins_with("despawn"), "despawn pose " + key)
		for i: int in range(20): follower.update(.05, anchor, doll, actor)
		check(not doll.visible, "doll removed " + key)
		results.doll.append({"game_id":record.sourceId,"frames":total,"passed":failed.size()==before})
		if results.doll.size()%50==0: await process_frame
	for record: Dictionary in db["성물"]:
		var before: int = failed.size()
		var key: String = "relic:" + str(record.sourceId)
		relic_motion.configure(record, relic, actor, Color("ffd060"))
		var total: int = _frames(relic_motion.motion.frame_source, key)
		relic_motion.update(.05, relic, actor)
		check(relic_motion.motion.state=="equip", "equip relic pose " + key)
		for i: int in range(20): relic_motion.update(.05, relic, actor)
		check(relic.visible and relic.offset.y<0 and relic.z_index==0, "relic body and elevation " + key)
		actor.start_combat_attack(actor.position+Vector2.RIGHT*100,.7,"slash")
		relic_motion.update(.02,relic,actor)
		check(relic_motion.motion.state=="activate", "relic skill reaction " + key)
		actor.cancel_attack()
		relic_motion.configure({},relic,actor,Color.WHITE)
		relic_motion.update(.02,relic,actor)
		check(relic_motion.motion.state=="unequip", "relic unequip pose " + key)
		for i: int in range(20): relic_motion.update(.05,relic,actor)
		check(not relic.visible and relic.texture==null, "relic removed " + key)
		results.relic.append({"game_id":record.sourceId,"frames":total,"passed":failed.size()==before})
		if results.relic.size()%50==0: await process_frame
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	var shared: Dictionary = {}
	for record: Dictionary in FAMILY.expand(base["몬스터"]):
		var info: Dictionary = VISUALS.monster_binding(record)
		if not info.is_empty():
			var texture: Texture2D = VISUALS.monster_texture(record)
			check(texture!=null,"original monster texture " + record.name)
			var key: String = str(info.family_id)
			if shared.has(key): check(shared[key]==str(info.path),"family shares original texture " + key)
			shared[key]=str(info.path)
		results.monsters.append({"name":record.name,"original_bound":not info.is_empty(),"has_original_spx":false})
	for record: Dictionary in db["아이템"]:
		var texture: Texture2D = UI.item_icon(record,record.name,{})
		check(texture!=null,"all inventory/shop/codex icons " + str(record.sourceId))
		var info: Dictionary = VISUALS.item_binding(record)
		if not info.is_empty():
			check(VISUALS.item_icon(record, record.name, true)!=null,"ground item image " + str(record.sourceId))
		results.items.append({"game_id":record.sourceId,"original_bound":not info.is_empty(),"icon_loaded":texture!=null})
	check(results.transform.size()==413 and results.doll.size()==166 and results.relic.size()==144,"entire catalog count")
	check(int(VISUALS.stats().frame_cache)<=VISUALS.LIMIT and int(VISUALS.stats().texture_cache)<=VISUALS.LIMIT,"bounded texture cache")
	DirAccess.make_dir_recursive_absolute("user://full-visual-review")
	var file := FileAccess.open("user://full-visual-review/runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"results":results,"failures":failed,"engine":Engine.get_version_info().string,"manual_review":false},"\t"))
	print("FULL_VISUAL_REPORT ",ProjectSettings.globalize_path("user://full-visual-review/runtime.json"))
	actor.queue_free();anchor.queue_free();relic.queue_free()
	await process_frame
	if failed.is_empty(): print("FULL_VISUAL_MANIFEST_OK transforms=413 dolls=166 relics=144 monsters=318 items=2129 art=installed_atlas")
	quit(0 if failed.is_empty() else 1)
