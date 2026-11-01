# Shared 2D skin pilot

Run `scenes/dev/SharedSkinPilot.tscn` in Godot 4.7.2 (F6). The first row is
1:1 pixel size; the second shows the same pose at 2.6x. Space moves/stops,
A attacks, S swaps skins, and L adjusts the shared swing height.

Both appearances use one pose dictionary: distance-driven legs, a restrained
chest/shoulder response, upper arm, forearm, hand/weapon, and following cape.
The idle chest moves by 0.25 pixels over a 2.6-second cycle while feet and
shadow stay fixed. These are authoring values, not measurements of Lineage M.
Run/stop blends cover the upper body and feet; starting an attack blends from
the previous pose rather than snapping to a separate ready stance.

Attack preparation, planted strike, follow-through and recovery coordinate the
pelvis, chest, shoulder and arm. The scene samples the existing unmodified
`TwilightActorMotion` attack clock and its slash marker. The visual resource
never emits damage or changes elapsed time. The demonstration uses 0.72 seconds,
the existing world's unbuffed normal attack interval. No combat or movement
code in Main is changed. Skin replacement during an attack preserves its clock.

The original warrior/assassin sheets remain untouched. The reproducible mask
builder and manifest describe 30 source cutouts/derived layers, source SHA-256,
fixed joint bindings and explicitly authored armor underpaint behind exposed
arms. The near arm has two fixed-length bones; skin widths are fixed bindings.
Head/torso/pelvis overlap around joints instead of scaling the whole silhouette.
The assassin's visible rear hand/dagger is rebound to the near wrist, with the
old blade removed from the torso mask. This is new skin authoring, not recovery
of hidden anatomy or an original game's skeleton. Far arms remain in the body;
capes use rigid overlapping cutouts rather than cloth simulation.

Reference review used the supplied expanded video archive: Girtas idle
0.00–1.05s; myth footage 02 idle 6.50–7.85s and attack from 8.00s; myth footage
03 left melee attack 0.89–1.38s. The visible preparation, body/shoulder/weapon
coordination and return informed this batch. Green projectile-like effects in
03 do not make that sword action a bow attack. Footage 04's short approach is
not a complete ordinary RUN cycle. Converted video frame rates do not establish
original animation cadence. Reference video pixels are not copied into assets.

This remains an **E-view ground pilot**, separate from the production actor
renderer. It is not a completed Girtas skin, eight-direction set, all-tier
migration, or Lineage M equivalence approval. Ground, winged floating and ranged
are declared families; only ground is implemented. Additional views, occluded
anatomy, other motion families and production integration remain outstanding.

Focused validation:

```sh
godot --headless --path . scenes/dev/SharedSkinPilot.tscn -- --pilot-test
python3 tools/animation/check_skin_pilot_parts.py
```

Contracts check shared pose identity, fixed limb lengths, stance contact,
run-to-attack continuity, attack-clock ownership, one strike per action, recovery
and skin-swap clock preservation. They do not approve visual naturalness.
`--pilot-capture` runs the complete 18-second idle/run/attack/swap/stop sequence
after a two-second warm-up. Movie Maker produces a fixed 30 FPS render, not a
real-time capture. Run without Movie Maker for separate wall-clock FPS results.
