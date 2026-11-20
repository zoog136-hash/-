extends SceneTree
const VFX=preload("res://scripts/animation/combat_vfx.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
var checks: int=0
var failures: Array=[]
var pixel_comparisons: int=0
var samples: Array=[]
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("VFX_DRAW_FAIL ",label)
func _initialize() -> void:run.call_deferred()
func script(previous: bool) -> GDScript:
 var s: String=FileAccess.get_file_as_string("res://scripts/animation/combat_vfx.gd").replace("class_name TwilightCombatVFX","")
 if previous:
  s=s.replace("\tvar draw_inverse: Transform2D=get_global_transform().affine_inverse()\n","")
  s=s.replace("\t\tvar kind: String=str(entry.kind)\n\t\tif kind!=\"death\" and kind!=\"ring\":continue\n","")
  s=s.replace("\t\tmatch kind:","\t\tmatch str(entry.kind):")
  s=s.replace("draw_inverse * (entry.point as Vector2)","_test_local(entry.point)")
 else:
  s=s.replace("get_global_transform().affine_inverse()","_test_inverse()")
  s=s.replace("draw_inverse * (entry.point as Vector2)","_test_point(draw_inverse,entry.point)")
 s+="\nvar inverse_calls: int=0\nvar point_calls: int=0\nfunc _test_inverse() -> Transform2D:\n\tinverse_calls+=1\n\treturn get_global_transform().affine_inverse()\nfunc _test_point(inverse: Transform2D,point: Vector2) -> Vector2:\n\tpoint_calls+=1\n\treturn inverse*point\nfunc _test_local(point: Vector2) -> Vector2:\n\tinverse_calls+=1\n\tpoint_calls+=1\n\treturn to_local(point)\n"
 var out:=GDScript.new();out.source_code=s;check(out.reload()==OK,"oracle/instrumented renderer compiles");return out
func view(s: Script) -> Dictionary:
 var vp:=SubViewport.new();vp.size=Vector2i(320,240);vp.transparent_bg=true;vp.disable_3d=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 var host:=Node2D.new();vp.add_child(host)
 var fx: Node2D=s.new();host.add_child(fx);fx.set_process(false)
 return {"vp":vp,"host":host,"fx":fx}
func fill(fx: Node2D,count: int) -> void:
 fx.active.clear();fx.available.clear()
 for i: int in fx.CAPACITY:fx.available.append({})
 var image:=Image.create_empty(8,10,false,Image.FORMAT_RGBA8);image.fill(Color(.8,.3,.6,.8))
 var texture:=ImageTexture.create_from_image(image)
 for i: int in count:
  var point: Vector2=fx.to_global(Vector2(40+(i%8)*28,70+(i%4)*26))
  if i%4==0:fx.number(point,str(i+100),Color(0.3,0.9,0.5),i%2==0)
  elif i%4==1:fx.impact(point,Vector2.RIGHT.rotated(i*.4),"sword",i%2==0)
  elif i%4==2:fx.ring(point,12,Color(0.6,0.7,1))
  else:fx.death_pose(point,texture,Vector2(.8,1.2),Vector2(2,-4))
 fx.set_process(false)
func geometry() -> void:
 var host:=Node2D.new();root.add_child(host);var fx:=VFX.new();host.add_child(fx);fx.set_process(false)
 for rotation: float in [0.0,0.3,-0.8]:
  host.position=Vector2(50000,-17000);host.rotation=rotation;host.scale=Vector2(1.7,.8);fx.position=Vector2(7,13);fx.rotation=-.2
  var inverse: Transform2D=fx.get_global_transform().affine_inverse()
  for i: int in 160:
   var point:=Vector2(i*9,-i*7)
   check(fx.to_local(point).is_equal_approx(inverse*point),"world/local coordinates equivalent with parent transform")
 host.free()
func render(old: Script,current: Script) -> void:
 var a: Dictionary=view(old);var b: Dictionary=view(current)
 for pose: int in 3:
  for v: Dictionary in [a,b]:
   v.host.position=Vector2(0,0) if pose==0 else Vector2(24,18)
   v.host.rotation=0.0 if pose==0 else .2
   v.host.scale=Vector2.ONE if pose!=2 else Vector2(.8,1.15)
  for count: int in [1,40,160]:
   for v: Dictionary in [a,b]:fill(v.fx,count)
   for age: float in [.0,.1,.18]:
    for v: Dictionary in [a,b]:
     for entry: Dictionary in v.fx.active:entry.age=age
     v.fx.inverse_calls=0;v.fx.point_calls=0;v.fx.queue_redraw()
    await process_frame;await RenderingServer.frame_post_draw
    var ia: int=a.fx.inverse_calls;var ib: int=b.fx.inverse_calls
    check(ia>0 and ib==1,"one inverse per new draw versus one per old conversion")
    check(a.fx.detailed_draws==b.fx.detailed_draws and a.fx.impact_draws==b.fx.impact_draws,"existing impact budgets preserved")
    var image_a: Image=a.vp.get_texture().get_image();var image_b: Image=b.vp.get_texture().get_image()
    check(image_a.get_data()==image_b.get_data(),"full RGBA matches previous three-pass renderer")
    check(not image_b.is_invisible(),"comparison contains visible effect/text pixels")
    pixel_comparisons+=1
    if pose==0 and age==0.0:samples.append({"active":count,"old_inverses":ia,"new_inverses":ib,"old_points":a.fx.point_calls,"new_points":b.fx.point_calls})
 # Change parent transform between draw calls; no cross-frame transform cache.
 for v: Dictionary in [a,b]:v.host.position+=Vector2(20,-9);v.fx.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 check(a.vp.get_texture().get_image().get_data()==b.vp.get_texture().get_image().get_data(),"live parent motion remains equivalent");pixel_comparisons+=1
 check(HITCH._details.has("vfx.draw") and HITCH._sections.has("combat_vfx_draw"),"production draw emits CPU section and inclusive detail")
 a.vp.free();b.vp.free()
func lifecycle() -> void:
 var fx:=VFX.new();root.add_child(fx);fx.set_process(false)
 for i: int in 1500:
  fx.number(Vector2.ZERO,str(i),Color.WHITE)
  fx.impact(Vector2.ZERO,Vector2.RIGHT,"slash")
 check(fx.active.size()==160 and fx.high_water==160 and fx.get_child_count()==0,"bounded pool retains all existing allocation limits")
 fx._process(2.0)
 check(fx.active.is_empty() and fx.available.size()==160 and not fx.is_processing(),"expired pool returns records and disables idle processing")
 var frames:=SpriteFrames.new();frames.add_animation("death");frames.set_animation_speed("death",1.0)
 var image:=Image.create_empty(8,8,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
 var texture:=ImageTexture.create_from_image(image)
 for duration: float in [.2,.2,.25]:frames.add_frame("death",texture,duration)
 fx.death_pose(Vector2.ZERO,texture,Vector2.ONE,Vector2.ZERO,frames,"death")
 var entry: Dictionary=fx.active.back()
 check(is_equal_approx(float(entry.pose_duration),.65),"synthetic unequal source ticks retain their duration")
 for sample: Array in [[.14,0],[.14,1],[.17,2]]:
  fx._process(sample[0]);check(VFX._death_frame_at_age(entry)==sample[1],"death playback keeps phase at low render cadence")
 fx._process(.4)
 check(fx.active.is_empty() and fx.available.size()==160,"death expires without retaining texture owner")
 fx.free()
func run() -> void:
 HITCH.reset_for_test("user://vfx_draw_transform")
 var old: Script=script(true);var current: Script=script(false)
 geometry()
 lifecycle()
 if "--render" in OS.get_cmdline_user_args():await render(old,current)
 print("VFX_DRAW_TRANSFORM_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"pixel_comparisons":pixel_comparisons,"samples":samples,"android_measured":false}))
 quit(0 if failures.is_empty() else 1)
