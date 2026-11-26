# 523.850 hunting periodic option-cost reduction
The uploaded phone trace has a normal ADEN frame 12878 at 26.79 ms; its timed monsterbook subsystem was 5.102 ms. That section also includes the existing expiry and reconciliation owners, so 5.102 ms is not the cost of the pre-change scan alone. No Android post-change result.

Main._process_slow still calls monsterbook523_runtime.tick once due. No journal progression was enabled. The prior fingerprint, flat bonuses and extra attributes enumerated/copied 33 eligible books out of 557 and evaluated each calendar before establishing whether there were any effective levels. These three consumers now scan the ordered source without copying, skip empty/irrelevant saved epochs, and resolve owned levels with the **same** temporal, owner and rotation rules. Nothing moves to startup.

Private source-pack experiment, Godot 4.7.2 headless on the same machine, 100 alternating paired calls per scenario after the first sample. All complete ordered result rows compared with the previous algorithm. Times below are isolated CPU-section wall time, **not** whole frames or phone FPS (median / p95 / max, milliseconds):

| Saved effective books | Previous | Changed |
|---|---|---|
| None | 1.422 / 2.084 / 2.923 | 0.001 / 0.002 / 0.003 |
| Two | 1.393 / 1.991 / 3.237 | 0.211 / 0.302 / 1.171 |
| All 33 | 2.314 / 2.983 / 3.607 | 2.109 / 3.062 / 3.967 |

The dense case did not improve at p95 or max in this run. The benefit is absent/sparse ownership; Android 16 ms scenario acceptance is unproven. 317/317 parity checks, including actual active effects, old epochs, option expiry and invalid source clocks. Full original rules 1,312/1,312; the test for absolute source expiry now explicitly selects absolute source-date mode rather than implicitly entering the next offline rotation.
