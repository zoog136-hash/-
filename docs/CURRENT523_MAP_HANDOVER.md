# 맵 원본 연결 상세 인계 — 2026-11-06 / PAUSED

## 1. 현재 목표와 중지 상태

과거 목표는 사운드를 제외한 제공 원본 데이터의 95% 이상 연결이었다. 최신 요청은 사용자가 명시적으로 제외한 대상을 빼고, 작업 범위에 남은 원본 연결을 전부 완료하는 것이다. 95%에 도달하면 멈추는 기준이 아니며, 실제 게임의 표시·입력·이동·효과·저장 소비까지 이어가는 것을 목표로 한다. 보유/복사/설치/등록/코드 연결/실행 관측을 구분한다. 실제 전체 달성률은 미확인이며 이 문서는 100% 달성이나 게임 동작 통과를 선언하지 않는다.

사용자 최신 결정: UI·맵·통합·이미지·데이터는 이 인계 문서 저장/로컬 커밋 후 중지한다. Sprite만 기존 허용 범위에서 계속할 수 있다. 맵 담당은 자동 재시작, 추가 기능, 보류 수정, 새 감사/검색/테스트를 시작하지 않는다. GPU·일반 Godot·폰 문제는 계속 보류다.

유지할 제외: Sprite 미확인 28개(27 보조 레이어와 6262-336), Rosemary 12 부품, 미입증 98 신원+1 dummy, 원문 명시 dummy/Test, 사용자 제외 68 Land와 미대응 배치 229건/11 SPR ID, 사운드·주문 단계·물약·이모티콘·퀘스트 신규 작업. 이는 물리 삭제나 모든 NPC 시스템 제외가 아니다. 지면 드랍 표시/규칙은 기존 유지, 이미지 신규 범위는 아이템·변신·성물·인형만이다. 원본 신원/관계/레이어/입장 권한을 추정으로 만들지 않는다. 새 이미지·Sprite·UI 제작 금지.

## 2. 저장소와 확정 상태

원 저장소: https://github.com/zoog136-hash/- , PR285 https://github.com/zoog136-hash/-/pull/285 . 원 checkout `/workspace/aden-native523`, 브랜치 `feature/current523-regional-portal-consumer-20261106`, HEAD `d4d04e298b6debe8e4eee5a22de9176ed2e97740`를 보존했다. 이 공개 HEAD와 이후 로컬 후보를 혼동하지 않는다. PR222는 이미 병합된 과거 범위이므로 충돌·아덴귀환·상시오픈·SPR 정책을 다시 구현하지 않는다.

마지막 부모 확인 main은 `e1513f7da10d6282f1ea7b8bdabe9606843b52fa`다. 문서 작업 중 새 원격 조회는 하지 않았다. 이 코드 뷰는 최신 main 전체 checkout이 아니다. PR292/293의 actor sleep/restore/GPU 경계를 보존하는 좁은 코드 조합이며 폰 설치본, v30/62ZIP/index/source-bank 선택은 변경하지 않았다.

완성 코드 계보의 마지막은 `1dc969b9de75ecc7810e783ea7513ef873b13af7`이다. 원 저장소에서 누락된 부모 객체와 디스크 부족 때문에 별도 작은 코드-only 저장소를 만들었다. 위치는 `/tmp/twilight-map-saved-checkpoint-o4qpwry4/standalone-code-checkpoint`, 브랜치는 `checkpoint/map-code-research-20261106`, 정상 root 백업 커밋은 `de938d840b3e9b10b1ffb2bf787a287c04d81c3a`다. 29파일 완성 뷰+조사 기록+manifest, 총31파일을 담았다. 본 인계 커밋은 그 위의 문서 전용 후속이다. 원 계보의 대체/병합/재작성이나 실행 가능한 전체 게임 백업이 아니다.

## 3. 로컬 구현 계보와 읽기 순서

원 공개 d4d04e29 위의 아래 계보를 보존했다. 짧은 표기는 유일한 표시용이고 상세 hash/파일별 bytes는 `docs/CURRENT523_MAP_BACKUP_MANIFEST.json`과 각 영수증에 있다.

