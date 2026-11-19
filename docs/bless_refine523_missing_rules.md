# 원본 523 용해(축복의 가루) · 질서의 연금 — 표에 없는 세부 규칙

코드: `scripts/refine523/` (규칙 `bless_refine523_rules.gd`, 거래 `bless_refine523_service.gd`,
창 `bless_refine523_panel.gd`), 검증 `tests/bless_refine523_test.gd`.
규칙은 설치된 원본 523 정의 ZIP(`current523_definition_rows.gd`)에서만 읽습니다. 이 문서에는
원본 표의 행을 옮기지 않고, 어떤 열·규칙이 없는지만 적습니다.

## 구현한 것 (표에 자료가 있는 부분)

- **일반 용해**: 대상 장비 자신의 ItemClass `IsSoluble`이 참일 때, `BlessPowderAmount`의
  (`GradeID`, `Enchant`) 행 `Amount`만큼 축복의 가루를 받습니다. 대상 장비는 사라집니다.
- **질서의 연금**: `RefineItem`(대상 ItemClassID + 정확한 강화 수치) → `RefineItemGroup` →
  `RefineInput` 1번 슬롯(상급 축복의 가루) `MinAmount`/`MaxAmount`와 그 확률
  `MinProbability`/`MaxProbability`(1,000,000 = 100%) → `RefineOutput`(확률 가중, 결과 강화 수치) ·
  `RefineConstants` `RefineCost`(`RefineCurrencyID` 1 = 아데나), `TargetItemMaxAmount` 1.
  확률 표시는 원본 도움말대로 소수점 아래를 버립니다. 실패하면 대상 장비가 돌아옵니다(도움말 문구).
- 한 번의 시도는 대상·재료(원본 물리 수량 장부)·아데나·결과·난수를 한 번에 저장하고, 저장이
  실패하면 아무것도 바뀌지 않습니다.

## 표에 없는 세부 규칙과 처리

