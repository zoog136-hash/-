# 플레이 중 렉·입력·아이템 등급 수정 — 2026-10-26

기준 main: `6a40b02fb39061da0aefa916db30f65692f683dc`
작업 브랜치: `feature/runtime-lag-ui-fixes-20261026`

## 요청별 결과

| 요청 | 변경과 확인 범위 |
| --- | --- |
| 아이템이 떨어질 때 렉 | 일반 처치마다 수행하던 장비·스킬·카드·인벤 전체 HUD 재구성을 보상·체력·아인 갱신으로 축소했다. 드랍 위치 탐색은 현재 맵의 인근 공간 버킷만 조회한다. |
| 크리티컬을 더 밝게 | 기존 빛 레이어의 밝기·크기·짧은 중심광을 강화했다. 일반 타격과 치명타 판정은 유지하고, 타격당 노드 추가나 풀 상한 확대는 하지 않았다. |
| 이동 시 렉 | 매 2px 구간에서 같은 격자를 반복 확인하던 비용을 줄였다. 발의 이동 경계가 모두 빈 셀인 경우만 빠른 경로를 사용하며, 정밀 장애물 검사와 기존 fallback은 유지한다. |
| 눌러야 카드 뒤집기 | 뽑기는 처음에 뒷면으로 대기한다. 누른 카드만 연출을 시작하며, 모두 뒤집기도 명시적 입력으로 동작한다. 각 카드의 번개 후 2초 확정 지연을 유지한다. 보상은 기존 저장 경로에서 이미 지급된 결과를 표시한다. 합성·시연의 자동 연출은 유지한다. |
| 컬렉션 안 눌림 | 장비 컬렉션 목록·등록 장비 목록에 native touch 선택을 연결했다. 좁은 화면에서도 상단 장비 컬렉션 바로가기에 접근할 수 있다. 스와이프·취소 입력은 등록 대상을 바꾸지 않는다. |
| 미습득 스킬 흑백·흐림 | 원본 이미지를 복제해 54px 회색 캐시를 만들고 밝기·알파를 낮춘다. 습득 즉시 원래 색으로 돌아오며 원본 텍스처의 색·알파는 보존한다. |
| 구매 후 다른 상품 선택 | 확인창 뒤 목록의 raw touch를 차단하고 누름/놓음의 상품 식별을 대조한다. 구매 후 목록을 재생성하지 않고 수량·지갑·상세만 갱신해 선택·검색·구매 수량·스크롤을 유지한다. |
| 잘못된 아이템 등급 | Inven 원본 quality와 2,129개 ID/이름을 대조해 도감 1,060개·게임플레이 DB 33개를 교정했다. 기존 가방·장착·창고·직접 내려놓은 바닥 장비의 등급 메타데이터도 복구한다. |
| 전반적인 렉 | 숨겨진 인벤은 최신 데이터만 저장하고 실제 슬롯 생성은 표시할 때 수행한다. 골드·무게 변경만으로 슬롯을 재생성하지 않으며, 화면 밖 바닥 드랍의 빛 애니메이션을 중단한다. |

## 성능과 동작 보존

- 이동 회귀는 기존 알고리즘과 랜덤/격자 경계/장애물 변경 결과를 비교한다. 최종 통합 상태의 합성 지형 측정 4,000회는 이전 72,004µs, 수정 30,448µs였다. 이 약 58% 감소는 해당 CPU 계산 경로의 로컬 측정이며 Android FPS나 전체 게임 프레임 개선율이 아니다.
- 바닥 드랍 1,800개를 여러 맵에 둔 회귀에서, 주변에 없는 아이템의 거리 비교는 0회다. 기존 36px 간격, 바닥 생성 후 습득, 중복 방지, 맵/저장/만료 동작은 보존한다.
- 숨겨진 인벤에 60회 상태·수량 갱신을 적용해 슬롯 생성 0회를 확인했다. 열거나 상위 창을 다시 표시하면 최신 물리 ID·강화·수량·필터를 반영한다.
- 크리티컬은 기존 레이어를 더 크게 밝히므로 해당 효과의 픽셀 처리량은 증가한다. 이것을 최적화 수치에 포함하지 않는다.
- 등급 교정은 강화·속성·축복·개체 ID·수량·기존 자체 스탯을 보존한다. 기존 27개 제작식의 비법서 등급 조건과 희귀 이상 전체 제작 정책에 필요한 수정 단검 자체 제작식 1개를 함께 맞췄다.

