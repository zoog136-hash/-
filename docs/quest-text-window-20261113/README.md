# 퀘스트 텍스트 목록 / 개별 수락

최신 사용자 요청에 따라 퀘스트 창은 **텍스트 목록·완료 표시·개별 수락**으로 단순화했다. 창을 열거나 게임을 실행했다고 전체 퀘스트를 완료시키거나 보상을 미리 만들지 않는다. 최초 기준 main `a9cdea9c29a2feacf83fbf47dff5b4b6cf22403e`에 #446이 이미 포함됐고, 이후 main `c898afcee9f277bb63db86397372014ceb243b1c`(#448 포함), `fb81d7e01258477aca9a54fc0abd79bcaef44af6`(#450 포함), `c94f760181d4b7dcab62b04571c276741681dd18`(#451 아이템 지급 규칙)를 충돌 없이 반영했다. #447의 로딩 코드는 구현하지 않았다.

## 확인한 경로와 변경

- 기존 #419의 native 우선 라우팅과 선택/claim refresh 병합, #421의 category 개별 RecordFile 읽기는 main에 이미 있었다. 이를 이번 수정으로 집계하지 않는다.
- 기존 native `_rows()`는 60행 제한 전에 카테고리 전체 상세 원본과 보상 계획을 보관했다. 일반 browser도 `entries()` 전체 결과를 만들었다. native `open()`/tab 변경은 새 Scene 트리를 만들고 이전 트리를 `queue_free()`했다. 합성 scene fixture에서 프레임 사이 정리 없이 50회 open/50회 tab을 호출하면 보유 tree가 51/101개까지 늘어났다. Android 종료 원인은 기기 로그 없이는 확정할 수 없다.
- 현재 HUD는 native Quest CSB·보상 이미지·native quest controls를 열지 않고 텍스트 view 하나를 사용한다. 반복 open은 같은 view를 재사용한다. 기존 native 코드와 원본 리소스 파일은 삭제·수정하지 않았다.
- `quest_service.text_page()`는 resident의 ID/제목/분류와 저장된 claimed 상태를 검색한다. 한 페이지 30행만 작은 표시 Dictionary로 만들고 보이는 미완료 행만 compact gate로 확인한다. full/detached/bulk/reward_plan/refresh_context를 호출하지 않는다. 완료·미완료 필터, 이름/ID 검색, 마지막 페이지 clamp, 기존 daily 완료 이력의 common 표시를 보존한다.
- 기본 `quest_auto.tick()`은 전체 ready/reward scan을 하지 않는다. 기존 scan과 자동 claim 구현은 명시적으로 켠 회귀 감사용으로 남겼다. 전체 완료 버튼은 표시하지 않는다.
- 수락은 기존 `quest_complete_requested -> world._claim_quest -> quest_auto.claim -> complete` 경로다. 수락 가능한 한 퀘스트만 즉시 완료하고 기존 원자 저장·보상 중복 방지를 사용한다. 목표 수행량을 일괄 생성하거나 임의 보상을 지급하지 않는다. 레벨/직업/선행조건/저장 보호와 지급 실패 처리는 기존 규칙대로 유지한다. 실패한 퀘스트는 완료로 위장하지 않는다.
- 재표시는 `process_frame` one-shot으로 합치며 닫힐 때 signal을 해제한다. 원본 callback/cycle을 추정으로 수정하지 않았다. 기존 native mission callback은 Godot에서 owner 해제를 막지 않는 것을 별도 확인했다.

## 검증

`tests/quest_text_window_test.gd`는 실제 SourceQuest/BAKE 형식의 **3,621행, 29,837,120바이트** 합성 레코드를 만든다. 실제 private 데이터의 바이트나 내용이 아니다. 목록 열기는 상세 record 읽기 0, reward plan 0, 첫 페이지 미완료 gate 29회다. 표시 모델 메모리 증가 표본은 25,444바이트다. 이는 전체 앱/폰 RSS/PSS/GPU 메모리 수치가 아니다. 최초 UI/글꼴/공통 theme 준비는 별도 비용이며 원시 측정은 `evidence.json`에 있다.

검사는 다음을 포함한다.

- 실제 text UI의 30행, 이미지 없는 quest rows, 전체 완료 버튼 없음.
- 실제 HUD의 최초 열기와 50회 재열기에서 view 한 개 재사용; 50회 빠른 탭 변경, 닫기 시 callback 해제, 재열기.
- 열기/검색/필터는 claimed/progress/기존 저장 파일 바이트를 바꾸지 않음.
- 실제 Button signal 수락과 49회 추가 클릭: 정확히 한 완료, 한 보상, 한 저장. 재로드 후 중복 수락 거부.
- 기존 atomic transaction의 쓰기 전 실패는 미완료 유지; 쓰기 후 오류는 확인된 durable 결과를 한 번만 반영; 재시도 중복 보상 없음.
- 원본 레코드 SHA 보존, 기존 daily 이력, source ID 3621 검색, 페이지 clamp.
- Linux OpenGL/Mesa 실제 렌더/캡처와 854×480 크기 확인. 합성 입력이며 원본 아트 또는 Android 시각 검증이 아니다.

기존 category64, record32, quest preparation37, hot paths62 회귀와 Python core staging14도 실행한다. preparation의 native-first 기대는 사용자가 요청한 text-first 동작으로 바꿨고, 기존 ready scan의 세부 감사는 explicit opt-in으로 유지했다. final head의 전체 core 및 원격 workflow 결과는 작업 보고에 별도 기록한다.

재현:

```sh
python3 tools/ci_core_map_pack.py --output /tmp/quest-map-input
TWILIGHT_SOURCE_MAP_PACK=/tmp/quest-map-input python3 tools/ci_core.py \
  --stage /tmp/quest-core-new --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 \
  --logs /tmp/quest-core-logs
# stage는 존재하지 않는 새 경로여야 한다. 테스트는 별도 임시 user profile을 쓴다.
# 그래픽 검증: Xvfb 또는 실제 X display에서 --headless 없이 다음을 실행한다.
/path/to/Godot_v4.7.2-stable_linux.x86_64 --path /tmp/quest-core-new \
  --audio-driver Dummy --rendering-method gl_compatibility \
  --script res://tests/quest_text_window_test.gd
```

## 보존 및 미검증

게임 저장 파일과 원본 팩은 수정/업로드하지 않았다. 새 Git 변경은 코드·테스트·검증 설명뿐이다. `tools/check_resource_integrity.py`와 `data/resource_delivery_ledger.json`은 현 main에 없어서 구형 검사를 성공으로 집계하지 않았다. 현행 `check_no_legacy_resources.py`는 tracked=20 통과한다. 저장소에 `.agents/skills`는 없다.

실제 Android 종료 재현·logcat/tombstone·private 원본 팩 장착·단말 GPU 검증은 미완료다. 이번 변경은 코드상 확인된 퀘스트 열기의 큰 데이터/장면 생성 경로를 제거했으며, 폰에서 종료가 해결됐다고 확정하지 않는다. 한 번의 개별 보상 지급/저장과 최초 글꼴 준비의 CPU 비용까지 없앴다는 주장도 하지 않는다.
