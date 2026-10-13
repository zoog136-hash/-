# Official LineageM footage observations

Observed on 2026-10-13 from the verified files in `lineagem_references/01_actual_gameplay_video/`. This is a visual reference audit, not a claim of original sprite extraction, runtime integration, or permission to redistribute the footage.

## Method and limits

All four clips are 400×300 H.264. Their 60 fps container rate is **not an established sprite animation rate**. Full decoding previously completed without errors. Survey samples use 0.5-second spacing (`taitan`: 1 second); detailed samples select actual decoded frame indices and label their `ffprobe` presentation timestamps. A sampled pose establishes what is visible at that timestamp, not the exact first/last frame of an action or a server damage event. No interpolation or generated pose frames were used.

The compressed, composited footage includes effects, names and health bars. Camera movement and occlusion prevent reliable world-speed, root-position or hit-registration measurements. The visible people are not established as the two PC Lineage actors in the separate animation kit.

## Observed evidence

| File / timestamp | Direct visual observation | What it supports |
| --- | --- | --- |
| `warrior.mp4` 0.500 s | Axeman is upright, weapon down, feet spread on the same stone patch as the other samples. | A planted ready stance; not an attack windup. |
| `warrior.mp4` 1.000, 1.500–3.000, 3.500 s | Bright red/gold flash, then green vertical sparkles around the body; later another red/orange flash. Body remains substantially in place. | Status/effect pulses can animate independently of the body. The clip does not establish attack contact or recovery timing. |
| `taitan.mp4` 7.000 s, frame 420 | Right-hand `3P` swordsman has raised the blade over/behind the upper body. | Readable preparation pose. |
| `taitan.mp4` 7.200–7.300 s, frames 432–438 | Same swordsman lowers into an extended strike, blade crossing toward the central axeman; stance widens and torso leans. | A distinct strike pose after the preparation. Visible overlap alone does not prove the damage timestamp. |
| `taitan.mp4` 7.400–7.600 s, frames 444–456 | Torso returns upright and blade withdraws from the low extended pose. At 7.700 s the blade is raised again; 7.800 s shows another extension. | Visible return and next preparation, rather than holding the attack silhouette continuously. These are sampled transitions, not a measured universal attack period. |
| `taitan.mp4` 11.000 s | Red/white ground-level burst appears with the text `Miss`. | Effect timing is not sufficient evidence of successful damage. |
| `desperado.mp4` 1.700 → 1.800 s, frames 102 → 108 | Small left-hand figure is distant at 1.700 s and beside the axeman at 1.800 s; a bright remnant remains at the previous location. | Abrupt relocation in this skill demonstration. There is no sampled intervening walk/dash pose, so this must not be described as a measured running animation. |
| `desperado.mp4` 1.800–1.900, 2.000–2.100 s | Axeman is leaned forward beside the relocated figure, then visibly upright again. Red glyph/effect remains over the nearby figure. | Body recovery and a longer-lived target effect are separately readable. |
| `desperado.mp4` 2.500 → 2.600 s, frames 150 → 156 | Axe is raised overhead, then extended low toward the adjacent figure; strong light/glyphs partially hide contact. | Distinct preparation and strike silhouettes, with uncertain exact contact. |
| `charge.mp4` 3.300 → 3.400 s, frames 198 → 204 | Two characters are separated; a red vertical enclosure appears around the left character. | Target effect precedes the close approach. |
| `charge.mp4` 3.500–3.700 s, frames 210–222 | Axeman changes stance while the displayed countdown reads `0.3`, `0.2`, `0.1`; a star-shaped flash is already visible at the target at 3.700 s. | A visible cue before arrival; the flash must not automatically be treated as collision. |
| `charge.mp4` 3.800–3.900 s, frames 228–234 | Character separation collapses, a pink directional streak appears, and the countdown reaches `0.0`. Background/pillar also shifts across the screen. | A brief approach/dash presentation. Camera scrolling makes raw screen displacement unsuitable for a world-speed estimate. |
| `charge.mp4` 4.000–4.100 s; 5.000 s | Close-range weapon/body pose is followed by a large bright burst; by 5.000 s both figures remain adjacent and the red enclosure has cleared. | Arrival/attack and later effect clearing. No precise recovery duration can be isolated from these samples. |

## Foot-plane and rhythm observations

In `taitan.mp4` 7.000–7.800 s, the swordsman's torso, arms and blade change markedly while the feet stay associated with a small, consistent patch of the floor pattern. The leading leg extends during the strike and the body returns; this is not evidence for uniform whole-sprite scaling or continual hopping. In `warrior.mp4`, conspicuous light pulses occur without comparable root travel. These clips provide no clean, sustained eight-direction walking cycle.

## Proposed tuning — interpretation, not measured source values

- Keep preparation, strike and return visually distinct; preserve the supplied per-frame durations where actual source action data exists.
- Anchor each frame by its supplied foot/root offsets. Give weapon reach and body lean their own pose changes rather than translating/scaling the entire character for every attack.
- Gate damage on validated action markers or game logic. Neither bright flashes nor floating combat text proves an exact contact time.
- Treat skill trails and target effects as separately timed layers. Use an explicit arrival condition for any implemented dash; the footage does not justify copying a numeric speed, countdown duration, or universal attack cadence.


Inspection montages remain in the authorized research folder outside the Godot project. No official footage/images are redistributed in this change. Source file links and hashes: [reference-inputs.json](evidence/reference-inputs.json).
