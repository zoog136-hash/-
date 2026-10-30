extends RefCounted
## Exact physical sample results for one immutable field's route graph.
## FIFO bounds memory while keeping reverse/neighbor-edge samples available.
## Eviction only repeats a physical check; it never changes its result.
const LIMIT: int=4096
var checks: Dictionary={}
var order:=PackedVector2Array()
var cursor: int=0

func lookup(point: Vector2) -> int:
	return int(checks.get(point,-1))

func store(point: Vector2, is_clear: bool) -> void:
	if checks.has(point):
		checks[point]=int(is_clear)
		return
	if order.size()<LIMIT:
		order.append(point)
	else:
		checks.erase(order[cursor])
		order[cursor]=point
		cursor=(cursor+1)%LIMIT
	checks[point]=int(is_clear)

func size() -> int:
	return checks.size()

func clear() -> void:
	checks.clear()
	order=PackedVector2Array()
	cursor=0