1. c484ba5bc06cc7b56b5622d12408c9c711f6e36c: 선택 M 필드→정확한 Land/AssetPath→명시 NpcBuff 환경 채택.
2. e71e667f2adac302e71f43f54d914b293474009a: 원본 자기 버프 수명/actor/원문 일치 가드.
3. d530f2b2837344b61b0614ab4ae50f098a1d501a: 등록된 환경 루트만 기존 열거 소비자에 공급.
4. accf53114099a459c8e23a75bbdea1d7a9ea916f: actor 반납 정리와 stale 자기 버프 갱신 필터.
5. df4147ef0108eedbe29c1b420d00ca4ef04c6b07: M 필드 host-map 신원과 미준비 cross-Land 사전 보류.
6. fcd7e1b0d9cdeb8ae15c42b6c29de9cf7698ec31: target encounter·위치·점유·사설 RNG 준비.
7. 013d5cbb86e9f94ac792a9269faabd24d958e0c5: 실제 data batch ABI 수신, RefCounted 필드 타입 보정 전 고정본.
8. 646599c4ed36d57a5bb08473834c331db7c8d0b2 및 104982cd429d3bb4d347dc0e026b4f111d55ce8b: 격리 actor 몸체/수정 ABI·자동사냥 OFF·안전 구간 랜덤 도착 결합.
9. 668f917c10b612af4a4e23c566c09cc18da6d83b: 실제 population 채택·저장/복구 경계. 이후 좁은 cleanup receiver가 이 버전의 광범위 combat clear를 대체한다.
10. eb783f9eee65d1a66e940d47ef7c168b1706336c: 확정 저장+catalog finish 이후 좁은 action cancellation. 기존 플레이어 버프/skill 수명을 유지한다.
11. 2b75ecf9189628f6816d9ff014d742e51b0efed9: 기존 fallback atk8 표식과 원문 ordinary NPC 수치 입력.
12. 1dc969b9de75ecc7810e783ea7513ef873b13af7: 실제 before-attempt begin, Map 이력 callback, 제한 discard, World 모델-refresh +57줄 조합.

최신 본 문서를 먼저 읽고 `CURRENT523_TRANSITION_ACTION_RECEIVER_LOCAL.md`, `CURRENT523_POPULATION_ADOPTION_LOCAL.md`, `CURRENT523_STAGED_TARGET_ENCOUNTERS.md`, `CURRENT523_DETACHED_ACTOR_BATCH_LOCAL.md`, `CURRENT523_NPC_SOURCE_REGION_RECEIVER.md`, `CURRENT523_ORDINARY_NPC_INPUT_LOCAL.md` 순으로 읽는다. 과거 boundary 문서의 “미구현 batch”/광범위 clear 설명은 역사적 상태이며 최신 구현에 되살리지 않는다.

## 4. 실제 코드 소비 경로

`scripts/maps/current523_aden_play_controller.gd::_commit_source_destination`가 실제 cross-Land 공통 호출자다. `_prepare_cross_land_encounter_specs`와 `current523_staged_encounters.gd`는 명시 Portal/SourceLand/TargetTerritory/TargetLand, 실제 목표 M 필드와 source cell/pin, 원문 encounter tuple을 사용한다. 현재 World actor 점유를 목표 점유로 대용하지 않는다. 빈/추정 population이나 첫 후보 자동 선택은 성공이 아니다.

준비는 현재 field/player/camera/root/population/World RNG/보스/돈/세이브를 바꾸지 않는다. target renderer와 disabled physics/body는 소유한 비활성 후보일 수 있으나 live owner 포인터는 채택하지 않는다. 기존 host 배치 수·respawn·spacing·155px 도착 margin은 native 원문 공식이 아니라 기존 TWILIGHT 정책이다. 원문 collision bit 의미는 발명하지 않는다.

정확한 호출 순서:

