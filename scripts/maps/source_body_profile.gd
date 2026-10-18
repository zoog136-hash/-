extends RefCounted
## Runtime-only collision footprint; never edits shared actor resources/animation.
const FOOT_RADIUS: float = 4.0
static func apply(actor: Node2D, remake: bool) -> void:
	var node := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if node == null: return
	if remake:
		if not node.has_meta("previous_source_shape"):
			node.set_meta("previous_source_shape",node.shape)
			node.set_meta("previous_source_position",node.position)
		var foot := CircleShape2D.new()
		foot.radius = FOOT_RADIUS
		node.shape = foot
		node.position = Vector2.ZERO
	elif node.has_meta("previous_source_shape"):
		node.shape = node.get_meta("previous_source_shape")
		node.position = node.get_meta("previous_source_position")
		node.remove_meta("previous_source_shape")
		node.remove_meta("previous_source_position")