| # | 항목 | 표에 없는 것 | 처리 |
|---|------|-------------|------|
| 1 | 일반 용해 촉매 | `용해제 (각인)`(DissolutionMethodID 14)은 있으나 일반 용해에 필수인지, 몇 개 소모하는지 없음 | 촉매 없이 진행, 촉매 미소모 (**사용자 확인 필요**) |
| 2 | 용해 결과 아이템 | `BlessPowderAmount`에 결과 아이템 열이 없음 | 523에서 활성(TestItem 거짓)인 유일한 `축복의 가루` ItemClass를 사용 (원본 용해 UI 문구 "축복의 가루 100"과 일치) |
| 3 | `BlessConstant` `BlessPowderRate` | 단위·적용식 없음 (값 하나만 있음) | 현재 값(100)일 때만 표 수량 그대로 지급, 다른 값이면 용해 보류 |
| 4 | 속성 강화 장비의 가루 증폭 | `BlessPowderAmplifyRate`는 속성 단계별 비율만 있고, 수량에 곱하는지·더하는지·반올림이 없음 | **TWILIGHT 근사(근거 약함, 2026-11-16)**: 표 수량 × (100 + AmplifyRate)% 버림. 아래 "근사 적용 (2)" |
| 5 | 상급·최상급 용해 (2026-11-19 원본 소비 규칙 + TWILIGHT 근사 safe): 결과 = (trunc(Amount × pow(`Multiplier`, max(0, 장비 강화 − safe))) + `AdvancedBlessPowderIncrement`[속성 단계].Amount(행 없으면 0)) × 수량. safe = max(`MinSafeEnchantLevel`, helper safe). 원본 helper는 복원되지 않아 **TWILIGHT 근사**: 행의 `ItemEnchantScrollID`(주문서 그룹 1 무기·11 갑옷·302 장신구)와 장비 `EnchantEquipGroupID`가 함께 가리키는 확률 그룹의 `BmItemEnchantProView` 100% 성공 단계 수(= 안전 강화). 못 정하면 `MinSafeEnchantLevel`만 쓴다. safe 이하 분기는 원본 미복원 → 배수 없음(지수 0). 결과 아이템 = 용해제 ItemBonus `SolutionItemClassID`(상급 → 117544, 최상급 → 192654), 용해제 장비 1개당 1개 | 보고서2 NEW02. 인벤 예 "영웅 무기 6강 + 속성 1단 = 4090개" = 4000 × 2^(6−6) + 90 (영웅 무기 안전 강화 6)과 일치. "마족 3강 + 속성 3단 = 1050개"(장신구 안전 0)는 원본 식으로는 395 + 870 = 1265라 맞지 않는다 — 2021년 글이라 `Multiplier` 도입 전 값일 수 있어 원본 식을 따른다 |
| 6 | `BlessConstant` HighMelt*/HighestMelt* 등급 범위 | 어떤 용해에서 어떤 대상 등급을 거르는지 설명 없음 | **TWILIGHT 근사**: HighMelt* = 상급(24) 대상 등급, Highest{Weapon,Armor,Accessory}Melt* = 최상급(34) 종류별 대상 등급 |
| 7 | 축복·저주 장비 용해 | 표에 축복 상태 열이 없음 | 축복 상태와 무관하게 등급·강화 수치로만 계산 |
| 8 | 다른 가공·보상 기록이 있는 장비 | 세공·제련·연금 기록, 퀘스트 보상 영수증 등이 붙은 장비를 용해·연금할 때의 처리 없음 | 거부 (해당 장비와 기록 보존) |
| 9 | 용해 한 번의 최대 개수 | 없음 | 제한 없이 선택한 장비 전부 |
| 10 | 질서의 연금 활성 여부 | `ContentsControl` `Refine`의 `Enable`이 거짓, 도움말에 "21년 6월 30일 업데이트 이후 사용 불가" | 지시대로 로컬에서 동작시키고, 창에 "원본 523에서는 꺼져 있음"을 표시 (**사용자 확인 필요**) |
| 11 | 최소~최대 사이 등록 수량의 확률 | 원본 창에 +100/+1000/직접입력 버튼이 있으나 중간 수량 확률 계산식이 없음 | **TWILIGHT 근사(2026-11-16)**: 두 끝점 사이를 직선으로 잇고 원본 단위(1,000,000=100%)에서 버림. 아래 "근사 적용" 참고 |
| 12 | 특수 재료 (`IsSpecialInput`, 2번 슬롯, 이벤트 "상급 제련의 가루") | 기본 슬롯 확률과 합치는 방식 없음 | **TWILIGHT 근사(근거 약함)**: 자기 Min~Max 직선 확률을 기본 확률에 더함, 최대 100% |
| 13 | 실패 시 재료·아데나 | 도움말은 "실패해도 대상 아이템은 돌아온다"만 적음 | 재료·아데나는 소모 (도움말 해석, **사용자 확인 필요**) |
| 14 | 결과물의 축복·속성 등 계승 | `RefineOutput`에 축복 상태 열 없음, 속성·기타 기록 계승 규칙 없음 | 일반(축복 코드 1)·속성 없음 장비만 대상으로 허용, 결과도 일반 상태로 지급. 축복·저주·속성 장비는 거부 |
| 15 | `RefineItemGroup` `FromEnchant` | 의미 설명 없음 | 사용하지 않고 `RefineOutput` `Enchant`를 그대로 사용 |
| 16 | `RefineDivinationProb` (수정구 색 예측) | `MaxGrade`가 무엇의 최대 등급인지 없음 | 사용하지 않음 (예측 연출 없음) |
| 17 | `RefineConstants` `ItemListMaxSize` | 무엇의 목록 크기인지 없음 | 사용하지 않음 |
| 18 | `RefineOutput` `ClassID` | 0이 아닐 때의 직업 제한 규칙 없음 (523은 전부 0) | 0만 허용, 다른 값이면 거부 |
| 19 | 같은 표에 결과가 여러 개일 때 | 523은 그룹마다 결과 1개 | `Probability` 가중 추첨 (합계가 정확히 100%가 아니면 거부) |

## 원본 UI

