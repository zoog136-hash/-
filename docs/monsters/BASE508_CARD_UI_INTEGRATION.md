# PR217 source card UI consumer integration

Handoff commits151b6463d and1a94d441f were cherry-picked on top of the current
source runtime, explicit awakening VFX and opt-in map changes. The only content
conflict was catalog_card_ownership.gd: native images now use the source UI
presentation reader through the existing shared private-pack resolver; legacy
loading remains intact. No World, awakening save key or runtime playback change
was replaced by the handoff.

Godot4.7.2 passed1347 native collection checks and44 targeted actual-Main UI
capture/input checks across1280x720 and854x480 using OpenGL/Mesa. This invocation
used the validated opt-in Albino source field and isolated in-memory ownership.
The inherited harness forces HUD processing for UI input. Its earlier static
checks.json label incorrectly said the map pack was absent; the script now
reports source_map_test explicitly. The source-test ordinary-save guards stayed
active. Missing audio hardware caused automatic dummy-driver fallback. Android
input and full-project CI are not claimed.

The integrated state-contract test passed: source:m508:98:21518 is identical
across UI, permanent ownership, existing accepted awakening save restoration and
conditional source VFX24748. A visual awakening flag grants no unsupported
collection condition or legacy progression bonus. Repeated collection reads
preserve stats and the owned/spare ledger. Native awakening collection conditions
remain blocked pending their gameplay implementation; no costs or server context
were invented.

1736 source sets remain registered, with892 supported unconditional definitions
and844 blocked definitions. The requested permanent-time policy preserves raw
dates and retains server/awakening/effect restrictions. Original UI frames,
tabs, backgrounds and buttons remain the follow-up worker's pending scope.
No original pixel files are included in the public commits.
