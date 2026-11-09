# 원본 클라이언트 계약 적용 — P2(C09–C10)·P3–P7 (C11–C28) (2026-11-09)

앞 문서(`ORIGINAL_CLIENT_CONTRACT_P0_P2.md`)의 이어지는 단위다. 인계 자료와 규칙은 동일하다: 원본 EXE/DLL은 한 번도 실행하지 않았고, 모든 새 인터페이스는 `DESIGN_NOT_RECOVERED_API`이며, 미승인 47–49는 승격하지 않았다.

## 추가한 모듈 (`scripts/original_client/`)

| 파일 | 계약 / 단계 | 내용 |
| --- | --- | --- |
| `actor_visual_layers.gd` | C09 / P2 | 주 SP2 + 보조 요청, 보조 선택, 주 교체, draw order |
| `sprite_cache.gd` | C10 / P2 | 요청/파일 캐시, remap 추가, hot reload, 모드 전환, 한도 450 / 64MiB |
| `map_path.gd` | C11 / P3 | 접두, half-cell x, 슬롯 파일 좌표(부호 있는 절단), `%04x%04x.s32`, 읽기 분류 |
| `s32_chunk.gd` | C12 / P3 | 접두/셀/그룹/꼬리 bounded 읽기 |
| `terrain_collision.gd` | C13 / P3 | 방향 delta, reject attr, 홀수 방향 쌍, step 검사. BFS 경로 탐색은 DESIGN 전용 |
| `input_projection.gd` | C14 / P3 | float32 투영·역투영, 입력점, 방향 열 변환(최대 50) |
| `actor_motion.gd` | C15 / P4 | 수신 좌표와 step 좌표 분리, CANCEL ACK, END 재길찾기 보존, timer 취소 |
| `effect_lifecycle.gd` | C16 / P4 | Missile/Direct 효과 수명, 완료 callback 분기 |
| `curve_path.gd` | C17 / P4 | 반올림(±0.5), 경로 캐시(원본 호환 hit) |
| `ui_tree_cache.gd` | C18 / P5 | CSB 로드/제외 set/프로토타입 캐시, hide ≠ detach ≠ destruct |
| `map_presentation.gd` | C19 / P5 | PARTY1–4, 로컬 1CB 미니맵, 큰지도 timer 분리 |
| `inventory_view_model.gd` | C20 / P5 | 수량 한국어 표기(만/억), 배지 규칙, 캐시 hit 후 갱신 |
| `spell_ui_numeric.gd` | C21 / P5 | u64→f32 직접 반올림, 백분율(f64 나눗셈 후 ×100), 진행 action 전이 |
| `health_display.gd` | C22 / P5 | 정수 raw %, NpcHpMp 분기, zero-extend 후 100 clamp, overhead 캐시 |
| `target_selection.gd` | C23 / P6 | float32 timer(strict >), 점수/안정 정렬, retention 분기 |
| `client_intents.gd` | C24 / P6 | wire 96/97/98·local 97 분리, `OfflineIntentRecorder` |
| `world_session_lifecycle.gd` | C25 / P7 | root+70/+78 raw owner, 표면 928×684 / 1200×675 |
| `render_trace.gd` | C26 / P7 | item suffix(V19), floor ≠ item dispatcher, 업로드 API ≠ 화면 성공 |
| `world_visual.gd` | C27 / P7 | 날씨 FIFO(틱당 1개), 빛 lerp, screen effect 422 |
| `audio_request.gd` | C28 / P7 | `Sound/<signed>.ogg`, material 효과 gain, family별 owner |

## 테스트와 인수 결과

| 테스트 파일 | 대상 |
| --- | --- |
| `tests/original_client_contract_p0_p2_test.gd` | C01–C08 |
| `tests/original_client_p2_layers_cache_test.gd` | C09–C10 |
| `tests/original_client_p3_map_input_test.gd` | C11–C14 |
| `tests/original_client_p4_motion_effect_curve_test.gd` | C15–C17 |
| `tests/original_client_p5_ui_state_test.gd` | C18–C22 |
| `tests/original_client_p6_p7_scene_test.gd` | C23–C28 |

acceptance 95개 전부 위 테스트로 실행했고 `acceptance_checklist.json`에 PASS로 기록했다(`tools/original_client_acceptance.py --run-log … --run-log …`, 로그에 있는 항목만 갱신). **PASS의 의미는 DESIGN 모듈이 문서화된 계약을 fixture에서 따랐다는 것뿐이다.** 원본 바이너리 실행·native 동등성·실제 화면 결과를 뜻하지 않는다. 수치 벡터 V01–V19는 모두 구현에 대해 실행했다(V14 `5F000001`/`5A031270`, V15 `3D1DDD22`, V19 start 5 / visited 35).

## 게임 연결 상태

- 연결: 이전 PR(#324)에서 SP2 member/group, `AssetType.Path+FilePath` 결합, 명시 FPS duration 세 곳. 동등성은 전수 differential 테스트로 증명.
- 이번 단위(C09–C28)는 **연결하지 않았다.** 현재 게임 코드에 같은 산술을 하는 지점(S32 파일명/좌표 변환, 투영, 충돌, UI 수명)을 찾지 못했고, 의미가 다른 곳에 억지로 끼우면 동작이 바뀔 위험이 있어 모듈 + 테스트로만 둔다. 연결 후보는 동등성 증명 가능한 지점이 생길 때 추가한다.

## 남은 미검증·한계

- 참조 DB(sqlite)가 이 환경에 없어 fixture 일부는 합성 값이다. `2500` 폴더 fallback 이름은 미복원(`fallback_name=null`).
- C13 경로 탐색(BFS)은 DESIGN 전용이며 원본 알고리즘이 아니다. C17 곡선 제어점 정책, C07 bucket shift ≥ 2, C25 중복 local2 안전성, C26 row gate의 게임상 의미, C27 최종 pixel, C28 실제 재생은 미검증.
- C23 점수식의 origin bonus(+150/+140)는 계약 문장 그대로이며 서버 AI·적대 판정·보상은 범위 밖(P8).
- C28 `category72`는 계약 표기를 category gain 입력값으로 받는 형태로만 구현했다(상수 의미는 미확정).
- 개인 팩이 필요한 `source523_skill_buff_images_test`는 이 환경에서 실행 불가(본 작업과 무관).
