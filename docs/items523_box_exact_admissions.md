# Original 523 reward-box recheck

Scope: the 270 native direct-handler gaps in LuckyBag (217), SelectReward (47)
and ComplexReward (6) from the November 24, 2026, 1,422-row audit. Source
archive SHA-256:
`d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`.
Related named or similar items are not treated as substitutes for a missing
exact edge or excluded reward.

## Exact admissions

- **307781**: Korean StoryDesc 2066161 and [NC's December 4, 2024
  fishing-exchange notice](https://lounge.plaync.com/feed/17105) confirm
  selection on use. Its four actual Reward rows grant separately one of the four
  existing coin wallets, 10,000 to the selected wallet only.
- **289702**: StoryDesc 1844122 confirms selection on use from four
  nested coin boxes. The outer box yields one existing supported child box;
  it does not directly pay coins or roll the child box.
- **164623, 164633, 167404, 167424**: source ComplexReward branch type 4
  has a guaranteed label and exactly one output, and branch 14 has a choice
  label and cardinality one. The respective StoryDesc confirms a guaranteed
  output plus one selection. Quote never pays either. Confirmation stages the
  fixed and chosen outputs with the single physical input debit and existing
  save writer. The existing optional local initial +0 and original-date
  rotation rules still govern; strict original-date mode refuses expired
  guaranteed outputs. No dates, chances or initial levels were changed.

## Remaining direct-handler gaps

| Category | Count | Main blocking fact |
| --- | ---: | --- |
| LuckyBag | 196 | No positive LuckyBagClassID (157 delete-time only, 36 no bonus rows, 3 class interval plus delete time). |
| LuckyBag | 1 | #168084 joins group 38274 with no reward entities. |
| LuckyBag | 1 | #8951 is a stateful 7-use cube, not a one-shot box. Source StoryDesc 222101 confirms final reward after seven uses; the source also has a 36,000-second interval. No matching per-instance cycle owner. |
| LuckyBag | 6 | #178282, #178292, #178302, #178312, #178322, #178332, legacy timed operations apologies with guaranteed and FinalReward chain edges. No matching stateful timing owner. |
| LuckyBag | 9 | #96114, #122271, #126682, #134832, #138243, #150594, #152513, #245961, #338562, no exact eligible known payout once source test/exclusion rows are honored. |
| LuckyBag | 4 | #373971, #373981, #374468, #374678, original selectable pools contain test/excluded items; not silently shrinking the choices. |
| SelectReward | 40 | Empty eligible selection after source test/exclusion handling. |
| SelectReward | 1 | #259374 has no SelectRewardClassID edge. |
| SelectReward | 1 | #307971 documents one nested box but has an archived date reference; its separate root timing-2/leaf timing-1 path and event recurrence are not admitted by the confirmed no-date cases. |
| SelectReward | 2 | #189834 and #353592 are acquisition-life selectors (24h and 72h); existing approximate sweep is not an exact quote/claim acquisition ledger. #353592's two outputs also need clan-buff use ownership, not a direct substitute or a coin wallet. |
| SelectReward | 1 | #215222 has five intact choices and source territory class 10672; the Nagvas altar-state choice exclusion still needs an in-game owner. A location-only gate is insufficient. |
| ComplexReward | 1 | #164643 lists all 29 choices; 21 are original test rows. Cannot silently reduce the original chooser to the eight remaining rows. |
| ComplexReward | 1 | #165633 expired in 2020 and contains two choice branches, one all-test. The one-branch rule does not apply. |
