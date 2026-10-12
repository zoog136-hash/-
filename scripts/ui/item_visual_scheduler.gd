extends Node
## A single low-frequency visibility pass; animation itself runs on shared GPU time.
var clients: Array[WeakRef] = []
var elapsed: float = 0.0
var active_count: int = 0

func register(client: Node) -> void:
	for entry: WeakRef in clients:
		if entry.get_ref() == client: return
	clients.append(weakref(client))
	set_process(true)

func unregister(client: Node) -> void:
	for i: int in range(clients.size()-1,-1,-1):
		if clients[i].get_ref() == null or clients[i].get_ref() == client: clients.remove_at(i)
	set_process(not clients.is_empty())

static func visible_area(target: Control) -> bool:
	if not target.is_visible_in_tree() or target.size.x <= 0 or target.size.y <= 0: return false
	var visible_rect: Rect2 = target.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,target.size)
	visible_rect = visible_rect.intersection(target.get_viewport_rect())
	var parent: Node = target.get_parent()
	while parent != null and visible_rect.has_area():
		if parent is Control and parent.clip_contents:
			visible_rect = visible_rect.intersection(parent.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,parent.size))
		parent = parent.get_parent()
	return visible_rect.has_area()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.12: return
	elapsed = 0.0
	active_count = 0
	for i: int in range(clients.size()-1,-1,-1):
		var client: Node = clients[i].get_ref()
		if client == null:
			clients.remove_at(i)
			continue
		if client.refresh_visibility(): active_count += 1
	set_process(not clients.is_empty())
