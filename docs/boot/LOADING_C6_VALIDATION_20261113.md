# C6 weight-validation loading work — 2026-11-13

Integration source: public main `04e07942dd78ed9360b17dea3e6c1fc63b38dd72` plus the already verified #460 source, locally combined at `a5f6b63f37efa8b1c9e9322c3271935ebe09d2b1`. #460 merge belongs to a separate task; this work does not merge it.

The weight-index validator used a full native-item expansion but consumed only `source_weight_unit`, `source_original_item` and `source_weight`. The private producer now explicitly opts its exact nested TemplateStore Script into a three-field expansion. Public/default binding, cached snapshots, generic/subclass providers, interning and malformed/missing-template fallback retain the prior provider path. A provider replacement cannot inherit an old opt-in. Fresh decoded fields remain independent; own overrides retain their previous aliases. No template cache is added. No reverse dependency from the shared field adapter to the item producer is introduced.

Original identity/row equality, exclusions, exact zero, integer policy, source-weight equality, overflow and rounding checks remain in `item_options.gd`. Only the expansion expression changes. The old uncached full expansion did not retain unused detail fields for future UI; removing that temporary assembly does not defer required work or change later public detail reads.

Verified local Linux headless / official Godot 4.7.2 evidence:

- Final fixture: 96 checks, no errors; cache-producer closure/key fixture 69 checks, no errors; existing bulk-weight fixture 13 checks, no errors.
- Frozen actual native-template fixture SHA `618d88797550b9db83e3581bb7a0236f7088958ff491d0eb68baddefa584e3f0`: all 30,331 nonempty records preserve complete bytes of the selected three-field projection. ABBA old/new/new/old field times: 3.603520 / 2.158320 / 2.228447 / 3.945368 s. This is a read-only fixture test, not production cache-key acceptance or startup timing.
- Earlier actual World ABBA weight-index diagnostic: old/new/new/old 8.167077 / 5.704125 / 5.399552 / 6.817537 s; every resulting 33,172-entry index SHA was `22d5ebf245ad47da14a8e81f69c705f0bfc53e931c58ee5675d48a41e53f6fa7`. That stage used an earlier opt-in implementation with a reverse dependency; its overall startup is excluded. The final explicit opt-in removes that dependency and passed the complete real-template comparison above.

Final full-startup first/next comparison and CI are pending at this source freeze. No whole-startup saving is claimed from the component measurements. Original definitions/maps/tiles/world-links stay private; no originals, saves or generated bakes are committed. Android/GPU and complete image/UI pack startup remain unmeasured. Original profiles and all prior evidence remain intact.
