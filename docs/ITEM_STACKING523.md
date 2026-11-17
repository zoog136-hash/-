# 가방 겹치기 (원본 523 묶음 병합)

사용자 요청 2026-11-17: "아이템들 겹칠 수 있는 건 좀 겹치게 해".
사용자 확인 2026-11-17: 장비류는 아이템 ID가 같아도 개체별로 절대 합치지 않음.

## 원인

원본 비장비 아이템(재료·소모품·보관용)은 지급·습득될 때마다
`current523_native_stack.stage_grant()`가 새 물리 ID와 영수증
(`source_native_stack_receipt`)을 만들었고, 가방은 물리 ID 1개당 1칸으로
그렸다. 그래서 같은 `[재료] 할파스의 집념`이 15칸 × 1개로 보였다.
소지 수량·무게는 원래부터 합계였다.

## 규칙 (`scripts/loot/native_stack_merge.gd`)

- 원본 열: `ItemClass.MaxStackAmount` (523 표 34,743행 모두 값 있음).
- 합치는 조건: 같은 이름·같은 원본 ItemClass ID·같은 축복/저주(`bless_raw`)·
  강화 0·나머지 기록 동일, 슬롯이 재료/소모품/화폐인 영수증 묶음.
- 장비(`patch523_monster_drops.equipment`)는 MaxStackAmount와 상관없이
  절대 합치지 않음. 다른 아이템 ID도 절대 합치지 않음.
- 한 칸의 상한은 원본 MaxStackAmount. 넘으면 다음 칸에서 새로 쌓는다
  (기존 묶음을 쪼개지 않음). MaxStackAmount 1인 행은 합치지 않음.
- TWILIGHT 근사: MaxStackAmount가 양의 정수가 아닌 행(523 표에는 없음)은
  9999개까지 쌓는다.
- 실행 시점: `_update_hud` / `_refresh_inventory_hud` (습득·지급·불러오기
  뒤) — 거래 중(`busy`)이 아닐 때만, 전체 소유 검증(`state_error`) 통과 후
  채택하고 다음 저장에 기록한다. 예전 저장의 쪼개진 칸은 불러오기 직후 합쳐진다.
- 창고·다른 캐릭터·바닥의 개체는 건드리지 않는다.

## 기록 보존

- 합쳐진 묶음은 schema 3 영수증을 가진다: `origin.kind=owned_quantity_merge`,
  `merge_id`, 흡수한 물리 ID와 수량 목록, `granted_quantity`=합계.
- 병합 장부 `consumable_state.source_native_stack_merges[merge_id]`에 흡수된
  각 묶음의 원래 영수증·사용량·이전량·잔량을 그대로 보관한다. 흡수된 묶음의
  사용 장부 행은 이 장부로 옮겨진다(사용량 그대로). 분할(바닥 내려놓기·창고
  부분 이동) 기록은 이 장부를 통해 계속 검증된다.
- 남는 묶음은 원래 물리 ID를 유지한다(잠금·착용 화살 선택이 따라감). 모든
  구성원이 분할 기록에 걸린 경우에만 새 물리 ID를 쓴다.
- 잠긴 칸이 하나라도 있으면 합쳐진 칸도 잠김.
- 병합 장부는 계정 공유 증명(`account_store.SHARED_PROOFS`)에 포함된다.
- 일반 거래는 병합 장부를 바꾸거나 새로 추가할 수 없다(`override_error`).

## 검증

`tests/item_stacking523_test.gd` (CI core 등록).
