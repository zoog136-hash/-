# Map usage ledger worker

Base: `270447e2ab8a73d12067cb633462946f9487c8cc` (main verified 2026-11-23).
Initially implemented on `f673119`, then rebased after #848 merged.
Independent of the map slicing and cooked NPC first-page branches.

## Ownership and persistence

`current523_map_usage.observe` retains the visible actual-Main ownership gate,
source member/ID/SHA/byte range rules and USER_MAIN versus AUTOMATED_ACTUAL_MAIN
classification. It now accepts a small scalar observation into a bounded inbox.
Its return value means **accepted**, not durable. Repeated observations hit a
bounded recent cache. `flush`, including calls from ground and static-SPR draw,
only sets a flag: it performs no read, parse, serialization, write or worker wait.
Ground and static-SPR draws transfer validated scalar evidence to the broker.
Transient pressure is retained in a bounded overflow queue and replayed by the
autoload when capacity returns; no later camera update, redraw, frame repetition
or visible renderer is needed. Invalid/disabled inputs are terminal and never
enter that queue. Ground removes handled refs without forcing observation redraws.
`observe_result` distinguishes ACCEPTED, RETAINED, INVALID, DISABLED and DROPPED;
the compatibility bool entry returns true for accepted/retained observations.

The always-processing MapUsagePump autoload owns scheduling across scene changes.
One low-priority WorkerThreadPool task at a time accesses one private LedgerWorker.
Only that worker reads/parses the existing v1 file, owns/merges its full Dictionary,
serializes JSON and calls the existing atomic temp-file/rename writer. The v1
path, inventory SHA, fixed Map/Tile denominator, origin separation, source ranges,
partial-observation meaning and no-95%-proof fields are unchanged. No game-save
path or game-save worker state is shared. No asset bytes, pixels, collisions,
travel rules or original Android SP2 worker settings change.

Main transfers the inbox array, without deep-copying it or the ledger. Each event
and the transferred array are read-only. An exclusively transferred envelope
is emptied by the worker so the event payload is also released on the worker;
reaping a task on main releases only the empty envelope and a small status array.
Main never reads worker fields. It reads the result only after completion and
joins only already-completed tasks during gameplay. No Node, GPU object or shared
mutable Dictionary crosses the boundary. The worker does not call gameplay code.

## Bounds and loss semantics

- One pending batch and one in-flight batch, each at most 2,048 events and a
  4 MiB conservative UTF-8 scalar-payload bound. A retained queue adds at most
  256 events / 512 KiB of scalar payload. Promotion swaps arrays in O(1), preserving
  captured origin, frame and range. Godot container overhead is extra.
- Recent dedup cache: at most 2,048 bounded keys. Older repeats can enter another
  batch; the worker's v1 units/ranges still deduplicate them without rewriting an
  unchanged ledger. Accepted/committed counters count accepted events, not unique
  global source coverage.
- Members above 1,024 characters are rejected; units retain the previous 256
  character limit. Overload/disabled ingress increments rejected-attempt status;
  invalid/disabled inputs do not retry. Only exhaustion of both pending and
  retained bounds produces DROPPED. `dropped_observation_attempts` explicitly
  counts those attempts, separately from rejection and force-kill loss. The next
  successful atomic save records cumulative `recording_dropped_observation_attempts`
  as an optional v1 top-level field; v1 members/schema remain compatible and the
  count survives reload. A dropped one-time frame/range can be absent, never
  falsely acknowledged. If storage is disabled/unwritable or the process dies
  before that save, the new counter is not yet durable; status exposes this too.
- Normal writes retain the 10-second interval. Retention pressure, scene exit/
  explicit force and application pause request a prompt drain. The autoload continues through scene changes.
- Only final process teardown uses `finish`: at most three drain attempts,
  including transient write retry. It can wait for disk I/O; it is deliberately
  outside gameplay. It does not impose an OS I/O timeout or alter quit/save routes.
- A write failure keeps the last committed file and worker-owned dirty state;
  a later pump retries. Corrupt, incompatible or over-16-MiB existing files are
  preserved and disable recording, as before. A new serialized snapshot exceeding
  16 MiB is not installed, preventing a write that next startup cannot read.
- Restart reads only the committed v1 file. Orphan temporary output is not evidence.
  Atomic replacement preserves old committed data on tested write failures.
  This does not add an fsync/power-loss guarantee beyond the existing writer.
- A crash or OS kill can lose pending/in-flight/failed-write observations in RAM.
  `committed_observations` advances only after successful replacement (or when an
  event already exists durably). `uncommitted_observations`, rejection counts and
  `problem` distinguish that state. These session counters are not a durable
  journal. No old ledger or user data is deleted to recover from an error.

## Reproduction and validation

Use Godot 4.7.2 with isolated XDG profile directories, never a player's profile:

```sh
godot --headless --path . --script res://tests/map_usage_async_test.gd
godot --headless --path . --script res://tests/map_usage_cost_test.gd
```

