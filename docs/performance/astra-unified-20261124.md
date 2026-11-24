# 11월 23~24일 PR 전수 대조 및 통합 수정

기준은 #877 병합 직후 main `2cd809a014066e4df753eff12f234e7125ff23ee`. #838부터 #878까지 41건 중 **35건은 이미 main**, **5건은 이 브랜치로 통합**, **#862 한 건은 의도적으로 제외**했다. 같은 날짜에 병합한 옛 #444·827은 맥락 두 건으로 따로 표기한다. 아래는 PR별 코드, 실행 주인 및 회귀 경로 대조이지, 전 항목의 같은 폰 재실행 증명은 아니다.

## 이번에 실제로 더 바뀐 곳

1. **사냥 첫 NPC.** #860은 *재등장*, #873은 같은 성장 중 *반복 ID 증명*을 다룬다. 둘 다 고정 열거표의 각 행에 대해 전체 표를 다시 훑는 문제는 남겼다. 실자료 BuffGroup 646개 행에서 그 검색만 646×646 자리 비교가 가능했다. 이제 BuffGroup / ElementalType / AttackType은 각 표에서 ID 중복 여부를 한 번 준비하고 고유 정수 ID는 기존 1-based 위치를 바로 보존한다. ID 충돌·누락·비정수에는 기존 완전 일치/제외 규칙을 사용한다. 다음 프레임 또는 부팅으로 작업을 옮기지 않았다.
2. **몽환의 섬.** #842의 메타데이터와 #872의 지면 합성은 다르다. #872의 실제 렌더 경로를 가져오고, 같은 y에서 겹치거나 접하는 원본 마스크 사각형만 한 수평 구간으로 묶었다. 523 원본 Land 22801, 303/ 및 Tile47의 199/202만 대상. 다른 바닥·상층·캐릭터는 그대로이며, 원본 두 텍스처가 인증되지 않으면 기존 타일을 유지한다. 단색 덮기나 신규 PNG 없음.
3. **통합 시 유실되던 회귀 검사.** 서로 다른 PR의 CI 파일 전체를 덮어쓰지 않고, 기본 실행 목록과 결과 마커에 신규·이관된 11개 테스트를 함께 등록했다. 기존 #878의 정제 시험 더블도 최신 시그니처로 유지한다.

## 재현과 검증 범위

