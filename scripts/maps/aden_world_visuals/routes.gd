extends RefCounted
## Hierarchical index of exact source edges. Local paths use the shared navigator.
const ROOT := "res://data/aden_world_visuals/routes/"
var labels: PackedByteArray
var graph: Array = []
var ready: bool = false
var last_metrics: Dictionary = {}

func configure(field: OriginalPlayableField) -> bool:
	if str(field.data.map_id)!="aden_world": return false
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	if not value is Dictionary or value.get("dimensions") != [2048.0,1536.0]: return false
	if FileAccess.get_sha256("res://data/map_remake/private/aden/definitions/aden_world.json") != str(value.source_definition_sha256): return false
	var blob: PackedByteArray = FileAccess.get_file_as_bytes(ROOT+"components.bin")
	if _sha(blob)!=str(value.compressed_sha256) or FileAccess.get_sha256(ROOT+"graph.json")!=str(value.graph_sha256): return false
	labels = blob.decompress(int(value.component_bytes),FileAccess.COMPRESSION_DEFLATE)
	if labels.size()!=2048*1536*4 or _sha(labels)!=str(value.raw_sha256):labels.clear();return false
	var rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"graph.json"))
	if not rows is Array or rows.size()!=int(value.components)+1:labels.clear();return false
	graph=rows;ready=true;return true

func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
	return hash.finish().hex_encode()

func component(cell: Vector2i) -> int:
	if cell.x<0 or cell.y<0 or cell.x>=2048 or cell.y>=1536 or labels.is_empty():return 0
	return labels.decode_u32((cell.y*2048+cell.x)*4)

func cells(field: OriginalPlayableField, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not ready:return empty
	var began: int = Time.get_ticks_usec()
	var first: int = component(start);var last: int = component(goal)
	if first==0 or last==0:return empty
	var queue := PackedInt32Array([first]);var at: int = 0
	var previous: Dictionary = {first:[first,0,0]}
	while at<queue.size() and not previous.has(last):
		var node: int = queue[at];at+=1
		for edge: Array in graph[node]:
			var next: int = int(edge[0])
			if previous.has(next):continue
			previous[next]=[node,int(edge[1]),int(edge[2])];queue.append(next)
	if not previous.has(last):last_metrics={"status":"NO_SOURCE_ROUTE","visited_components":at};return empty
	var links: Array = [];var node: int = last
	while node!=first:
		var record: Array = previous[node];links.append(record);node=int(record[0])
	links.reverse()
	var navigator := LocalNavigator.new();navigator.field=field;navigator.routes=self
	navigator.loaded=true;navigator.coordinates.configure(Vector2i(field.width,field.height),Vector2i.ZERO,Transform2D.IDENTITY)
	var result: Array[Vector2i] = [];var current: Vector2i = start
	for link: Array in links:
		var enter := Vector2i(int(link[1])%2048,int(link[1])/2048)
		var leave := Vector2i(int(link[2])%2048,int(link[2])/2048)
		navigator.allowed=component(current)
		var part: Array[Vector2i] = navigator.find_path(current,enter,2048)
		if part.is_empty() or not field.can_step(enter,field.DIRECTIONS.find(leave-enter)):return empty
		if not result.is_empty():part.pop_front()
		result.append_array(part);result.append(leave);current=leave
	navigator.allowed=component(current)
	var part: Array[Vector2i] = navigator.find_path(current,goal,2048)
	if part.is_empty():return empty
	if not result.is_empty():part.pop_front()
	result.append_array(part)
	last_metrics={"status":"PASS","visited_components":at,"component_links":links.size(),"cells":result.size(),"usec":Time.get_ticks_usec()-began}
	return result

class LocalNavigator extends TwilightL1JSourceNavigation:
	var field: OriginalPlayableField
	var routes: RefCounted
	var allowed: int
	func can_step(cell: Vector2i, heading: int) -> bool:
		return routes.component(cell)==allowed and routes.component(cell+DIRECTIONS[heading])==allowed and field.can_step(cell,heading)
