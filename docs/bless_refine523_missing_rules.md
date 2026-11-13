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
| 4 | 속성 강화 장비의 가루 증폭 | `BlessPowderAmplifyRate`는 속성 단계별 비율만 있고, 수량에 곱하는지·더하는지·반올림이 없음 | 속성 강화된 장비는 용해 거부 (보존) |
| 5 | 상급·최상급 용해 | `AdvancedBlessPowderAmount`/`Increment`: 촉매(상급/최상급 용해제) 소모 수량, `Increment`와 `MinSafeEnchantLevel`의 관계, `Multiplier`·`ItemEnchantScrollID`의 의미, 최상급 결과 아이템 연결 열, +6 이상 증가량 | 미구현 (상급 용해 선택 불가, 재료 보존) |
| 6 | `BlessConstant` HighMelt*/HighestMelt* 등급 범위 | 어떤 용해에서 어떤 대상 등급을 거르는지 설명 없음 | 사용하지 않음 (5번과 함께 보류) |
| 7 | 축복·저주 장비 용해 | 표에 축복 상태 열이 없음 | 축복 상태와 무관하게 등급·강화 수치로만 계산 |
| 8 | 다른 가공·보상 기록이 있는 장비 | 세공·제련·연금 기록, 퀘스트 보상 영수증 등이 붙은 장비를 용해·연금할 때의 처리 없음 | 거부 (해당 장비와 기록 보존) |
| 9 | 용해 한 번의 최대 개수 | 없음 | 제한 없이 선택한 장비 전부 |
| 10 | 질서의 연금 활성 여부 | `ContentsControl` `Refine`의 `Enable`이 거짓, 도움말에 "21년 6월 30일 업데이트 이후 사용 불가" | 지시대로 로컬에서 동작시키고, 창에 "원본 523에서는 꺼져 있음"을 표시 (**사용자 확인 필요**) |
| 11 | 최소~최대 사이 등록 수량의 확률 | 원본 창에 +100/+1000/직접입력 버튼이 있으나 중간 수량 확률 계산식이 없음 | 최소·최대 두 끝점만 허용, 중간 수량 거부 |
| 12 | 특수 재료 (`IsSpecialInput`, 2번 슬롯, 이벤트 "상급 제련의 가루") | 기본 슬롯 확률과 합치는 방식 없음 | 사용 불가 (보류) |
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
