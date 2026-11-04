# Current523 card UI and collections

Production card menus use402 transformations,171 dolls and147 relics. Collection views use1793 game-deck sets,5059 member rows and2052 reward rows. The four empty test-deck sets never enter completion. Existing701 `source:m508:<deck>:<card>` identities remain stable; new19 use `source:m523:<deck>:<card>`, consistent with PR231. `base508:collection:<set>` identities remain stable; saved acquisition/spare/RNG state and automatic, non-consuming collection registration are unchanged. The original508 metadata and verified actor bindings remain available unchanged for existing tooling, playback and regression tests; current523 declared sprite IDs are recorded separately.

A collection's deck does not determine its members' decks:32 current member rows point to transformation cards inside doll collections. Runtime validation, card inspection, copy counts, live refresh and the focused-card entry use each exact member identity. Reset returns to the complete originating category. Sets with identical card requirements retain distinct set IDs/rewards; effect filtering and displayed totals distinguish bonus type, application type, target and unit. The138 class/gender variant rows remain metadata on six cards, never138 extra acquired cards.

The existing card-menu collection tabs open the view. Added controls provide an effect filter and an effects/status toggle. Long effect menus have a bounded, scrollable popup so release of the opener does not immediately choose a covered item. Status shows permanent card acquisitions and completed collections. Eleven current523 StringTable/CSB bindings drive the adapted Godot controls. Source positions/animation durations and designer example numbers are not treated as game rules. Missing external portraits/atlases retain explicit missing-image states.

Server context and exact option-awakening conditions remain required where declared. Unsupported spell/tag/damage-option effects and HP-interval references remain visible and blocked rather than being flattened into unrelated stats. HP branches preserve their original bounds and typed child rewards. No native server profile, interval rounding rule, card cost/probability or missing original pixel is invented. New card option/skill-awakening definitions and new actor pixels remain separate integration work. The new metadata does not enter existing draw/fusion pools. PR231 now overlaps the shared catalog/native recognition helpers; the final catalog index deduplicates exact source IDs and preserves supplemental readiness fields. Resolve overlapping helper changes together without changing either saved identity namespace.

## Reproduction

Inputs are external Library artifacts, materialized and byte-checked in the consuming environment:

| Library file | Bytes | SHA-256 |
|---|---:|---|
| `libfile_f3e9e5b322cc8191ae441565bbd24c27` |25031173|`d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`|
| `libfile_c8d83aa179148191ba0a70dc3b947597` |365186|`8346479fd35be76b8b5e082571af11715ef077b9d9490f7f1de78a945ac5c860`|
| `libfile_0ba507ea27888191b60532f6aa6b6ff0` |25261734|`6e5c636cabe48ab8d4aa4a5d6d26122c3300ca65789568668335b71fdb386d91`|

`tools/build_patch523_cards.py` takes `--source`, `--baseline`, `--evidence`, `--catalog-output`, and `--collections-output`. The baseline is `data/lineagem_base508/cards.json`; evidence is `all_collection_requirements_bonuses523.json` from the collection artifact. `tools/build_patch523_card_ui.py` takes the extracted UI artifact's `--evidence-root` and `--output`. Generators verify source hashes and exact row/node joins. Git contains code/derived metadata; source archives, private pixels and captures stay external.

Focused tests are `tests/patch523_card_collections_test.gd` and `tests/patch523_card_collection_ui_test.gd`. The latter runs actual Main with an explicitly verified current source-map pack in `TWILIGHT_SOURCE_MAP_PACK`; optional `TWILIGHT_CARD523_CAPTURE` selects a local capture folder. Use an isolated XDG data directory. Tests exercise both1280×720 and854×480 windows, physical UI input, real list filtering/status, cross-deck ownership/copies, focused reset and unchanged save bytes. Original-art equivalence and Android execution are separate checks.
