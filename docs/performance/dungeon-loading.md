# Dungeon entry loading

Base: main `270447e2ab8a73d12067cb633462946f9487c8cc`. This is independent of map-usage #850 and actor-page opt-in #851. No resource bytes, sprite worker defaults, player-save schema, tariff or access-policy changes.

## Behavior

The original dungeon window and source dungeon view now use one in-game transition cover. Special dungeon Land entry, world/master/global-master lobby entry and walking onto original Portal cells share the asynchronous source-Land preparation path. Orim and tower begin actions also show the cover. Their existing local/offline rules remain: tower uses the current field, and Orim's already-established local run fallback remains if its original stage Land cannot be entered. This does not add server access or invent dungeon destinations.

The existing boot style supplies the backdrop and text. This is **not** the 523.824 boot/character initialization screen (33%, 1/3). It has no percentage, generated imagery or minimum artificial display time.

The cover pauses gameplay, draws once, then invokes the original eligibility/payment owner. Source-Land transitions configure a hidden candidate, pump the existing bounded chunk/atlas/block work on successive frames and wait for every screen block to have been submitted. Verified empty blocks need no viewport. Margin prefetch is not a barrier. Failed visible chunk reads refuse arrival rather than opening a gray map. A 60-second readiness timeout is a failure guard, not a display delay.

After preparation, the existing final condition recheck, collision creation, checkpoint and atomic payment/rollback sequence run. Only a committed destination is revealed; input remains paused until that reveal has drawn. Duplicate requests are rejected by the overlay, service and controller guards. Preparation errors/timeouts retain the old field, restore player/camera and do not reach the special/lobby payment commit. An uncertain save retains the existing uncertain-result handling. Special-dungeon loading wall time is excluded from the first live time-pool tick.

Synchronous public APIs remain for existing callers and fixtures. Return, item/scroll and prepared same-map teleport paths are not converted by this dungeon-entry change; their existing paths and policies remain intact. This PR does not claim to implement a new general loading flow for every travel item.

## Measurement and limits

`DUNGEON_TRANSITION_TIMING` separates first cover paint, prepared arrival-ground submission (when applicable), operation duration, destination reveal paint, and total/input-return time. These are wall-clock microseconds, not percentages or exclusive CPU attribution. Headless runs are explicitly labelled.

Linux Godot 4.7.2 / Mesa llvmpipe / Xvfb tests use synthetic fixtures, not installed original dungeon packs. The first cover paint can include cold text/shader work. A loading screen is not proof of a 16 ms gameplay frame budget. Catalog configuration, collision creation, static-object setup and the existing atomic save remain indivisible work; they can still stall a loading frame. The renderer's existing budgets are reused, not a wholesale map/save rewrite.

The user's 523.824 device report (`270447e2`) reports 3,342 frames and 123 frames at least 100 ms. Its 698 ms interval includes 630 ms attributed to `dungeon.play`; save scopes may nest and are not summed here. The mostly unclassified 7.974-second interval and the earlier 3.189-second submission gap are not identified as dungeon entry by this change. Encyclopedia/kill-path bottlenecks are outside scope. Android/device performance and original-pack dungeon visuals have not been measured in this environment.

## Validation

- `dungeon_loading_test`: cover-before-work, actual desktop draw, duplicate taps, delayed readiness, failure/timeout input restoration, pre-existing pause, host cancellation before work, missing/empty/unsubmitted ground, margin independence, hidden candidate viewport submission, unreadable chunk refusal, special level gate, failed entry preserving gold/run, successful single debit and repeat rejection.
- Selected core suites: boot readiness, dungeon loading, original dungeon window, special dungeon entry, actual Main/save preservation, renderer, long teleport, movement/map travel and current Main UI.
- Competition suite without private definitions only exercises its two unavailable-data guards. It is **not** world/master physical traversal evidence.
- Optional `dungeon_execution_main_test` and `dungeon_local_play_test` could not validate actual play: required private definitions/resident actors are absent. They reported fixture/property errors after that missing-data prerequisite and were stopped. These are not passing tests.
- Repository-requested `tools/check_resource_integrity.py` is absent on this main; current `check_no_legacy_resources.py` and its seven Python tests are used and pass. No original-art delivery claim.

Final repeatable desktop fixture (four deferred readiness pumps; not real dungeon loading): 34 checks passed. First invocation cover paint 42.949 ms, reveal 96.037 ms, input return 96.042 ms; repeated invocation 24.354 / 62.987 / 62.990 ms. Maximum sampled frame 48.183 ms. The final headless fixture passed 29 checks. The desktop test also read back the hidden candidate's synthetic pixel, rather than treating a post-draw signal alone as proof of content. These numbers measure the test orchestration and software renderer; they are neither Android GPU measurements nor an A/B speedup for original dungeon entry. All nine selected core suites passed with full staged import; optional missing-pack tests above remain blocked.
