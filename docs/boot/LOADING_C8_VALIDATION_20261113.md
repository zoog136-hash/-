# C8 binding overlap validation — 2026-11-13

Fixed base: ae47e8df5265b75929a79d5fb3bea0584e931f81 (includes merged #470).

The cold private compiler prepares the same normalized slim/packed binding,
then computes the unchanged complete binding JSON SHA on one worker while the
main thread builds the rules from independent parsed copies. It joins before
model acceptance/serialization/readiness. No post-ready work is introduced.

The worker owns a normally SHA/key/index-verified reopened template handle and
its bounded cache/order snapshot. It reads immutable borrowed inputs while the
synchronous caller is blocked; no live template seeks, live adapter-cache
changes, source-reader calls, scene/GPU operations or shared container resizing
occur on the worker. Its extra retained references are limited by the existing
128-entry adapter cache and template index. No new value bake or original file
is written. Failed worker reads invalidate its hash. Start failure falls back
to the same synchronous hash; invalid completion rejects the candidate.

Exact private owner/source/provider, non-interning template, main-thread,
multiple CPU and JSON-like input/cache/contract guards preserve public,
subclass, injected-reader, foreign-object and cyclic paths. The escape hatch
TWILIGHT_BINDING_SEQUENTIAL=1 retains the former private path. Public full(),
field(), provider/cache/alias behavior and full JSON audit/hash format remain.

Local final field/snapshot/worker/eligibility/read-error fixture:119 checks,
failures0. Existing synthetic cold/record-store fault matrix:2024 checks passed
before the final read-error guard; the final rerun is recorded in delivery
receipts. These are synthetic checks, not original-media delivery.

Actual-original component comparison (Godot4.7.2 Linux headless; fresh profiles,
production owner): base equipment cold36.749s, warm1.344s; fixed pre-read-error-
guard candidate cold31.953s, warm1.315s. Both same model digest
687d7501fa0d2290d9516e8ecf38a4fb9f0de31d45a71b378c7ab757217ed527 and all five
producer binary payload paths/sizes/SHA. Native registration39.886→37.324s is
variation; this candidate does not optimize that producer. The extra hash join
was129ms. One earlier candidate observation31.540s is preliminary because an
eligibility guard changed during that run; it is not final-source evidence.

Final complete Loading/title/character selection/Main first/next timings and
remote Core/resource/Exchange/SP2 results are pending at this source freeze.
Later results belong in the PR and local receipt without rewriting this
runtime freeze. No whole-start improvement is claimed before those results.

Rejected local prototypes remain on separate branches: bounded group JSON
parallelism129293af (12.9→19.1s), leaf memo plus normalization9b8f8ec8 (no gain),
small-row materializationfd4fc44b (wide-row micro gain but no whole-producer
gain). None is in this candidate. No item is removed or newly excluded; existing
TestItem and explicit exclusion handling is unchanged. Uncertain usage is not
a reason to delete an item, since saves, drops, shops, crafting and catalogs can
reference it. Large detail fields already load on demand; this boot-only change
adds no first-bag deferred work. Actual bag UI/GPU latency was not measured.

Inputs are the existing SHA/CRC-verified private original definition ZIP and
map/tile/world-link inputs. Originals, saves and bakes stay local. No Android
physical device or complete original image/UI-pack descriptor was available.
No GPU/full-original-delivery or unrun manual audit pass is claimed.
