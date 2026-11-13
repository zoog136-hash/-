# Inventory header refresh without rebuilding live slots

Base: main `7884db9890aa78846f8f69d554b6f53bac0d367f` (PR #472 merged after all four checks passed). Work is isolated from exchange, character creation, original resources and save data.

## Concrete cause and change

`renewal_inventory.set_character_state` updates currency/weight labels, then fingerprints equipment, ammo, enhancement, instances and locks. A change confined to gold/current weight/max weight/carrying capacity does not dirty or rebuild the owner's rows. The native HUD nevertheless included those four values in the same signature that called `source_main_inventory_view.refresh()`. That builds a replacement Inventory_All scene, every authored slot row and its icon bindings before retiring the old scene. Thus a header-only change could recreate the entire open bag even with warm resource caches.

The HUD now retains a second integer signature excluding only these four header values. All other row/layout/selection inputs remain in that signature. When only the header differs, the existing chrome bindings refresh the live scene; slot nodes, icon owners, playback, scroll position and hit controls remain in place. The existing public chrome snapshot contract (including independent inventory/row copies) is preserved. No new texture cache, item cap, frame skipping or quality change is introduced.

The fast path verifies the manifest identities and existing optional gold/capacity source scope. Added/removed fields, invalid bindings or failed text updates return to the full transactional rebuild/fallback. Equipment, lock, item-model, filter, search, columns, external selection and icon re-registration keep the full refresh. Native selection acknowledgment updates the new baseline. Active gestures still defer work. A pending refresh no longer acknowledges a model it has not presented, so the next available frame retries it.

`ui.inventory_chrome` is a separate inclusive detail timer; `ui.inventory_stage` continues to cover the full construction. Neither should be summed with an enclosing HUD section.

## Validation and measured scope

Godot 4.7.2 headless:

- New `source_inventory_header_refresh_test`: **341 checks passed**; real HUD polling, view fast path, chrome snapshot and `sprite_scene` visibility/text setters, physical slot ownership and production renewal owner setter. Full CSB scene construction and font rendering are synthetic/counting substitutes.
- Differential 64-item fixture, both 4 and 8 columns, twelve gold/weight changes: previous routing performed twelve additional full stages and allocated 768 fixture slot nodes; new routing performed zero additional full stages/slot allocations and no additional owner-entry reads. Header/tab values remain equal, live slot identity/selection, z order and scroll are retained. These are operation counts, not device milliseconds or whole-game RAM savings.
- Changed row state, input capture/release, native selection then header update, pending retry, icon replacement, close/reopen, missing/added/removed optional fields, text failure and manifest mismatch are exercised.
- Existing selection acknowledgment 907 checks, inventory snapshot 983, quickslot identity 527, row work 115, UI memory lifecycle 210, HUD 6, quest 30, frame hitch 26 and draw phases 205 passed. Actual Main save/reload 33 passed in the available absent-install source-pack context.
- Python CI staging tests: 14 passed. Clean staging import succeeded; tracked-resource guard: `NO_LEGACY_RESOURCES ok tracked=20`.
- Historical `tools/check_resource_integrity.py` and `data/resource_delivery_ledger.json` named by older rules are absent on current main. The attempted historical command reports file-not-found; current tracked-resource guard and remote resource CI are the applicable available evidence. No art files are added or changed.

Private reproducibility evidence in this executor: `/workspace/twilight-inventory-header-validation/` contains stage, import log, focused logs and summaries. Remote CI checks the committed test through `tools/ci_core.py`; use the PR's exact head checks for its final status.

## Device and reference limits

The supplied image was previously materialized and visually verified: loading screen 523.447 reports **previous execution 523.445@447ed69f**, 1,491 hitches, maximum 9,213 ms; unmeasured 8,866 ms, skills 213 ms, player 104 ms, inclusive inventory stage 337 ms once, callback before/between/after 245/18/8,949 ms. The 337 ms stage is not evidence that it caused the 8,949 ms callback gap. We have no matching full hitch JSON/logcat/Perfetto capture. This change does not establish the cause of that gap, or claim to resolve all Android lag/crashes.

Original Windows static report `SPRITE_CACHE_LIFETIME_REPORT_KO.md`, re-read from the retained report, traces RawSpriteFile hit `01C74AB0` to LRU movement/strong return without reader/parser, and completed Graphics ownership surviving raw expiry. That supports preserving usable owners generally; it does **not** establish an original inventory header algorithm. XP Hero's previously verified IL2CPP pool/cache metadata is likewise structural evidence, not execution timing or this implementation. The header path here is a TWILIGHT-specific correction based on its actual owner contract, not a copied native function. Native refcount constants, raw 64 MiB accounting and Unity GC settings are not imported.

Android device performance, full installed original CSB pack traversal and original-font pixel equivalence were not tested here. The implementation changes update routing, not rendering commands, source assets, game/save ownership or resource revalidation policy. Full bag opening and true item/row changes still rebuild synchronously and remain candidates for finer phase measurement; they are not solved by this header optimization.
