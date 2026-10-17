# Existing PR #100 navigation and spawn regressions

The baseline full CI failed both `hunting_navigation_cache_test` and
`renewed_map_spawn_test`. They were reproduced on Godot 4.7.2 against the current
real authored map JSON, without terrain fixtures or new maps.

All 25 baked cache signatures described older runtime inputs. The runtime's
signature guard correctly rejected them and rebuilt navigation. The checked-in
cache requirement therefore failed on all 25 maps. After the real dense spawn
fix and final boss metadata changes, `tools/bake_hunting_navigation.gd` regenerated
all 25 caches. SHA verification remains mandatory. The cache algorithm version
is now 2, and a previous version is rejected. The `.nav` files total 295,735 bytes
(previously 365,487); no duplicate cache set was added.

Oman 3 and 7 had a separate population fault. Their protected road-side dense
hotspots had 54 valid cells inside the original 220-pixel radius. At the existing
38-pixel separation on a 32-pixel grid, random greedy placements saturated at
23 actors for both seeds 20261012 and 20261013, with zero remaining usable cells.
Increasing retries could not fill the declared 24 slots.

`PlayableField` now selects the larger valid checkerboard subset when its
diagonal distance satisfies the requested dense spacing and the subset fits the
declared capacity. For both affected maps there are 28 such cells, each at least
45.25 pixels apart. A per-instance shuffled dense deck samples distinct cells
before reshuffling. Normal spawn selection is unchanged. The original 24 slots,
38-pixel minimum spacing, 220-pixel radius, and road/safe/landing exclusions remain.
The before/after actual-map probe logs show 23/24 becoming 24/24 for both seeds.

The respawn test also compared current bosses to obsolete historical intervals.
It now requires the already implemented regional wall-clock policy: Aden 28,800
seconds and other maps 86,400 seconds. Normal/dense respawns still require exact
historical intervals. The additional Death Knight rule's unused `600` metadata
was corrected to `28800`, matching the existing policy header and runtime.

Verification completed with actual exit code 0:

| Check | Result |
|---|---:|
| Actual-map navigation bake | 25 maps |
| Cache/fresh geometry equivalence, copy isolation and invalidation | 225 assertions |
| Native PCK cache SHA/load/walkability | 25 maps |
| Real-map renewed spawns, both seeds and eight-slot death/refill cases | 9,694 assertions |
| Portable rules and regional policy | 7 tests |

The runtime `monster_world_test` also passed 9,327 assertions after the dense fix;
its log belongs to the separate boss/world regression evidence. No production
world/combat system rewrite or population-cap reduction was used.

The focused logs, `navigation-spawn-test-results.json`, and
`navigation-resource-audit.json` accompany this report. Reproduce after import:

```sh
godot --headless --path . --script res://tests/hunting_navigation_cache_test.gd
godot --headless --path . --script res://tests/renewed_map_spawn_test.gd
godot --headless --path . --script res://tools/verify_hunting_navigation_pack.gd
python3 -m unittest discover -s tests -p 'test_renewed_map_spawn_rules.py' -v
```

Use Godot 4.7.2 and isolated XDG data/config/cache directories for these checks.
