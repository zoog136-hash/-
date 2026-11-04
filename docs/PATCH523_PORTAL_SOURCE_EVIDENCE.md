The optional private map-source handoff can be inspected from the existing map
screen → 포탈·출현 정보 → 아덴 본토 · 포탈 정의. Append this argument after `--`
alongside the existing verified `--patch523-world-links` directory and its SHA:

```
--patch523-map-evidence=/ABSOLUTE/M523_PR232_PR230_map_source_crosslinks_20261104.zip
```

The accepted archive SHA256 is
`7fa773dfa1e040ba6afc9eed917b90f1a6bbca4cd64fbef44b0b85fe3697c71f`.
The archive remains private and outside Git. The loader checks its exact digest,
all64 inventoried member hashes,50 raw-record proofs, and the corresponding
Portal, Land and TargetTerritory declarations against the active verified523
definition pack. A missing or mismatched input leaves research metadata unavailable
without changing existing travel, source definitions or saves.

These are50 additional raw-record matches to existing declarations, including31
Aden departures; the existing93 outgoing Aden Portal definitions stay93. The
panel exposes each matching record's member, byte offset and hash. The31 records
from the current-DAT verification lineage and19 current-selected retained508
records remain distinct; this consumer verifies the handoff bytes and current
Content declarations, not newly acquired whole DATs. Packed destination candidates
are labeled separately. In particular Portal350 keeps its declared arrival
(34275,32222), while the distinct raw packed candidate (34278,32224) is shown
as a mismatch. No nearest-point correction or global raw-target=LandID rule is used.

The handoff does not establish trigger geometry, activation, arrival selection or
walking permission. Gate, Obstacle, InteractionCell, ClientMapObject and typed
movement-state declarations in its other reports do not become one collision
flag or production movement rule. PR232's full-map implementation is separate.
The existing host movement-stone UI and navigation remain independent.

Focused validation uses `tests/patch523_portal_source_main_test.gd` with the
private handoff and existing resource packs. It opens the actual Main map UI,
checks Portal350's two coordinates, missing/mismatched input rejection, preserves
all93 definitions and host placements, and compares saved character bytes.
