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
