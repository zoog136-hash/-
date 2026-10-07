# Playable region schema 2

Schema 1 Aden remains supported without rewriting its data.
All geometry uses the same world-space pixel coordinate system, feet at origin.
Schema 2 preserves the schema 1 collision, navigation, spawn and portal formats.

| Extension | Contract |
|---|---|
| `field_index.json` | Map ID, name, bounds, family and `res://` JSON path only. No props/textures/geometry are preloaded into menu records. |
| `family`, `short_name`, `floor` | Theme identity and region HUD/minimap labels. |
| `surfaces` | Authored floor rectangles (`rect`, `material`, optional `tint`). Walls are their exact grid-aligned complement plus authored internal blockers. |
| `render_style` | Ground palette/saturation/lift, wall/prop tint, accent. Defaults keep Aden unchanged. |
| `background.base_material` | Base atlas quadrant; 0 grass, 1 earth, 2 stone, 3 dark ground. |
| `collision.kind` | `dungeon_wall` and `fortress_wall` are directly rendered from collision geometry. Other props and water retain shared source footprints. |
| Native prop kinds | `crystal`, `obelisk`, `altar`, `torch`, `spore`, `arch`, `stairs`, `tomb`, `banner`, `rune`, `rubble`; drawn by `FieldLandmark` without per-prop process. |
| `monster_spawn.variants` | Optional DB-name keyed per-region level/name. Copy DB records before applying; preserve source art/drop keys. |
| `portal` | Previous/next/Aden return routes. Inter-map arrival uses the target's clear authored spawn or an explicitly authored `target_position`. |
| `review_points` | Authored entrance/central/boss camera positions for actual screenshot QA. |
| `route_checks` | Reachable room/hunting fixtures; tests reject wall/river shortcuts. |

Invariants: 47px conservative navigation clearance, visible solid walls, reachable
spawn/portals, entry not overlapping monster spawn, no stale target/path or old
collision world on transitions, independent gameplay services and active-map-only
geometry ownership. Camera and touch transformations stay in `world_coordinates.gd`.

Old coordinates migrate only when the saved map layout revision differs; progress
and equipment survive. Reusing an ID requires increasing revision when geometry
changes incompatibly. Do not bump Aden's revision when editing only other regions.
