# Aden worn courtyard edges — third PR84 resume unit

The original three overlapping courtyard ellipses produced visible concentric
boundaries. Aden's existing three paving areas now use one continuous, irregular
stone-to-ground fade with fine and broad edge erosion. Placement and existing
stone atlas are retained. Each courtyard needs one ground draw instead of three.
Independent materials follow classic/default visual mode changes and restore
their original palette. Non-Aden maps retain their earlier behavior.

Actual Godot 4.7.2 Linux llvmpipe OpenGL: 25 gameplay checks and 13 additional
style/placement/view/scope checks PASS. Unedited village, classic-style village,
ruins and northern-courtyard screenshots are included. Village before view is
reused from `../aden-polish-v3/after/01-village.png` at the same (2416,4112) position.
All gameplay/map/atlas bytes remain unchanged. No Windows/Android device runs,
original art restoration, Lineage M parity or main merge is claimed.

Remaining: paving material still has a visible repeat pattern; buildings reuse
one cottage image at multiple scales. Next: introduce compatible authored cottage
variants using the existing town building positions and collision footprints.
