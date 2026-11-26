# Reuse prepared NPC source playback timing

The non-cooked gameplay NPC preview already proves its exact reference-bank
request and checks current manifest/actor pins and member stamps before reusing
immutable metadata. It still copied every track, direction array and frame and
reran the same timing/presentation rules on every life. The same validated
snapshot can now keep immutable results for **one** playback mode and at most
4,096 frame entries. It owns no live actor, sprite, texture, playback clock,
instance fields or pending request. Each preview receives a separate top-level
map; clocks, nodes and styles remain private. Snapshot eviction still does not
revoke an existing view. A changed mode rebuilds; absent/unreadable policy and
oversized input take the old path. Cooked, player, effect and card previews are
unchanged. No source assets were made, modified or published.

Godot 4.7.2 Linux headless: a 2,048-frame synthetic metadata-only A/B (96 paired
samples per path) measured repeated timing preparation 3.507 → 0.002 ms median.
This excludes existing bank validation, texture upload, rendering and first
pose. The genuinely first NPC and actual Android/real resources were not
measured. Regression: source bank pins and replacement rejects, exact synthetic
decoded body pixels and provenance, mode swap/rebuild, two independent actor
clocks and node owners, teardown isolation and overflow fallback. Reproduce:

```bash
godot --headless --path . --script res://tests/reference_sp2_prepared_bank_test.gd -- --npc-timing-benchmark
```
