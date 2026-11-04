# 수호성 누적523 연결

기준 main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`. 작업 시작 시 열린 PR #218/#222/#224/#228/#230/#231/#232에 수호성 변경이 없음을 확인했다. 다른 PR을 병합하지 않는다.

기존 `lineage_growth.json`은 6분류·41개 안내 노드이며 모든 노드의 prerequisites/cost/cards/effects/card_rule이 null이었다. 일반 플레이는 활성화가 잠겨 있었다. 해당 파일과 개발 프로필을 보존하고 일반 플레이에서 별도 523 projection을 읽는다.

## 적용 범위

- 6분류·172슬롯, 실제 UIPosX/Y, 166개 비영 선행행. ID/화면순 정렬을 선행으로 사용하지 않는다. 선행 Lv3 조건을 만들지 않는다.
- 274개 비영 보상(원본 275행 중 Slot0 sentinel 1행 제외), 27개 강화행. 보상의 Level·Bonus·적용 종류·대상·InvokeOption·타입 선언·SpellClass를 함께 보존한다.
- 보상 중 140행을 기존 게임이 지원하는 스탯으로 매핑했다. 능력치는 대표 선택 없이 상시 적용한다. STR/DEX 등의 속성과 치명타 추가 대미지도 Main의 실제 소비 경로에 연결했다. 단, 서버조건으로 보류된 분류의 효과는 실행하지 않는다. 현재 일반 플레이에서 개방 가능한4분류112슬롯의 적용 대상은91행이며, 나머지2분류60슬롯의49매핑 행은 서버조건 확인 전 실행하지 않는다.
- 미해석/특수/PvP 능력치 66행, 발동 옵션 62행, 사용 스킬 6행은 원문과 표시를 보존한다. 해당 전투 효과는 **실행하지 않는다**. 따라서 모든 수호성 전투 효과를 완료한 변경이 아니다.
- 강화는 원문 Currency822/수량/Probability를 사용한다. 로컬 거래는 성공 시 단계 +1, 실패 시 단계 유지 및 비용 소모다. 현재 단계의 보상만 선택하며 기본/강화 보상을 누적하지 않는다. 원본 서버의 전체 난수·연출·실패 처리 프로토콜을 복원한 것은 아니다. 수호성 초기화/환급과 원본 CSB 애니메이션·음성은 이 변경의 실행 범위에 포함하지 않는다.
- 해금/강화 재료는 Currency822 → CurrencyUnitClass832 → Item147672 수호석이다. 축복포인트를 차감하지 않는다. 선택 전에는 지불하지 않고 카드 선택 확정 시 한 번 지불한다. 저장 실패 시 재료·슬롯·실패 카드·강화 단계가 바뀌지 않는다.
- 카드 수는 원본 ActiveCardCount, 성공 카드는 한 장이다. 기존 로컬의 고정 덱/실패 카드/승자 저장 모델을 유지한다. 이는 오프라인 상태 보존 정책이며 원본 서버의 재배치/재접속 정책이나 보장 비용으로 주장하지 않는다.
- 대표 발동 스킬은 분류별로 저장한다. 사용 스킬·능력치 노드를 대표 발동 스킬로 지정하지 않는다. 기존 코드에 있던 대표 변경 대기시간 잠금은 미확정 상태로 보존한다. SkillTreeConstant.CoolTimeSec나 CSB 예시의 5초를 대표 변경 공식으로 추정하지 않는다.

## 혼동하지 않는 원문 조건

- 최신 SkillTreeCategory262(크리스터)의 ServerLimitSetID는 **0**이다. 508의1294를 복사하지 않는다. 222/232/244/262는 로컬에서 비영 서버목록 참조 없이 진행한다. 273/288은1294의 지역/월드 판정 의미가 확인되지 않아 개방을 보류한다. 원문0을 서버 전체 무제한이라는 사실로 확장하지 않는다. 1294의 KR291/TW115 총406행을 보존한다.
- Defence_Spell의 BySpellAttack=false/true는 별도 행이다. Slot2852의 동일 주문 두 분기를 합산하거나 중복 제거하지 않는다. 공격·치명타·피격·최소피해·주대상 조건은 InvokeOption 원문 그대로 남는다.
- Type5의 Param1은 감소량이다. Param2는 설명용 주문 후보로만 남고 실행 Spell FK로 취급하지 않는다. Param6은 별도 필드다.
- 질리언 사용 스킬의 SpellMaterialType41(ClanCoin)·수량10과 CastDelay 원문900000·CastGroup311을 보존한다. 41을 CurrencyID41로 조인하거나 CastDelay를 임의의 초 단위로 환산하지 않는다. 수호석 해금 비용과 분리한다.
- 시련의 탑 제한6행은 SkillTreeSlot → LandGroupAttribute(NoSpell) → 기본/강화 Spell 사슬로 보존한다. 맵/주문 제한이며 슬롯 소유/해금 금지로 사용하지 않는다. 실제 해당 스킬 실행이 보류돼 있으므로 이 PR은 맵 내 전투 억제 실행을 주장하지 않는다.

## 세이브와 자료 보존

schema1의 기존 nodes/representative/searches/pending 및 문양 상태를 보존한다. 새 ID는 `source523_<SlotID>`이며 옛41개 ID를 추측 매핑하지 않는다. 기존 ID는 검증·불러오기에서 유지하고 일반 모드에서 효과를 만들어내지 않는다. 새 optional guardian_levels/guardian_representatives가 없으면 기본값을 사용한다. 새 검색은 원본 카드 수, 시도 수, 선행조건을 검증한다. 개발 프로필은 종전41노드 및 별도 저장을 유지한다. restore가 파일을 덮어쓰지 않는다.

구형 소스1/2·폐기 서버 프로토타입·퀘스트·펫·혈맹·공성을 가져오지 않는다. 드랍 확률·각성 비용도 변경하지 않는다.

## 현재 환경에서 실제 읽은 입력

지정 Library 파일을 이 소비 환경에서 정식 prepare_materialize 및 최신 Library transfer helper로 설치하고 `user.library-file-id` xattr를 검증했다. ZIP CRC 전수검사와 SHA256:

| Library ID | 파일 | SHA256 |
| --- | --- | --- |
| libfile_3acd63a50c148191b10d669d77efd5e3 | TWILIGHT_523_symbol_guardian_crosslinks_20261104.zip | 60fa306d6310cddd4b5eb042bbf59720e6dc732d92b3438cf54044815f76811f |
| libfile_0ba507ea27888191b60532f6aa6b6ff0 | TWILIGHT_UI551_binding_animation_evidence_20261104.zip | 6e5c636cabe48ab8d4aa4a5d6d26122c3300ca65789568668335b71fdb386d91 |
| libfile_f3e9e5b322cc8191ae441565bbd24c27 | lineagem_patch523_all_content_validated_and_508_520_deltas.zip | d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832 |

실제로 읽은 자료: REPORT_KO, guardian_invoke_conditions, guardian_active_skill_costs, relevant_ui_source, source_row_evidence, UI551 focus_growth_bindings/implementation_findings 및 생성기가 참조하는523테이블 전체 행. UI551은 SKILLTREE_ENCHANT의 전후 표시·비용·성공실패 상태 근거로 참고했다. CSB 예시 텍스트를 비용값으로 쓰지 않으며, 원본 음성·CSB 애니메이션을 이식했다고 주장하지 않는다.

`data/growth/guardian_source523.json` は選択した各原文行・1始まり行番号・元テーブル全体SHA256/byte数を保持する。原本ZIPは変更せずLibraryに保持し、公開Gitに原本アートを追加しない。

再生成/原文再照合:

```sh
python3 tools/build_guardian_source523.py --source-dir /workspace/guardian-sources/lineagem_patch523_all_content_validated_and_508_520_deltas/content --output data/growth/guardian_source523.json --check
```

## 검증 상태

검증 로그·실행 코드 SHA256·입력 영수증·캡처는 [evidence/manifest](guardian-source523-evidence/manifest.json)에 보존했다. 최종 커밋 SHA는 PR HEAD와 작업 최종 보고를 따른다. 전체 원본 리소스/서버 전투 복원이나 Android 실기기 완료를 의미하지 않는다. 이번 작업에서 옛 원본 아트 a1.zip은 없어서 기존 `--source-dir` 아트 검사는 해당 항목에서 실패한다. 지정된 데이터 ZIP3개 접근/CRC/SHA/행 일치는 별도로 검증했다. 원본 아트를 요구하는 단계는 수행하지 않았다.


최종 로컬 검증(Godot4.7.2): 수호성 거래39, 성장/실제 터치111, 개발 프로필37, 연출 상태5, 실제 OpenGL 화면35항목이 모두 통과했다. 핵심 실제Main32항목·동일 저장 재작성 방지·지연 저장 게이트도 최종 코드로 재검사하여 통과했다. 리소스723시트/41,442프레임SHA 검사 통과. Android 실기기·전체 시각/게임플레이 감사는 수행하지 않았다.

첫 화면 검사는 축소된 core stage의 기존 몬스터 초상화 누락과 카드 확인 버튼의 레이아웃 갱신 전 스크롤 문제로 실패했다. 실제Git의128개 기존 초상화(바이트/SHA 영수증 첨부)를 검사 stage에 보충하고, 레이아웃 다음 프레임에 확인 버튼을 노출하도록 수정한 뒤 재검사했다. 프로덕션 아트 파일은 추가/수정하지 않았다. 초기 실패 로그도 남겼다. 개발 프로필에서 수동 restore 후 오래된 스탯 캐시가 남는 문제는 restore 시 캐시 무효화로 보정했다. HP 검사의750평면 보상에는 기존CON→HP 효과가 함께 적용되므로 원문750과 실제 증가를 각각 검증한다.

첫 cold import는 기존 Godot import cache를 활용하기 위해 중단했고, 엔진의 원본 MD5/설정 재판정 후 import와 모든 최종 검사를 실행했다. 중단한 import를 통과로 집계하지 않는다.

사용자의 추가 지시에 따라 커밋에 `[skip ci]`를 넣고 원격 CI 수동 실행/재실행을 요청하지 않았다. 워크플로·보호 규칙을 변경하거나 실행 중인 원격 CI를 취소하지 않았다. 이 PR은 draft이며 다른 PR/main을 병합하지 않는다.

화면: [1280보드](guardian-source523-evidence/guardian-523-board-1280x720.png), [854×480](guardian-source523-evidence/guardian-523-board-854x480.png), [비용/선행 상세](guardian-source523-evidence/guardian-523-detail.png), [선택 성공](guardian-source523-evidence/guardian-523-card-success.png), [강화 결과](guardian-source523-evidence/guardian-523-enchant-result.png).
