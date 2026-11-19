# Original523 quests and verified reward consumers

All3621 source quest definitions use the user-requested immediate completion policy after verified acquisition eligibility. Definitions loaded, quests completed and reward effects usable are different measures.

The current closeout ports the owned follow-up onto current main while preserving existing save, card, title, equipment and source restrictions. See [CLOSEOUT.md](CLOSEOUT.md), [CONSUMPTION_ABI.md](CONSUMPTION_ABI.md) and [main-closeout-validation.json](main-closeout-validation.json).

Current-main focused checks:2756 passed. Existing811/822 baseline save bytes and50quickslots are preserved.58 of the initial146 ItemClasses have at least one bounded reviewed path;88 remain. Four learned spell effects and other blessing/enhancement cases remain separate. This is not full source-effect completion.

Private source data, packs, save files and their delivery references are retained outside this public change. Installation and optional-input identity must be verified privately; repository code alone does not install original assets. No new UI or artwork is provided. Sound is excluded from this integration.

Historical checkpoints are retained in the specific follow-up documents; their LOCAL_ONLY/public/main and count statements refer to those checkpoints.

## 기간 제거 · 반복 초기화 (2026-11-19, `tests/quest_repeat_reset523_test.gd`)

- 사용자 결정(기간제는 기한 없앰, 제작 2026-11-16 "기간 제거"와 같음): 원본 `StartTime`/`EndTime`(행의 `starts_at`/`ends_at`)은 보존하되
  퀘스트를 닫지 않는다(`시작 전`/`기간 종료` 사유 없음). 다른 막힘(혈맹, 연계 콘텐츠, 운영 시간, 보상 미연결 등)은 그대로.
- TWILIGHT 근사 — 523 데이터에 `QuestResetType` 이름 표가 없다. `11` = 일간(매일 05:00 KST), `21` = 주간(수요일 05:00 KST),
  `MaxDailyRepeat` = 주기당 완료 횟수(0 = 1회). 근거: 11 행은 일일 부탁(판도라·라라의 부탁, MaxDailyRepeat 1), 21 행 이름이
  "주간 퀘스트"; 시즌 패스는 이미 11을 일간으로(`unconfirmed523/events_domain`), 요정 숲은 21을 주간으로(`content523`) 읽는다;
  시각은 한 게임 달력(사용자 결정 2026-11-09)과 원본 523 상점 안내 "일일 05시 / 주간 수요일 05시", 리니지M 미션(개인) 퀘스트 05:00 초기화.
  다른 값(32, 42)은 계속 `원본 반복/초기화 규칙 확인 필요`.
- 저장: `quest_state.repeats[id] = {period, count, again}`. `claimed[id]`는 그대로 "한 번 이상 완료"(선행 조건·영수증)이고,
  장부는 이번 주기에 다시 받을 수 있는지만 정한다. 기기 시계를 되돌려도 새 주기가 열리지 않는다.
- 중복 지급 방지: 반복 완료는 영수증이 필요 없는 보상(EXP·아데나·화폐 스택)만 다시 준다. 원본 보관/공급 아이템 보상은
  (퀘스트, 보상)마다 영수증 1개 계약이라 첫 완료만 지급하고 `반복 보상에 1회 지급 영수증 아이템 포함 · 1회만 지급(TWILIGHT 근사)`으로 표시.
- 퀘스트 기록 묶음(`quest523_records`) 스키마 1 → 2(압축 행에 반복 규칙 포함): 업데이트 후 첫 시작에 한 번 다시 만든다.
