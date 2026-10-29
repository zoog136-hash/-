extends RefCounted
## L1J 3.80c L1V1Map directional byte rules. A byte is never a Boolean floor mask.
## No doors or runtime occupants are manufactured from image colors.
const DIRS: Array[Vector2i] = [Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1)]
var source_id: int = -1
var origin := Vector2i.ZERO
var width: int = 0
var height: int = 0
var bytes: PackedByteArray

func configure(id: int, bounds: Array, size: Vector2i, raw: PackedByteArray) -> bool:
	if bounds.size()!=4 or size.x<1 or size.y<1 or size.x*size.y!=raw.size(): return false
	if int(bounds[2])-int(bounds[0])+1!=size.x or int(bounds[3])-int(bounds[1])+1!=size.y: return false
	source_id=id;origin=Vector2i(bounds[0],bounds[1]);width=size.x;height=size.y;bytes=raw
	return true

func contains(c: Vector2i) -> bool:
	if c.x<0 or c.y<0 or c.x>=width or c.y>=height:return false
	var p: Vector2i=c+origin
	if source_id==4 and (p.x<32520 or p.y<32070 or (p.y<32190 and p.x<33950)):return false
	return true

func tile(c: Vector2i) -> int:
	return int(bytes[c.y*width+c.x]) if contains(c) else 0

func edge(c: Vector2i, heading: int) -> bool:
	if heading<0 or heading>=8 or not contains(c) or not contains(c+DIRS[heading]):return false
	var a: int=tile(c)
	var b: int=tile(c+DIRS[heading])
	if (b&128)!=0 or (b&3)==0:return false
	match heading:
		0:return (a&2)!=0
		1:return (tile(c+Vector2i(0,-1))&1)!=0 or (tile(c+Vector2i(1,0))&2)!=0
		2:return (a&1)!=0
		3:return (tile(c+Vector2i(0,1))&1)!=0
		4:return (b&2)!=0
		5:return (b&3)!=0
		6:return (b&1)!=0
		7:return (tile(c+Vector2i(-1,0))&2)!=0
	return false

func can_step(c: Vector2i, heading: int) -> bool:
	if not edge(c,heading):return false
	if heading%2==0:return true
	var offset: Vector2i=DIRS[heading]
	var hx: int=2 if offset.x>0 else 6
	var hy: int=4 if offset.y>0 else 0
	return edge(c,hx) and edge(c,hy) and edge(c+Vector2i(offset.x,0),hy) and edge(c+Vector2i(0,offset.y),hx)

func mask(c: Vector2i) -> int:
	var result: int=0
	for heading: int in range(8):
		if can_step(c,heading):result|=1<<heading
	return result
