extends Node2D
## Shared current523 loading art. Callers own status text and control input.
const PACK := preload("res://scripts/ui/original_ui/source_pack.gd")
const NAMED_TREE := preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const FX_LOADING := PACK.LOADING_FX_MEMBER
const FX_CLIP := "Fx_Loop"
const FX_DESIGN := Vector2(1600, 675)
var _design := FX_DESIGN

func mount(host: Control, pack: RefCounted) -> Dictionary:
	if pack == null or not pack.manifest.get("scenes", {}).has(FX_LOADING):
		return {"ok": false, "reason": "fx_loading_missing_in_pack"}
	var built := _build_world(pack)
	if not built.get("ok", false):
		built = NAMED_TREE.new(pack).scene_of(FX_LOADING, {"Text": {"visible": false}, "Text_Sub": {"visible": false}}, {})
	if not built.get("ok", false): return built
	var scene: Node2D = built.scene
	var player: Node2D = built.get("player", scene)
	var played: Dictionary = player.play(FX_CLIP, true)
	_design = built.get("design", FX_DESIGN)
	name = "OriginalFxLoading"
	add_child(scene)
	host.add_child(self)
	# Above the backdrop, below the transition's status labels.
	host.move_child(self, 1)
	_fit(host)
	host.resized.connect(_fit.bind(host))
	return {"ok": true, "member": FX_LOADING, "world_layout": built.get("world_layout", ""), "clip": FX_CLIP, "playing": played.get("ok", false)}

func _build_world(pack: RefCounted) -> Dictionary:
	var member: String = PACK.WORLD_LOADING_MEMBER
	var layout: Dictionary = pack.scene(member)
	if layout.get("_source_sha256") != PACK.WORLD_LOADING_SHA or pack.scene(PACK.WORLD_LOADING_LAYOUT).get("_source_sha256") != PACK.WORLD_LOADING_LAYOUT_SHA:
		return {}
	var design := Vector2(1200, 675) # LoadingScene's authored size, with anchor (0, 0).
	var nodes := {}
	# Original backgrounds and their placement come from the source CSB.
	# The game's existing status and measured progress replace the default notices.
	var result: Dictionary = NAMED_TREE.new(pack).scene_of(member, {
		"LoadSceneLayout/Deco": {"visible": false},
		"Fx_Loading_Layout/Bg": {"visible": false},
		"Text": {"visible": false},
		"Text_Sub": {"visible": false},
	}, nodes)
	if not result.get("ok", false):
		return {}
	var scene: Node2D = result.scene
	var matches: Array[String] = NAMED_TREE.matches(nodes, "Fx_Loading_Layout")
	if matches.size() == 1:
		var child: Dictionary = scene.project_player([int(nodes[matches[0]].offset)])
		if child.get("ok", false) and child.get("source") == FX_LOADING:
			scene.position = Vector2(-0.5, 0.5) * design
			return {"ok": true, "scene": scene, "player": child.player, "design": design, "world_layout": member}
	scene.free()
	return {}

func _fit(host: Control) -> void:
	var area: Vector2 = host.size if host.size.x > 0 and host.size.y > 0 else host.get_viewport_rect().size
	var fit: float = minf(area.x / _design.x, area.y / _design.y)
	scale = Vector2.ONE * fit
	position = area * 0.5
