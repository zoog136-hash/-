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

All skins consume the common motion resource. A skin may provide fixed arm/leg
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

## RUN correction after the first Girtas preview

The first binding preview was rejected as walking: its contact interval exceeded
half a cycle, its six-pixel recovery stayed low, and the 46-pixel stride was short
for Girtas. The development scene also ran at 80 px/s rather than the existing
Player/Girtas reference speed of 210. Production movement code was never changed.

`configure_run()` selects a shared RUN preset for both skins in the Girtas demo:
84-pixel stride, 44% contact per foot, a short unsupported interval, curved heel
recoil/recovery and forward extension, stronger opposite-arm response, and a
restrained forward torso posture. A Hermite return joins the stance's horizontal
velocity at toe-off/landing. The loaded pelvis is 4.5 pixels lower than idle;
its flight rise is bounded to 0.8 pixels. Run/stop blends include the pelvis so
this posture change does not snap. Fixed bone lengths, actual displacement and
attack timing remain unchanged. These are authored tuning values informed by
the supplied ordinary RUN and male-elf clips, not claimed original measurements.

The comparison re-renders the previous c630cdf gait and the corrected gait at
the same 210 px/s, 30 FPS and view scale. It does not accelerate the old uploaded
80 px/s video. The earlier v0 remains in Library history. The existing two-skin
default demo and all source/art bindings are preserved; RUN is a shared preset,
not a Girtas-specific set of replacement frame images.

The rejected first RUN preset overemphasized leg recovery while retaining an
almost fixed chest. The current pose has separate counter-rotating pelvis and
chest channels, a small shoulder-girdle displacement, opposing arms and head
counterbalance. Skin bindings apply the pelvis angle to hip roots and the waist,
so the leg IK and upper body respond together while stance feet stay on their
world-distance path. Recovery height is ten pixels and flight occupies a short
part of the cycle; it is not used as a visual-quality pass criterion. New channels
blend out into idle and the unchanged attack poses. The supplied male-elf clip
is shown at normal playback speed beside the result, with differing direction
and appearance labeled. Rigid armor/cape layers still limit the torso's depth
and perspective change compared with redrawn animation.