- 원본 창 `UI/RefineScene.csb`, `UI/Refine/Refine_All.csb`(제목 "질서의 연금", +100·+1000·Min·Max·직접입력,
  연금 시작, 시스템 메시지), `Refine_Inventory`, `Refine_Slot`, `Refine_Roulette` 등과 용해 팝업
  `UI/CommonUi/Common_Dissolution_Popup.csb`, `Common_MessageBox_Dissolution.csb`가 있습니다.
- (2026-11-13 연결) 메뉴 "질서의 연금"은 원본 `RefineScene`(`source_main_refine_window.gd`)로 열립니다.
  연금 재료(대상 장비 + 상급 축복의 가루)는 원본 `Inventory_Slot_Set`/`Common_Slot`, 대상·기본재료 칸,
  최소·최대 수량, 성공 확률, 아데나 비용, 연금 시작, 시스템 메시지를 서비스 값으로 채웁니다.
  +100/+1000/직접입력은 11번 규칙이 없어 비활성 상태로 표시, 특수재료 칸은 잠금, 연금 결과물 목록·도움말·
  룰렛 연출·마법 구슬(프레임 이벤트)·레시피 문구는 연결하지 않았습니다.
- 용해는 "용해·질서의 연금" 작업창에서 장비를 고르고, 원본 `Common_MessageBox_Dissolution`
  ("N개의 아이템을 용해하시겠습니까?", 예상 결과물 축복의 가루 그림·수량)으로 확인합니다. 원본 가방의
  용해 모드(Inventory_All Btn_Dissolve)와 촉매 선택 팝업(Common_Dissolution_Popup)은 연결 규칙(어느 버튼이
  모드를 여는지, 촉매)이 없어 연결하지 않았습니다. 이미지는 만들지 않았습니다.

## 근사 적용 (사용자 정책 2026-11-16 "원본 데이터에 없는 건 검색 후 근사치로 적용해")

### #11 중간 수량 확률 — 적용 (PR `feat/approx523-refine-amount`)
- 없던 것: `RefineInput`에는 `MinAmount`/`MaxAmount`와 그 확률 `MinProbability`/`MaxProbability` 두 끝점만 있다.
- 찾은 것:
  - 원본 523 행 자체가 비례한다. 가장 많은 행 묶음 `10,000개 → 10%`, `20,000개 → 20%`(192행), `8,000 → 10% / 16,000 → 20%`(108행)는
    "가루 1,000개당 1%"(첫 묶음) 직선 위에 있다.
  - 플레이어 실험 글(인벤 팁 게시판, 2021-02-08): "확률 10% 부터 도전이 가능하네요", "9천개니깐 확률 9%?" —
    <https://www.inven.co.kr/board/lineagem/5056/17012> (2026-11-16 확인). 공식 공지·가이드에서 중간 수량 공식은 찾지 못했다.
  - 다른 연금 실험(희귀 장비 1개당 영웅 확률 +1%, 선형): <https://www.inven.co.kr/board/lineagem/5056/19361>.
- 적용: 등록 수량 N(최소 ≤ N ≤ 최대)의 확률 = `MinProbability + (MaxProbability − MinProbability) × (N − MinAmount) / (MaxAmount − MinAmount)`,
  원본 단위에서 버림. 최소 미만·최대 초과는 거부. 상수 `bless_refine523_rules.gd` `APPROX_LINEAR_BETWEEN`(false로 바꾸면 예전처럼 끝점만).
- 화면: `용해·질서의 연금` 작업창에 가방의 상급 축복의 가루가 최소와 최대 사이일 때 "보유 N개 (P% · 근사)" 버튼이 추가된다.
  원본 `RefineScene` 창(+100/+1000/직접입력 버튼)은 다른 작업 영역(`scripts/ui/original_ui`)이라 이번에 바꾸지 않았다(서비스는 `amount:N`을 받는다).
- 확인: `tests/bless_refine523_test.gd` — 15,000개 → 15%, 10,001개(10,000~19,000 / 10.53~20%) → 10.531%, 범위 밖 거부, 실제 Main 원본 팩에서
  대상 장비의 중간 수량 견적이 직선 값과 같음.

