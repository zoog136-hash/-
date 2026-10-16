extends "res://scripts/maps/authored_remake_renderer.gd"
## Faith 4F-only opt-in. Existing TWILIGHT code / 23 other playable maps unchanged.
## Architectural sprites and carpet tile geometry are separate from navigation/physics.
var curated: Node2D

func configure(value: PlayableField, actor: Node2D) -> void:
    super.configure(value,actor)
    if str(value.data.map_id) != "faith_04": return
    curated = preload("res://content/newmaps/lineagem_reference/samples/faith4_scene_art.gd").new()
    curated.name = "Faith4ArchitecturalEnvironment"
    add_child(curated)
    if not curated.configure():
        push_error("Faith4 architecture failed to build. Fail instead of recolored fallback.")

func refresh_visible() -> void:
    super.refresh_visible()
