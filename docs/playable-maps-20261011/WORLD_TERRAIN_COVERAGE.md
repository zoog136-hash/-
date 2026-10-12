# Whole-map terrain phase 1 (2026-10-11)

Scope: all 25 TWILIGHT map IDs, independent of A3 source maps and any unverified original-art restoration.

The previous renderer built a large ground rectangle, road Line2D strips, rectangular dungeon rooms, and randomly placed ground-cover props. New visual-only geometry builds two triangulated biome meshes over each map's full Rect2 bounds. Shared world-coordinate noise yields seam-free material transitions across virtual 512-unit cells, persistent through prop chunk streaming. The already committed authored terrain atlas is reused. Families vary between vegetation/earth (Aden), stone (Oman/Domination/Faith), ruins (Escaros) and mineral/wet ground (Albino).

Collision, navigation, portals, map JSON, NPC and monster coordinates, all props, and the separate A3 runtime are unchanged. No original third-party graphics added.

This is a first full-coverage terrain foundation, not completed high-quality terrain. Road ribbons, dungeon floors, river and terrain topology still need map-wide reconstruction and direct visual QA.

CI: tests/world_terrain_coverage_test.gd + .github/workflows/pr84-world-terrain.yml. The workflow must actually complete successfully before claiming Godot 4.7.2 screen captures. Windows/Android physical acceptance is still pending. Next saved unit: replace ribbons with road and plaza meshes over existing route geometry, then build family-specific terrain boundaries and run full-map camera sweeps/gameplay regressions.
