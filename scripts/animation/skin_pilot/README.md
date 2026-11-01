# Shared 2D skin pilot

Run `scenes/dev/SharedSkinPilot.tscn` in Godot 4.7.2 (F6). The first row is
1:1 pixel size; the second shows the same pose at 2.6x. Space moves/stops,
A attacks, S swaps skins, and L adjusts the shared swing height.

Both appearances use one pose dictionary: distance-driven legs, a restrained
chest/shoulder response, upper arm, forearm, hand/weapon, visible far-arm counterbalance, and following cape.
The idle chest moves by 0.25 pixels over a 2.6-second cycle while feet and
shadow stay fixed. These are authoring values, not measurements of Lineage M.
Run/stop blends cover the upper body and feet; starting an attack blends from
the previous pose rather than snapping to a separate ready stance.

Attack preparation, planted strike, follow-through and recovery coordinate the
pelvis, chest, shoulder and arm. The planted strike now transfers weight from
the rear leg to the front: pelvis travel changes the knee bend while the feet
remain stationary through the loaded/strike interval. The far arm draws back
as the weapon arm extends; this movement is limited to the attack. The scene samples the existing unmodified
`TwilightActorMotion` attack clock and its slash marker. The visual resource
never emits damage or changes elapsed time. The demonstration uses 0.72 seconds,
the existing world's unbuffed normal attack interval. No combat or movement
code in Main is changed. Skin replacement during an attack preserves its clock.

The original warrior/assassin sheets remain untouched. The reproducible mask
builder and manifest describe 32 source cutouts/derived layers, source SHA-256,
fixed joint bindings and explicitly authored armor underpaint behind exposed
arms. The near arm has two fixed-length bones; skin widths are fixed bindings.
Head/torso/pelvis overlap around joints instead of scaling the whole silhouette.
The assassin's visible rear hand/dagger is rebound to the near wrist, with the
old blade removed from the torso mask. This is new skin authoring, not recovery
of hidden anatomy or an original game's skeleton. Only the visible far-arm silhouette is separated and pivoted; occluded anatomy
is not reconstructed. The assassin blade overlap is excluded from this cutout
to avoid leaving a second blade behind. Capes remain rigid overlapping cutouts
rather than cloth simulation.

Reference review used the supplied expanded video archive: Girtas idle
0.00–1.05s; myth footage 02 idle 6.50–7.85s and attack from 8.00s; myth footage
03 left melee attack 0.89–1.38s. The visible preparation, body/shoulder/weapon
coordination and return informed this batch. Green projectile-like effects in
03 do not make that sword action a bow attack. Footage 04's short approach is
not a complete ordinary RUN cycle. Converted video frame rates do not establish
original animation cadence. Reference video pixels are not copied into assets.

This remains an **E-view ground pilot**, separate from the production actor
renderer. It is not a production Girtas replacement, eight-direction set, all-tier
migration, or Lineage M equivalence approval. Ground, winged floating and ranged
are declared families; only ground is implemented. Additional views, occluded
anatomy, other motion families and production integration remain outstanding.

Focused validation:

```sh
godot --headless --path . scenes/dev/SharedSkinPilot.tscn -- --pilot-test
python3 tools/animation/check_skin_pilot_parts.py
```

Contracts check shared pose identity, fixed limb lengths, stance contact,
run-to-attack continuity, planted weight transfer, far-arm response, attack-clock ownership, one strike per action, recovery
and skin-swap clock preservation. They do not approve visual naturalness.
`--pilot-capture` runs the complete 18-second idle/run/attack/swap/stop sequence
after a two-second warm-up. Movie Maker produces a fixed 30 FPS render, not a
real-time capture. Run without Movie Maker for separate wall-clock FPS results.

## Girtas appearance

Pass `--girtas-skin` to compare the warrior and Girtas on the same pose and
clock, including a mid-attack skin swap. The upper row is 1x; the lower row is
1.8x. This E-view binding uses the preserved r049 E-idle source cell, separated
into 14 visible parts by `build_girtas_shared_skin.py`. Its separate manifest
records the original sheet hash, polygons and two small copied armor joint caps.
These caps and the guard pose are newly authored, not recovered original anatomy.
The old blade and boot silhouettes are excluded from the body so they do not
remain behind the moving parts. Golden back ornaments are part of the armor;
this does not implement a winged or floating motion family.

The common motion resource is unchanged. A skin may provide fixed arm/leg
lengths, shoulder/hip offsets, ankle height and a wrist range for a long blade.
Retargeting preserves world-distance foot travel, contact timing and the shared
attack clock. It does not scale each frame, use separate animation frames or
change production movement speed. Girtas uses the production profile's fixed
0.219105 pixel scale for body parts; no silhouette bounds determine scale.
The long-blade wrist range reduces downward follow-through without shortening
or rescheduling the attack. Cape and hanging armor remain rigid cutout layers;
this is a visible limitation compared with fully redrawn motion.

The additional supplied general-running clip was inspected at 2.80–3.55s:
heel recovery, knee advance, opposite-arm response and restrained torso motion
are visible. It is a general movement reference, not an identified Girtas RUN
or proof of 90% equivalence. No reference-video pixels are redistributed.

```sh
godot --path . scenes/dev/SharedSkinPilot.tscn -- --girtas-skin
godot --headless --path . scenes/dev/SharedSkinPilot.tscn -- --girtas-skin --pilot-test
python3 tools/animation/build_girtas_shared_skin.py --check
```