1. 목표 원문 relation과 필드 입장/핀/조건/비용/좌표 검사를 수행하고 private target encounter/container/점유/RNG/보스 상태를 준비한다. 템플릿 sourceId는 중복 없이 data에 넘긴다.
2. data `prepare_actor_batch(records, field, world, population, expected_model_sha256)`는 live configure/admission 없이 격리 catalog로 실제 projected record를 생산한다. field는 RefCounted, World/population은 Node다. `spawn_authorized:false`는 등록이 입장/스폰 승인이 아님을 뜻한다.
3. `commit_actor_batch(candidate)` 성공 뒤 실제 catalog identity로 detached media를 준비하고 disabled population을 만든다. live `Monster.setup/project_actor_record` 재입장이나 환경 등록을 사이에 넣지 않는다.
4. `prepare_current523_transition_actions(old_root, old_population, actual_map_guard)`로 이전 actor/life/owner/epoch를 캡처한다. 첫 `_registered_cross_land_route`에서 명시 ok:false이면 Map이 그 거절을 기록한다.
5. 해당 첫 거절에서만 실제 `restore_actor_batch`의 ok:true/restored:true와 원 source/model/owner/life/epoch/position/RNG/gold 불변을 증명한 callback이 discard를 허용한다. token 메타데이터만 폐기하며 refund/이동 승인/cleanup 성공이 아니다.
6. 경로가 유효하면 첫 OPTIONS.write 직전에 `begin_current523_transition_attempt(token, epoch)`의 ok:true/attempt_started:true/동일 epoch/무변이를 요구한다. options/session/owner adoption/save/catalog finish 시도는 각각 외부 호출 직전에 단조 history에 기록한다. rollback으로 false로 되돌리지 않는다.
7. 기존 옵션/시간 owner를 거쳐 field/player/camera와 실제 target root/population을 채택하되 새 actor는 disabled 상태다. 자동사냥을 OFF로 하고 private RNG를 채택한다. target passability/충돌/점유가 통과하는 선언 구간 내 후보만 랜덤 선택한다.
8. `TRAVEL_PAYMENT.commit`는 무료 cross-Land에서도 기존 실제 저장 owner를 호출한다. 확정 실패와 결과 불명을 기존 receipt/fingerprint로 구분한다. 원래 field/root/population/boss export/RNG/옵션/시간/위치를 소유 계약에 맞게 복구하되 충돌 상태를 강제 덮어쓰지 않는다.
9. 확정 저장 receipt의 saved:true/save_error:OK/rollback_allowed:false/uncertain:false, 변경 hash·실제 save fingerprint·owner/model/epoch를 확인한 뒤 `finish_actor_batch`를 호출한다. 환경 registry를 그 전에 변경하면 snapshot guard가 보류하므로 새 Land 환경 등록은 finish 뒤다.
10. token+epoch+확정 saved-map 증거 hash로 `cancel_current523_transition_actions`를 호출한다. 기존 NPC-applied 플레이어 버프와 legitimate skill state, World epoch를 유지하는 좁은 action 정리다. 명시 cleanup 성공과 불변 context/save proof 후에만 새 actor/population과 기존 loot owner를 활성화한다.

begin 요청 이후(반환 불명/거절 포함), options/session/adoption/save/finish 시도 이후에는 rollback이 성공해도 discard하지 않는다. restore conflict, started/uncertain cleanup, save 결과 불명은 token/영수증/양측 자원과 복구 증거를 보존하고 자동 refund/rollback/retry하지 않는다. DISCARD_HELD도 자동 재시도하지 않는다. 완료 callback 재호출은 같은 receipt/context일 때만 idempotent하다.

## 5. ABI와 조합 충돌 주의

Data 원문/공개 구현 기준: https://github.com/zoog136-hash/-/tree/21bcd2d1325fffcb27923ffccf3a59b1542e1149 . 환경 API는 catalog `build_land_environment/adopt_land_environment/admit_land_environment/registered_land_environment`, 원문 행 열거 `environment_attributes()`다. 정확한 Land.AssetPath와 명시 type504 NpcBuff/Unit16/BuffClass root만 허용한다. NPC 입력 모델 신원과 별도 환경 registry를 섞지 않는다. 실제 Land0/AssetPath `0/`를 허용하는 좁은 local producer 수정은 원문 증거가 있고 root는 빈 배열이다. Buff/Spell/속성 zero sentinel은 완화하지 않는다.

배치 ABI는 catalog `prepare_actor_batch/commit_actor_batch/restore_actor_batch/finish_actor_batch`. 환경 registry까지 snapshot 비교하므로 다른 등록 뒤 restore가 거부되면 기존 상태를 보존한다. old data21b만으로 batch API가 있다고 가정하지 않는다. 이 코드-only 뷰에 실제 local batch와 RefCounted 수정이 들어 있다.

