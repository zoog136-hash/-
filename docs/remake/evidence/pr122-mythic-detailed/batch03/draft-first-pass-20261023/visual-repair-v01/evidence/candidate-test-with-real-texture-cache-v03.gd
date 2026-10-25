extends SceneTree
## Scope: changed first-pass candidates only. No quality or production approval.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
var textures: Array[ImageTexture] = []
func _initialize() -> void:
 call_deferred("_run")
func _invariants(world: Node) -> String:
 return JSON.stringify([world.hp, world.gold, world.inventory, world.equipped_items, world.equipped_catalog, world._normal_attack_interval(), world._current_weapon_type(), world.player.position, world.player.get_node("CollisionShape2D").transform, world.player.move_speed, world.player.attack_speed_multiplier])
func _tick(player: Node2D, velocity: Vector2) -> void:
 player.motion.advance(1.0 / 120.0, velocity)
 player.motion.apply(player.transform_sprite, player.transform_sprite.get_meta("base_scale", Vector2.ONE))
func _run() -> void:
 assert(OS.get_environment("XDG_DATA_HOME").get_file().begins_with("twilight-test-"))
 var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json"))
 var keys: PackedStringArray = OS.get_environment("TWILIGHT_NATIVE_TEST_KEYS").split(",", false)
 assert(not keys.is_empty())
 # Restore real textures after the ephemeral Godot import-cache loss.
 for path: String in ["res://assets/actors/eight_direction/expanded/antlion_armored/attack.png", "res://assets/actors/eight_direction/expanded/antlion_armored/cast.png", "res://assets/actors/eight_direction/expanded/antlion_armored/death.png", "res://assets/actors/eight_direction/expanded/antlion_armored/hit.png", "res://assets/actors/eight_direction/expanded/antlion_armored/idle.png", "res://assets/actors/eight_direction/expanded/antlion_armored/walk.png", "res://assets/actors/eight_direction/expanded/antlion_small/attack.png", "res://assets/actors/eight_direction/expanded/antlion_small/cast.png", "res://assets/actors/eight_direction/expanded/antlion_small/death.png", "res://assets/actors/eight_direction/expanded/antlion_small/hit.png", "res://assets/actors/eight_direction/expanded/antlion_small/idle.png", "res://assets/actors/eight_direction/expanded/antlion_small/walk.png", "res://assets/actors/eight_direction/expanded/female_plate_plate_helm_longsword/attack.png", "res://assets/actors/eight_direction/expanded/female_plate_plate_helm_longsword/cast.png", "res://assets/actors/eight_direction/expanded/female_plate_plate_helm_longsword/death.png", "res://assets/actors/eight_direction/expanded/female_plate_plate_helm_longsword/hit.png", "res://assets/actors/eight_direction/expanded/female_plate_plate_helm_longsword/idle.png", "res://assets/actors/eight_direction/expanded/female_plate_plate_helm_longsword/walk.png", "res://assets/actors/eight_direction/expanded/goblin/attack.png", "res://assets/actors/eight_direction/expanded/goblin/cast.png", "res://assets/actors/eight_direction/expanded/goblin/death.png", "res://assets/actors/eight_direction/expanded/goblin/hit.png", "res://assets/actors/eight_direction/expanded/goblin/idle.png", "res://assets/actors/eight_direction/expanded/goblin/walk.png", "res://assets/actors/eight_direction/expanded/hobgoblin/attack.png", "res://assets/actors/eight_direction/expanded/hobgoblin/cast.png", "res://assets/actors/eight_direction/expanded/hobgoblin/death.png", "res://assets/actors/eight_direction/expanded/hobgoblin/hit.png", "res://assets/actors/eight_direction/expanded/hobgoblin/idle.png", "res://assets/actors/eight_direction/expanded/hobgoblin/walk.png", "res://assets/actors/eight_direction/expanded/hobgoblin_archer/attack.png", "res://assets/actors/eight_direction/expanded/hobgoblin_archer/cast.png", "res://assets/actors/eight_direction/expanded/hobgoblin_archer/death.png", "res://assets/actors/eight_direction/expanded/hobgoblin_archer/hit.png", "res://assets/actors/eight_direction/expanded/hobgoblin_archer/idle.png", "res://assets/actors/eight_direction/expanded/hobgoblin_archer/ranged_attack.png", "res://assets/actors/eight_direction/expanded/hobgoblin_archer/walk.png", "res://assets/actors/eight_direction/expanded/male_leather_leather_hood_longbow/attack.png", "res://assets/actors/eight_direction/expanded/male_leather_leather_hood_longbow/cast.png", "res://assets/actors/eight_direction/expanded/male_leather_leather_hood_longbow/death.png", "res://assets/actors/eight_direction/expanded/male_leather_leather_hood_longbow/hit.png", "res://assets/actors/eight_direction/expanded/male_leather_leather_hood_longbow/idle.png", "res://assets/actors/eight_direction/expanded/male_leather_leather_hood_longbow/ranged_attack.png", "res://assets/actors/eight_direction/expanded/male_leather_leather_hood_longbow/walk.png", "res://assets/actors/eight_direction/expanded/male_leather_leather_hood_longsword/attack.png", "res://assets/actors/eight_direction/expanded/male_leather_leather_hood_longsword/cast.png", "res://assets/actors/eight_direction/expanded/male_leather_leather_hood_longsword/death.png", "res://assets/actors/eight_direction/expanded/male_leather_leather_hood_longsword/hit.png", "res://assets/actors/eight_direction/expanded/male_leather_leather_hood_longsword/idle.png", "res://assets/actors/eight_direction/expanded/male_leather_leather_hood_longsword/walk.png", "res://assets/actors/eight_direction/expanded/male_mage_mage_hood_staff/attack.png", "res://assets/actors/eight_direction/expanded/male_mage_mage_hood_staff/cast.png", "res://assets/actors/eight_direction/expanded/male_mage_mage_hood_staff/death.png", "res://assets/actors/eight_direction/expanded/male_mage_mage_hood_staff/hit.png", "res://assets/actors/eight_direction/expanded/male_mage_mage_hood_staff/idle.png", "res://assets/actors/eight_direction/expanded/male_mage_mage_hood_staff/walk.png", "res://assets/actors/eight_direction/expanded/skeleton/attack.png", "res://assets/actors/eight_direction/expanded/skeleton/cast.png", "res://assets/actors/eight_direction/expanded/skeleton/death.png", "res://assets/actors/eight_direction/expanded/skeleton/hit.png", "res://assets/actors/eight_direction/expanded/skeleton/idle.png", "res://assets/actors/eight_direction/expanded/skeleton/walk.png", "res://assets/actors/eight_direction/expanded/skeleton_archer/attack.png", "res://assets/actors/eight_direction/expanded/skeleton_archer/cast.png", "res://assets/actors/eight_direction/expanded/skeleton_archer/death.png", "res://assets/actors/eight_direction/expanded/skeleton_archer/hit.png", "res://assets/actors/eight_direction/expanded/skeleton_archer/idle.png", "res://assets/actors/eight_direction/expanded/skeleton_archer/ranged_attack.png", "res://assets/actors/eight_direction/expanded/skeleton_archer/walk.png", "res://assets/actors/eight_direction/expanded/skeleton_knight_boss/attack.png", "res://assets/actors/eight_direction/expanded/skeleton_knight_boss/cast.png", "res://assets/actors/eight_direction/expanded/skeleton_knight_boss/death.png", "res://assets/actors/eight_direction/expanded/skeleton_knight_boss/hit.png", "res://assets/actors/eight_direction/expanded/skeleton_knight_boss/idle.png", "res://assets/actors/eight_direction/expanded/skeleton_knight_boss/special.png", "res://assets/actors/eight_direction/expanded/skeleton_knight_boss/walk.png", "res://assets/actors/eight_direction/expanded/wyvern/attack.png", "res://assets/actors/eight_direction/expanded/wyvern/cast.png", "res://assets/actors/eight_direction/expanded/wyvern/death.png", "res://assets/actors/eight_direction/expanded/wyvern/hit.png", "res://assets/actors/eight_direction/expanded/wyvern/idle.png", "res://assets/actors/eight_direction/expanded/wyvern/ranged_attack.png", "res://assets/actors/eight_direction/expanded/wyvern/special.png", "res://assets/actors/eight_direction/expanded/wyvern/walk.png", "res://assets/actors/eight_direction/expanded/wyvern_air_boss/attack.png", "res://assets/actors/eight_direction/expanded/wyvern_air_boss/cast.png", "res://assets/actors/eight_direction/expanded/wyvern_air_boss/death.png", "res://assets/actors/eight_direction/expanded/wyvern_air_boss/hit.png", "res://assets/actors/eight_direction/expanded/wyvern_air_boss/idle.png", "res://assets/actors/eight_direction/expanded/wyvern_air_boss/ranged_attack.png", "res://assets/actors/eight_direction/expanded/wyvern_air_boss/special.png", "res://assets/actors/eight_direction/expanded/wyvern_air_boss/walk.png", "res://assets/actors/eight_direction/expanded/zombie/attack.png", "res://assets/actors/eight_direction/expanded/zombie/cast.png", "res://assets/actors/eight_direction/expanded/zombie/death.png", "res://assets/actors/eight_direction/expanded/zombie/hit.png", "res://assets/actors/eight_direction/expanded/zombie/idle.png", "res://assets/actors/eight_direction/expanded/zombie/walk.png", "res://assets/actors/eight_direction/knight/attack.png", "res://assets/actors/eight_direction/knight/death.png", "res://assets/actors/eight_direction/knight/hit.png", "res://assets/actors/eight_direction/knight/idle.png", "res://assets/actors/eight_direction/knight/walk.png", "res://assets/actors/eight_direction/original_based/cockatrice/poses.png", "res://assets/actors/eight_direction/original_based/crabman/poses-0.png", "res://assets/actors/eight_direction/original_based/crabman/poses-1.png", "res://assets/actors/eight_direction/original_based/dire_wolf/poses-0.png", "res://assets/actors/eight_direction/original_based/dire_wolf/poses-1.png", "res://assets/actors/eight_direction/original_based/evil_shelob/poses-0.png", "res://assets/actors/eight_direction/original_based/evil_shelob/poses-1.png", "res://assets/actors/eight_direction/original_based/evil_shelob/poses-2.png", "res://assets/actors/eight_direction/original_based/fire_egg/poses-0.png", "res://assets/actors/eight_direction/original_based/fire_egg/poses-1.png", "res://assets/actors/eight_direction/original_based/ghoul/poses-0.png", "res://assets/actors/eight_direction/original_based/ghoul/poses-1.png", "res://assets/actors/eight_direction/original_based/harpy/poses.png", "res://assets/actors/eight_direction/original_based/horn_cerberus/poses-0.png", "res://assets/actors/eight_direction/original_based/horn_cerberus/poses-1.png", "res://assets/actors/eight_direction/original_based/ice_golem/poses.png", "res://assets/actors/eight_direction/original_based/ice_man/poses-0.png", "res://assets/actors/eight_direction/original_based/ice_man/poses-1.png", "res://assets/actors/eight_direction/original_based/iron_golem/poses-0.png", "res://assets/actors/eight_direction/original_based/iron_golem/poses-1.png", "res://assets/actors/eight_direction/original_based/killer_bee/poses-0.png", "res://assets/actors/eight_direction/original_based/killer_bee/poses-1.png", "res://assets/actors/eight_direction/original_based/killer_bee/poses-2.png", "res://assets/actors/eight_direction/original_based/lamia/poses-0.png", "res://assets/actors/eight_direction/original_based/lamia/poses-1.png", "res://assets/actors/eight_direction/original_based/lava_golem/poses.png", "res://assets/actors/eight_direction/original_based/lizard/poses-0.png", "res://assets/actors/eight_direction/original_based/lizard/poses-1.png", "res://assets/actors/eight_direction/original_based/ogre/poses.png", "res://assets/actors/eight_direction/original_based/orc_mage/poses-0.png", "res://assets/actors/eight_direction/original_based/orc_mage/poses-1.png", "res://assets/actors/eight_direction/original_based/orc_mage/poses-2.png", "res://assets/actors/eight_direction/original_based/phoenix_monster_boss/poses-0.png", "res://assets/actors/eight_direction/original_based/phoenix_monster_boss/poses-1.png", "res://assets/actors/eight_direction/original_based/phoenix_monster_boss/poses-10.png", "res://assets/actors/eight_direction/original_based/phoenix_monster_boss/poses-11.png", "res://assets/actors/eight_direction/original_based/phoenix_monster_boss/poses-12.png", "res://assets/actors/eight_direction/original_based/phoenix_monster_boss/poses-2.png", "res://assets/actors/eight_direction/original_based/phoenix_monster_boss/poses-3.png", "res://assets/actors/eight_direction/original_based/phoenix_monster_boss/poses-4.png", "res://assets/actors/eight_direction/original_based/phoenix_monster_boss/poses-5.png", "res://assets/actors/eight_direction/original_based/phoenix_monster_boss/poses-6.png", "res://assets/actors/eight_direction/original_based/phoenix_monster_boss/poses-7.png", "res://assets/actors/eight_direction/original_based/phoenix_monster_boss/poses-8.png", "res://assets/actors/eight_direction/original_based/phoenix_monster_boss/poses-9.png", "res://assets/actors/eight_direction/original_based/saber_tiger/poses-0.png", "res://assets/actors/eight_direction/original_based/saber_tiger/poses-1.png", "res://assets/actors/eight_direction/original_based/sand_worm/poses-0.png", "res://assets/actors/eight_direction/original_based/sand_worm/poses-1.png", "res://assets/actors/eight_direction/original_based/scorpion/poses-0.png", "res://assets/actors/eight_direction/original_based/scorpion/poses-1.png", "res://assets/actors/eight_direction/original_based/snowman/poses-0.png", "res://assets/actors/eight_direction/original_based/snowman/poses-1.png", "res://assets/actors/eight_direction/original_based/werewolf/poses.png", "res://assets/actors/eight_direction/original_based/yeti/poses-0.png", "res://assets/actors/eight_direction/original_based/yeti/poses-1.png", "res://assets/actors/eight_direction/skeleton_guard/attack.png", "res://assets/actors/eight_direction/skeleton_guard/death.png", "res://assets/actors/eight_direction/skeleton_guard/hit.png", "res://assets/actors/eight_direction/skeleton_guard/idle.png", "res://assets/actors/eight_direction/skeleton_guard/walk.png", "res://assets/catalog/79716bba5363e8db6133b687.png", "res://assets/catalog/81b34d5f0b244c7dd86abbfb.png", "res://assets/inven_inventory/1184_91f575f3f8cda505.png", "res://assets/inven_inventory/226992_fb11c6150ac99b23.png", "res://assets/inven_inventory/227002_3c3aa767c335c101.png", "res://assets/inven_inventory/233_6abc322674a34eaa.png", "res://assets/inven_inventory/236_009ca30acfd450f8.png", "res://assets/inven_inventory/239_d7e9b75131ed1c7d.png", "res://assets/inven_inventory/271248_fba73950c6c8d5e9.png", "res://assets/inven_inventory/2731_39fcf6fa85c6c642.png", "res://assets/inven_inventory/313_2db096d043399f82.png", "res://assets/inven_inventory/385_2c2ebb6c0d935003.png", "res://assets/inven_inventory/389_2692de586c69c43a.png", "res://assets/inven_inventory/549_dd753c7036d2fc2a.png", "res://assets/inven_inventory/6401_23c27e1b57b7b4c0.png", "res://assets/inven_inventory/6411_d91d776271ac6f4d.png", "res://assets/inven_inventory/65291_e71d54ba129f5ad7.png", "res://assets/inven_inventory/75174_590246007d6d0d02.png", "res://assets/inven_inventory/7651_d3af7f547d0f6587.png", "res://assets/inven_inventory/855_8ed61c1af68d0b5d.png", "res://assets/maps/aden_giran_review_v1/props.png", "res://assets/maps/aden_giran_review_v1/terrain.png", "res://assets/maps/aden_world_visuals_v1/landmarks.png", "res://assets/maps/aden_world_visuals_v1/landmarks_ids.png", "res://assets/maps/aden_world_visuals_v1/nature.png", "res://assets/maps/aden_world_visuals_v1/nature_ids.png", "res://assets/maps/aden_world_visuals_v1/structures.png", "res://assets/maps/aden_world_visuals_v1/structures_ids.png", "res://assets/maps/aden_world_visuals_v1/terrain.png", "res://assets/maps/reference_expansion_v2/terrain.png", "res://assets/monsters/original/atlas_0.png", "res://assets/monsters/original/atlas_1.png", "res://assets/monsters/original/atlas_2.png", "res://assets/monsters/original/atlas_3.png", "res://assets/monsters/original/atlas_5.png", "res://assets/sprites/classes/archer.png", "res://assets/sprites/classes/assassin.png", "res://assets/sprites/classes/mage.png", "res://assets/sprites/classes/warrior.png", "res://assets/ui/attack.png", "res://assets/ui/bag.png", "res://assets/ui/leaf.png", "res://assets/ui/macro.png", "res://assets/ui/potionRed.png", "res://assets/ui/settings.png", "res://assets/ui/shop.png", "res://assets/ui/skill.png", "res://assets/ui/teleport.png", "res://data/aden_world_visuals/materials.png"]:
  var image := Image.load_from_file(path)
  assert(image != null and not image.is_empty(), path)
  var restored := ImageTexture.create_from_image(image)
  restored.take_over_path(path)
  textures.append(restored)
 # Rasterize the four actual skill SVG sources missing from the temporary cache.
 for path: String in ["res://assets/skills/icons/lm_09a971bf26507878.svg", "res://assets/skills/icons/lm_0f78dd70d9994d34.svg", "res://assets/skills/icons/lm_d44e85981c877135.svg", "res://assets/skills/icons/lm_ea8ce04ed942acae.svg"]:
  var svg_image := Image.new()
  assert(svg_image.load_svg_from_string(FileAccess.get_file_as_string(path)) == OK, path)
  var restored_svg := ImageTexture.create_from_image(svg_image)
  restored_svg.take_over_path(path)
  textures.append(restored_svg)
 var world: Node = load("res://Main.tscn").instantiate()
 world.process_mode = Node.PROCESS_MODE_DISABLED
 root.add_child(world)
 await process_frame
 world.save_timer = -10000.0
 var clips := 0
 var deaths := 0
 var fixtures := 0
 for key: String in keys:
  var record: Dictionary = register.actors[key]
  assert(not record.production_connected and not record.detailed_completed)
  for track: Dictionary in record.tracks:
   var path := "res://" + str(track.texture)
   var texture := ImageTexture.create_from_image(Image.load_from_file(path))
   texture.take_over_path(path)
   textures.append(texture)
  var source: Dictionary = {}
  for item: Dictionary in world.catalog_db.get("변신", []):
   if "transform:" + str(item.get("sourceId", "")) == key: source = item; break
  assert(not source.is_empty())
  var catalog_before := JSON.stringify(source)
  var native: Resource
  if record.has("native_profile"):
   native = load(record.native_profile)
  else:
   # No locomotion reference: test an injected frame fixture only. This does
   # not create a production profile or claim physical sizing validation.
   native = CATALOG.for_record("transform", source).duplicate(true)
   native.frames_path = record.frames
   native.layout = "directional8"
   native.animation_names.clear()
   fixtures += 1
  var candidate := source.duplicate(true)
  var settings: Dictionary = {}
  for property: String in ["frames_path", "layout", "motion_style", "movement_fps", "reference_speed", "pixel_scale", "native_width_ratio", "embedded_shadow", "authored_motion_weight", "hit_recoil", "death_duration", "body_kind", "floating", "attack_hit_frame", "action_hit_frames", "attack_animation_speed"]:
   settings[property] = native.get(property)
  settings.sprite_offset = [native.sprite_offset.x, native.sprite_offset.y]
  settings.color_tint = native.color_tint.to_html()
  if native.use_profile_hit_ratio: settings.attack_hit_ratio = native.attack_hit_ratio
  candidate.animation_profile = settings
  world.player.motion.dead = false
  world.player.motion.hit_clock = 0.0
  world.player.motion.cancel_attack()
  var before := _invariants(world)
  world._apply_transform_visual(candidate)
  assert(world.player.transform_active and world.player.motion.profile.profile_id == key)
  assert(world.player.motion.profile.frames_path == record.frames)
  var sprite: AnimatedSprite2D = world.player.transform_sprite
  for track: Dictionary in record.tracks:
   assert(sprite.sprite_frames.get_frame_count(track.animation) == 6)
   assert(sprite.sprite_frames.get_animation_loop(track.animation) == (track.role in ["idle", "run"]))
   if track.role == "death": continue
   var direction: int = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"].find(track.direction)
   var aim := Vector2.RIGHT.rotated(float(direction) * PI / 4.0)
   world.player.motion.advance(2.0, Vector2.ZERO)
   world.player.motion.face(aim)
   _tick(world.player, Vector2.ZERO)
   var velocity := Vector2.ZERO
   if track.role == "run": velocity = aim * native.reference_speed * 1.25
   elif track.role == "attack": world.player.start_combat_attack(world.player.global_position + aim, 0.9, native.motion_style)
   elif track.role == "hit": world.player.motion.react(false, Vector2.ZERO)
   var seen: Dictionary = {}
   var wraps := 0
   var previous := -1
   for tick: int in range(300):
    _tick(world.player, velocity)
    if str(sprite.animation) == track.animation:
     seen[sprite.frame] = true
     if previous > sprite.frame: wraps += 1
     previous = sprite.frame
   assert(seen.size() == 6, key + " " + track.animation + " missing phase")
   if track.role in ["idle", "run"]: assert(wraps >= 1)
   assert(_invariants(world) == before)
   clips += 1
  for track: Dictionary in record.tracks:
   if track.role != "death": continue
   for direction: int in range(8):
    world.player.motion.dead = false
    world.player.motion.face(Vector2.RIGHT.rotated(float(direction) * PI / 4.0))
    world.player.motion.die()
    var seen: Dictionary = {}
    for tick: int in range(int(ceil((native.death_duration + 0.2) * 120.0))):
     _tick(world.player, Vector2.ZERO)
     assert(str(sprite.animation) == track.animation)
     seen[sprite.frame] = true
    assert(seen.size() == 6 and sprite.frame == 5 and world.player.motion.state == "corpse")
    world.player.start_combat_attack(world.player.global_position + Vector2.RIGHT, 0.9, native.motion_style)
    for tick: int in range(240): _tick(world.player, Vector2.RIGHT * 300.0)
    assert(world.player.motion.dead and world.player.motion.state == "corpse" and sprite.frame == 5 and str(sprite.animation) == track.animation)
    deaths += 1
   clips += 1
  assert(_invariants(world) == before and JSON.stringify(source) == catalog_before)
  print("BATCH_CANDIDATE_ACTOR_PASS key=%s clips=%d final_approval=0" % [key, record.tracks.size()])
 print("PR122_BATCH_CANDIDATE_INTEGRATION_PASS actors=%d clips=%d death_directions=%d unsized_frame_fixtures=%d production_switches=0 approvals_added=0" % [keys.size(), clips, deaths, fixtures])
 world.queue_free()
 await process_frame
 quit(0)
