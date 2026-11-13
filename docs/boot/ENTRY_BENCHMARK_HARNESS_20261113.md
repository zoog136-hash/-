# Production Loading entry benchmark

`tools/boot/benchmark_loading_entry.py` launches Godot with the actual production
`Loading.open(tree, Main.tscn)` caller, observes its `progress_changed` and
`finished` signals, and records the destination's actual `loading_readiness()`.
No World/Loading/producers are replaced or timed by a synthetic approximation.
The optional synthetic mode alone selects the existing delayed-ready fixture.

Run after import and merging the candidate optimizations. Do not compare an
unimported checkout with an imported stage. Use separate new profiles for each
arm, then `next` on each arm's own profile. No app profile/cache is deleted.

```sh
python3 SOURCE/tools/boot/benchmark_loading_entry.py \
  --project STAGE --source-project SOURCE --godot GODOT_4_7_2 \
  --profile NEW_ISOLATED_PROFILE --output NEW_RESULTS \
  --mode authored --condition first \
  --env TWILIGHT_PATCH523_CONTENT=/absolute/original-definition.zip \
  --input /absolute/original-definition.zip
```

Repeat with `--condition next` and the same profile/output/input/environment.
`first` means empty app data, not a controlled cold OS page cache; `next` is a
separate process with the prior app bakes/saves. Neither is the catalog tool's
same-process warm producer call. Baseline and candidate should be sequential
and matched, with repeated observations when system noise matters.

For real Land 4 use `--mode source-land4 --options /absolute/options.json`.
This must be a production `current523_aden_play_options.gd` JSON dictionary with
`enabled: true`, `navigation_profile: CURRENT523_GENERIC_S32_OWN_ALLOWLIST_V1`,
`native_land_id: 4`, `raw_root`, `tile_root`, exact `source_manifest_sha256` and
`tile_manifest_sha256`, and a verified native `source_position: [x,y]`.
Pass both original manifest files through `--input` as well. The production
validator writes this config only inside the tool-created isolated profile.
Do not invent a point, substitute an authored map, generate converted media, or
claim actual-source success while original inputs are unavailable. Exact
manifest pins/point come from the separately verified private pack restoration.
The authored mode explicitly disables source play and keeps this condition
separate from an enabled source map. Source pack autoload environment must be
provided identically in each arm and is retained in the receipt.

Each receipt includes process wall time, 50 ms sampled peak RSS, every printed
BOOT_PROGRESS event, strict engine errors, return status/timeout, existing save
file hashes before/after, newly created save files, command, source revision and
dirty status, and per-file stage/source SHA evidence. Existing save changes fail
the receipt; new saves are separately listed. Byte equality covers scripts,
data, boot tools and the delayed fixture. `project.godot` hashes are recorded
separately because an imported Linux stage may have explicit platform overrides.
Main/scene imports and original input identity remain the caller's obligations.

The Godot result records all emitted progress snapshots, monotonicity and
100%-after-readiness assertions, ready reason, map/source flags, field metadata,
field scope/cache metrics, renderer frame metrics (including unresolved counts
when exposed), and available draw-region properties. Missing renderer counters
stay absent/null: headless execution cannot verify rendered pixels, GPU cost,
complete original media, or Android behavior. A failed/timeout receipt is evidence
of failure, never a usable speed claim. No thresholds or invented timings exist.

## Catalog producer comparison

The existing catalog runner accepts `--source-project SOURCE` for imported
stages without `.git`, and `--owner production` to call
`P.register(DROPS, candidate, document)` with the real script resource identity.
The default `profiled` owner retains the old wrapper. Production owner counters
remain empty; source row counters still use forward-only wrappers. The comparator
rejects different owner modes. Pass the same owner in both arms: production code
may select a registrar path by the owner's exact script resource path.

## Validation performed

Godot 4.7.2 headless, synthetic delayed fixture only:

- First and next process: strict receipts pass; progress 0,33,66,100; readiness
  pending observed; final readiness true; no engine errors.
- Rejected readiness: receipt fails and retains `synthetic_readiness_rejection`;
  final progress stays below 100.
- Python modules compile. Actual original catalog and successful Land4 first/next comparisons are recorded in LOADING_DEEPER_VALIDATION_20261113.md.
- Historical `tools/check_resource_integrity.py` is missing in current main.
  Current replacement `python3 tools/check_no_legacy_resources.py` passes
  (`tracked=20`). This does not prove original asset delivery.

Original full media, GPU rendering and Android remain unverified. Land4 timing is a single headless comparison, with exact measured revisions recorded separately. Results live outside Git; only harness source/documentation is committed.

First/next identity includes runtime-file, stage-setting and Godot executable SHA.
A failed first run cannot authorize next. Ambient TWILIGHT variables are removed;
only explicit inputs are applied and their effective environment is recorded.

Catalog `--market-public` measures the first actual public Market query and all
matching admitted items after producer phases. Full and Market-only output SHA,
serialization overhead and memory are separate; this work is not included in the
initial producer speed comparison. Both arms must use the same option.

Generic Land entry also requires its original definition provider. Use the existing
production launch flags with `--game-arg=--patch523-world-links=ROOT` and
`--game-arg=--patch523-world-links-sha256=PIN`, and hash its manifest with
`--input`. Launch arguments participate in first/next identity. An absent provider
is a real readiness failure; do not count that failure time as successful entry.

A passing preservation map can be empty when the isolated profile contains no
existing save files. Report that condition explicitly; it does not independently
prove preservation of a nonempty player save. The actual Main seeded-save Core
test and required remote Core gate remain the preservation evidence.

Final C3 uses a separate new first profile because its runtime fingerprint differs
from C2. The retained baseline/C2 results are historical observations, not C3
measurements. The final report records all three and includes slower next/warm
observations rather than treating every phase as an improvement.

Further C4 validation preserves two phases: the independent patch runtime and
the later fixed-main integration runtime. Never attribute an integrated timing
that includes unrelated main changes solely to the patch. Instrumented cash
preparation, warm install and post-readiness first-shop calls are separate from
the uninstrumented first/next receipts. Profile-start manifests and mandatory
positive scope activation are retained with the local diagnostic evidence.
