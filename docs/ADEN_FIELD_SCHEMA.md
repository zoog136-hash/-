# Playable field schema 1

`data/maps/aden_field.json` is the authored definition. `tools/build_aden_field.py`
recreates it deterministically; editing the generator is preferred over editing generated output.
All positions are **global world pixels**, origin top left, +X right, +Y down.
Actor/object origins are their feet. No image-space coordinates participate in gameplay.

| Key | Format / use |
|---|---|
| `map_id`, `map_name`, `layout_revision` | Existing stable map ID, display name, saved-coordinate compatibility |
| `bounds` | `[x,y,width,height]`; current field origin is `[0,0]` |
| `spawn_position` | `[world_x,world_y]` |
| `navigation` | `cell_size`, `agent_radius`, conservative `clearance`, corner cutting disabled |
| `background`, `foreground` | Shared material/prop atlas resource paths, fade alpha |
| `roads` | ID, width, material index, ordered world-space points |
| `water` | World-space polygons; exact same polygons appear in collision |
| `bridges` | Walkable deck rectangles with physical rail edges |
| `props` | Kind, foot position, scale, horizontal flip; only visible chunks instantiate sprites |
| `collision` | Circles (`center`, `radius`), rectangles (`rect`), polygons (`points`) and semantic kind |
| `regions` | ID, name, center, radius, safe/combat/boss type and minimap color |
| `safe_zone`, `combat_zone`, `boss_zone` | Region ID lists |
| `monster_spawn` | Region ID/rectangle, monster DB names, level range, max count, density per million px², respawn seconds, roaming radius |
| `npc_spawn` | ID, name, position and shop/guide role |
| `portal` | ID, name, position, activation radius, target map, optional target position |
| `teleport` | Named intra-map waystone entries drawn from portals |
| `minimap` | Display capabilities; geometry/markers derive from the same map data |
| `streaming` | Prop chunk size, prefetch margin, monster AI sleep distance |

Ground detail, roads, water and bridges are separate render groups beneath `FieldRenderer/Terrain`.
Buildings, walls, cliffs and props are typed data; their sprites sort with actors by their feet.
Foreground occlusion is an actor-relative alpha transition on large props, independent of collision.
`FieldCollision` is a separate `StaticBody2D` on layer 4. The existing legacy physics masks are restored
on legacy maps. Actor-actor blocking is disabled on this field so a crowd cannot permanently stop auto-hunt.

`PlayableField` derives an AStar grid from expanded collision geometry. Its 47px expansion is conservative
for a 24px actor and a 32px grid (24 + half-cell diagonal ≈ 46.6). The flood fill from spawn excludes islands.
Paths remove only collinear points; diagonal corners remain blocked. Failed routes never fall back to
straight-line pursuit. This deliberately uses the project's existing AStarGrid2D pipeline rather than
maintaining an unrelated NavigationServer mesh with a different coordinate system.

New layouts must preserve clear corridors, reachable region spawn cells, explicit return routes, and
rerun `tests/field_world_test.gd` with region-specific route fixtures. Raising `layout_revision` migrates
old coordinates to the authored spawn while preserving progression and equipment.
