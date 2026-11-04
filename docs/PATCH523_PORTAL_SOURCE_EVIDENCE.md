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

The map panel's **도착 계약 확인** button calls the read-only
`patch523_portal_arrival.inspect(catalog, portal_id, destination_field)` API.
It checks source geometry availability rather than interpreting a PC field's
numeric map ID as an M Land. Even a successful landing preflight returns
`travel_enabled=false`: it is not portal execution. It never writes a player
position, queues travel, charges currency, samples a region or corrects a raw
packed candidate. Region-only arrivals remain held without a selection policy.

A future source-coordinate field must provide `portal_geometry_contract()` with:

```
schema: 1
source_snapshot: patch523
coordinate_space: LINEAGEM_WORLD_SOURCE_CELLS_V1
definition_manifest_sha256: <active verified world-links manifest SHA256>
land_id: <exact destination M LandID>
asset_path: <exact destination M AssetPath>
geometry_sha256: <source geometry SHA256>
collision_scope: EXPLICIT_LOCAL_POLICY
traversal_policy_id: <explicit configured local traversal policy>
actor_foot_policy_id: <explicit configured actor-foot projection policy>
```

Its methods must include `source_cell_supplied(Vector2i)`, `source_to_world`,
`world_to_source`, `point_clear(point, padding)` and `line_clear(from, to)`.
Coverage and clearance results must be actual booleans. The preflight verifies
the declared point's supplied chunk, finite projection and inverse roundtrip,
floor/occupancy and the existing TWILIGHT4px eight-offset footprint. Geometry
and foot policy are explicitly local, not claimed as verified M collision.
The current PR230 host field and the inspected PR232 renderer at
`f7ee56c478142efba6d9e1062a14482a95e60675` over legacy traversal do not implement
this source-coordinate landing interface.
No PR232 code is imported here; source geometry and portal activation remain
separate dependencies.

`patch523_portal_arrival_test.gd` checks all93 real declaration contracts and
unsafe landing rejection. Its successful geometry adapter is synthetic test
data, not an original map installation or a completed physical arrival.