## 등급 조사 한계

[아이템 등급 복구 보고서](ITEM_GRADE_REPAIR_20261026.md)와 [ID별 감사표](../data/catalog_item_grade_audit_20261026.json)에 조회 URL·응답 해시·교정 전후를 기록했다. 원본 quality 42의 217개는 표준 등급이 확정되지 않았으며, 게임플레이 DB의 미매칭·특수·자체 아이템 409개까지 원작 등급 검증 완료로 취급하지 않는다. 원본 신규 아이템이나 외부 바이너리를 추가하지 않았다.

## 검증

공식 Godot `4.7.2.stable.official.ed1daf0bf`와 각 테스트의 격리된 사용자 저장 경로를 사용했다. 전체 스크립트 import, 탐색 캐시 준비, Main 부팅과 변경 관련 회귀를 수행했다. 최초 제한 환경에서 에디터의 로컬 포트 생성 오류가 있었으며, 같은 코드의 로컬 포트 허용 재실행으로 코드 오류와 분리했다.

| 범위 | 검증 항목 |
| --- | --- |
| 기본 준비/게임 | import, bake_navigation, boot, ain_exp_progression_test, critical_damage_bonus_test, inventory_db_smoke_test |
| 바닥 드랍/이동 | ground_drop_smoke_test, ground_loot_system_test, ground_loot_spatial_index_test, ground_loot_grade_restore_test, native_png_motion_cost_test |
| 크리티컬/카드 | hit_feedback_test, hit_feedback_render_test, card_manual_reveal_test |
| 인벤/UI | inventory_hidden_refresh_test, mobile_ui_state_regression_test, ui_stage4_item_instance_test, equipment_collection_runtime_test, shop_consumables_gameplay_test, l1j_reviewed_shop_test |
| 도감/등급/제작 | catalog_grade_policy_test, catalog_full_browser_smoke_test, loot_balance_smoke_test, crafting_scroll_grade_test, crafting_atomic_test, crafting_material_drop_test |
| 리소스/드랍 경로 | check_resource_integrity.py: 기존 723시트·41,442프레임·SHA 확인. validate_twilight_drop_coverage.py: 장비458/458·물약11/11. |

위 Godot 검증 항목 26개와 Python 리소스/드랍 검사 2개가 모두 통과했다. 독립 리뷰에서 발견한 일반 처치 후 가방의 아데나 표시 누락도 슬롯 재생성 없이 라벨만 갱신하도록 수정했고, 실제 Main 회귀에서 상태와 라벨을 추가 확인했다.

크리티컬의 실제 OpenGL 렌더 5개 상태도 확인했다. 카드의 native touch 직후 emulated mouse 중복, 첫 카드 완료 후 장시간 대기하고 다음 카드 공개도 별도 재현했다. 이 결과는 Android 실기기 플레이, 전체 게임 회귀, 전체 원본 리소스 전달 완료를 뜻하지 않는다.

## 통합 상태

- 하나의 feature PR에 모으고 `[skip ci]` 커밋으로 보존한다. 이번 작업에서 GitHub CI dispatch·재실행·main 병합은 하지 않는다.
- #179의 상점 수량/카드 연출 추가 변경은 별도 열린 PR이다. 본 수정은 최신 main을 기준으로 하며, #179의 추가 번개 시간은 이후 통합 시 유지해야 한다. 수동 공개의 종료 시간은 카드의 `reveal_at()`을 기준으로 늘어나도록 구현했다.
- #181 Android 에디터 클래스 파싱 대응 역시 별도 열린 PR이며 이 변경에 합치지 않았다.
- 검증 과정에서 생성한 탐색 캐시·임시 그림·캡처는 변경 파일에 포함하지 않는다.
