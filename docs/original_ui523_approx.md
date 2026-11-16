# 원본 523 UI 창: 비워 둔 값의 근사·출처 기록

사용자 방침(2026-11-16 09:30): 원본 데이터에 없는 동작이나 수치는 웹 검색(리니지M 실제 화면·가이드)으로 근사치를 정해 적용하고, 그 값을 이 문서에 "TWILIGHT 근사(출처 URL)"로 모은다.

- 그림이 없는 것은 계속 비워 둔다(이미지를 만들지 않음).
- 게임에 기능 자체가 없는 것은 근사하지 않고 보고만 한다.
- 원본 테이블이나 CSB에 값이 있는 것은 근사가 아니라 원본 값을 쓴다. 이 경우 "원본"으로 적는다.

## 적용한 값

| 창 | 항목 | 구분 | 적용 값 | 근거 |
|---|---|---|---|---|
| TJ의 쿠폰 합성 재도전 (Recovery_All_Compose) | 등급 카드의 확률 보기 | 원본 | 덱·등급별 원본 합성 규칙의 SuccessProbability ÷ 10,000 %. 같은 행으로 `scripts/tj/runtime.gd`가 굴리며, 서버 조건이 맞는 행 하나일 때만 표시함 | 원본 BuffCardMergeRule |
| 검색 키패드 (ItemBook/Inventory/Production/Trade_Popup_Keypad) | 입력 글자색 | 원본 | 흰색 (255,255,255,255) | 각 키패드 CSB TextField의 widget color가 흰색. 빈칸 글자는 Cocos TextFieldTTF 기본값인 127 회색(이미 적용됨). 근사 필요 없음 |
| 스킬 카드 강화 (SkillCard_Popup_Enchant) | 강화 전후 Lv·Exp·게이지 | 원본 형식 | `Lv.%d`, `Exp` 소수 4자리 % (원본 자리 표시 `00.0000%`), 게이지는 먹인 뒤 경험치 ÷ 필요 경험치 | 원본 CSB 자리 표시 + 기존 levelup quote 값 (#573) |
| 스킬 카드 강화 (SkillCard_Popup_Enchant) | 성공 확률 버튼 | 원본 | 기존 levelup quote의 원본 강화 확률(예: 66.7%) | 원본 표 · 실제 후기 "첫 시도 66.7%, 두 번째 33.3%" https://www.inven.co.kr/board/lineagem/5063/10729 |
| 카드 다시 뽑기 (CardChange_Popup_Retry) | 뽑기 확률 | 기능 규칙 | 같은 등급 후보 N종 중 1장, 각 1/N(지금 카드 제외). card523_swap execute가 균등하게 뽑음 | `scripts/cards/card_swap523.gd` |
| 카드 다시 뽑기 (CardChange_Popup_Retry) | 목록 보기 | 기능 데이터 | quote의 후보 이름(앞 20개 + 나머지 종 수) | quote.candidates |
| 카드 다시 뽑기 (CardChange_Popup_Retry) | 주의 사항 | 기능 규칙 | "다시 뽑은 결과는 카드 확정을 눌러야 획득, 확정 전에는 원래 카드 유지, 영웅 이상만" | 사용자 결정 2026-11-16. 원본 문구는 현금·마일리지 안내라 쓰지 않음 |

## TWILIGHT 근사(근거 약함): 정렬·필터 선택지

원본 문자열 테이블(UIStaticTextData/UITextData)에는 선택지 문구가 "정렬", "레벨 별 정렬", "등급 별 정렬"밖에 없다. 웹 검색으로도 실제 화면의 선택지를 확인하지 못했다. 검색어는 "리니지M 변신 목록 정렬 등급순", "리니지M 인벤토리 정렬 버튼 옵션", "리니지M 스킬 카드 강화 재료 정렬 자동 등록"이었다. 사용자 지시(2026-11-16 "근사치로 다 넣어")에 따라, 리니지M 화면에서 흔히 쓰는 등급순·이름순·수량순·진행 상태로 근사한다. 각 창의 첫 선택지는 원본 버튼에 적힌 문구 그대로다.

| 창 | 버튼 | TWILIGHT 근사(근거 약함) |
|---|---|---|
| 아이템 컬렉션 (ItemBook_Tab_Collection Btn_Sort) | 전체 | 전체 / 진행 중 / 미완성 / 완성. 같은 원본 버튼에 카드 컬렉션 창이 이미 쓰는 선택지 |
| 몬스터 도감 (MonsterBook_CollectionView Btn_Sort) | 모두 보기 | 모두 보기 / 진행 중 / 완료. 완료는 모든 단계 보상을 받은 도감 |
| 제작 목록 (Production_Tab_List Btn_Sort) | 아이콘 토글 | 제작 가능 우선. 기존 quote가 허용하는 제작이 먼저 오고, 각 묶음은 원래 순서를 유지 |
| 변신·인형·성물 목록 (Change_DetailView Btn_Sort2) | 전체 | 전체(원래 순서) / 등급순(높은 등급 먼저) / 이름순 |
| 스킬 카드 강화 재료 (SkillCard_Popup_Enchant Btn_Sort) | 전체 | 전체(기능 순서) / 수량순(많은 것 먼저) / 이름순 |

## 보류한 것

| 창 | 항목 | 이유 |
|---|---|---|
| 카드 다시 뽑기 (CardChange_All) | 상품 안내 | 현금 상품 안내라 TWILIGHT에 해당 기능이 없음 |
| 스케줄 | 정렬 | 스케줄 목록 기능 자체가 없음 |

## 그림이 없어 비운 것 (변경 없음)

- 던전·시련 던전 썸네일
- 위치 그림(SpecialDungeon/Challenge Mini·FullAssetID)
- 오림 스킬 그림
- 현황판 카테고리 그림
- 보상 아이콘 중 원본 아이콘을 모르는 것

## 기능이 없어 보고만 한 것 (변경 없음)

- 혈맹 기억장소
- 스케줄 목록·무접속 플레이
- 확정 합성·실패 이력
- 성급 강화
- 디버프·발동 마법 목록
- 재화 획득처

각 창 스크립트 머리의 "Left empty" 또는 "Not connected" 주석을 참고한다.

## 선택 보상 (Common_Reward_SelectBox)

- 수량 선택 줄: TWILIGHT 근사(근거 약함). 버튼(+1/+10/Max/직접입력/초기화)은 빼고, 제목 "선택한 보상"과 고른 보상 이름을 표시한다. TWILIGHT는 상자를 하나씩 연다.
