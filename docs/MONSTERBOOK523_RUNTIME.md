# 누적523 몬스터 도감: 구현과 실행 경계

기준 main은 `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`이다. 기존 main의 단순 몬스터 목록과 분리된 실제 Main 메뉴·도감 서비스·저장 연결이다. 열린 PR을 확인했으며 #218의 몬스터 전투/드롭, #230의 출현 정의, #232의 아덴 로더를 병합하거나 변경하지 않았다. 도감은 개체 생성·위치·재생성·드롭 확률을 다루지 않는다.

## 실제 연결된 것

- 메뉴 → 사냥·모험 → **몬스터 도감**. 검색, 현재33개/과거 포함557개 정의, 원본 집계/옵션 기간, 단계별 처치 수, 등록 여부, 옵션, 비용, 보상과 수령 여부를 표시한다. 기존 목록 UI를 완료 처리하지 않는다.
- 523 원본 MonsterBook557, 단계1531, 단계옵션1282, 단계보상2570행을 보존한다. 현재 NpcGroupID가 연결된 시즌22는33개/97단계이며 대상 NPC는944개다. 524개는 현재 대상 연결이0인 과거 정의다. 과거508의904개 집합을 재사용하지 않는다.
- 정확한 NpcClassID 멤버십으로만 후보를 찾는다. 이름·Sprite·맵·도감 설명으로 합치지 않는다. 최신 핫스팟16, 알비노 리부트18+버섯6을 놓치지 않는다.
- 확인된 판정 어댑터가 **해당 단계에 인정한 처치**만1씩 증가시킨다. 단계별 대상 ID를 판정 입력으로 받으므로 누적/단계별 재시작 방식을 임의로 선택하지 않는다. Main의 기존 죽음 중복 방지 뒤에서 호출하며 소환 개체를 제외한다. 어댑터가 없으면 집계하지 않는다.
- 등록·수령·명시적으로 선택된 적용 단계, 세대(epoch), 판정 순번을 캐릭터 저장의 `monsterbook523`에 보존한다. 저장이 성공한 뒤에만 공개 상태와 UI를 갱신한다. 실패·중복·잘못된 대상·손상 저장을 거부한다. 팩이 없어도 과거/알 수 없는 ID·확장 필드·소유/등록/수령 상태를 지우지 않는다.
- 등록 상태와 보상 수령 상태를 구분하며 전체 원본 Reward 묶음을 원자적 경제 처리기에 전달한다. Exp/Class281을 Item281로 바꾸지 않는다. 비용 재화4는 Gem이며 아데나로 차감하지 않는다.
- 확인된 현재 원문 시각과 적용 단계 선택이 있는 경우에만 Unit.Value·무조건 적용의 고정값8종(MeleeDamage/RangeDamage/MagicDamage/MeleeHit/RangeHit/MagicHit/MagicResist/DamageReduction)을 기존 실제 전투 소비자에 연결한다. 퍼센트 환산·AC 부호·조건부 옵션·나머지 효과는 원문만 보존한다. 어댑터가 없으면 능력치를 바꾸지 않는다.

## 미확정이며 자동 실행하지 않는 것

최신 UI의 BASICGUIDE는 공백이다. 과거508의 ‘자신이 처치’ 문구를 최신 막타/서버 판정으로 사용하지 않는다. CountConditionTypeID와 ResetType의 실행 사전, 신용 배분, 누적 단계 계산, 단계 간 합산/대체, 서버 활성, 날짜 시간대, 등록/수령 가능 구간, Gem·Exp·원본 아이템의 현 게임 경제 환산은 정적 표만으로 확정하지 않았다.

따라서 **일반 플레이의 원본 도감 집계·유료 등록·보상 자동 지급이 완성된 상태는 아니다.** 확인된 판정/경제 처리기 없이 시즌을 재개하거나 비용을 새로 만들지 않는다. UI에서 연결 대기/미달/등록/수령 상태와 이유를 표시한다. 실제 Main에서 확인된 어댑터·무료 단계 등록 경로까지 검증하며, 임의 보상 환산을 원본 기능 완료로 세지 않는다.