최종 필수 파일 신원:

- `scripts/monsters/current523_npc_batch.gd`: 14,024B, SHA256 860175799dde8d720381ad640e46a3a3b76caf675722c97cc913678032068511.
- `scripts/monsters/current523_npc_input_projection.gd`: 13,003B, SHA256 6b0bf0d8587ce7497a9a66b8c36d71885cda8215dfe6735e974136bf8ef319c0.
- `scripts/monsters/patch523_npc_catalog.gd`: result blob26224dc1cb74f1fadfd227d7a80c59986776ba73, SHA256 ad5501bc45f3d46457d5582bc4e477e38542557abe869350ddb421711d44213a.
- `scripts/maps/field_population.gd`: retained main blobc080c02b194e463e5de0d20740f5353d23c067e3, SHA256 277216cbb23394d3280a2b8412db5308fc920c5ca7a7a59cc0c22a0d8a1a575e.

最新4파일 base→result blob:

- Controller: ff94802fb6d12938b883b579ed951a106835eada → 0b986a1bd154d00825f3030dce60d95364dc7e56.
- Population transaction: 987143ef6be0470324a29de663a937eeb87354c4 → 0a21229b1bd5886b7cc9c26a264d0fbd5823b73e.
- Transition helper: 0ab2fca4b488767abbe8b7e9dbde9d74c02e56b4 → 7f8a2e262482265b3fba1fc56bdd13719c187f98.
- World: d578b921196941e7688c054fbb724d6a0282947e → f9d2a1f654f8151fbb95f3e10691bf3e6beacf16.

World는 맵 host-map +16줄, 통합 모델-refresh +57줄, action receiver/wrapper를 실제 hunk로 조합한 것이다. 모델 WeakRef/digest와 combat_generation은 별개다. 실제 patch523_rules `data/digest/load_original/load_file`, rules projection `build`, pack store `INDEX`, craft catalog `install_zip/register`, World `_apply_loaded_patch523_equipment`, 기존 저장 가드를 읽어 확인했다. 사용자 명시 모델 파일/핀·미추적 accepted 모델·바뀐 source/catalog/selection은 자동 교체하지 않는다. Monster/World/FieldPopulation을 과거 전체 파일로 덮어쓰면 main sleep/visual 및 다른 owner 변경을 잃는다. owner별 좁은 hunk와 exact hash를 비교해야 한다.

## 6. 권위 있는 원문과 추정 경계

원문 Content ZIP SHA256은 d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832, world-links pin은 2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90. 원문 ZIP/맵/타일/SP2/SPR·이미지는 기존 private 원본 위치에 보존하며 Git backup에 넣지 않았다. 코드/문서의 원문 행 증인은 전체 원문 파일 보유나 재배포 권한의 증명이 아니다.

PR276 원문 spawn 관계 참조는 https://github.com/zoog136-hash/-/tree/6b9cfc85f4113c7d054ae5057724225f0c7bd04d . live `_attach_source_population/configure`는 boss/RNG/root/catalog admission을 바꾸므로 준비 단계에 그대로 호출하지 않는다. host placement/count/respawn은 기존 host 정책이다. 원문 입구/목적지/미디어 관계가 없으면 검색 실패라고 일반화하거나 다른 Land/World/NPC ID로 만들지 말고 해당 입력 부재로 보류한다. batch 필드 타입 문제와 host transaction 미완은 검색 실패가 아니라 구현 문제였고 local 코드로 연결했다. 새 검색은 이 문서 작업에서 하지 않았다.

ordinary NPC attack 입력은 `floor(DiceBonus + DiceCount*(DiceSpots+1)/2)`라는 명시 TWILIGHT 수치 추정이다. 기존 fallback atk8만 대체하고 caller override, boss/special/spell/chain과 native raw dice/확률/선택/큐/시간을 바꾸지 않는다. 그 공격력에 의존하는 기존 명중 기본값은 달라질 수 있다. 480은 원문 형태 후보이지 실제 spawn/공격 수가 아니다.

## 7. 수량과 소비 증거 — 이전 측정만

