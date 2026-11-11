# 원본 523 NPC 생산 — 표에 없는 규칙 목록

대상 표: `NpcProductionGenerationOutput`(402행), `NpcProductionCombinationInput`(92행),
`NpcProductionCombinationOutput`(23행), `NpcProductionMerge`(2행), 그리고 이 표들을
가리키는 유일한 표 `LuckyDefenceUnitSummon`(35행). 참고: `NpcCombination`(1행),
`NpcCombinationPool`(8행).

구현: `scripts/npc_production523/` (rules / state / service / panel).
테스트: `tests/npc_production523_test.gd`.

## 원본 표가 말하는 것

- 생산되는 "NPC"는 아이템이 아니라 `NpcClass`의 `[디펜스][아군 npc]` 유닛이다. 생산 표에 나오는 유닛은 37종이다
  (일반·희귀·영웅·전설·신화). 마을 NPC의 `CraftList`(제작) 기능은 `ItemCraft*` 표를 쓰며,
  `EarthObjectDialogActions`에 NPC 생산과 이어지는 행동 종류(`DialogActionType`)는 없다.
- 이 표들은 미니게임 `MiniGame` 8 "LuckyDefence"(4인 `PlayerIndex` 1~4, 905초,
  `MiniGameWaveTime` 26웨이브)에 속한다. `ContentsControl` "LuckyDefence"의 `Enable`은
  523에서 **false**다.
- 소환 비용: `LuckyDefenceUnitSummon.CurrencyID` 2718 "[디펜스] 마물의 결정" ×
  `Cost`(랜덤 50, 영웅 60, 전설 70). `CurrencyUnitClass`로 연결된 가방 아이템은
  326368 "[디펜스][화폐] 마물의 결정"이다.
- 확률 단위는 1,000,000. 랜덤 소환 그룹의 합계는 100%이고, 영웅 소환은 20~40%,
  전설 소환은 10~20%다.
- 조합 23개: 재료 유닛 4개(같은 유닛이 두 번 들어가기도 함) → 결과 1개, 확률 100%.

## 이번에 구현한 것 (표 그대로)

| 기능 | 규칙 | 처리 |
| --- | --- | --- |
| 소환 | `LuckyDefenceUnitSummon` 시작 레벨 행(8 랜덤 / 28 영웅 / 48 전설) | 326368 물리 묶음에서 `Cost`만큼 차감하고, 0~999,999 사이 한 번 굴려 행 ID 순서의 누적 확률로 유닛 1개를 준다 |
| 조합 | `NpcProductionCombinationInput/Output` 23개 | 재료 유닛을 모두 차감하고, 결과를 `Probability`로 준다 |
| 저장 | 저장 키 `npc_production523` | 유닛 보유 수(NpcClassID → 수), 최근 기록 20개. 재화 차감·유닛·RNG가 한 번의 저장으로 함께 기록된다 |

해석해서 쓴 부분은 아래 표의 "해석" 항목에 적어 두었다.

## 표에 없는 규칙 (지어내지 않고 보류 또는 해석)

| # | 빠진 규칙 | 처리 |
| --- | --- | --- |
| 1 | **합성 결과**: `NpcProductionMerge`에는 Grade(1 일반, 3 희귀)와 Quantity 3만 있고, 결과 유닛·등급·확률·생산 그룹 열이 없다 | 합성은 거부(`merge_output_missing`) |
| 2 | **확률 합계가 100% 미만일 때의 의미**: 영웅·전설 소환 그룹의 합계가 11~40%다 | 해석: 남은 범위는 "유닛 없음"(실패)이고, 비용은 시도마다 소모한다(비용은 결과 행이 아니라 소환 행에 있음). 합계로 나눠 정규화하면 레벨 1~6 행이 모두 같은 분포가 되어 레벨별 확률 차이가 사라지므로 이 해석을 택했다 |
| 3 | **소환 레벨 상승**: 레벨 0~6 행(레벨X·0·1·2·3·4·MAX)이 있지만, 레벨을 올리는 조건·비용·시점이 없다 | 시작 레벨(이름이 "레벨0"인 Level 1 행)만 사용하고, 다른 레벨은 거부(`summon_level`) |
| 4 | **"레벨X"(Level 0) 행의 용도** | 사용하지 않음 |
| 5 | **UnitSummonType 38 / 48**: 이름은 "영웅/전설 소환 레벨0"인데 결과는 희귀 4종(10%)과 영웅 6종(10%)이고, 레벨 0~6 모두 같은 그룹이다. 종류 이름 표가 없다 | 거부(`summon_type`) |
| 6 | **재화 획득**: 326368은 원본에서 `[디펜스] WaveN 시작 재화 지급` NPC 82종만 떨어뜨린다(웨이브마다 지급). 일반 필드 획득 경로가 없다 | 이 PR은 경로를 추가하지 않는다. 지금은 가방에 326368이 있을 때만 소환할 수 있다 |
| 7 | **유닛 사용처**: 배치 칸(`MiniGameCellGroup`/`Cells`), 공격, 웨이브 방어, 판매, 보유 상한, 매치 종료 후 유지 여부 | 정해진 것이 없음. 유닛은 보유 목록으로만 남는다(전투에 쓰지 않음) |
| 8 | **MiniGameComponent** 45행: `MiniGameComponentTypeID` 이름 표가 없어 값의 의미(시작 재화, 소환 레벨, 보유 상한 등)를 알 수 없다 | 사용하지 않음 |
| 9 | **입장 비용·횟수**: `MiniGame.EntryCurrencyID` 174 × 20, `MiniGameTicketCost` | 매치 루프가 없으므로 사용하지 않음 |
| 10 | **보물·재굴림**: `MiniGameTreasure*`의 등급 확률은 있지만, 효과를 적용하는 시점이 없다 | 사용하지 않음 |
| 11 | **서포터·보상**: `MiniGameSupporter*`(협업 캐릭터), `MiniGameReward`, `MiniGameFinishCondition` | 사용하지 않음 |
| 12 | **4인 매치**: PlayerIndex 1~4 구성(온라인 파티) | 범위 밖(온라인 전용) |
| 13 | **NpcCombination / NpcCombinationPool**: 파티던전 오림의 버프 NPC 8종 풀(IsRandom, RewardType 1, TimeLimit 7000)이다. 재료 열이 없고 생산 표가 아니다 | 사용하지 않음 |
| 14 | **CurrencyUnitClass.UnitID 4 / ConsumePriority**: 의미가 적혀 있지 않다 | 해석: `Currency.ExchangeRate`가 1이므로 재화 1 = 아이템 1개로 계산 |
| 15 | **유닛 표시 이름**: `NpcClass.DescId`가 가리키는 `DescData_Korean` 행이 비어 있다 | `NpcClass.Name`에서 `[디펜스][아군 npc]` 접두어를 뗀 이름으로 표시 |
| 16 | **원본 UI**: `Hud_Defense_AttackPad_Random/Epic/Legend`, `Hud_Defense_Combination_Myth/Epic_Btn`, `Hud_Defense_PadGroup`은 매치 HUD의 부품이고, 따로 여는 창(csb)이 없다 | 기존 작업 창으로 노출: 제작 창 → "NPC 생산" 버튼 |

## 연결 경로

마을 NPC 대화창의 마지막 페이지 → `CraftList` → 기존 제작 창(`open_crafting`) →
상단 "NPC 생산" 버튼 → NPC 생산 창. 원본에서 NPC 생산과 이어진 마을 NPC가 없기 때문에,
대화창의 제작 기능으로 열리는 제작 창 안에 버튼으로 붙였다.
