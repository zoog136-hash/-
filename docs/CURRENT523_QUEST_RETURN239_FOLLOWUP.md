# Current original quest-return connection — UNVERIFIED

PR281 continues from d978e888. The existing original-use API authenticates the
full original ItemClass row, physical ID, immutable receipt and expected remaining
quantity before routing ItemClass239 to consumable_service.use_owned_quest_return.

quest_return239.prepare now requires the actual current original definition and
identical source ItemClass239 row instead of the old38ee BIN. The existing common
quest_reward_consumption.stage builds inventory/physical/use-quantity/quest-state
changes with the current archive identity, retaining historical receipt proof.
current() also authenticates that staged quantity payload. There is no live
materialization, rename, regrant, second debit, new movement or destination rule.
The existing return owner owns admission and the one movement/receipt save.

No new tests, parsing, game, rendering or CI. This is an unexecuted implementation,
not proof of real use or a change to historical58/146 and88 remaining. Saves,
originals, packs and old worktrees are preserved. Only code/docs are published.