2026-11-06 보존 감사/Map668 장부 기준, 고정 원본 member inventory SHA256 c395f35afa067dfad04db3d615c7f39acbdea7134ae8f2023bbbf75c5639f1b7:

- Map 8,311파일 / 994,755,558 원본 비압축B.
- Tile 8,514파일 / 297,767,184B. 합계16,825 / 1,292,522,742B.
- 조건부 partial 소비 경로: Map6,558 / 794,309,914 nominalB, Tile7,557 / 261,213,094 nominalB, 합계14,115 / 1,055,523,008 nominalB.

partial은 해당 파일의 일부 cell/영역/참조가 조건부 코드 경로에 들어간 파일 footprint이며 파일 전체 사용이나 실제 읽은 bytes가 아니다. 단순 설치·등록과도 구분한다. 최근 cross-Land/receiver 변경의 추가 고유 Map/Tile는 0파일/0B다. 기존 source field/cell/행을 소비하는 기능이 늘었으나 신규 runtime file/byte는 측정하지 않았다. shared Land/NpcClass/spawn/territory/Buff 테이블의 일부 행을 통째 JSON 파일 사용으로 올리지 않는다. SP2/SPR/이미지까지 합친 맵 섹터 전체 분모/whole-file 사용률은 미확인이다. 사운드/dummy 등의 별도 수·bytes는 이 Map/Tile 장부만으로 확정하지 않는다.

577 physical/997 logical 대표 QA와 과거 Main 표시 기록은 역사적 범위이며 USER_MAIN 실기 전체 소비의 증거가 아니다. 본 후보에서 실제 게임/저장/복구/폰 실행을 하지 않았다. 코드31/33파일, ZIP member수, NPC slot, 원문 후보480을 원본 전체 완성률로 바꾸지 않는다.

## 8. 파일 보존·위험 백업 inventory

공통 임시 위치 `/tmp/twilight-map-saved-checkpoint-o4qpwry4/`. 원본 filesystem `/workspace`는 마지막 확인 여유0B다. `/tmp`는 별도 여유가 있지만 ephemeral이므로 영구 저장/외부 전달 완료가 아니다. 지원 index `docs/CURRENT523_MAP_BACKUP_INVENTORY.json`은 정확한 member 목록·hash·범주·원본 dirty 비교를 담는다.

- `TWILIGHT_Map_Code_Research_Root.bundle`: 317,670B; SHA256 b1b982e27a261bde75fdfbf84dfba1768ebc61116cf66768cad09dc3999fe6b3. de938d84 root1커밋/31 tracked파일의 자체 포함 코드·조사 이력. 원 game repo/base assets는 포함하지 않는다.
- `TWILIGHT_Map_Local_Save_Code_Research.zip`: 674,185B; SHA256 b1099c1eda6a151b8ccc257288462d3aa87a8b5ace851f69cabc7f3cbb7ffb76. 1dc969b9 코드29+당시 조사1, 영수증과 private 코드 packet. 바깥41 member/선언 해제1,649,515B. 내부 ZIP 3개는 각각70/9/23 member이며 중복 코드/patch 사본이므로 원본파일수로 합산하지 않는다.
- 바깥 범주: GD21, MD8, JSON5, TXT1, ZIP3, bundle1, patch2. 내부 범주에는 문서/GD/JSON/patch/TXT/TSV/bundle가 있다. 중앙목록에서 raw SP2/SPR/이미지/사운드 member는 없다. Git bundle은 author/committer 개인 식별 metadata를 포함할 수 있다(값은 본 inventory에 출력하지 않음). credentials/key/cookie/token/config/save 파일 범주는 목록에 없지만 포렌식 secret scan을 했다는 뜻은 아니다.

정확한 산출물별 base/hash는 기존 `/tmp/current523-map-attempt-guard-77czlear/composition-receipt.json`, `guard-model-over-2b75.patch`(29,284B/SHA256 ad969d2f1e6b5079aa5f870d9c1ac32a27eea0d982a79fbfaffa971d819e7600), `HANDOFF.txt`에 보존했다. 기존 packet 원본은 덮어쓰지 않았다. 작은 incremental bundle은 부모2b75ecf9 객체가 있어야 하며 독립 전체 백업이 아니다. 317670B root bundle과 구분한다.