The async test is registered in the core gate. Its original 35 checks cover v1 merging,
exact origins/units/ranges, source identity conflict, rejection of fixture Main
ownership, immutable handoff, repeated pumping against a semaphore-blocked
worker, both queue bounds, deduplication, multiple batches, scene-flush lifetime,
normal drain, bounded failed-shutdown retries, storage recovery, incompatible and
corrupt files, missing worker results, incomplete temp output, restart and a byte-identical save sentinel.
The benchmark asserts equality of committed member observations against sync.

Separate child-process checks used `--exit-fixture=/tmp/...` to quit with a pending
observation and verified the real autoload teardown persisted it. A
`--crash-fixture=/tmp/...` child was killed while its worker was blocked; old
committed bytes survived, its explicitly uncommitted event was absent, and a
subsequent normal child restarted successfully. These switches exist only in the
test script. The synthetic ledger paths are separate from the game's ledger.

Local full staged import and eight selected core suites passed: usage cost,
async ledger, loading readiness, actual Main/save preservation, map renderer,
long teleport, source field and Main UI. The final envelope-lifetime refinement
was also rerun in the focused ledger test. This is not the entire remote core
suite. Current resource policy and seven Python regression checks passed. The
old AGENTS command `tools/check_resource_integrity.py` is absent in this revision;
the current workflow runs `tools/check_no_legacy_resources.py`.

## Synthetic Linux A/B

One recorded sample, Godot 4.7.2 headless, warm OS file cache, synthetic v1 units.
The synchronous baseline reads/parses the full file and performs the same JSON
stringify/atomic writer. Both paths add the same unit; committed members match.
The synthetic ingress calls the internal accepted-event entry and `flush`,
bypassing the actual-visible-Main gate. Thus it measures the changed render-facing
work, not complete `_draw`, actual GPU frame time or the eligibility check.

| Ledger bytes | Sync first parse | Sync write | Ingress + flush | Worker read/merge/write | Ready wall time |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 804,447 | 21.7 ms | 23.8 ms | 21 µs | 42.2 ms | 50.3 ms |
| 3,015,772 | 119.4 ms | 95.5 ms | 61 µs | 240.2 ms | 253.3 ms |
| 5,628,977 | 182.7 ms | 185.5 ms | 40 µs | 454.9 ms | 456.7 ms |

The maximum measured poll/submit/collect call in that test was 225 µs. One hundred
polls against a blocked worker took 46 µs total. These are samples, not hard time
limits. Total persistence need not become faster: the gain is removing full
ledger work from drawing. Background CPU and allocator contention can still
influence frame time.

Each single-event ingress added about 1,004 bytes of Godot static allocation in
this fixture. Whole-test process static peaks at the three sizes were about
53/123/221 MB, including synchronous baseline dictionaries, generated fixture
strings and the asynchronous ledger together. They are **not** isolated worker
memory or Android app peaks. Raw process allocation deltas can be negative as
prior fixture objects are freed; do not interpret them as worker retained size.
The worker's 16 MiB file limit does not mean its decoded Dictionary uses 16 MiB.

No physical Android run, original-pack gameplay, FPS claim, APK/OTA deployment or
main merge. These measurements do not establish the cause of the reported
Android 12.79-second freeze.


## Pending-observation follow-up

The ff5768f draft retained ground refs for a future draw but did not own a retry
for cached/idle ground or short-lived static frames. The follow-up fixes that at
the scalar ingress and removes the dependency on another draw. Only a genuine
visible-Main draw can enter the public observation API; replay does not invent
observations or re-check a now-hidden scene. Already captured scalars survive
scene destruction and normal shutdown.

Additional tests fill the inbox, retain known ground and static frame/range
observations, and drain with only the normal pump (no camera/redraw/second observe).
They verify invalid/disabled results do not retain, both memory bounds, dedup,
shutdown of a new retained frame, explicit hard-drop absence, durable drop count,
and v1 counter reload. A real child-process exit begins with a full inbox plus a
retained observation and verifies that the autoload commits all 2,049 events.

The desktop-only integration harness calls the actual production ground and
static-SPR draw callbacks in a visible Main-ownership context, then hides the
scene. It verifies the three captured identities/ranges commit with zero further
draw callbacks. The harness attaches the real world inheritance chain after
ready to suppress gameplay bootstrap; all inputs and the ledger path are
synthetic and isolated. This is not original-pack gameplay or Android evidence.

Follow-up verification: **46 headless checks / 50 desktop OpenGL checks** pass,
plus a fresh full staged import and the eight focused runtime suites listed
above. The separate real process-exit check persisted the retained 2,049th
observation. Resource policy and seven Python tests pass. The desktop run emitted
only the llvmpipe V-sync warning. The added world/draw harness preloads production
world classes, so its roughly 700 MB whole-test static peak is not comparable to
the earlier smaller benchmark process or a worker-memory claim. Observed
poll/submit maxima varied across concurrent runs (0.126–5.385 ms); they remain
samples, not a fixed frame-time guarantee. Android hardware remains untested.
