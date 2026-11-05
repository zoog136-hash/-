extends SceneTree
## Manual source-coordinate inspection, never automatic gameplay portal activation.
const PACK=preload("res://scripts/maps/base508_pack.gd")
const SPACE=preload("res://scripts/maps/base508_contract.gd")
class Markers extends Node2D:
 var locations:Array=[]
 func _draw()->void:
  for entry:Array in locations:draw_circle(entry[0],6,entry[1])
var directory:String
var pack:RefCounted
var sprite:Sprite2D
var label:Label
var markers:Markers
var arrival:Vector2i=Vector2i(-1,-1)
var transitions:Array=[]
func _initialize()->void:
 directory=OS.get_environment("TWILIGHT_BASE508_UNIVERSE")
 call_deferred("run")
func show_map(land:int)->void:
 var asset:String="13146" if land==43942 else "13147"
 pack=PACK.new();assert(pack.load_pack(directory+"/assets/base508_asset_"+asset,land),pack.error)
 var image=Image.load_from_file(pack.root+"/"+pack.manifest.art.overview);assert(image!=null)
 sprite.texture=ImageTexture.create_from_image(image)
 var scale_factor:float=min(1248.0/image.get_width(),600.0/image.get_height());sprite.scale=Vector2.ONE*scale_factor;sprite.position=Vector2(640,410)
 var top_left:Vector2=sprite.position-Vector2(image.get_size())*scale_factor/2
 var ratio=Vector2(image.get_size())/Vector2(pack.manifest.art.size[0],pack.manifest.art.size[1])*scale_factor
 markers.locations=[]
 for portal:Dictionary in pack.portals:
  assert(int(portal.SourceLandID)==land)
  var point=Vector2i(int(portal.SourceX),int(portal.SourceY))
  assert(SPACE.supplied_cell(pack.manifest,point))
  markers.locations.append([top_left+SPACE.visual_cell_center(pack.manifest,Vector2(point))*ratio,Color.YELLOW])
 if arrival.x>=0:markers.locations.append([top_left+SPACE.visual_cell_center(pack.manifest,Vector2(arrival))*ratio,Color.MAGENTA])
 markers.queue_redraw()
 label.text="MANUAL PORTAL INSPECTION | Land "+str(land)+" / Asset "+asset+"\nENTER: inspect exact original destination | terrain UNKNOWN BLOCKED | no saves\nYellow: source portal | Magenta: original arrival "+str(arrival)+" | display cell center, actor foot unverified"
func inspect_destination()->void:
 assert(pack.portals.size()==1)
 var portal:Dictionary=pack.portals[0];var destination:Dictionary=pack.portal_destination(int(portal.ID))
 assert(int(destination.StartX)==int(destination.EndX) and int(destination.StartY)==int(destination.EndY),"Regions may not be replaced by a center")
 var source_land:int=int(pack.manifest.land.ID);var target_land:int=int(destination.LandID)
 assert(target_land in [43942,43952])
 arrival=Vector2i(int(destination.StartX),int(destination.StartY))
 show_map(target_land)
 assert(SPACE.supplied_cell(pack.manifest,arrival));assert(pack.raw_attribute(arrival.x*2,arrival.y)>=0);assert(not pack.can_enter(arrival))
 transitions.append({"portal_id":portal.ID,"source_land":source_land,"original_source":[portal.SourceX,portal.SourceY],"destination_land":target_land,"original_arrival":[arrival.x,arrival.y],"mode":"MANUAL_INSPECTION_ONLY","automatic_trigger_conditions":"UNKNOWN","movement":"UNKNOWN_BLOCKED"})
func capture(name:String)->void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(directory+"/"+name)==OK)
func run()->void:
 root.size=Vector2i(1280,720)
 sprite=Sprite2D.new();root.add_child(sprite);markers=Markers.new();root.add_child(markers);label=Label.new();label.position=Vector2(16,12);root.add_child(label)
 show_map(43942)
 if "--selftest" in OS.get_cmdline_user_args():
  await capture("portal-review-43942.png")
  inspect_destination();await capture("portal-review-43952.png")
  inspect_destination();await capture("portal-review-return-43942.png")
  var file=FileAccess.open(directory+"/portal-pair-review-evidence.json",FileAccess.WRITE);file.store_string(JSON.stringify({"manual_transitions":transitions,"automatic_runtime_portal_connections":0,"saves_accessed":false},"  "));file.close()
  print("BASE508_PORTAL_PAIR_MANUAL_REVIEW_OK ",JSON.stringify(transitions));quit();return
 while true:
  if Input.is_action_just_pressed("ui_accept"):inspect_destination()
  if Input.is_action_just_pressed("ui_cancel"):quit();return
  await process_frame
