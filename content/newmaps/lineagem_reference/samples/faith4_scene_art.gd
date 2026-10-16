extends Node2D
## TRUE GAMEPLAY WORLD OBJECTS — not an image backdrop, not NC-owned graphics.
## The geometry is consumed by the same prototype map's PlayableField.
const ROOT := "res://content/newmaps/lineagem_reference/samples/assets/faith04/"
const LAYOUT := "res://content/newmaps/lineagem_reference/samples/faith4_layout.json"

var layout: Dictionary = {}
var sprites_spawned: int = 0
var floor_surfaces: int = 0
var texture_cache: Dictionary = {}
var geometry_hash: String = ""

func configure() -> bool:
    if not FileAccess.file_exists(LAYOUT):
        push_error("PR121 Faith4 layout missing")
        return false
    var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
    if not (result is Dictionary) or str(result.get("id", "")) != "faith_04":
        push_error("PR121 Faith4 layout invalid")
        return false
    layout = result
    geometry_hash = FileAccess.get_sha256(LAYOUT)
    for key: String in ["floor_tile", "carpet_tile", "gothic_wall", "balustrade", "teal_pillar", "ritual_ring", "guardian_statue", "stone_altar", "candelabra", "rubble", "teal_glow"]:
        var path := ROOT + key + ".png"
        if not ResourceLoader.exists(path):
            push_error("Faith4 2D atlas missing: " + path)
            return false
        texture_cache[key] = load(path)
    var floor_layer := Node2D.new()
    floor_layer.name = "StoneTileSurfaces"
    floor_layer.z_index = -15
    add_child(floor_layer)
    for entry: Array in layout.floor_rects:
        _tile_rect(floor_layer, entry, texture_cache.floor_tile, 1.0)
    var carpet_layer := Node2D.new()
    carpet_layer.name = "CrimsonCarpets"
    carpet_layer.z_index = -14
    add_child(carpet_layer)
    for entry: Array in layout.carpets:
        _tile_rect(carpet_layer, entry, texture_cache.carpet_tile, 1.0)
        _trim_carpet(carpet_layer, entry)
    var chamber := Node2D.new()
    chamber.name = "InscribedRitualCircle"
    chamber.z_index = -13
    add_child(chamber)
    _sprite(chamber, "ritual_ring", layout.ring, "CircleMasonry")
    var props := Node2D.new()
    props.name = "YSortedArchitecture"
    props.y_sort_enabled = true
    props.z_index = 1
    add_child(props)
    for row: Dictionary in layout.walls:
        var width: float = float(row.width)
        _wall_or_rail(props, "gothic_wall", row.at, width, float(row.get("scale_h",1.0)))
    for row: Dictionary in layout.rails:
        _wall_or_rail(props, "balustrade", row.at, float(row.width), 1.0)
    for row: Array in layout.pillars:
        _glow(props, Vector2(float(row[0]),float(row[1])-210),float(row[2]))
        _sprite(props, "teal_pillar", row, "ArchitecturalPillar")
    for row: Array in layout.statues:
        _sprite(props, "guardian_statue", row, "GuardianStatue")
    for row: Array in layout.candles:
        _sprite(props, "candelabra", row, "WarmCandelabra")
    for row: Array in layout.rubble:
        _sprite(props, "rubble", row, "RubbleCluster")
    for row: Array in layout.altars:
        _sprite(props, "stone_altar", row, "StoneAltar")
    return floor_surfaces >= 14 and sprites_spawned >= 48

func _tile_rect(parent: Node2D, values: Array, tex: Texture2D, factor: float) -> void:
    var r: Rect2 = Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))
    var poly := Polygon2D.new()
    var corners := PackedVector2Array([r.position, Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
    poly.polygon = corners
    poly.uv = PackedVector2Array([corners[0]*factor,corners[1]*factor,corners[2]*factor,corners[3]*factor])
    poly.texture = tex
    poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    poly.name = "TileFloor_%d" % floor_surfaces
    parent.add_child(poly)
    floor_surfaces += 1

func _trim_carpet(parent: Node2D, values: Array) -> void:
    var box := Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))
    var d := Line2D.new()
    d.width = 6.0
    d.default_color = Color("a68450")
    d.points = PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y),box.position])
    parent.add_child(d)
    var d2 := Line2D.new()
    d2.width = 1.5
    d2.default_color = Color("deba76")
    d2.points = d.points
    d2.position = Vector2(8,5)
    parent.add_child(d2)

func _wall_or_rail(parent: Node2D, asset: String, origin: Array, width: float, scale_h: float) -> void:
    var tex: Texture2D = texture_cache[asset]
    var scale := Vector2(width/float(tex.get_width()),scale_h)
    var node := Node2D.new()
    node.name = "Built_" + asset
    node.position = Vector2(float(origin[0]),float(origin[1]))
    parent.add_child(node)
    var sprite := Sprite2D.new()
    sprite.texture = tex
    sprite.scale = scale
    sprite.position = Vector2(0,-float(tex.get_height())*scale.y*0.5)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    node.add_child(sprite)
    sprites_spawned += 1

func _sprite(parent: Node2D, asset: String, anchor: Array, name: String) -> void:
    var tex: Texture2D = texture_cache[asset]
    var amount: float = float(anchor[2]) if anchor.size()>2 else 1.0
    var node := Node2D.new()
    node.name = name
    node.position = Vector2(float(anchor[0]),float(anchor[1]))
    parent.add_child(node)
    var sprite := Sprite2D.new()
    sprite.texture = tex
    sprite.scale = Vector2.ONE*amount
    sprite.position.y = -float(tex.get_height())*amount*0.5
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    node.add_child(sprite)
    sprites_spawned += 1

func _glow(parent: Node2D, pos: Vector2, amount: float) -> void:
    var spot := Sprite2D.new()
    spot.name = "ColdTealLight"
    spot.position = pos
    spot.texture = texture_cache.teal_glow
    spot.scale = Vector2.ONE * maxf(.65, amount * 1.22)
    spot.modulate = Color(0.58,1.0,0.9,.63)
    spot.z_index = -1
    parent.add_child(spot)