원 checkout dirty4파일은 receiver 문서, Controller, portal provider, NPC extensions다. 바깥 ZIP와 root bundle의 최신 project snapshot에서 원 dirty 바이트와 정확히 같은 것은 receiver 문서1개뿐이다. 나머지3개의 같은 경로에는 이후 구현 버전이 있고 원래 dirty 바이트는 기존 checkout에 보존됐다. 원 dirty4개 전체를 그대로 백업했다고 말하지 않는다. 원 checkout을 clean이라고 부르지 않는다. 기록된 original dirty SHA는 inventory에 있다. 이 환경은 다른 섹터의 Integration/Sprite backup을 보유/검사했다고 주장하지 않는다.

## 9. 다음 작업자의 복원·통합 순서 — 재개 승인 후에만

1. 먼저 중지 상태를 확인하고 보존/전달 권한과 실제 대상 위치를 정한다. 현재 문서/packet은 로컬뿐이다. 따로 승인 없이 업로드/Space/Library/공개 blob을 만들지 않는다. `/workspace` 공간 확보를 위해 source/cache/save를 임의 삭제하지 않는다.
2. 제공받은 317670B bundle의 SHA를 대조하고 별도 빈 코드 백업 폴더에 `git clone -b checkpoint/map-code-research-20261106 <bundle파일> <새_코드백업폴더>`로 복원할 수 있다. 이는 명령 예시이며 여기서 실행하지 않았다. 이전 bundle은 de938d84까지만 포함하므로 이번 인계 commit/document는 별도 새 bundle 또는 정확한 문서 전문으로 함께 받아야 한다. sparse incremental bundle은 parent 객체가 없으면 사용하지 않는다.
3. 이 root backup에는 project.godot, 모든 unchanged scripts, 설치팩, 원본, saves가 없으므로 game 실행용으로 취급하지 않는다. 원 저장소의 정식 최신 checkout과 권한 있는 원본 pack/핀을 별도로 확보해야 한다. 새 코드 fetch/clone/폰 변경은 본 중지 지시로 허용되지 않았다.
4. 재개 승인 후 실제 최신 main/열린 owner 후보와 문서 기준을 비교한다. 원 source/field/controller+Data21b/Land0/batch/RefCounted+NPC lifetime/enumeration/retirement+main actor sleep 경계를 맞춘 뒤 Map staged/adopt/save/receiver/discard, ordinary numeric input과 World model hunk를 좁게 조합한다. 전체 PR276/World/Monster/field_population 파일을 덮어쓰거나 임의 merge하지 않는다.
5. 실제 target entry/territory/source relation와 selected map/tile/world-links/source-bank pins, NPC registry/model, installed original media, environment opt-ins를 담당 owner에게 확인한다. data owner는 batch/registry 계약, 통합 owner는 SkillService 및 World action/model receiver, map owner는 field/route/adoption/save transaction을 맡는다. 설치/리소스 선택과 Sprite 자원 누락을 map이 새 정책으로 우회하지 않는다.
6. source/actor media가 없거나 save/restore 결과가 불명인 이동은 hold한다. 검증을 다시 허용받기 전에는 테스트/parser/compiler/game/render/CI를 실행하지 않는다. 향후 허용된다면 성공, 확정 실패, save 불명, restore conflict, cleanup 거절/재진입을 실제 owner와 세이브 보존 기준으로 검증해야 한다. 지금은 미검증 계획이지 통과 결과가 아니다.

## 10. 종료 상태

이번 작업은 인계 문서와 작은 로컬 inventory index만 커밋한다. 코드/원본/팩/세이브/폰/선택/공개 PR/main/workflow를 바꾸지 않는다. 이전 normal parent-tree commit은 missing Git object70669dbc8dd6ddb013422d426342655c97f294b9 (`docs/CURRENT523_GROUND_SPRITE_CONSUMER.md`) 때문에 실패했다. 실패 작업을 재시도하거나 대형 객체 fetch/삭제로 우회하지 않았다. 독립 root 코드 백업은 그 실패와 별개로 성공했다. 모든 맵 구현·검색·검증은 이 문서 커밋 후 PAUSED, 자동 재개하지 않는다.
