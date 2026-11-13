extends RefCounted
const FRAME_HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
## Pure partial-source projection. Every retained node is an unchanged original
## record except its filtered children array. Ancestors are retained, never
## their unselected siblings/descendants. No resources or nodes are invented.

static func select(tree: Dictionary, offsets: Array[int]) -> Dictionary:
	var started: int=FRAME_HITCH.now()
	var result: Dictionary=_select(tree,offsets)
	FRAME_HITCH.detail("ui.scene_scope",started)
	return result

static func _select(tree: Dictionary, offsets: Array[int]) -> Dictionary:
	if offsets.is_empty():return _fail("source_node_scope_selection_empty")
	var requested: Dictionary={}
	for offset: int in offsets:
		if requested.has(offset):return {"ok":false,"code":"source_node_scope_duplicate_request","offset":offset}
		requested[offset]=true
	if not tree.get("nodeTree") is Dictionary:return _fail("source_node_scope_tree_missing")
	var counts: Dictionary={}
	_count(tree.nodeTree,counts)
	for offset: int in offsets:
		if not counts.has(offset):return {"ok":false,"code":"source_node_scope_node_missing","offset":offset}
		if counts[offset]!=1:return {"ok":false,"code":"source_node_scope_node_ambiguous","offset":offset}
	var retained: Array[int]=[]
	var action_tags: Dictionary={}
	var node: Dictionary=_prune(tree.nodeTree,requested,retained,action_tags)
	if node.is_empty():return _fail("source_node_scope_no_retained_root")
	# The pruned node already owns detached children. Do not first deep-copy
	# the complete node tree only to replace it with that projection.
	var scoped: Dictionary=tree.duplicate(false)
	scoped.nodeTree={}
	if scoped.get("action") is Dictionary and scoped.action.get("timeLines") is Array:
		# Project before detaching: excluded timelines can contain thousands of
		# frames that this instance never validates, animates or renders. Keep
		# the action's field order and metadata, then deep-copy retained data.
		var action: Dictionary=scoped.action.duplicate(false)
		var tracks: Array=[]
		for track: Dictionary in action.timeLines:
			if action_tags.has(int(track.get("actionTag",0))):tracks.append(track)
		action.timeLines=tracks
		scoped.action=action
	scoped=scoped.duplicate(true)
	scoped.nodeTree=node
	scoped["_selected_source_offsets"]=offsets.duplicate()
	scoped["_partial_source_scene"]=true
	# Durations, speed, animationList/clips, frames and retained track values
	# remain exactly serialized; no synthesized state or animation timing.
	return {"ok":true,"tree":scoped,"source_node_offsets":offsets.duplicate(),"selected_source_offsets":offsets.duplicate(),"retained_source_offsets":retained,"retained_action_tags":action_tags.keys(),"partial_source_scene":true,"complete_screen_contract":false}

static func _count(node: Dictionary, counts: Dictionary) -> void:
	if node.has("_offset"):
		var offset: int=int(node._offset)
		counts[offset]=int(counts.get(offset,0))+1
	for child: Dictionary in node.get("children",[]):_count(child,counts)

static func _prune(node: Dictionary, requested: Dictionary, retained: Array[int], action_tags: Dictionary) -> Dictionary:
	var children: Array=[]
	# Postorder determines inclusion; child arrays keep serialized order.
	for child: Dictionary in node.get("children",[]):
		var kept: Dictionary=_prune(child,requested,retained,action_tags)
		if not kept.is_empty():children.append(kept)
	if not requested.has(int(node.get("_offset",-1))) and children.is_empty():return {}
	# Detach this node's metadata without copying descendants that were either
	# discarded or independently copied above. Keep the children key in place
	# so the projected Dictionary retains the original field order as well.
	var result: Dictionary=node.duplicate(false)
	result.children=[]
	result=result.duplicate(true)
	result.children=children
	var offset: int=int(node._offset)
	retained.append(offset)
	var options: Dictionary=node.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	if widget.has("actionTag"):action_tags[int(widget.actionTag)]=true
	return result

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
