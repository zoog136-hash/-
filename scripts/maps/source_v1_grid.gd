extends RefCounted
## L1J 3.80c L1V1Map directional byte rules. A byte is never a Boolean floor mask.
## No doors or runtime occupants are manufactured from image colors.
const DIRS: Array[Vector2i] = [Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1)]
var source_id: int = -1
var origin := Vector2i.ZERO
var width: int = 0
var height: int = 0
var bytes: PackedByteArray
var artwork_chunks: Dictionary={}
var require_artwork: bool=false
var masks: Dictionary={}
var closed_doors: Dictionary={}
var open_doors: Dictionary={}
var clipped_cells: Dictionary={}

func configure(id: int, bounds: Array, size: Vector2i, raw: PackedByteArray) -> bool:
	if bounds.size()!=4 or size.x<1 or size.y<1 or size.x*size.y!=raw.size(): return false
	if int(bounds[2])-int(bounds[0])+1!=size.x or int(bounds[3])-int(bounds[1])+1!=size.y: return false
	source_id=id;origin=Vector2i(bounds[0],bounds[1]);width=size.x;height=size.y;bytes=raw
	artwork_chunks.clear();require_artwork=false
	masks.clear()
	return true

func restrict_to_artwork(rows: Array) -> bool:
	artwork_chunks.clear()
	masks.clear()
	for row: Dictionary in rows:
		var b: Array=row.world_bounds
		var offset:=Vector2i(b[0],b[1])-origin
		if offset.x%64!=0 or offset.y%64!=0 or int(b[2])-int(b[0])!=63 or int(b[3])-int(b[1])!=63:return false
		artwork_chunks[Vector2i(offset.x/64,offset.y/64)]=true
	require_artwork=true
	return not artwork_chunks.is_empty()

func contains(c: Vector2i) -> bool:
	if c.x<0 or c.y<0 or c.x>=width or c.y>=height:return false
	if closed_doors.has(c) or clipped_cells.has(c):return false
	# Some server rectangles have open padding outside every retained client
	# chunk. Keep the bytes, but never walk into terrain that was not supplied.
	if require_artwork and not artwork_chunks.has(Vector2i(c.x>>6,c.y>>6)):return false
	var p: Vector2i=c+origin
	if source_id==4 and (p.x<32520 or p.y<32070 or (p.y<32190 and p.x<33950)):return false
	return true

func tile(c: Vector2i) -> int:
	if not contains(c):return 0
	return (int(bytes[c.y*width+c.x])&124)|3 if open_doors.has(c) else int(bytes[c.y*width+c.x])

func edge(c: Vector2i, heading: int) -> bool:
	if heading<0 or heading>=8 or not contains(c) or not contains(c+DIRS[heading]):return false
	var a: int=tile(c)
	var b: int=tile(c+DIRS[heading])
	if (b&128)!=0 or (b&3)==0:return false
	if heading%2==0 and (open_doors.has(c) or open_doors.has(c+DIRS[heading])) and (a&3)!=0:return true
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
	if not contains(c):return 0
	var key: int=c.y*width+c.x
	if masks.has(key):return int(masks[key])
	var result: int=0
	for heading: int in range(8):
		if can_step(c,heading):result|=1<<heading
	masks[key]=result
	return result
