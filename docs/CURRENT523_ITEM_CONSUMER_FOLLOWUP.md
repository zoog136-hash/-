# Current523 item consumer follow-up

Continues the remaining PR269 work from main5db920332f9298b4fc1f70713dde11740c91a7d2.

The original-use five-field API now routes a genuinely owned quest-issued
ItemClass310 to the existing quest_cure310 owner, after authenticating the full
original ItemClass row, actual physical ID, immutable quest receipt and expected
remaining quantity. The owner still checks its exact310/Buff27 source contract,
poison, locks, source conditions, cooldown and selected debit, commits once, then
uses its existing single visual event. No new grant, raw-key conversion, duplicate
debit, effect implementation or event is introduced.

UNVERIFIED: no new tests, parsing, game execution, rendering or CI were run under
the standing user instruction. This connection does not increase the historical
58/146 reviewed count or reduce the88-class baseline. Existing original inputs,
packs, saves and workspaces remain preserved. Other remaining consumers/effects
continue in this PR. No main merge is requested by this checkpoint.
