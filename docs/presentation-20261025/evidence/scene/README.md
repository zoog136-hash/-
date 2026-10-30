# Actual Main encounter evidence

`tests/capture_lineagem_presentation.gd` drives the production Main scene, existing
class confirmation, movement input, starter Energy Bolt, HUD attack signal, actual
monster AI/damage/death, floor-drop service and manual pickup UI, then inventory.
The fixture uses unchanged main records for 고스트, 버그베어 and 드레이크. It places
these three consecutively on verified walkable, non-safe terrain in the current
Aden map. It pauses the 77 existing background actors/population to isolate the
encounter. This is a presentation fixture, not an ordinary spawn demonstration or
performance benchmark. No combat stats, timing, rewards, rates, anchors or art are
modified. Main's unmapped Drake heroic drop warning remains visible in the logs;
no arbitrary substitute is supplied.

Baseline source is main `cba19558de2764839feb4887a8af8f69b905257a`. A temporary
source overlay copies scripts/tests and links unchanged resources, then resets
all modified production source files to that SHA. The exact same harness runs
before and after, with separate empty XDG save profiles, seed 20261025 and the
same resolution and fixture positions. The source overlay does not modify the
shared feature branch.

MovieWriter uses 60 fixed frames per second and the MP4 is encoded at 30fps. This
preserves game time, not real-time wall-clock performance. `scene.json` records
simulation and wall time separately. Linux llvmpipe software OpenGL is not an
Android device. Dummy audio driver is used for capture; no listening validation
is claimed.

Initial fixture diagnostics are retained under `diagnostics/`: a property-name
error, interrupted capture, AUTO prioritizing floor pickup, and manual attacks
out of range when the boss retreated. Only the harness was corrected to follow
the target through the existing path API and activate the existing HUD attack
signal. Production assertions and combat rules were not relaxed. The final
headless probe checks real HP loss, normal/skill strike flow, three actual deaths,
floor loot and earned-quantity manual pickup. Cold-import/system-4.6.3 diagnostics
were not counted as 4.7.2 validation.

Reproduce the final render from the repository with an empty save profile:

```sh
XDG_DATA_HOME=/tmp/twilight-scene-new-profile \
TWILIGHT_CAPTURE_DIR=/tmp/twilight-scene-output \
DISPLAY=:97 /workspace/tooling/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --path . --audio-driver Dummy --fixed-fps 60 \
  --write-movie /tmp/twilight-scene.avi \
  --script tests/capture_lineagem_presentation.gd
```

Use an already-running 1280×720 X server (here Xvfb) and writable XDG config/cache.
Encode the AVI with ffmpeg H.264 CRF22/fps30 and AAC128k. The large temporary
MJPEG AVI is not a deliverable; its encoded MP4 and frame-count metadata are.
