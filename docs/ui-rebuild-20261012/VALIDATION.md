# 실제 실행 결과

기준 `main`은 `49f5470e6d9561183e0a8e8e56901da6d4d93f27`. Godot `4.7.2.stable.official.ed1daf0bf`로 프로젝트를 실행했다. Linux headless 입력 검사와 Xvfb + Mesa llvmpipe OpenGL 렌더를 구분했다. 각 테스트는 임시 사용자 데이터 디렉터리를 사용하며 실제 사용자 저장 파일을 덮어쓰지 않는다.

## UI 기능과 렌더

| 검사 | 실제 결과 | 증거 |
| --- | --- | --- |
| 마우스·네이티브 터치·페이지·드래그·물리 ID·거래·저장 | 49 assertions, failures `[]` | [입력 로그](evidence/ui-tests/ui_pointer_transfer_test.log) |
| 기존 UI 가독성·터치·확인 회귀 | 88 assertions 통과 | [UI 회귀 로그](evidence/ui-tests/ui_fidelity_regression_test.log) |
| 실제 UI 통합 | 62 assertions 통과 | [통합 로그](evidence/ui-tests/ui_renewal_integration_test.log) |
| 인스턴스·50칸 슬롯·도감 드래그·스킬 출처·NPC 구매·메뉴·창 배치 | 개별 재검사 통과 | [개별 로그](evidence/ui-tests/) |
| 변경 전 실제 렌더 | 17화면×4해상도 = 68 PNG 생성 | [로그](evidence/before-capture.log) |
| 변경 후 실제 렌더 | 34상태×3요청 해상도 = 102 PNG 생성 | [로그](evidence/capture.log), [크기·좌표 JSON](evidence/render-render-results.json) |
| 대표 변경 전·후 화면 | 원본 PNG 32개를 Git에 보관 | [비교](COMPARISON.md), [크기·SHA-256 목록](evidence/images.json) |
| 공개 체크아웃 리소스 무결성 | 723 아틀라스 / 41,442 프레임 / 233,420,026 bytes 통과 | [검사 로그](evidence/resource-integrity.log) |

터치 테스트는 `InputEventScreenTouch`·`InputEventScreenDrag`를 뷰포트에 실제 전달한다. 마우스 이벤트를 터치 성공으로 계산하지 않는다. 0.30초 길게 누르기·10px 스크롤 판정, 퀵슬롯 42px 가로 페이지 전환·28px 위/아래 AUTO를 구분하며, 입력 에뮬레이션의 중복 마우스 이벤트도 전달해 새 바인딩이 즉시 소비되지 않는지 검사한다. 렌더 프레임이 지연되는 동안의 길게 누르기는 실제 경과 시간으로 판정한다.

102개 전체 PNG는 로컬 실행 산출물과 UI CI의 `twilight-ui-renewal-evidence` 아티팩트 대상이다. Git에는 위 32개 대표 화면을 포함했다. CI가 완료되기 전에는 원격 102개 산출물 전달 완료로 표시하지 않는다. 2400×1080 요청의 활성 렌더는 기존 `aspect=keep`에 의해 1920×1080이다.

## 전체 프로젝트 검사의 실패 기록

첫 전체 실행은 개발 중 시작했으며 **128개 중 104 통과, 21 실패, 3 건너뜀**이었다. [원본 요약](evidence/full-suite/summary.json)과 [진행 로그](evidence/full-suite/progress.log)를 그대로 보존했다. 최종 전체 검사 성공으로 바꾸어 보고하지 않는다. 이후 변경과 실패 원인에 해당하는 개별 검사를 재실행했다.

