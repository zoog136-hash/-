# Original Lineage M source inspection

Status: **private body/shadow inspection, not production integration**. The existing collectible registry is unchanged. No new collectible identities, names, grades, stats, effects, or motion frames are invented.

Based on main `0cab9b3d39e9330feb1c404d8c36b80d3e417b2d`, this path reads native declaration timing and pixels independently of the authored animation presentation. The first reviewed targets are `transform:267` (22262 → 22258) and `transform:393` (28443 → 28439). Alias action overrides remain intact. Native Walk and Run are separate tracks; idle starts with the declared frame11. Movement uses the explicit 36Hz sections; these two idle/basic attack tracks use their preceding explicit 24Hz sections and original per-frame durations.

`original_source_preview.gd` uses source pixel offsets directly, scale1, and no root wobble, normalized canvas, generated shadow, generated actor overlay, frame interpolation or speed-based FPS changes. Attack presentation has its own native clock; the existing `TwilightActorMotion` strike marker remains authoritative. Repeated manual movement cancellation preserves the locomotion clock.

The source origin has not been established as a physical foot anchor. Direction bit5 is mapped to game down by visual inspection; this is recorded as inspection rather than native-world semantic approval. Native shadow pixels are rendered literally. **sc/mu attr8/128 are retained as unresolved layer IDs and are not rendered**. No original composite fidelity is claimed. The explicit `--lineagem-original-preview` switch is required; normal launches do not enable this incomplete compositor.

## Build and run

Use Python3.12 and the pinned `requirements.txt` in an isolated environment. Original inputs remain outside Git.

```sh
python tools/lineagem_original/build_original_preview.py \
  --inputs /absolute/local/original-inputs \
  --output /absolute/local/private-preview

godot --path . -- \
  --lineagem-original-preview=/absolute/local/private-preview/manifest.json
```

Equip the existing reviewed transform normally. The preview manifest is a local inspection pack, not permission to redistribute the underlying art. No original SP2 or derived source art is committed by this change.

```sh
python -m unittest discover -s tools/lineagem_original -p 'test_original_*.py' -v
godot --headless --path . \
  --script res://tests/lineagem_original_player_validation.gd -- \
  --lineagem-original-preview=/absolute/local/private-preview/manifest.json
```

Use Godot4.7.2 and isolated `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `XDG_CACHE_HOME`; do not use a player's save directory. The player validation requires the real private pack and is not part of the default synthetic/CI test collection. It checks both transforms, native idle order, damage marker preservation, cancellation, transform removal, and root invariants across eight directions. Those checks do not approve visual quality.

`lineagem_original_game_capture.gd` runs Main with an explicit authored albino validation map and `--legacy-map-layouts`. It selects a starter class in the isolated session, checks the actual source role, and captures front idle/walk/run/attack/idle transitions. Walk uses test speed90, then restores normal speed. This is Linux software-rendered inspection, **not normal Aden map validation or Android30FPS validation**.

## Full-source scope

`audit_supplied_manifest.py` verifies the parent-supplied corrected category manifest against local size/CRC. In this environment, all51 pixel ZIPs plus the metadata ZIP were downloaded through Library, SHA256/ZIP-CRC checked, and all32,314 explicit-scope SP2 files matched locally. Missing inputs:0. The full10GB source ZIP was not materialized here, and its historical MD5 is not re-verified here.

`build_source_catalog.py` collects source-native body candidates across the full supplied scope, without cutting at the existing registry. It groups aliases by terminal body while retaining variant actions, excludes referenced layers and roots without the required actor actions, and leaves `gameplay_identity=unverified`, `registered_in_game=false`, `gameplay_grade=null`, and `production_replay_ready=false`. Its904 transformation,143 doll and144 relic body-candidate groups are **not counts of unique/new collectible entities**. Effects/items, duplicate declarations, unmatched identities and unknown native timing remain pending. Existing registry review:413 transforms,166 dolls,144 relics; two reviewed visual targets, six name-only candidates,715 unresolved.

Protected content tables were not opened or decrypted. A source candidate is not automatically registered as a collectible. Missing/default FPS is not assigned a guessed value. Remaining work requires verified identity/tier correspondence, native timing where unspecified, and layer/origin semantics before production registration and full original composition.
