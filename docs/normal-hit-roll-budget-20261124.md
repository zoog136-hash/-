# 523.850 ordinary gameplay: normal-hit roll budget
Frame 5369 in the supplied Android JSON records player.visual 90 ms containing
player.strike 90 ms and player.impact 89 ms, with hit.roll 55 ms, hit.deal 20 ms
and hit.passives 14 ms. This establishes a CPU gameplay cost in one recorded
frame, not the cause of the two other player.visual ~70 ms samples whose
inner trace is unavailable. No original imagery, geometry or animation changed.

The normal hit's pure damage/RNG phase sees the existing equipped weapon just
once. Derived stat memoization starts **after** any mastery advance and ends
**before** damage, weapon bleed, passives/cooldowns, extra strike and HUD
publication. Hit probability, RNG draw order, critical/element rules, stat
owners and post-roll behavior are not changed. No work is moved to another frame.

In a PC headless Main scene, equipped for a controlled heavier normal attack
(known fixture sword/bow and filled equipment; not a copy of the user's
mobile character), the exact previous formulas and the new production roll
were run in alternating order on the same inputs and seed. 80 measured pairs,
medians/p95/max in ms:

| Timing | Previous | Updated |
|---|---:|---:|
| calculation only | 58.513 / 70.613 / 114.077 | 44.515 / 53.603 / 58.728 |
| next processed frame (uncapped headless; NOT GPU render) | 59.608 / 71.672 / 122.559 | 45.342 / 54.572 / 59.628 |

Next process interval above 16 through 50 ms: 40→54 / 80; above 50 ms:
40→26 / 80. Strict 16ms still unmet on this fixture. Phone results, actual
GPU presentation, and the other visual spikes remain unmeasured.

The test compares damage, crit, exact RNG state and real Main HP for hit/miss
in melee and ranged, with repeated weapon and live-stat changes. Gear is
synthetic where legacy-tested, not rebranded original data. The unchanged
proc path is outside the memo; no claim every source passive got live testing.

Final 98/98 run added the original sword MasteryWeaponType #21 row without
mounting a private pack. The actual skill point owner grants exactly +3 on
a successful matched return, not on queued weapon mismatch. CPU median /
p95 / max was 60.211 / 78.052 / 211.386 → 44.574 / 56.529 / 81.621 ms.
Next processed frame median / p95 / max was 61.159 / 79.132 / 212.740 →
45.404 / 57.294 / 82.423 ms; >50 ms 42→16 / 80. Maximum reflects host
scheduling as well as hit work. No script errors in this tested path.
