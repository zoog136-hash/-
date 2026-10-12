# 전체 회귀 비교

동일한 Godot 4.7.2, 별도 사용자 데이터 디렉터리, 외부 ZIP/SPX 팩이 없는 동일 설치 조건에서 `tools/test_project.py`를 시작 main worktree와 feature worktree에 각각 실행했다. 화면을 기다리는 기존 테스트는 실제 OpenGL/Xvfb에서 실행했다. 성능 측정과는 별개의 실행이다.

| 결과 | 시작 main | 구현 후 |
|---|---:|---:|
| 전체 검사(Import/Boot 포함) | 135 | 137 |
| 통과 | 120 | 122 |
| 실패 | 12 | 12 |
| 명시적 건너뜀 | 3 | 3 |
| 미실행 | 0 | 0 |
| 새로 추가된 실패 | — | 0 |

추가된 두 검사는 전체 변신/몬스터와 전체 보스 검사다. 최종 체형 분류·돌진 잔상 보완 뒤에는 관련 집중 테스트 12개를 다시 실행해 통과했고, 실제 화면도 다시 렌더했다. 전체 suite의 나머지 항목까지 최종 보완 후 두 번 실행했다고 주장하지 않는다. 최종 집중 검사의 실제 결과는 `evidence/*_test.txt`에 있다.

원본 [변경 전 요약](evidence/regression/baseline-summary.json), [변경 후 요약](evidence/regression/changed-summary.json), [기계 비교](evidence/regression/comparison.json), [변경 전 전체 로그](evidence/regression/baseline-logs.tar.gz), [변경 후 전체 로그](evidence/regression/changed-logs.tar.gz)를 보존했다. 아래 실패는 **양쪽에서 모두 재현**되었다.

| 실패 검사 | 관측된 이유 |
|---|---|
| `hunting_navigation_cache_test` | 설치되지 않은 원본 source cache 25개 검사 실패 |
| `l1j_map_grid_test` | 외부 원본 맵 바이트 누락/불일치 |
| `l1j_png_load_test` | 선택 설치되는 실제 item/monster PNG 없음 |
| `l1j_spx_frames_test` | 선택 설치되는 변환 SpriteFrames 없음, JSON 파싱 오류 |
| `monster_world_test` | 기존 일부 보스 special 기대 및 밀집 구역 population/respawn 기대 불일치 |
| `original_skill_catalog_runtime_test` | 기존 무작위 스폰 코드의 AStarGrid 좌표 범위 초과 ERROR |
| `original_skill_summon_test` | 같은 AStarGrid 범위 초과 ERROR |
| `original_turn_undead_rewards_test` | 이미 제거된 `quest_kills` 필드를 테스트가 참조하는 script error와 timeout |
| `renewed_map_spawn_test` | 기존 boss respawn 기대값 불일치 |
| `skill_mechanism_smoke_test` | 기존 stun cooldown 기대값 실패 |
| `world_regions_test` | 기존 지역 몬스터 레벨 기대값 불일치 |
| `world_structure_test` | 기존 `map_id` dictionary 필드 접근 오류와 timeout |

건너뛴 검사는 `original_map_catalog_test`, `original_world_runtime_test`, `source_first_map_test`다. 선택 설치된 외부 원본 자료가 없는 상태를 스스로 SKIP으로 보고했다. 성공으로 세지 않았다.

제거된 퀘스트를 복구하거나 기존 AI·리스폰·지역 레벨을 바꿔 이 테스트들을 통과시키지 않았다. 별도 main 진행 커밋에는 스폰 범위 수정이 포함되어 있으나 이번 작업 브랜치에 임의 병합하지 않았다. 따라서 전체 회귀가 모두 녹색인 상태는 아니며 PR을 자동 병합하지 않았다.

CI에는 엔진을 4.7.2로 고정한 `Animation Presentation Validate`를 추가했다. 실제 GitHub 체크 상태는 PR에서 확인해야 하며, 로컬 통과를 GitHub/Android CI 통과로 대체하지 않는다.