### (이전 메모) 보류했던 근거
- #5·#6 상급·최상급 용해: 촉매 소모량·증가량·배수 해석. 검색한 글(인벤 "상급 축복 가루표 / 연금 / 상급 용해제", 2021-07-26,
  <https://www.inven.co.kr/board/lineagem/5056/19201>)은 "계산은 강화 가루 + 속성단계 가루", "마족 3강 + 속성 3단 = 1050개" 같은 결과 예만 있고
  촉매 소모 수량·`Increment`/`Multiplier` 열의 뜻은 없다. 근사할 근거가 부족해 이번 PR에서는 그대로 둔다.
  (같은 글의 "강화 가루 + 속성단계 가루"는 #4 속성 강화 장비의 가루를 '더한다'는 단서지만, 속성 단계 가루 값과 `BlessPowderAmplifyRate`의 관계가 확인되지 않아 #4도 유지.)
- #12 특수 재료(2번 슬롯): 원본 창 연결이 다른 작업 영역이라 보류. → 아래 "근사 적용 (2)"로 대체.

## 근사 적용 (2) 2026-11-16 — 사용자 지시 "근사치로 다 넣어" (PR `feat/approx523-refine-advanced`)

근거가 약해 보류했던 항목을 모두 근사로 열었다. 근거가 약한 것은 **TWILIGHT 근사(근거 약함)**으로 표시했다. 상수는 `bless_refine523_rules.gd`
(`APPROX_ELEMENT_AMPLIFY` · `APPROX_ADVANCED_DISSOLVE` · `APPROX_SPECIAL_INPUT` · `ADVANCED_SOLVENT_PER_ITEM`)에 있고 false/값 변경으로 되돌릴 수 있다.

| # | 적용 | 근거 |
|---|---|---|
| 4 (원본 소비 규칙, 2026-11-19) | 일반 용해 가루 = (표 수량 + ceilf(float32(`BlessPowderAmplifyRate`/100) × float32(표 수량))) × 수량. 속성 1~3단 10%, 4~5단 15%, 6단 이상 20%. float32 그대로라 예: 100 × 15% → 15.000001f → 116, 101 × 5% → 107 (예전 정수 버림은 115·106) | 보고서2 NEW01(원본 클라이언트 소비 함수). 인벤 정리 글 "계산은 강화 가루 + 속성단계 가루"(2021-07-26, <https://www.inven.co.kr/board/lineagem/5056/19201>)와도 같은 방향 |
| 5 | 상급·최상급 용해: 결과 = `AdvancedBlessPowderAmount`(장비 종류 `ItemCategory`·등급·용해 방식).Amount + `AdvancedBlessPowderIncrement`(같은 방식, `EnchantLevel` = 장비의 **속성 단계**).Amount. 결과 아이템 = 용해제 ItemBonus `SolutionItemClassID`(상급 용해제 → 상급 축복의 가루 117544, 최상급 용해제 → 최상급 축복의 가루 192654). 용해제는 장비 1개당 1개 소모(표에 열 없음, 가장 보수적) | 같은 인벤 글의 예 "마족 3강 + 속성 3단 = 1050개" = 장신구 3등급 180 + 증가량 3단 870, "영웅 무기 6강 + 속성 1단 = 4090개" = 무기 4등급 4000 + 증가량 1단 90과 정확히 같다. 이 예에서 강화 수치·`Multiplier`·`MinSafeEnchantLevel`은 결과를 바꾸지 않으므로 적용하지 않는다 |
| 6 | 대상 등급: 상급(24) = `HighMeltGradeMin~Max`(3~4), 최상급(34) = 무기/방어구/장신구별 `Highest*MeltGradeMin~Max`(4~5) | 상수 이름 그대로 |
| 12 (근거 약함) | 특수 재료(2번 슬롯) M개 = 자기 Min~Max 직선 확률(#11과 같은 규칙)을 기본 확률에 **더함**, 최대 100%. 특수 재료도 차감 | 원본 행(1~2개 → 1~2%)이 "추가 확률" 크기라 더하는 해석이 가장 자연스럽다. 공식 설명은 찾지 못함 |
| 14 (근거 약함) | 축복·저주 대상 장비도 연금 가능, 결과물은 대상의 축복 상태를 이어받음. 속성 강화 장비는 계속 거부(아이템 공급자에 속성 필드가 없어 이어받을 수 없음) | 공식 설명 없음 |

- 화면: 용해 작업창에 가방에 있는 상급/최상급 용해제마다 "선택한 장비 상급 용해 / 최상급 용해 (용해제 #ID · 근사)" 버튼. 연금 서비스는 `amount:N|special:M`을 받는다
  (원본 `RefineScene` 창은 `scripts/ui/original_ui` 작업 영역이라 바꾸지 않음).
- 저장: 장비 제거·용해제/특수 재료 차감·결과 지급이 한 번의 저장으로 기록된다(기존 용해·연금과 같은 원자 저장).
- 확인: `tests/bless_refine523_test.gd` — 일반 101×10%×3 = 336, float32 경계(5×20% → 6, 100×15% → 116), 상급 100×2^(7−5)+9 = 409·안전 이하 109·int64 넘침 거부, 표 행마다 safe+2 = Amount×Multiplier², 영웅 무기 6강+속성1단 = 4090, 실제 Main에서 안전 강화 초과 장비의 상급 견적 = 지급, 속성 +4 = ceilf 15%, 상급/최상급 표 행마다 실제 원본 장비로 Amount 일치, 상급 + 속성 3단 = Amount + 870,
  용해제 → 방식·결과 아이템, 특수 재료 2개 → +2%, 실제 Main에서 3등급 무기 + 상급 용해제 2개 → 상급 용해 → 상급 축복의 가루 +표 수량·용해제 1개 남음·다시 불러와도 유지.

## 대장간 연마 (ItemHoning) — 연결 + TWILIGHT 근사 (2026-11-16, 같은 PR)

이전 상태: `scripts/honing/`(소유 확인·결과 정책·소비 경계)만 있고 게임에서 부르는 곳이 없었다(`docs/REST_INTEGRATION.md` "honing target/source authentication … remain explicit follow-ups").

- 원본 표: `ItemHoningEntity`(대상 신화 무기 24종, MinEnchant 7), `ItemHoningProbability`(+7 7% · +8 15% · +9 33%), `ItemHoningCost`(시도마다 신화 연금석 2 + 태고의 구 1),
  `ItemHoningEpithet`(태고의, 100%), `ItemHoningEpithetBonus`(PierceDamageReductionPercent 50000).
- NC 공식 확률 정보 "무기 연마 확률"(<https://probability.plaync.com/lineagem/view?probCategoryId=6a66b3649bb1696f4bf77325>, 2026-11-16 확인):
  같은 7/15/33%, "+7 이상 신화 등급 무기에만 연마가 가능", "성공 확률을 제외한 나머지 값은 실패 확률", 수식어 "태고의 · 대미지 증가 +5%".
- TWILIGHT 근사:
  - +10 이상은 마지막 행(+9, 33%)을 쓴다(표·공식 모두 +9까지만 있음).
  - 실패: 재료만 소모, 무기와 강화 수치는 그대로(공식 표에 소실 언급 없음, 기존 `outcome_policy.gd`와 같음).
  - 무기마다 수식어 1개(연마된 무기는 다시 연마하지 않음).
  - PierceDamageReductionPercent 5% → 공식 문구대로 **대미지 +5%**: 연마된 무기를 착용하면 일반 공격·스킬 피해(`world._deal_successful_player_hit`)에 곱한다.
- 연결: `scripts/honing/honing523_service.gd`(규칙·견적·시도·효과), 용해·질서의 연금 작업창의 "[대장간 연마]" 버튼. 재료 차감·결과·난수를 저장 한 번에 기록.
  연마 기록은 무기 물리 개체의 `honing` 칸(수식어·보너스·시도 확률)으로 저장된다. 원본 대장간 창(원본 UI)은 다른 작업 영역이라 연결하지 않았다.
- 확인: `tests/honing523_test.gd` — 확률 행, 비용, 실제 Main에서 +7 진명황의 집행검 실패(재료 차감·무기 유지) → 성공(태고의) → 착용 시 +5% → 저장·불러오기 유지.
