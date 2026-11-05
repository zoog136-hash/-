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
	var result: int=_mask_from_neighbourhood(c)
	masks[key]=result
	return result

## Reference definition of mask(): the bit set of can_step() for each heading.
## Kept for verification; mask() computes the same bits from one 3x3 read.
func mask_reference(c: Vector2i) -> int:
	if not contains(c):return 0
	var result: int=0
	for heading: int in range(8):
		if can_step(c,heading):result|=1<<heading
	return result

# Every cell edge()/can_step() reads for headings around c lies in c's 3x3
# neighbourhood, so read contains/tile/open-door state once per cell (index
# (dy+1)*3+(dx+1)) and evaluate the same rules locally.
func _mask_from_neighbourhood(c: Vector2i) -> int:
	var inside: Array[bool]=[]
	var tiles:=PackedInt32Array()
	var opened: Array[bool]=[]
	inside.resize(9);tiles.resize(9);opened.resize(9)
	for dy: int in range(-1,2):
		for dx: int in range(-1,2):
			var n: Vector2i=c+Vector2i(dx,dy)
			var i: int=(dy+1)*3+(dx+1)
			inside[i]=contains(n)
			opened[i]=open_doors.has(n)
			tiles[i]=((int(bytes[n.y*width+n.x])&124)|3 if opened[i] else int(bytes[n.y*width+n.x])) if inside[i] else 0
	var result: int=0
	for heading: int in range(8):
		var offset: Vector2i=DIRS[heading]
		if not _local_edge(inside,tiles,opened,Vector2i.ZERO,heading):continue
		if heading%2==0:
			result|=1<<heading
			continue
		var hx: int=2 if offset.x>0 else 6
		var hy: int=4 if offset.y>0 else 0
		if _local_edge(inside,tiles,opened,Vector2i.ZERO,hx) and _local_edge(inside,tiles,opened,Vector2i.ZERO,hy) and _local_edge(inside,tiles,opened,Vector2i(offset.x,0),hy) and _local_edge(inside,tiles,opened,Vector2i(0,offset.y),hx):
			result|=1<<heading
	return result

# edge(c+from, heading) evaluated on the 3x3 snapshot. Only calls whose cells
# stay inside the snapshot are made by _mask_from_neighbourhood().
func _local_edge(inside: Array[bool], tiles: PackedInt32Array, opened: Array[bool], from: Vector2i, heading: int) -> bool:
	var to: Vector2i=from+DIRS[heading]
	var ia: int=(from.y+1)*3+(from.x+1)
	var ib: int=(to.y+1)*3+(to.x+1)
	if not inside[ia] or not inside[ib]:return false
	var a: int=tiles[ia]
	var b: int=tiles[ib]
	if (b&128)!=0 or (b&3)==0:return false
	if heading%2==0 and (opened[ia] or opened[ib]) and (a&3)!=0:return true
	match heading:
		0:return (a&2)!=0
		1:return (tiles[(from.y)*3+(from.x+1)]&1)!=0 or (tiles[(from.y+1)*3+(from.x+2)]&2)!=0
		2:return (a&1)!=0
		3:return (tiles[(from.y+2)*3+(from.x+1)]&1)!=0
		4:return (b&2)!=0
		5:return (b&3)!=0
		6:return (b&1)!=0
		7:return (tiles[(from.y+1)*3+(from.x)]&2)!=0
	return false
