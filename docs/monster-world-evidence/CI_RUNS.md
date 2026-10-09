# 같은 코드에서 새로 실행한 GitHub Actions

게임 코드 HEAD: `539e932b98d86db3d41bba84a07ce3d0704ba4ea`. main: `82dbbdb18ec3088fcf521ce887af61c0c48c5a28`.

이후 증거·문서만 커밋했습니다. 아래 실행은 해당 코드의 실제 신규 실행이며 이전 테스트 결과를 대체해 쓰지 않았습니다.

| 워크플로 | 결과 | 실제 실행 |
| --- | --- | --- |
| Twilight Consumable Integration | success | [#57](https://github.com/zoog136-hash/-/actions/runs/37907038743) |
| Twilight Skill Mechanism | success | [#144](https://github.com/zoog136-hash/-/actions/runs/37907038880) |
| Twilight Item Options Runtime | success | [#49](https://github.com/zoog136-hash/-/actions/runs/37907038693) |
| Godot Validate | success | [#185](https://github.com/zoog136-hash/-/actions/runs/37907038775) |
| Ground Loot Validate | success | [#55](https://github.com/zoog136-hash/-/actions/runs/37907038774) |
| TWILIGHT Integration Validate | success | [#88](https://github.com/zoog136-hash/-/actions/runs/37907038865) |
| Monster World Validate | success | [#12](https://github.com/zoog136-hash/-/actions/runs/37907038735) |
| Combat Animation Validate | success | [#58](https://github.com/zoog136-hash/-/actions/runs/37907038744) |

현재 main과 병합 충돌은 없었습니다. 병행 PR #41·#45·#46은 `scripts/world.gd`를 수정하므로 향후 함께 병합할 때 연결부 검토가 필요합니다. 이 PR은 Draft이며 main에 병합하지 않았습니다.
