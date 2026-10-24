# Windows Aden load failure after CI recovery

Failure: https://github.com/zoog136-hash/-/actions/runs/40071598290/job/120806020686

The working branch fast-forwarded from cbd42cc4 to remote 45e334f1 before this fix, preserving b7c4cd2b and merge 043a09b8. No CI recovery or PR152 navigation change was replaced.

`production Aden field missing` was not a missing A3 definition. The test's diagnostic checks an older A3 definition, while ordinary Main now attempts Native PNG first. `world._set_map()` returns before assigning any field if Native PNG rejects its plan. The subsequent eight-direction clearing failure is a consequence of that null field.

Recovery commit b7c4cd2b added `apply_navigation_corrections()` to the shared PNG plan loader. It authenticates `domination_png_plan.json` before loading *any* PNG map. Existing attributes protected native_png and aden_faith_png plans, but not this Domination plan. Git `core.autocrlf=true` converted its LF bytes to CRLF on Windows, making the shared plan empty and Aden loading fail.

Minimal comparison, same Godot 4.7.2 Linux environment and installed packs:

| Registry | Domination plan bytes | Shared plan / Aden load |
| --- | --- | --- |
| 45e334f1 | LF | success / success |
| 45e334f1 | CRLF | rejected / null |
| cbd42cc4 (before recovery) | CRLF | success / success |

Original LF SHA: `80db63cde9dba6dc0ca4b33e4f12d40c1f108a8f77a87a420fec0eb6e778fea4`.
CRLF SHA: `7dcc8b6f47e73b6509a29a7fe30b47e689fdd316a8d5ccf571d7ba23ed693a52`.

This identifies the new shared hash gate as the trigger for the Aden regression, combined with a pre-existing missing checkout attribute. It is unrelated to the manually reviewed Aden collision changes. It does not establish that Domination itself worked on Windows previously.

Fix: add `data/maps/domination_png_plan.json -text` to `.gitattributes`. Do not normalize files at runtime, relax SHA checks, replace terrain, remove assertions, or change gameplay/CI workflows.

`tools/test_authenticated_map_checkout.py` creates an isolated Git repository, stages the real three authenticated plans and current attributes, switches to `core.autocrlf=true`, deletes the working files and performs a real `checkout-index`. Before the fix only Domination fails its expected SHA. After the fix all three plans match exactly. This exercises Git checkout behavior on Linux; it is not a Windows engine execution. The remote Windows job must confirm the complete platform run.

Focused unchanged Godot tests: original_based_spear_captain_gameplay_test and native_png_route_recovery_test PASS (2/2, skip0). Initial diagnostic runs emitted user-data-directory errors due to unset XDG paths; clean isolated-XDG replays reproduced the identical result matrix, and those clean logs are archived here. Full original logs remain under /workspace/windows-aden-diagnosis.
