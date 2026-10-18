# PR122 batch11 — source authoring, strict refusals and original-source recovery

This batch does **not** complete the remaining 106 species. New final approvals:
**0**. The historical 392 completions and 394 runtime bindings are preserved.

Albino Monk was independently authored from its existing project atlas reference
while Deer, Servant and the earlier HOLD subjects remained separate. Its planned
contract is idle2/walk6/attack3/hit2/death3 × eight directions = **128** poses.
No required motion or direction was removed to fit a smaller source contract.

## Actual source results

Fourteen whole PNGs were generated, **35,587,051 bytes**. The unmodified importer
accepts eight files containing 58 source slots geometrically and refuses six:
idle, E/SE attack, and all four walk sheets. E/SE walk contains only eleven
separated bodies for twelve required slots; other rejected rectangles contain
pixels from neighboring bodies. These failures are retained in result.json.
Geometric acceptance does not approve identity, gait, contact or animation.

Eight new independent single-body E idle/walk PNGs were then authored. They
avoid neighboring-pose contamination, but every original fails the existing
strict eight-neighbor alpha>100 single-body rule because of isolated pixels.
Opposite support and frame-to-frame model/camera consistency also remain HOLD.
All raw sources are unchanged and preserved with exact requests and SHA.

The existing `tools/pr122_unicorn_alpha_microrepair.py` function was reused with
its **unchanged** max-island3/max-total11 budget. Three unapproved derivatives
change just 8, 3 and 2 isolated pixels, with the original main body's RGBA exact.
Five cases are explicitly REFUSED. No threshold/budget was increased, no body
part was removed, and these derivatives count as **zero new motion poses**.

No complete approved source matrix exists. No new Monk SpriteFrames or runtime
binding is installed; new Monk Main, complete gameplay and Android are NOT_RUN.
An incomplete matrix cannot be made complete by copying successful slots,
omitting directions, reusing an incompatible body, or reducing walk6 to walk3.

## Existing original archives were searched

Google Drive's existing TWILIGHT archive was located and the stored source kit
was actually downloaded: 26,775,284 bytes, SHA-256
`99dd0cb2f02da039b56923b9f3b947ed7ef4f73843d7f4e0c0dcdd7006b98a98`.
CRC, its file SHA manifest and all **3,512** reconstructed native RGBA frames
were verified. Its two bodies are21624/21653, named reboot high dragonknight
male/female, including original chain-sword walk8/runL8/runR8 and action ticks.
They are **two bodies**, not eight: shadows and clothing layers are separate.
They do not establish full498 source coverage.

Those bodies resemble the transform142/411 references, but no authoritative
TWILIGHT identity mapping was established. The user was asked for an existing
mapping/additional original source location; no substitution was made. The
existing source report also distinguishes static illustrations and gameplay
videos from a complete transparent eight-direction original actor set.

Original game PNG/SPX/ZIP bytes remain outside the public checkout. Only the
recovery receipt, hashes, action counts and status are committed here. Existing
Drive permissions were not changed; no source was declared publicly licensed.
The receipt contains canonical Drive IDs/URLs, never temporary download tokens.

## Concrete continuation

Keep the existing approved assets and exact source guards. For Monk, author
the missing complete gait/idle/E-SE impact matrix with one connected body,
stable model proportions and the true opposite support sequence. Reuse the
58 accepted source slots only after their independent appearance/chronology
review. The three microcandidates remain unapproved and do not fill missing
slots. Do not modify existing104/112 contracts or lower any failure threshold.

For native original bodies21624/21653, establish exact target identity and the
permitted private-pack delivery/CI path before connecting a named transform.
The verified kit already contains originals; do not ask for it to be uploaded
again. Preserve the source tick order and native offsets if integration proceeds.

Resume from the actual remote PR122 HEAD in a new isolated worktree. Run:

```bash
python3 tools/check_resource_integrity.py --root .
python3 tools/audit_pr122_recovery.py --root . --output /tmp/pr122-new-reconciliation.json
python3 tools/check_pr122_locomotion_source_controls.py --root . --output /tmp/pr122-new-controls
gh workflow run pr122-locomotion-source-preview.yml --ref feature/twilight-remaining106-20261016
```

Use fresh output paths, a fresh exact-SHA CI snapshot and the latest continuation
JSON. The source preview workflow verifies the already preserved Doguri/reaper
Main trials; it does not approve these failed Monk/Deer sources. Android remains
NOT_RUN. No main merge, force push, reset or approved-asset replacement occurred.
