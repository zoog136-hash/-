# Floor pickup: ask for the targets the player can actually use

The manual pickup button used the first of a completely sorted set of visible drops; automatic pickup only tries the first eight. Both now scan once and retain the exact one or eight candidates. Rank preserves the current hunt batch, distance rounded to tenths, grade descending (unknown last) and exact ID. Each drop is revalidated; no cross-frame result reuse, pathfinding delay, changed pickup odds or speculative work at boot.

**Other-game comparison:** [NetHack 3.6.7, dog_goal, lines 476–525](https://github.com/NetHack/NetHack/blob/NetHack-3.6.7_Released/src/dogmove.c#L476-L525) checks floor food against the best suitable goal so far instead of sorting the map's objects. This is a comparison of selection work only: TWILIGHT keeps its own radius, priority, cooldowns, actual-grant checks and eight auto-path candidates. No external code or images used. Neither this source nor the mobile JSON proves the original Lineage M pickup implementation.

## Reproduction

Run `tests/ground_pickup_shortlist_test.gd` with isolated XDG_DATA_HOME. Set TWILIGHT_PICKUP_RANK_BENCH=1 for 100 alternating paired repetitions per density; TWILIGHT_PICKUP_UNCAPPED=1 removes the cap **only for the test**. Both suites passed 1,249 checks. The independent reference reproduces the replaced full sort. Real Main, floor Button views, player and acquisition handlers, exact bag delta/removal, and next-target sweep; controlled empty walkable geometry, no GPU, no Android, no active monsters. Counts below denote persistent surrounding drops plus one collectable target at the player's feet. Measurements start at the actual pickup handler, not touch hardware. Frame wall is handler start to next engine process-frame signal, not presentation time. No cost was moved to another phase.

Times in milliseconds: median / p95 / maximum, before → after. Bands show exact counts out of 100 before → after. No frame or action sample exceeded 50 ms in either experiment.

| Surrounding drops | cap | button CPU | button to next frame | frame >16 to 50 |
|---:|---:|---|---|---|
|4|none|1.02/2.26/3.68 → 1.04/2.17/2.76|9.66/12.75/37.04 → 9.67/13.03/20.50|1 → 1|
|32|none|2.05/3.65/4.96 → 1.25/2.07/6.28|9.43/11.08/20.45 → 9.70/11.22/12.53|1 → 0|
|128|none|7.56/16.19/18.01 → 2.12/4.34/8.03|11.45/23.16/26.46 → 7.38/10.70/19.12|13 → 1|
|4|60|1.02/2.49/3.60 → 1.01/2.28/4.99|19.83/23.66/29.43 → 19.88/24.77/28.85|99 → 99|
|32|60|2.03/2.62/3.68 → 1.27/1.80/2.44|19.71/22.62/36.31 → 19.67/20.84/23.37|99 → 99|
|128|60|7.34/11.23/16.32 → 2.23/3.32/4.58|19.70/21.17/33.20 → 19.79/21.37/25.02|98 → 100|

128-drop uncapped isolated selector CPU alone fell 3.21/5.14/7.98 → 0.61/1.17/3.91. Actual uncapped button CPU over 16 ms fell 7 → 0; 60-cap button CPU 1 → 0. Four drops: no reliable gain. Automatic and manual ranking both matched the reference across batch, cooldown, ownership, position, grade/distance and ID ties; timing is manual acquisition only.

**Acceptance:** CPU headroom improved with dense loot; normal capped headless next-frame wall did **not** meet the requested 16-ms/5% target. Do not extrapolate uncapped results to phone, or from acquisition to base hunting, movement or menu opening. These require separate physical-device scenario traces; build 523.848's aggregate cannot establish them.
