extends SceneTree
## Real source DDA/can_step/door rules with an explicit in-memory tile fixture.
## No texture, terrain file, movement speed or collision implementation changes.
class MemoryField extends "res://scripts/maps/source_field.gd":
 var masks:Dictionary={}
 var closed:Dictionary={}
 var traversed:Array=[]
 func value_at(cell:Vector2i,_mask:bool=false)->int:
  if not in_bounds(cell) or closed.has(cell):return 0
  return int(masks.get(cell,255))
 func _line_can_step(cell:Vector2i,heading:int)->bool:
  traversed.append([cell,heading])
  return super._line_can_step(cell,heading)

var errors:Array=[]
var checks=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:errors.append(message);printerr("SOURCE_ENDPOINT_FAIL ",message)
func field()->MemoryField:
 var f=MemoryField.new();f.width=16;f.height=16
 check(f.coordinates.configure([0,0],[16,16],{"basis_x":[1,0],"basis_y":[0,1],"translation":[0,0]}),"Valid independent grid fixture")
 f.source_doors.configure([],Vector2i.ZERO)
 return f
func clear_case(f:MemoryField,a:Vector2,b:Vector2,expected:bool,label:String)->void:
 f.traversed=[]
 check(f.line_clear(a,b)==expected,label)
 var start=f.coordinates.world_to_cell(a);var target=f.coordinates.world_to_cell(b)
 for edge:Array in f.traversed:
  var origin:Vector2i=edge[0];var heading:int=edge[1]
  check(heading>=0 and heading<8,label+" valid existing heading")
  if heading<0 or heading>=8:continue
  var destination:Vector2i=origin+f.DIRECTIONS[heading]
  check(destination.x>=mini(start.x,target.x) and destination.x<=maxi(start.x,target.x) and destination.y>=mini(start.y,target.y) and destination.y<=maxi(start.y,target.y),label+" never steps beyond either target axis")
  var before=absi(target.x-origin.x)+absi(target.y-origin.y)
  var after=absi(target.x-destination.x)+absi(target.y-destination.y)
  check(after<before,label+" source-cell progress is monotonic")
func _initialize()->void:call_deferred("run")
func run()->void:
 var f=field()
 # Ordinary, reverse, cardinal, same-cell, and both signs of exact corner endpoints.
 for pair in [[Vector2(2.5,2.5),Vector2(7.5,5.5)],[Vector2(7.5,5.5),Vector2(2.5,2.5)],[Vector2(2.5,2.5),Vector2(8,2.5)],[Vector2(8,2.5),Vector2(2.5,2.5)],[Vector2(2.5,2.5),Vector2(2.5,8)],[Vector2(2.5,8),Vector2(2.5,2.5)],[Vector2(3.25,4.75),Vector2(3,5)],[Vector2(3,5),Vector2(3.25,4.75)],[Vector2(3.75,4.25),Vector2(4,4)],[Vector2(4,4),Vector2(3.75,4.25)],[Vector2(2.5,2.5),Vector2(4,4)],[Vector2(4,4),Vector2(2.5,2.5)],[Vector2(2.5,2.5),Vector2(2.999,3)],[Vector2(2.5,2.5),Vector2(3,2.999)],[Vector2(3.2,3.2),Vector2(3.8,3.8)],[Vector2(3,3),Vector2(3,3)]]:
  clear_case(f,pair[0],pair[1],true,"Open/endpoint "+str(pair))
 # Exact endpoints still require their real entering edge. No t>=1 bypass.
 f.masks[Vector2i(3,4)]=255&~(1<<4)
 clear_case(f,Vector2(3.25,4.75),Vector2(3,5),false,"Blocked exact endpoint entering edge")
 f.masks.clear()
 # Preserve directed source masks: forward permission does not imply reverse.
 f.masks[Vector2i(4,4)]=255&~(1<<6)
 clear_case(f,Vector2(3.5,4.5),Vector2(4.5,4.5),true,"Directed east edge allowed")
 clear_case(f,Vector2(4.5,4.5),Vector2(3.5,4.5),false,"Directed reverse west edge blocked")
 f.masks.clear()
 # Interior diagonal crossings keep the same can_step heading/mask checks.
 f.masks[Vector2i(2,2)]=255&~(1<<3)
 clear_case(f,Vector2(2.5,2.5),Vector2(4.5,4.5),false,"Blocked interior corner diagonal")
 f.masks.clear();f.closed[Vector2i(4,4)]=true
 clear_case(f,Vector2(2.5,2.5),Vector2(4,4),false,"Forbidden endpoint cell")
 f.closed.clear();f.closed[Vector2i(3,3)]=true
 clear_case(f,Vector2(2.5,2.5),Vector2(4.5,4.5),false,"Forbidden intermediate cell")
 f.closed.clear();f.masks[Vector2i(3,4)]=255&~(1<<2)
 clear_case(f,Vector2(2.5,4.5),Vector2(6.5,4.5),false,"Ordinary blocked source edge")
 f.masks.clear()
 # Actual door blocking also applies at the corrected endpoint and in reverse.
 f.source_doors.flags[Vector2i(3,5)]=64
 clear_case(f,Vector2(3.25,4.75),Vector2(3,5),false,"Door blocks exact entering edge")
 clear_case(f,Vector2(3,5),Vector2(3.25,4.75),false,"Same door blocks reverse edge")
 f.source_doors.flags.clear()
 check(not f.line_clear(Vector2.INF,Vector2.ZERO),"Nonfinite source coordinates remain rejected")
 clear_case(f,Vector2(2.5,2.5),Vector2(16,2.5),false,"Out-of-bounds destination remains rejected")
 # Both world-S/N one-pixel steps end at a source corner, as in Osiris.
 check(f.coordinates.configure([0,0],[16,16],{"basis_x":[24,-12],"basis_y":[24,12],"translation":[41208,-2280]}),"Real 48x24 isometric basis")
 for pair in [[Vector2(41448,-2269),Vector2(41448,-2268)],[Vector2(41448,-2291),Vector2(41448,-2292)]]:
  clear_case(f,pair[0],pair[1],true,"Osiris world one-pixel exact endpoint")
  clear_case(f,pair[1],pair[0],true,"Osiris reverse world one-pixel endpoint")
 print("SOURCE_ENDPOINT_RESULT checks=",checks," errors=",errors.size())
 quit(0 if errors.is_empty() else 1)