| 원인/검사 | 조치와 상태 |
| --- | --- |
| `aden_building`, `aden_terrain_polish`, `l1j_reviewed_shop` | NPC 창을 별도 `npc_shop`으로 분리하고 구매 확인을 추가한 동작에 맞춰 검증 경로를 갱신. 실제 구매·금액·아이템 검사는 유지 |
| `lineage_side_ui_smoke` | 원래 삭제한 퀘스트를 포함하는 16개 기대값을 유지 메뉴 14개+닫기로 교정. 삭제 기능이 없는지 추가 검사 |
| `lineagem_ui_visual_smoke` | 1280 논리 뷰포트를 명시하고 없앤 공통 사이드바 대신 우측 소형 창을 검사 |
| `original_skill_provenance` | 상세창 재구성 때 빠진 원작 확인/추정·학습·가격 출처 표시를 복원. 재검사 통과 |
| `inventory_db_smoke`, `ground_loot_system`, `original_skill_learning_conditions`, `original_turn_undead_rewards`, `world_structure` | 첫 실행의 150초 제한 시간 초과. 450초 제한의 별도 재검사 결과를 `evidence/rechecks`에 보관 |
| `hunting_navigation_cache` | 수정 전 main에서도 25개 서명 불일치 재현. UI 작업에서 맵 캐시를 재작성하지 않음 |
| `monster_world` | 수정 전 main에서도 보스 별도 스킬/밀집 리젠 6개 실패 재현 |
| `renewed_map_spawn` | 수정 전 main에서도 리젠 보존 관련 30개 실패 재현 |
| `skill_mechanism_smoke` | 수정 전 main에서도 스턴 쿨타임 1개 실패 재현 |
| `original_skill_catalog_runtime`, `original_skill_summon` | 자체 OK 문구 뒤 AStar 범위 밖 ERROR가 출력되어 실패로 판정. 두 검사 모두 수정 전 main에서도 재현. OK 문구만으로 성공 처리하지 않음 |
| `world_regions` | 24맵·6036검사 중 지역 레벨 65개 실패. UI 범위 밖이며 수정 전 전체 24맵 비교 재실행은 하지 않았음 |
| `l1j_map_grid`, `l1j_png_load`, `l1j_spx_frames` | 공개 체크아웃에 비공개 원본/fixture 경로가 없음. 합성 fixture를 실제 원본 납품으로 만들지 않음 |
| `original_map_catalog`, `original_world_runtime`, `source_first_map` | 원본 팩 부재로 SKIP. 통과 수에 넣지 않음 |

[수정 전 main 재현 로그](evidence/baseline/)에는 해당 기준 SHA에서 실행한 오류를 보존했다. `world_regions`와 리소스 누락까지 모두 ‘기존 main 재현 완료’라고 확대하지 않는다. 전체 첫 실행은 새 입력 테스트 파일이 발견 목록에 들어가기 전에 시작됐으므로 신규 입력 회귀는 별도로 실행했다.

## 재현 명령

```bash
python3 tools/check_resource_integrity.py --root .

GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64
XDG_DATA_HOME=/tmp/twilight-check "$GODOT" --headless --path . \
  --script res://tests/ui_pointer_transfer_test.gd
XDG_DATA_HOME=/tmp/twilight-fidelity "$GODOT" --headless --path . \
  --script res://tests/ui_fidelity_regression_test.gd
XDG_DATA_HOME=/tmp/twilight-integration "$GODOT" --headless --path . \
  --script res://tests/ui_renewal_integration_test.gd

LIBGL_ALWAYS_SOFTWARE=1 XDG_DATA_HOME=/tmp/twilight-render \
  xvfb-run -a -s '-screen 0 2560x1440x24' "$GODOT" --path . \
  --rendering-driver opengl3 --audio-driver Dummy \
  --script res://tests/capture_ui_reference.gd

DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 python3 tools/test_project.py \
  --godot "$GODOT" --logs /tmp/twilight-full --render-visual-tests
```

OpenGL 검사는 실행 가능한 디스플레이가 필요하다. `frame_post_draw`를 기다리는 검사를 `--headless`로 실행한 것은 올바른 렌더 검증이 아니다. `aden_terrain_polish`의 잘못된 headless 재시도는 별도 OpenGL 실행으로 대체했다.

Windows/Android 실기기, 고해상도 DPI·기기 안전 영역, 장시간 플레이는 실행 미검증이다. 카드 소유·중복·합성·컬렉션, 일반 아이템 삭제 서비스는 미구현이다. 외부 원본 팩 `original_*: not_delivered` 상태는 그대로 유지했다. [화면별 경로·근거·남은 차이](SCREENS.md)를 확인한다.
