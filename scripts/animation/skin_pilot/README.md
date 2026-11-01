# Shared 2D skin pilot

Open `scenes/dev/SharedSkinPilot.tscn` in Godot 4.7.2 and run this scene (F6).
The first row renders at authored pixel size; the second is the same pose at 2.6x.
The demo idles, moves both skins, changes **one shared** swing-height setting,
swaps appearances without resetting the gait, then settles to idle.
Space toggles movement, L changes the shared lift, S swaps appearances.

`shared_ground_motion.gd` owns distance/phase, fixed-length two-bone leg IK,
stance contacts and swing paths. `cutout_skin.gd` only binds artwork to the
resulting joints: it has no frame animations or independent motion clock.
A single pose dictionary is supplied to both skins. Segment width/length are
fixed authoring bindings, not recomputed from frame silhouettes. Head/torso
stay stable. A shared opposite-phase elbow rotation moves the visible forearm
and hand; the warrior hand and sword remain one cutout texture. The cape tail
has a separate shared, phase-lagged rotation under an overlapping upper cape.
A boot-only sole binding aligns visible soles with the ground.

The two skins are cut from existing repository warrior/assassin sheets, not
private client resources. `tools/animation/build_skin_pilot_parts.py` reproduces
all eighteen parts and the source hashes, polygons and bindings in
`data/animation/shared_skin_pilot.json`. Original sheets are unchanged.
These are hand-authored cutout joints, not recovered source-game skeletons.
Small torso underlays exposed by forearm motion are explicitly authored flat
armor paint, sampled from visible torso color and restricted to the previous
opaque footprint. They are recorded in the manifest, not claimed as recovered
source anatomy. All other cutout pixels remain source pixels.

This is an **E-view ground-locomotion pilot**, separate from the live actor
renderer. It does not change movement speed, attacks, hit clocks or saves.
The requested families are ground, winged floating and ranged; only ground
is implemented. Visible forearms and cape tails are articulated; shoulders,
far arms and the upper cape remain in the stable upper-body composite. This
is rigid cutout motion, not simulated cloth. Further rigging, occluded anatomy,
other views, floating/ranged reference motions and production integration remain future work. This is not
an eight-direction animation approval or a claim of Lineage M equivalence.
The previously observed SOOP general-human movement is a qualitative reference
for stable upper body and restrained motion, not source joint/timing data.

Focused validation:

```sh
godot --headless --path . scenes/dev/SharedSkinPilot.tscn -- --pilot-test
python3 tools/animation/check_skin_pilot_parts.py
```

The contract check covers fixed limb lengths, stationary torso, world-relative
stance contact, shared pose identity and preserved phase across a skin swap.
It cannot certify natural-looking animation. Review the entire idle/run/edit/
skin-swap/stop playback as well. `--pilot-capture` exits after the 16-second
scripted demonstration following a two-second render warm-up. Movie Maker
(`--write-movie /tmp/skin.avi --fixed-fps 30`) captures actual scene rendering at
fixed simulation steps; assess real-time performance separately without it.