- 사용자 폰의 기존 523.843→523.848: 33ms 초과 프레임 1,261/10,700 (11.8%)→2,920/14,147 (20.6%). 같은 NPC 73681, Sprite 4576의 setup.projection 346.373→590.487ms. 장면 전체가 동일하게 통제된 벤치가 아니며, 4초 이상 이벤트만 고른 자료도 아니다. 이것은 문제의 증거이지 이 PR 이후의 폰 결과가 아니다.
- 원본 523 정의 SHA-256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`, Godot 4.7.2 PC headless. `TWILIGHT_PATCH523_CONTENT=<zip> TWILIGHT_VERIFY_NPC73681=1 godot --headless --path . --script tests/current523_npc_enum_position_test.gd`. 같은 선행 정의 캐시에서 카탈로그를 매번 새로 만들어 실물 NPC 최초 투영 호출을 교차 측정. 초기 1회 예열 뒤 옛/새 알고리즘 각 6회. 테스트 중 모든 회차의 반환 NPC·공개 카탈로그·모델 해시·등록 식별자 직렬화 바이트가 일치했다. 중복 ID/상이한 내용/누락/제외·순서도 비교, 총 27/27.
- 기존 μs: 33501, 37859, 34027, 42635, 34190, 33242 (**중앙 34.109ms, 최대 42.635ms**). 수정 μs: 12514, 12864, 12435, 14741, 15423, 12877 (**중앙 12.871ms, 최대 15.423ms**). 중앙 약 62.3% 감소. **정의 파일 최초 디코드·전체 게임 프레임·폰은 포함하지 않는다.** 이전 #873만으로 같은 NPC 원본 ID 조회가 18→14로 줄었지만 완전 콜드 시간의 안정적 개선은 검증되지 않았다. 서로 다른 실험을 합산하지 않았다.
- 배포 pack-63fb1355 원본 이미지 manifest SHA-256 `db51444bcd65d89c8775b67f321db0c1aa6bcb801f5e4375f6d50a0de2d3cb1f` 및 실제 PNG를 선택한 환경에서 원본 정의→AssetView 691/690→설치 이미지 선택→두 텍스처를 확인. sky `92af0868a00a7b35724c9514a8b107b34b312d0f0c982f112c905c609d73292f`, cloud `ba51b07c3b4ea71e3cdc640fd09dc5fc2c3201f578b2f4559951f6c76ae8ccf7`. override를 비운 채 2장 로드. 원본 S32 80007ffd의 지면을 정상 투영·분할한 한 블록에서 같은 지면 마스크 842개를 44회로 합쳐 수평 픽셀 구간 전체가 일치했다. `_bake_block` 진입과 설치팩 경로를 합쳐 13/13. 단, headless라 실제 GPU 픽셀 캡처는 아니다. 이 검사는 전체 팩 설치가 아닌 해시가 일치하는 설치팩 파일 부분집합이다.
- 원본 강화 창 애드온 pin 5263d925: 실물 결과 저장 성공 뒤에만 원본 성공 연출 49/49; 정제 원본 창 37/37. 별도 실물 Main에서 원본 토큰 234774 + 주문서 6411: 25/25. 실제 가방에서 퀘스트 영수증→매직 솔져 원본 아이콘과 선택상자 UI는 16/16(첫 실행은 임시 디스크가 가득 차 대형 원본 표 1개 미열림; 여유 디스크에서 코드 변경 없이 동일 증례 재통과). 이 결과가 모든 강화 그룹, 모든 이미지의 실제 폰 렌더를 뜻하지 않는다.
- 나머지 통합 회귀: 지도 해제 11/11(300ms 잔여 작업을 둔 해제 1.772ms), 던전 저장 Main 11/11, 미니맵 5/5, 일반 뽑기 31/31, 기본 원본 인벤토리 14/14, 예비 인벤토리 18/18, 동기 원본 경로 143/143, native 스택 저장 검증 17/17, 가방 크롬 12/12, 아이콘 누락 분류 10/10. 예비 가방 326행 PC 중앙 재생성 4.109ms/재사용 0.424ms, 기본 가방 502행 비교 8.124→5.607ms. 일반 뽑기 전체 handler PC 측정 57.015/69.441/164.649ms로 **여전히 16ms를 넘는다**.
- 단말의 이번 빌드 프레임 로그, 실제 몽환의 섬 화면/동영상, Android OTA 배포·설치는 별도 검증 필요. 서명된 기기·화면 없는 상태에서 끊김 해결이나 시각 수정 완료로 표시하지 않는다.

## PR별 판정

경로는 실제 소스 파일과 관련 검사를 가리킨다. “기존”은 새로 고쳤다는 말이 아니다. 각 PR의 기존 테스트 중 위에 나열하지 않은 것은 이 통합에서 **소스만 대조**했다.

| PR | 상태 | 실행 경로 / 관련 회귀 | 이번 판정 |
|---|---|---|---|
| [#444](https://github.com/zoog136-hash/-/pull/444) | 기존(참고) | [current523_sp2_decoder](../../scripts/resources/current523_sp2_decoder.gd) · [검사](../../tests/sp2_block_copy_test.gd) | SP2 블록 복사 할당과 해독 단계 계측. 표준 해독 경로를 유지한다. |
| [#827](https://github.com/zoog136-hash/-/pull/827) | 기존(참고) | [native_option_awakening](../../scripts/cards/native_option_awakening.gd) · [검사](../../tests/card_deck_bonus523_test.gd) | 보유 변신 옵션의 석화 및 범위 공격 발동을 전투에 연결. 기기 발동률 측정 아님. |
| [#838](https://github.com/zoog136-hash/-/pull/838) | 기존 | [world](../../scripts/world.gd) · [검사](../../tests/auto_target_search_budget_test.gd) | 자동 사냥 타깃 탐색·지도 작업량 제한. 이후 #868·869 경로와 함께 판단. |
| [#839](https://github.com/zoog136-hash/-/pull/839) | 기존 | [consumable_service](../../scripts/consumable_service.gd) · [검사](../../tests/item_use523_owned_elixir_test.gd) | 실물 원본 엘릭서 사용을 능력치 선택으로 연결. 보유 증빙 유지. |
| [#840](https://github.com/zoog136-hash/-/pull/840) | 기존 | [current523_aden_play_controller](../../scripts/maps/current523_aden_play_controller.gd) · [검사](../../tests/competition_dungeon523_test.gd) | 월드/마스터 던전 목록과 원본 지역 진입 연결. 모든 던전 완주 확인 아님. |
| [#841](https://github.com/zoog136-hash/-/pull/841) | 기존 | [performance_report_session](../../scripts/boot/performance_report_session.gd) · [검사](../../tests/performance_report_session_test.gd) | 프레임·입장 구간을 Android JSON으로 내보냄. 계측 자체는 최적화 아님. |
| [#842](https://github.com/zoog136-hash/-/pull/842) | 기존 | [current523_aden_play_renderer](../../scripts/maps/current523_aden_play_renderer.gd) · [검사](../../tests/cooked_actor_pack_test.gd) | 원본 액터·정적 SPR·지도 캐시. 기존 배경 조회는 하늘을 보여줬다는 증거가 아니었음. |
| [#843](https://github.com/zoog136-hash/-/pull/843) | 기존 | [current523_native_stack](../../scripts/loot/current523_native_stack.gd) · [검사](../../tests/native_stack_save_validation_budget_test.gd) | 일반 저장 시 native 스택의 출처 검증. 임의로 소유권 검증 전체 해제하지 않음. |
| [#844](https://github.com/zoog136-hash/-/pull/844) | 기존 | [source_main_card_gacha_window](../../scripts/ui/original_ui/source_main_card_gacha_window.gd) · [검사](../../tests/original_ui_card_gacha_window_test.gd) | 카드 뒤집기/번개·합성 결과 창에 원본 연출 연결. Android 영상 미검증. |
| [#845](https://github.com/zoog136-hash/-/pull/845) | 기존 | [source_main_card_change_window](../../scripts/ui/original_ui/source_main_card_change_window.gd) · [검사](../../tests/cards523_reroll_skillcard_test.gd) | 일괄 카드 확정에서 레거시 카드 제외. 합성/교환 제한은 유지. |
| [#846](https://github.com/zoog136-hash/-/pull/846) | 기존 | [current523_aden_play_renderer](../../scripts/maps/current523_aden_play_renderer.gd) · [검사](../../tests/current523_map_foreground_test.gd) | 지도 전경 준비 및 아틀라스 업로드를 여러 프레임에 분산. 전체 프레임 16ms 보장 아님. |
| [#847](https://github.com/zoog136-hash/-/pull/847) | 기존 | [current523_definition_rows](../../scripts/resources/current523_definition_rows.gd) · [검사](../../tests/current523_npc_relation_index_test.gd) | 지연 로드하는 NPC 관계 색인 작성 축소. 첫 스폰 자체의 새 병목 수정은 아래 별도. |
| [#848](https://github.com/zoog136-hash/-/pull/848) | 기존 | [cooked_actor_store](../../scripts/resources/cooked_actor_store.gd) · [검사](../../tests/cooked_actor_pack_test.gd) | 색인 퇴출 뒤 살아 있는 원본 액터 번들을 재사용. 파일 무결성 검사 유지. |
| [#849](https://github.com/zoog136-hash/-/pull/849) | 기존 | [source_main_skill_card_window](../../scripts/ui/original_ui/source_main_skill_card_window.gd) · [검사](../../tests/original_ui_skill_card_window_test.gd) | 스킬 카드 창은 보이는 행만 마운트하고 상세만 갱신. |
| [#850](https://github.com/zoog136-hash/-/pull/850) | 기존 | [current523_map_usage](../../scripts/maps/current523_map_usage.gd) · [검사](../../tests/map_usage_async_test.gd) | 지도 사용 기록 저장·읽기를 렌더 호출 밖으로 이동. 지도 데이터 보존. |
| [#851](https://github.com/zoog136-hash/-/pull/851) | 기존 | [current523_source_population](../../scripts/maps/current523_source_population.gd) · [검사](../../tests/cooked_page_prepare_test.gd) | NPC cooked 첫 페이지 예약 실험. 기본 비활성이라 이 PR로 인게임 가속을 주장하지 않음. |
| [#852](https://github.com/zoog136-hash/-/pull/852) | 기존 | [world](../../scripts/world.gd) · [검사](../../tests/save_snapshot_budget_test.gd) | 자동저장 스냅샷 중복 복사와 쓰이지 않는 완료 해시를 제거. |
| [#853](https://github.com/zoog136-hash/-/pull/853) | 기존 | [save_writer](../../scripts/skills/save_writer.gd) · [검사](../../tests/background_writer_identity_test.gd) | 창고 중복 입력 방지, 외부에서 교체된 저장 내용 덮어쓰기 방지. |
| [#854](https://github.com/zoog136-hash/-/pull/854) | 기존 | [dungeon_play_service](../../scripts/dungeons/dungeon_play_service.gd) · [검사](../../tests/dungeon_loading_test.gd) | 원본 던전 진입 전에 로딩 UI를 먼저 보여줌. 진입 비용이 줄었다는 뜻은 아님. |
| [#855](https://github.com/zoog136-hash/-/pull/855) | 기존 | [monsterbook523_runtime](../../scripts/monsterbook/monsterbook523_runtime.gd) · [검사](../../tests/monsterbook523_paused_test.gd) | 사용자 지시에 따라 몬스터 도감 진행 중지. 비활성 상태 유지. |
| [#856](https://github.com/zoog136-hash/-/pull/856) | 기존 | [patch523_monster_drops](../../scripts/loot/patch523_monster_drops.gd) · [검사](../../tests/drop_hotpath_test.gd) | 획득 전 드롭 정보 조기 조회 및 반복 배치 검사 축소. |
| [#857](https://github.com/zoog136-hash/-/pull/857) | 기존 | [dungeon_play_service](../../scripts/dungeons/dungeon_play_service.gd) · [검사](../../tests/dungeon_special_entry523_test.gd) | 던전 체크포인트 반복 계산 축소. 강제 종료/일시중지 보장은 #873에서 별도 보완. |
| [#858](https://github.com/zoog136-hash/-/pull/858) | 기존 | [source_main_change_window](../../scripts/ui/original_ui/source_main_change_window.gd) · [검사](../../tests/catalog_open_budget_test.gd) | 도감 열 때 표시할 화면 분량만 준비. 보이지 않는 카드 목록을 전개하지 않음. |
| [#859](https://github.com/zoog136-hash/-/pull/859) | 기존 | [source_main_inventory_view](../../scripts/ui/original_ui/source_main_inventory_view.gd) · [검사](../../tests/source_inventory_reopen_test.gd) | 짧게 닫았다 연 실제 원본 인벤토리 뷰 재사용. 기본/예비 주인은 #871과 구분. |
| [#860](https://github.com/zoog136-hash/-/pull/860) | 기존 | [patch523_npc_catalog](../../scripts/monsters/patch523_npc_catalog.gd) · [검사](../../tests/current523_npc_actor_projection_cache_test.gd) | 동일 NPC가 다시 등장할 때 전투 속성 투영 재사용. 최초 등장 개선과 구분. |
| [#861](https://github.com/zoog136-hash/-/pull/861) | 통합 | [current523_retired_map_jobs](../../scripts/maps/current523_retired_map_jobs.gd) · [검사](../../tests/current523_map_retirement_test.gd) | 이전 지도 작업 종료를 화면 해제에서 분리. 300ms 작업을 둔 은퇴 시험을 이번에 재실행. |
| [#862](https://github.com/zoog136-hash/-/pull/862) | 미채택 | [current523_aden_source_field](../../scripts/maps/current523_aden_source_field.gd) · [검사](../../tests/current523_route_cell_memo_test.gd) | 4ms 단위로 자동 경로 탐색을 다음 프레임에 넘기는 옛 실험. 요청 후 이동 시작 시점이 바뀌므로 가져오지 않음. |
| [#863](https://github.com/zoog136-hash/-/pull/863) | 기존 | [current523_aden_source_field](../../scripts/maps/current523_aden_source_field.gd) · [검사](../../tests/current523_aden_source_field_test.gd) | 동기식 원본 경로 판정 유지. #862가 아닌 이 경로를 기준으로 함. |
| [#864](https://github.com/zoog136-hash/-/pull/864) | 기존 | [source523_inventory_tickets](../../scripts/shop/source523_inventory_tickets.gd) · [검사](../../tests/source523_ticket_pool_preflight_test.gd) | 원본 티켓/저장 증명·경로/프레임 기록 계산 정리. 출처가 다른 자료는 공유하지 않음. |
| [#865](https://github.com/zoog136-hash/-/pull/865) | 기존 | [source_main_inventory_view](../../scripts/ui/original_ui/source_main_inventory_view.gd) · [검사](../../tests/source_inventory_virtual_rows_test.gd) | 원본 인벤토리 최초 표시/가상 행 스냅샷 정리. 모든 아이템 아이콘이 붙었다는 뜻은 아님. |
| [#866](https://github.com/zoog136-hash/-/pull/866) | 기존 | [current523_aden_source_field](../../scripts/maps/current523_aden_source_field.gd) · [검사](../../tests/current523_shared_collision_chunks_test.gd) | 같은 인증 S32 충돌 청크를 표시·경로 소유자 사이에서 공유. 일치하지 않는 자료에는 미사용. |
| [#867](https://github.com/zoog136-hash/-/pull/867) | 기존 | [source523_ground_acquisition](../../scripts/loot/source523_ground_acquisition.gd) · [검사](../../tests/source523_ticket_hud_publish_test.gd) | 줍기 및 원본 카드 지급 후 원장/화면 갱신 불필요 작업 축소. |
| [#868](https://github.com/zoog136-hash/-/pull/868) | 기존 | [world](../../scripts/world.gd) · [검사](../../tests/current523_auto_pursuit_reuse_test.gd) | 안정적인 자동 추격은 매 프레임 경로를 새로 만들지 않음. 대상 변경 시 다시 검증. |
| [#869](https://github.com/zoog136-hash/-/pull/869) | 기존 | [current523_aden_source_field](../../scripts/maps/current523_aden_source_field.gd) · [검사](../../tests/current523_verified_route_verdict_test.gd) | 검증된 원본 셀 판정만 재사용. 이번 동기 경로 회귀 143개 통과. |
| [#870](https://github.com/zoog136-hash/-/pull/870) | 기존 | [current523_native_stack](../../scripts/loot/current523_native_stack.gd) · [검사](../../tests/item_stacking523_test.gd) | 원본 스택 보유 명세 검증 재사용. 소비/저장 원장은 유지. |
| [#871](https://github.com/zoog136-hash/-/pull/871) | 통합 | [renewal_inventory](../../scripts/ui/renewal_inventory.gd) · [검사](../../tests/source_inventory_default_owner_test.gd) | 원본 가방 주인에게 필요 없는 분류, 예비 가방 재열기, 일반 뽑기의 불필요한 후처리를 제거. 기본 가방과 별도 구현 모두 시험. |
| [#872](https://github.com/zoog136-hash/-/pull/872) | 통합 | [current523_aden_play_renderer](../../scripts/maps/current523_aden_play_renderer.gd) · [검사](../../tests/current523_dream_background_render_test.gd) | 몽환의 섬 실바닥 두 타일에서 원본 구름·하늘로 합성하는 경로. 이번에 설치팩 선택 및 원본 지면 렌더 블록 검증·수평 구간 병합을 추가. |
| [#873](https://github.com/zoog136-hash/-/pull/873) | 통합 | [current523_npc_input_projection](../../scripts/monsters/current523_npc_input_projection.gd) · [검사](../../tests/dungeon_durable_cpu_main_test.gd) | 첫 NPC ID 근거 재사용·미니맵·동료/원장 및 던전 체크포인트 보완. 실제 첫 등장 고정표 전수 중복 제거는 이 통합에서 추가. |
| [#874](https://github.com/zoog136-hash/-/pull/874) | 기존 | [reference_sp2_bank](../../scripts/resources/reference_sp2_bank.gd) · [검사](../../tests/actor_frame_composite_cache_test.gd) | 원본 SP2 액터의 반복 증거 재조회 절감. 새 파일/다른 식별값까지 신뢰하지 않음. |
| [#875](https://github.com/zoog136-hash/-/pull/875) | 기존 | [current523_native_stack](../../scripts/loot/current523_native_stack.gd) · [검사](../../tests/native_stack_save_validation_budget_test.gd) | 실물 원장 저장 검증의 중복 작업 정리. 독립 소유자의 지급/거래 검증 유지. |
| [#876](https://github.com/zoog136-hash/-/pull/876) | 기존 | [source_main_inventory_view](../../scripts/ui/original_ui/source_main_inventory_view.gd) · [검사](../../tests/source_inventory_chrome_stage_budget_test.gd) | 원본 인벤토리 크롬/바인딩 단계 재조립 축소. 일반/예비 UI와 구분. |
| [#877](https://github.com/zoog136-hash/-/pull/877) | 기존 | [verified_source_bytes](../../scripts/io/verified_source_bytes.gd) · [검사](../../tests/runtime_single_read_integrity_test.gd) | 제작/효과/전리품/UI 등의 같은 원본 바이트 재읽기 정리. 이미 병합된 변경을 신규 공으로 계산하지 않음. |
| [#878](https://github.com/zoog136-hash/-/pull/878) | 통합 | [patch523_enhancement](../../scripts/crafting/patch523_enhancement.gd) · [검사](../../tests/patch523_native_event_token_enhancement_test.gd) | 원본 아이템 사용·강화·퀘스트 카드/이미지·확정 후 연출, 정제 UI 시험 수정까지 통합. 수치가 없는 성공률·제한 및 이미지는 추정하지 않음. |

## 아이템: 연결한 것과 남긴 것

#878 이관분은 새로 3만 개 코드를 작성했다는 뜻이 아니다. 정확한 원본 고정 변신 보상은 8개이며, 예전 퀘스트 영수증으로 보유한 카드도 원본 식별자가 일치할 때만 쓸 수 있게 하고 아이콘에는 실제 원본 PNG를 사용한다. 64개 비착용 강화 토큰은 같은 무리의 현행 원본 단계·확률·소지·재료 증명을 통과할 때만 경로를 연다. 2,146개 구조상 강화 후보는 현재 보유품이나 무조건 실행 가능한 개수가 아니다. 단계별 능력치만 있는 795개나 결과 자료 없는 17 ID에는 임의 성공률을 만들지 않았다. [강화 경계](../PATCH523_ENHANCEMENT_FAMILY_JOIN_20261124.md), [퀘스트 카드 8종](../quests/current523/QUEST_CARD_USE_20261124.md).

현재 배포 파일 목록과 원본 조인 기준 30,398개(non-TestItem): 정적 이미지 29,902, 선택된 원본 장면 459, 아이콘 선언 없음 34, 명시적 더미 3. 파일 목록·크기 대조는 모든 픽셀의 기기 표시 검증과 다르다. 제작한 이미지는 0개. [자산 검사 범위, 실제 파일 및 미확인 구분](../source523-item-icon-audit-20261124.md).
