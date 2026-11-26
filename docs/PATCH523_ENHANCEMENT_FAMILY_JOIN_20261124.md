# Native 523 enhancement family join

The compilation catalog exists for crafting. It is not the authority for
whether an owned original item is an enhancement scroll or target. The native
path now verifies current ItemClass identities, then resolves 2032 equipment
groups / 2022 and blessing-keyed 8352 scroll groups directly from the pinned
523 definitions. It reuses the existing exact stage probability, four outcomes,
blessing, consumption and cost interpreter. The selected inventory receipt and
save transaction are unchanged. Existing seal and expedition owners retain their
narrower contracts. Existing TWILIGHT interpretations (such as one scroll when
the raw amount is 0) remain separate from original numeric data.

- The exact ItemClass group joins in the audit cover 2,146 structural candidates.
  This is not a count of items granted, targets permitted by date/region, or all
  blessing/level combinations. A missing or competing stage never guesses a
  different family's odds. Tests and source-declared exclusions stay protected.
- 795 items have an original stat-at-rank relation, but no audited equipment or
  scroll declaration for an executable enhancement. Stat-at-rank is not evidence
  for a consumable, outcome, cost or cap.
- 17 IDs still lack original inputs, enumerated in
  `PATCH523_PHYSICAL_ENHANCEMENT_20261124.md`. The seven event families' public
  stage view has only stage, server and unbroken flags; it does not contain
  the missing four outcomes. Similar group names are not probability evidence.

Rebuild the test input locally with:
```sh
python tools/patch523_enhancement_family_matrix.py <pinned-523.zip> /tmp/native-enhance.json
TWILIGHT_TEST_ENHANCE_SOURCE=<pinned-523.zip> TWILIGHT_TEST_ENHANCE_MATRIX=/tmp/native-enhance.json godot --headless --path . --script tests/patch523_enhancement_family_test.gd
```
There are 71 paired, unique exact groups. Of the other seven groups with
complete numeric stage rows, 61/164/182/192/233/243 do not have a non-test
target declaration and 538 has neither a non-test target nor a scroll.

## Nonwearable event targets with published odds

There are 50 paired groups with a usable physical equipment and scroll
projection. The other 21 paired groups have valid numeric rules, but all 60
associated non-test target ItemClass IDs have **zero** original ItemEquipSlot
rows. The item categories and ItemEnchant relations establish an enhancement
use, not an equippable slot. Existing native storage receipts cannot store a
rank and can represent multiple units, so mutating that receipt's item rank
would expand the effect across units and fail owner checks. The equipment
route remains closed on such targets until there is a dedicated nonwearable,
single-target native owner with denomination, receipt and reload tests.

Affected groups:
462, 472, 482, 492, 533, 543, 561, 571, 584, 594, 608, 618, 663, 673,
688, 698, 708, 743, 753, 763, 851. These are distinct from the 17 IDs
lacking exact probability/group inputs; the obstacle here is physical
representation, not odds.

For release evidence, use both the source matrix test (71 exact quotes,
50 accepted physical families) and the Main scene test with the unrelated
crafting book intentionally empty (physical receipt, write failure, successful
enhancement, original destruction, charge, and stale request check).
