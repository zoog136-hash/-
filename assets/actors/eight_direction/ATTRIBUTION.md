# Eight-direction knight / skeleton sprites

Source: [Flare Game](https://github.com/flareteam/flare-game), revision
`af6eee6d339ac98011864bfe89da837fe7769c28`. Art by Clint Bellanger and the
Flare contributors; skeleton sword concept by Misha (CC BY 3.0).
The supplied 2D PNGs are licensed under **CC BY-SA 3.0** (later versions allowed).
These adapted atlases are distributed under the same license; see
`LICENSE-CC-BY-SA-3.0.txt`, `UPSTREAM-CREDITS.txt`, and
[upstream per-file credits](https://github.com/flareteam/flare-game/wiki/Credits).

Changes: selected stance/run/swing/hit/die frames, combined the seven knight equipment
layers using upstream direction-specific drawing order, retained the source
foot offsets, uniformly reduced pixels to 50%, packed onto transparent 256px
cells and mapped source directions to Godot screen coordinates. No synthesized
view, mirrored weapon, repeated image presented as a new pose, or new 3D render.
The upstream PNGs were originally rendered assets; this project consumes only
the already published **2D sprites**. No model / 3D scene is used or delivered.

This is an openly licensed TWILIGHT visual adaptation, **not Lineage or
LineageM original art**. Black plate armor, one-handed sword and shield identify
the selected existing `transform:46` 흑기사; a sword/shield skeleton identifies
the existing `monster:해골 근위병`. Their previous illustrative details are not
an exact match. Other transformations and monster identities are not replaced.

`tools/build_open_sprite_sample.gd` reconstructs the runtime files from the
pinned PNG / text inputs listed by hash in `source_receipt.json`. Only runtime
atlases and native SpriteFrames are included. `provenance.json` records genuine
unique poses separately from the back-and-forth idle playback order.

Source stance/run durations are Flare timing, not evidence of Lineage timing.
TWILIGHT's existing attack interval and hit ratio remain authoritative; frame 2
is the chosen contact pose. Only visual playback is fitted around that marker.