시즌22 한국 원문은 시작2026-10-07 05:00, 집계 종료2026-10-28 05:00, 옵션 종료2026-11-04 05:00이다. 원문 날짜를 UTC로 바꾸거나 현재 라이브 활성으로 선언하지 않는다. 어댑터는 현재 `Korean` 원문 시각을 제공해야 한다. 집계 구간은 시작 포함/집계 종료 제외, 옵션은 End 제외로 검사하며 등록/수령은 별도 확인 승인도 요구한다. 원본 시각이나 단계 옵션이 만료되어도 저장 상태는 삭제하지 않는다.

일일 Book6013은 정확한96 NPC, Level16423/1000회/비용0, **단계 옵션0개**, Exp5,000,000(Class281)과 Item3631/1500 보상이다. 모든 특수던전 몬스터로 일반화하거나 반복 완료를 영구 옵션으로 만들지 않는다. ResetType1만으로05시 초기화를 추측하지 않으며 확인된 새 epoch만 시작한다. 이전 epoch는 보관한다.

## 외부 실행 팩

원본 ZIP `lineagem_patch523_all_content_validated_and_508_520_deltas.zip`:

- bytes25,031,173
- SHA256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`

도감 제약 감사 ZIP `TWILIGHT_MONSTERBOOK_ITEMBOOK523_population_registration_expiry_20261104.zip`:

- bytes170,140
- SHA256 `704daa65656b7e61a2723cb5eec68edfa195ff1e17c524ebb954ae0975436961`

두 ZIP은 이 소비 환경에서 정식 Library materialize를 거쳐 실제 바이트·SHA256·전체 CRC를 검증했다. 원본은 수정하지 않았다. ItemBook 장비등록/카드 컬렉션 기능을 이 PR로 가져오지 않았다.

```sh
python3 tools/monsterbook523/build_pack.py \
  --source-zip /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  --output /private/monsterbook523.private.json

godot --path . -- \
  --monsterbook523-pack=/private/monsterbook523.private.json \
  --monsterbook523-sha256=89aa9b330d6c1b19dfae59cdb7062675d41df219d98d504c6823154bae473f8e
```

생성 팩은1,660,517bytes, SHA256 `89aa9b330d6c1b19dfae59cdb7062675d41df219d98d504c6823154bae473f8e`이다. 원본 행과 Unit/Desc/RewardType/Currency/ItemClass 참조를 포함하므로 **공개 Git에 넣지 않는다.** 생성기는 저장소 내부 출력을 거부한다. 이 팩은 별도 Library 저장 성공 후 새 경로로 다시 정식 materialize하여 동일 바이트/SHA를 확인했다. 이 전달은 도감 **정적 규칙 팩**이며 원본 몬스터/맵/카드 아트 전달 상태를 바꾸지 않는다.

## 판정·경제 API

`world.monsterbook523_runtime`:

- `catalog.load_pack(path, expected_sha)`: digest·snapshot·관계 검증 후 원자적 교체. 실패하면 현재 레지스트리/진행 상태 보존.
- `credit_authority(npc_class_id, life_id, actor_instance_id, state) -> receipt`: 전투 신용·서버·현재 epoch·인정 단계가 확인된 경우에만 `count` 영수증 반환. life/instance ID만으로 서버 신용을 확정하지 않는다.
- `action_authority(action, book_id, level_id, state) -> receipt`: UI 등록·수령 가능성의 확인된 판정.
- `clock_authority() -> YYYYMMDDHHMM`: 현재 한국 원문 시각. 시스템 UTC나 마지막 처치의 오래된 시각으로 대체하지 않는다.
- `settlement(before, proposed, raw_quote, persist) -> bool`: 원본 비용/보상 **전체와 제안된 저장 상태를 함께 내구적으로 처리**한 뒤에만 true. `persist(proposed, existing_world_save_overrides)`는 실제 Main의 원자적 저장기를 사용한다. 이 계약을 지키는 검증된 경제 어댑터가 없는 경우 유료 등록/원본 보상 지급은 차단된다.
- `apply_confirmed(receipt)`: 확인된 `begin_epoch`, `count`, `register`, `claim`, `effects` 처리. 순번은 도감 전체에서 단조 증가하여 이전 epoch 판정 재생도 막는다. 작업 중 재진입과 외부 상태 교체를 막는다.

영수증 공통 필드: `action`, `book_id`, `epoch`, `sequence`, 비어 있지 않은 `authority`, `approved=true`, `server_allowed=true`, `clock_locale="Korean"`, 확인된 `source_clock`. count는 정확한 `npc_class_id`와 승인된 `level_ids`, register는 `level_id`/`registration_approved`, claim은 `level_id`/`claim_window_approved`, begin_epoch는 `reset_approved`, effects는 등록된 `effective_levels`를 추가한다. 공개 UI에서 승인값을 만들어 넣지 않는다.

## 검증 재현과 한계

```sh
MONSTERBOOK523_SOURCE_ZIP=/private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  python3 -m unittest discover -s tests -p test_monsterbook523_pack.py -v
MONSTERBOOK523_PACK=/private/monsterbook523.private.json \
MONSTERBOOK523_SHA256=89aa9b330d6c1b19dfae59cdb7062675d41df219d98d504c6823154bae473f8e \
  godot --headless --path . --script res://tests/monsterbook523_test.gd
