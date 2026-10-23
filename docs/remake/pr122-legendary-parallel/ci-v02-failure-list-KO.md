# CI 2차 실행: 원본 결과와 남은 실패

실행: https://github.com/zoog136-hash/-/actions/runs/40014699342

기준 a2dbbb01659e562980653c8d33898d3b7d761e58. 233개 중216통과·12실패·5건너뜀. import/boot 통과,900초 import 오류 재발 없음. 후속floor-loot·combat·monster-crowd3단계는 앞 단계 실패로 건너뜀.

| 테스트 | 원인 그룹 | 남은 원인 |
|---|---|---|
| animation_presentation_test | PROTECTED_EXISTING_ANIMATION | 기존 몬스터 사망 318건 실패. |
| full_visual_manifest_test | PROTECTED_EXISTING_ANIMATION | 기존 WALK 트랙 선택 1848건 실패. WALK 보존. |
| native_animation_expansion_test | PROTECTED_EXISTING_ANIMATION | 기존 native profile 1, virtual canvas 240, 방향 트랙 24, 자세 구별 40건 실패. |
| pr122_girtas_native_default_main_connection_test | TEST_RESULT_CONTRACT | 출력 _PASS 또는 비JSON _RESULT는 공통 판정기의 _OK/JSON failures=[] 계약에 맞지 않음. CI FAIL 유지. |
| pr122_native_action_test | TEST_RESULT_CONTRACT | 출력 _PASS 또는 비JSON _RESULT는 공통 판정기의 _OK/JSON failures=[] 계약에 맞지 않음. CI FAIL 유지. |
| pr122_native_default_main_connection_test | TEST_RESULT_CONTRACT | 출력 _PASS 또는 비JSON _RESULT는 공통 판정기의 _OK/JSON failures=[] 계약에 맞지 않음. CI FAIL 유지. |
| pr122_native_locomotion_resource_test | TEST_PRECONDITION_ASSERTION | 16행은 모든 기존 actor의 production_connected=false 및 detailed_completed=false를 요구. 레지스터 조건 불일치 후150초 종료. |
| pr122_native_main_connection_test | TEST_PRECONDITION_ASSERTION | 20행은 TWILIGHT_NATIVE_MAIN_KEY를 요구하지만 전체 실행에서는 미지정. assertion 후150초 종료. |
| pr122_native_player_connection_test | TEST_RESULT_CONTRACT | 출력 _PASS 또는 비JSON _RESULT는 공통 판정기의 _OK/JSON failures=[] 계약에 맞지 않음. CI FAIL 유지. |
| pr122_native_reaction_test | TEST_RESULT_CONTRACT | 출력 _PASS 또는 비JSON _RESULT는 공통 판정기의 _OK/JSON failures=[] 계약에 맞지 않음. CI FAIL 유지. |
| pr122_s_only_death_main_test | TEST_RESULT_CONTRACT | 출력 _PASS 또는 비JSON _RESULT는 공통 판정기의 _OK/JSON failures=[] 계약에 맞지 않음. CI FAIL 유지. |
| pr122_transform_run_only_scope_test | TEST_RESULT_CONTRACT | 출력 _PASS 또는 비JSON _RESULT는 공통 판정기의 _OK/JSON failures=[] 계약에 맞지 않음. CI FAIL 유지. |

기존 몬스터·WALK·신화급 레지스터·공통 테스트 코드를 보존했다. 출력 PASS만으로 실패를 통과 처리하지 않았다. 추가 전체 CI는 실행하지 않았다. 이후 전설급 수정은 변경·영향받는 클립의 검사로 기록한다.

원본 ZIP SHA256: 77ddb99ca5e619afb1a9371c30dab0fc20fe39b16b4b982a0e1d16e04c764c53
원본 summary SHA256: c8b83e07de159a917aa2f78e6fc94cecd65149a099c72a7016b2ca50d5c51df2

상세: [ci-v02-focused-failure-diagnosis-v01.json](ci-v02-focused-failure-diagnosis-v01.json)
