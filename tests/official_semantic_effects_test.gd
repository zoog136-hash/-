extends SceneTree
const CATALOG=preload("res://scripts/skills/skill_catalog.gd")
const BRIDGE=preload("res://scripts/skills/skill_similar_bridge.gd")
const LIBRARY=preload("res://scripts/skills/skill_vfx_library.gd")
const VFX=preload("res://scripts/skills/skill_vfx.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("SEMANTIC_EFFECT_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(500,300)
 var catalog=CATALOG.new();catalog.configure(null)
 var bridge=BRIDGE.new();var art=LIBRARY.new()
 var roster:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/official_roster.json"))
 var vfx=VFX.new();root.add_child(vfx)
 var reviewed:int=0;var enhanced:int=0;var loaded:int=0
 check(bridge.cache.is_empty() and art.entries.is_empty(),"registry construction never preloads atlases")
 for row:Dictionary in roster.references:
  if str(row.get("visual_matching_basis","")).is_empty():continue
  if row.has("visual_review_source"):reviewed+=1
  else:enhanced+=1
  var record:Dictionary=catalog.record_for(str(row.name))
  check(record.runtime_blocked and not catalog.enabled(record),"preview cannot grant skill implementation "+str(row.name))
  check(CATALOG.CURRENT.detail_text(record).contains("유사 효과 프리뷰"),"UI identifies substitute preview "+str(row.name))
  check(not art.profile_for(str(record.id)).is_empty(),"authored preview inheritance resolves "+str(row.name))
  var binding:Dictionary=bridge.binding_for(str(record.id))
  check(not binding.is_empty(),"similar SPR inheritance resolves without order dependence "+str(row.name))
  var phase:String="impact" if binding.get("phases",{}).has("impact") else "cast"
  var resource:String=str(binding.get("phases",{}).get(phase,""))
  var frames:SpriteFrames=bridge.frames_for(str(record.id),phase)
  check(frames!=null and frames.get_frame_count("source")>0,"actual texture decode "+str(row.name))
  if frames!=null:loaded+=1
  bridge.release(resource);bridge.trim()
  vfx.emit_skill(str(record.id),phase,Vector2(160,120))
  check(not vfx.live.is_empty(),"production VFX event "+str(row.name))
  if DisplayServer.get_name()!="headless":
   for item:Dictionary in vfx.live:
    var sprite:AnimatedSprite2D=item.get("spx_sprite") as AnimatedSprite2D
    if sprite!=null:sprite.frame=sprite.sprite_frames.get_frame_count(sprite.animation)/2
   await process_frame;await RenderingServer.frame_post_draw
   var image:Image=root.get_texture().get_image();var colors:Dictionary={}
   for y:int in range(image.get_height()):
    for x:int in range(image.get_width()):
     var pixel:Color=image.get_pixel(x,y)
     if maxf(pixel.r,maxf(pixel.g,pixel.b))-minf(pixel.r,minf(pixel.g,pixel.b))>0.08:colors[pixel.to_rgba32()]=true
   check(colors.size()>8,"production preview visible in actual GPU readback "+str(row.name))
  else:await process_frame
  vfx.clear()
 check(reviewed==28,"all explicitly reviewed description motifs")
 check(enhanced>0,"reviewed new base previews reach enhancement references")
 check(bridge.cache.is_empty(),"finished preview resources unpinned")
 vfx.queue_free();await process_frame
 if "--main-ui" in OS.get_cmdline_user_args():await main_ui(roster)
 print("OFFICIAL_SEMANTIC_EFFECTS_RESULT reviewed=",reviewed," enhancement=",enhanced," decoded=",loaded," checks=",checks," errors=",errors)
 quit(0 if errors==0 else 1)

func main_ui(roster:Dictionary):
 var world:TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
 check(preload("res://tests/qa_class_selection.gd").enter_game(world),"actual Main class confirmation")
 world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false);world.save_timer=-100000
 world._update_hud();world.hud.open_skills();await process_frame
 var view:Node=world.hud.skills_view;view.type_filter.select(3)
 var mp:int=world.mp;var hp:int=world.hp;var inventory:Dictionary=world.inventory.duplicate(true)
 var learned:Dictionary=world.original_skills.catalog.learned.duplicate(true)
 for row:Dictionary in roster.references:
  if str(row.get("visual_matching_basis","")).is_empty():continue
  view.search.text=str(row.name);view.refresh()
  var selected:int=-1
  for i:int in range(view.filtered.size()):
   if view.filtered[i].name==row.name:selected=i;break
  check(selected>=0,"actual skill UI search "+str(row.name))
  if selected<0:continue
  view.select(selected)
  check(view.use_button.disabled and view.learn_button.disabled and view.quick_button.disabled,"real UI keeps unimplemented skill blocked "+str(row.name))
  check(view.detail.text.contains("유사 효과 프리뷰"),"real UI labels substitute "+str(row.name))
  view.preview_button.pressed.emit();await process_frame
  check(view.preview_container.visible and not view.preview_vfx.live.is_empty(),"real preview button emits linked source "+str(row.name))
  view.preview_vfx.clear()
 check(world.mp==mp and world.hp==hp and world.inventory==inventory and world.original_skills.catalog.learned==learned,"preview UI cannot change combat/economy/ownership")
 world.queue_free();await process_frame;await process_frame