# 실제 Main/도감 화면 검사에는 검증된 현재 지도 팩·격리 XDG 저장소 필요.
TWILIGHT_SOURCE_MAP_PACK=/private/core-source-pack \
  godot --path . --script res://tests/monsterbook523_main_ui_test.gd -- \
  --monsterbook523-pack=/private/monsterbook523.private.json \
  --monsterbook523-sha256=89aa9b330d6c1b19dfae59cdb7062675d41df219d98d504c6823154bae473f8e
```

원본 팩 검사는 실제523 원문 없이는 skip이며 합성 fixture를 원본 성공으로 계산하지 않는다. 일반 CI의 기존 실제 Main/current-map·세이브 게이트와 리소스 게이트는 유지한다. 전체 CI·다른 PR·Android·원본 아트 시각 동등성 검증을 반복하거나 완료로 주장하지 않는다.

리소스 preflight는723시트/41,442frames/233,420,026bytes를 확인했다. 역사적 `--source-dir` 검사는 예전 미제공 `a1.zip` 부재로 실패했다. 이것은 별도로 검증한 위 두523 ZIP과 다르다. 원본 아트 복원/전체 배포 장부는 승격하지 않는다.

최종 실행 결과와 SHA/PR은 PR 본문에 기록한다.

### 이 작업의 로컬 결과

- Godot **4.7.2**: 실제 Library 복원 팩을 소비한 도감991검사 통과.944개 대상의 유일 연결, 신규 대상, 집계/옵션 기간 분리, 저장 실패, 재진입/재생, JSON 정수 정규화, 등록/수령/과거 상태 보존 포함.
- 원본 팩 Python5검사 및 기존 core staging7검사 통과.
- 실제 Main/current source-map·원본 바이트/진행도/장비/컬렉션/보스 보존32검사 통과. 동일 payload 저장·지연 저장 게이트 통과. JSON 상태 보정 후 실제 Main 핵심32검사도 다시 통과했다.
- 실제 OpenGL(llvmpipe) Main UI39검사(Viewport를 통한 터치 전달·취소 포함)와1280×720·960×540 캡처, 작은 화면의 보상 버튼 스크롤 접근을 확인했다. 확인된 테스트 판정으로 무료 단계 등록·실제 저장·결과 표시·재불러오기, 원본 보상 환산 미확정 차단과 실제 고정값 전투 소비를 검사한다. 실제 원본 서버 판정이나 지급·Android 실기기 검증은 아니다.
- UI 프레임을 진행할 때 필요한 기존 몬스터 초상2개는 축소 검증 프로젝트에서 제외되어 첫 시도가 실패했다. 정확한 main Git 바이트2개(1,027/1,818bytes)를 그 검증 프로젝트에만 추가하고 가져와 재검사했다. 게임 원본 파일/리소스 장부/공개 바이너리를 교체하지 않았다.
- 사용자 지시에 따라 최종 커밋은 `[skip ci]`이며 원격 CI의 수동 실행·재실행·취소나 워크플로/보호 규칙 변경을 하지 않는다. 원격 게이트를 통과했다고 주장하지 않는다. 다른 PR/main은 미병합이다.
