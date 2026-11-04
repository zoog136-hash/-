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

`patch523_world_links.portal_contract(id)` now returns a detached declaration,
source and destination Land/AssetPath namespaces, the original source point,
declared destination region, and an arrival point only when the region is a
single declared point. There are91 point arrivals and2 region-only arrivals
(Portal18071/18081). Conditions remain raw target-Land/territory context;
LandTeleport routes, costs and prerequisites remain separate travel routes.
No portal fee, trigger or activation is inferred from an empty condition list.

The map panel's **도착 계약 확인** and **원문 포탈 사용** buttons now consume
PR232's public Main API, read at commit
`f8cf6c2ad803d7d66fdd4590cf2e960e823c9476`:

- `current523_aden_source_portals()`
- `current523_aden_source_portal_context(id)`
- `use_current523_aden_source_portal(id)`

The actual source field metadata key in that implementation is
`current523_source_field`. The source mode must be active and loaded. The bridge
matches the selected runtime Portal/TargetTerritory/TargetLand and exact source
and landing points against PR230's verified declarations. It requires a unique
list/context match, verified raw endpoint candidate and actual source-cell
member/hash/policy verdicts at both endpoints. Actor position must be the exact
source cell; no trigger radius is introduced. It checks cooldown, living state,
AUTO, immobilization and charge state before delegating.

The selected field instance, active definition SHA and runtime context digest
form a selection receipt. Replaced fields and changed contracts require a fresh
selection. The request rechecks current state and calls the public execution API
once; a reentrant request is rejected. The runtime owns the final attribute,
movement, destination-rendering and rollback checks. This bridge never writes
player position or currency, creates terrain, samples a destination, substitutes
a PC field or restores over a controller-owned safe return. A failed backend
request stays visible in the panel; success closes it. A false return that
changed field/position is reported separately and is never automatically retried.

PR232's documented default own policy accepts both endpoints only for335/343.
That is distinct from30 raw source/destination matches,31 Aden raw source
matches and93 declarations. The bridge does not hardcode335/343 as universally
active: it consumes the installed field's current policy verdict and still
requires exact actor location and final runtime authorization. Other configured
policies may differ. Portal350's raw candidate never replaces its M declaration.

This PR230 branch does not install or copy PR232's source-field runtime or its
private source/portal resources. With those APIs absent the actual Main panel
holds the request with `source_runtime_api_required`. Positive API and widget
probes are synthetic; they do not establish real M-field movement on this
branch. Integration must provide the three public methods and the actual active
source field together. Source endpoint files, rendering and failure rollback
remain owned and tested by PR232. No other PR is merged here.

The earlier `patch523_portal_arrival.inspect` helper is retained as an independent
read-only strict geometry-preflight utility, with its synthetic regression test.
Its proposed `portal_geometry_contract` interface is not required by the PR232
public-API bridge and is no longer described as the integration blocker.
