# TWILIGHT 데이터 작업 인계 — 2026-11-06

## 1. 현재 정지 상태와 재개 조건

현재 상태는 **PAUSED**다. 사용자는 조사·구현 저장/로컬 커밋 후 다른 작업자가
이어갈 상세 기록을 요청했고, Sprite를 제외한 UI/Map/Integration/Image/Data는
중지하도록 지시했다. 이 문서 작성은 새 구현·수정·실행·게시 승인이 아니다.
Data는 명시적인 후속 사용자 재시작 지시 전까지 새 기능을 시작하지 않는다.
GPU/일반 Godot/Android 실행 문제와 폰 변경도 보류 상태다.

최종 목표는 제공 원본을 실제 게임 소비 경로에 연결하는 것이다. 원본 보유,
파싱, 등록, 코드 연결, 실제 실행 관측은 서로 다른 단계다. 95% 목표는
달성했다고 보고하지 않았다. 원본 → 필요한 합법적 공개 조사 → 그래도 없는
데이터/수치의 명시적 host 추정 순서다. ID·FK·열거형·자산 신원·원본 역할이나
게임 순서를 추정해서 원본 사실로 만들면 안 된다.

현재 제외/보존 조건:

- 새 퀘스트 목표 조사·추적·보상 연결은 제외. 기존 즉시완료 기능/파일/세이브는 유지.
- 사운드, 주문 단계, 물약, 이모티콘의 미완 연결 작업은 제외. 모든 스킬을
  제외하는 뜻이 아니며, 기존 공통 시스템이나 원본을 삭제하지 않는다.
- 명시 dummy/Test/폐쇄 콘텐츠와 금칙어를 새로 활성화하지 않는다. 금칙어
  원본 보관본은 유지하고 런타임 제외 상태를 보존한다.
- Sprite28 보조 부품, Rosemary12, 미확정 Sprite99(98 미입증+1 dummy)는 제외.
  이는 누락된 native layer가 선택적이라는 증거가 아니다.
- 새 이미지/Sprite/프레임/UI 제작 금지. 이미지 새 작업은 아이템·변신·성물·인형
  네 범위만 대상이며 기존 다른 정상 기능/원본은 삭제하지 않는다.
- 기존 바닥 드롭/습득·지면 규칙, 물리 ID·수량·영수증·저장 소유자는 유지.
- 폰 설치본,62ZIP/v30/index/source bank 및 별도 후보 팩·명시 선택을 변경하지 않는다.
- 설명표 DescData_Korean/DescID는 후순위다. 삭제나 사용 완료로 처리하지 않는다.

## 2. 저장소와 정확한 로컬 이력

저장소: `zoog136-hash/-`. 기존 브랜치:
`feature/current523-data-followup-20261105`.

| 순서 | 커밋 | 상태/내용 |
| --- | --- | --- |
| 기존 | `b923e2208f0b51af6a21aa2e14bd38752ad450d4` | 공개된 좁은 +0 기본값 연결 checkpoint |
| 다음 | `21bcd2d1325fffcb27923ffccf3a59b1542e1149` | 마지막 확인된 공개 Data PR282 checkpoint; Land/environment 입력 API |
| 다음 | `0feeb580935b270871afa41b5940c2c3ced65e0a` | 로컬82경로 장비 후보, 이전 이력 보존 |
| 현재 코드 | `118e6f4df4e64b8e38de8f69c259849a991b7f30` | 로컬 저장 완료; 15파일 +718/-5, 미게시 |

118e의 부모는 정확히0feeb다. amend/rebase/병합/푸시는 하지 않았다. 이 문서의
커밋은118e 다음의 문서 전용 커밋으로 별도 보고한다. 새 PR은 만들지 않았다.
로컬 커밋의 GitHub 링크나 외부 전달 링크는 없다.

마지막으로 좁게 대조한 main은
`e1513f7da10d6282f1ea7b8bdabe9606843b52fa`다. 이는 이전
`d758bcfc0424baa331fc4b954dbf50aa5343ba63` 뒤 외부 PR292/293가
들어온 상태였다. 문서 작업에서 원격을 다시 조회하지 않았다. PR base_sha를
현재 main으로 대체하지 말고, 실제 재개 시 승인 범위 안에서 main ref를 확인한다.
PR292의 actor/GPU/sleep 변경과 PR293 import 규칙을 옛 Monster/World 전체
파일로 덮어쓰지 않는다. 이 Data checkpoint는 Monster/World를 수정하지 않았다.

## 3. 실제 커밋 코드와 사용 단계

118e 포함 경로:

```text
.gitignore
docs/DATA_CONSUMPTION523_STATUS.md
data/monsters/current523_ordinary_damage_input_policy.json
data/skills/current523_distance_input_policy.json
scripts/crafting/patch523_enchantment_projection.gd
scripts/growth/guardian_combat.gd
scripts/item_options.gd
scripts/monsters/base508_source_roster.gd
scripts/monsters/current523_npc_batch.gd
scripts/monsters/current523_ordinary_damage_input.gd
scripts/monsters/patch523_npc_catalog.gd
scripts/resources/current523_equipment_ignore_input.gd
scripts/resources/current523_owned_item_witness.gd
scripts/skills/progression_runtime523.gd
tools/equipment/patch523_enhancement.py
```

### 3.1 장비 피해감소 무시 비율

BonusType4952/5681/5691/5701:
IgnoreDamageReductionPercent, IgnoreMeleeDamageReductionPercent,
IgnoreRangeDamageReductionPercent, IgnoreMagicDamageReductionPercent.
정확한 Unit3 Percentage 입력을 `/10000`하여 기존 장비 입력에 연결했다.
기본 reader와 강화 Python/GDScript producer가 같은 단위 가드를 유지한다.

실제 소비는 `guardian_combat.outgoing → sum_equipped`에서 기존 flat 복구 후,
percent_reduction 예산 처리 전에 일반+해당 채널을 한 번 공급한다. World의
일반 증폭이나 카드 collection amplification에 다시 넣으면 안 된다.
helper의 원문 재계산은 compiled/prepared 값 비교용이며 이미 변환된 값에
다시 `/10000`하지 않는다. physical/mapped/overlay/조건/원문/pin/축복/강화 및
기본+강화 중복 가드를 유지한다.

보존된 좁은 근거:31 기본 item 경로,105 강화 item-row 경로,60 고유 강화 행,
10 item,5 group. 이것은 전체 아이템/파일 완료 분모가 아니다. 실제 선택된
비fixture enhancement 모델 산출물은 확보되지 않았으므로 코드 연결과 실제
모델 공급·채택·효과 발생을 구분한다.

### 3.2 NPC 배치 준비/원자 등록

`patch523_npc_catalog.gd`의 실제 API:

```gdscript
prepare_actor_batch(records: Array, field: RefCounted, world: Node,
    population: Node, expected_model_sha256: String) -> Dictionary
commit_actor_batch(candidate: RefCounted) -> Dictionary
restore_actor_batch(candidate: RefCounted) -> Dictionary
finish_actor_batch(candidate: RefCounted) -> Dictionary
```

prepare는 shadow catalog와 명시된 encounter/NPC 전체 원문 closure로 작업하고
live NPC content/index/source_model_sha/admission/environment를 바꾸지 않는다.
실제 M field는 PlayableField extends RefCounted다. World/population은 Node로
유지하며 가짜 Node wrapper를 만들지 않는다.

prepare 성공 키는 ok/candidate/records/selection/source_identity/
previous_model_sha256/prepared_model_sha256/catalog_changed=false/
spawn_authorized=false다. commit은 exact-current snapshot을 재확인하고 NPC
registry를 한 번 채택하며, records/selection/model_sha256/batch_revision과
restore_required_on_population_failure=true를 반환한다. restore는 이후 다른
정상 등록을 덮어쓰지 않도록 post-state stale 검사를 한다. finish는 finalize다.
모든 단계의 spawn_authorized는 false다. actor 생성·점유·RNG/보스 컨테이너·이동
비용·저장은 Map/Integration 소유이며 이 API가 승인하지 않는다.

기존 environment registry 분리와 `_actor_batch_revision`을 보존한다. 일반
project_actor_record는 여전히 즉시 admission할 수 있으므로, target population
준비 단계에서 live catalog로 Monster.setup을 먼저 호출하지 않는다.
Map은 실제 SOURCE_SPAWNS.apply → 정확한 tuple → SOURCE_M_ROSTER.for_spawn
결과로 records를 준비해야 한다. 개수·위치는 기존 host 정책이지 원작 좌표 복원이 아니다.

### 3.3 원문 일반 NPC 공격력

`base508_source_roster.record`가 caller에 의해 덮어쓰이지 않은 자기 기본 atk8에만
source_m_ordinary_host_atk_default 표식을 붙인다. catalog projection의 마지막
`ORDINARY_DAMAGE_INPUT.project(self,result,source)`가 이를 소비한다.

적용 조건은 같은 current 원문/입장 신원, nonboss melee, ai.special 및 별도 host
action contract 없음, 완전한 admitted NpcAttack 집합이 단일 비주문/비연쇄 행인
경우다. 명시 Test/미사용/dummy 및 잘못된 원문 관계는 보류한다. caller가
atk/attack/공격력을 지정한 경우에는 새 표식을 만들지 않아 기존 값을 보존한다.

`floor(DiceBonus + DiceCount*(DiceSpots+1)/2)`는 명시적 TWILIGHT 수치 추정이다.
기존 Monster.setup의 attack_power 입력만 대체하고, `_resolve_attack → player_hit`
경로가 이를 읽는다. 원문 `patch523_npc_combat.damage_spec`은 여전히 raw dice를
사용하며 평균값을 다시 더하지 않는다. Prob는 정규화/추첨/선택에 쓰지 않고,
FixedDelayTime·queue·clock·cost·target·save는 바꾸지 않는다. attack_power에
의존하는 기존 명중 기본값은 달라질 수 있으며 원작 공식으로 주장하지 않는다.

2026-11-06의 좁은 source-shape 집합은480 NPC였다. 이는 특정 원문 형태의
숫자이며 실제 admitted/nonboss/host-default 표식·실행 수가 아니다. 예:
Npc103712 → Attack352942, DiceBonus563/4d11 → host 추정587.

### 3.4 기존 선택 child의 거리

`progression_runtime523.gd`에서 이미 선택된 원문 그래프만 읽는다:

| 기존 경로 | 원문 값 | host 입력 |
| --- | --- | --- |
| Triple Arrow root350→on119642→effect120712 | CastRange10 | 10×32=320, 기존430 대체 |
| Static Field root69581→on70961→107343→effect107963 | AreaRadius3 | 3×48=144, 기존128 대체 |
| Taunt root98871→on99181→Invoke17541→effect99231 | AreaRadius10 | 10×48=480, 기존160 대체 |

32/48은 별도의 조절 가능한 host 추정이다. 원문 서버 단위나 셀 변환을 복원한
것이 아니다. full root binding/child row/graph/target kind와 Test/제외 가드,
IsAttackRange=false/MinCastRange0을 요구한다. repeat의 root는 native_toggle이므로
직접 시전용 target_filter 표식 요구를 제거하고 exact child TargetKind 및 기존
try_repeat→target_allowed 계약을 확인하는 후속 수정이 포함됐다.

거리/LoS/큐/지불은 기존 소유자가 수행한다. aura의 기존 boss/conceal 제외,
최대10·tick·지속시간, static의 기존 proc/cost/dice는 바꾸지 않는다.
root-only distance_numeric_input과 child metadata는 다른 ABI다. 루트가 거리0인
toggle인데 child 거리를 root 거리로 위장하면 안 된다.

### 3.5 읽기 전용 물리 아이템 원문 증인

`current523_owned_item_witness.inspect(book, selected, physical_id, physical)`은
실제 선택된 patch523_rules owner와 현재 native DTO/물리 snapshot을 받는다.
original에는 ItemClass 전체 행/semantic row hash와 슬롯·직업 FK 증인을,
admission에는 실제 모델 digest/행 일치를, physical에는 명시된 축복/강화와
snapshot hash를 분리해 보존한다. JSON hash는 sorted/full-precision semantic
hash이며 원본 JSON member의 byte hash와 다르다.

모든 held 결과는 ok=false/ready_for_owner_recheck=false다. 완성된 원문 증거는
original_evidence_available로 보존하며 전체 inspect 계약 성공 때만 두 플래그가
true다. ownership_authorized/collection_eligible/physical_membership_verified는
항상 false다. 실제 key membership·잠금·수량·custody·revision·한 번의 저장은
Integration 소유자가 다시 확인해야 한다. 축복 필드 부재를 일반1로 추정하지 않는다.

Integration의 prospective receipt 소비자 전문은 별도 owner에서 작성돼 전달됐다.
Data 환경에는 그 collection/World/save 파일을 적용하지 않았다. 최신 전달된
native 등록 guard7472B는 pending producer를 신규 native 등록에서 막으며 과거
absent/pending receipt 읽기는 유지한다. 남은 실제 호환 문제는 catalog 기본
source_bless_raw1과 현재 pinned/physical 축복2를 같은 값으로 요구하는 과도한
비교다. immutable catalog identity와 mutable blessing을 나누도록 owner에게
인계했으며, 수정된 소비자의 최종 결과는 아직 받지 않았다. 94개 표시용 eqc
후보는 native-unbound이며 기존 진행도/보너스를 native 완료로 이관하지 않는다.

## 4. 보류 후보와 정확한 소유 경계

### Rune Burst 공격 채널 — HELD/미적용

`player_skills523.gd` 활성 파일은 blob
`774e28ba0c24c497645b3528a1c97f6c405847df` 그대로다. private candidate는
`4661083fee9472de015632a22bc0d84d435d8d6c`, patch4014B/SHA
`244e65c108b843d61934bd512f723323c17c206ef0d084f0a6600e1025adf388`다.

실제 binding lm_36641c582649e3a0 → Spell95542, root row SHA
`ae021cd23ffcdcef6c5d8902900ad7e07cfdb8ae8008b9ed74505ef9bc54a720`.
마검사 Class142는 bindings.class_ids의 별도 매핑이다. 원문 join은
SpellBonus608132→Bonus1760852→BonusType3401 SpellAttackType,
Unit10431 AttackTypeID/Value1→AttackType1 Melee다. balance는 magic이다.

현재 SkillService.hit_chance/deal_damage는 attack_type으로 명중·치명타·채널
보너스를 읽는다. 같은 필드가 ready의 CannotCastSpell 검사와 cast의 queue kind,
World._queue_player_attack의 CannotCastSkill/Spell 검사에도 쓰인다. 따라서
기존 필드를 전역 대체하면 시전 권한까지 달라진다. Integration이 피해 채널과
기존 시전/큐 권한을 분리하는 수신 계약을 제공하기 전까지 이 패치는 적용 금지다.
조건부 NextSpell96012 실행·선택이나 무기 허용은 이 후보가 만들지 않는다.

### FoeSlayer/장비 모델/기타

FoeSlayer effect122992는 CastRange3/IsAttackRange=true, WeaponType11
ChainSword는 AttackRange2/NoAmmoAttackRange2다. add/replace/cap 결합 규칙은
확정되지 않았다. Integration의 실제 읽기 API는
`world.original_skills.current_source_weapon_context() -> Dictionary`다.
성공 시 physical_id/item_class_id/source_id/bless_raw/enchant/weapon_type_id/
weapon_type_row/original_item_row/source/source_basis/use_authorized=false를
반환한다. 호출 순간 장착 증거이지 장기 permission token이 아니다. 지연 실행은
다시 조회하고 기존 life/field/combat generation/range/LoS 가드를 보존해야 한다.
이 API는 사거리 결합 공식을 제공하지 않으므로 임의로3+2를 적용하지 않는다.

실제 비fixture rules/model JSON과 등록 binding 산출물은 input pending이다.
필수 입력은 실제 catalog_v19 바이트와 실제 등록 binding 바이트, 같은 원문 pin이다.
빈 별도 patch523_rules 인스턴스의 load_original로 후보를 만들고 입력/선택을
재확인한 후 기존 적용 경계로 채택하는 것은 Integration 소유다. 이미 data가
있는 인스턴스는 early-return할 수 있으므로 성공 반환을 새 모델 생성으로
오인하지 않는다. 명시 환경변수/활성 INDEX를 자동 우회·교체하지 않는다.

Land0 정확한961B 보정은 Map 호환 후보에 전달됐고 별도 private patch로 보존한다.
이를 batch API나 현 Data producer 전체 파일로 임의 덮어쓰지 않는다. flat 결정타
공동 후보, 양수 최소거리 증거, 과거 quest 증거도 별도 보존 상태다. Test 대상이나
퇴역한 조사 항목을 재활성화하지 않는다. 한 계약 대기가933파일 전체의 차단은 아니다.

## 5. 장부·원본·조사 근거

고정 원본 ZIP25,031,173B, SHA
`d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`.
게임 정의 분모는 content/*.json 1,065 member/2,323,700행/
457,729,872 비압축 bytes다. 별도10 metadata member/1,368,485B를 게임 정의에
중복 합산하지 않는다. 컨테이너 압축 bytes와 JSON/생성 캐시 bytes도 섞지 않는다.

2026-11-06/e151 기준 bounded static ledger는132 고유 partial/conditional JSON,
whole-file footprint283,211,115B다. 나머지933/174,518,757B는 이번 bounded pass의
미분류이며 미사용 확정이 아니다. 전체 행/필드 사용, 실제 byte extents, 실행
관측은 측정되지 않았다. 옛122/712, source ZIP 전체 로드,82경로,480원문 형태를
최신 전체 완료율로 쓰지 않는다. 공유 table은 hash/member로 중복 제거하며 섹터
합계를 단순 합산하지 않는다. PR/local-only 공급을 main 사용으로 세지 않는다.

내부 원본 위치는 private checkpoint-index.json의 originals_preserved_in_place에
기록되어 있다. 원본 ZIP은 Git 밖에 있고 이 문서 작업에서 복사/재추출/검사하지 않았다.
reader는 TWILIGHT_PATCH523_CONTENT 또는 기존 growth96_definitions/source.zip 등
정확한 동일 pin 입력을 받는다. 명시된 잘못된/빈 경로를 다른 자료로 우회하지 않는다.
다른 실행환경의 로컬 경로는 공유된 것으로 가정하지 않는다. 과거 Library HTTP401
대상은 동일 조건 재시도나 다른 executor/전송 경로로 우회하지 않는다.

project-relative private 보존 루트:
`.local-data-checkpoints/data-20261106/` (Git ignored, 외부 전달되지 않음).
checkpoint-index.json은302 보존 자료/24,922,891B와13 코드 파일 해시, 원본/대형
코드뷰 원위치 locator를 담는다. commit-receipt.json은118e/부모/15경로와 당시
tracked/nonignored clean 상태를 기록한다. 다음은 `retained/` 아래 상대 경로다:

| 자료 | 용도 |
| --- | --- |
| inventory.json, content-consumption-audit523.main.json, ownership-evidence.json | 역사적 전체 inventory/소비/소유 근거; 최신 사용률로 재활용 금지 |
| candidates/current-source-trace-d758/current-static-ledger-e151.json | 최신 bounded member SHA/bytes→16 실제 소비 경로 |
| 같은 폴더 compact-member-consumer-join.csv |132 canonical member/bytes/path-key 합집합용 |
| candidates/reviewed-child-distance-expanded/ |3거리 patch/코드/원문·공식 검색 기록 |
| candidates/repeat-source-target-contract-fix/ |native_toggle target guard 수정 |
| candidates/npc-batch-admission/, npc-batch-refcounted-field-fix/ |batch와 RefCounted hunk/기준·결과 해시 |
| candidates/npc-ordinary-damage-input/ |4파일 patch/기준·결과 manifest/원문 증인 |
| candidates/equipment-percentage-ignore/ |5파일 입력/소비 patch와 범위별 근거 |
| candidates/owned-item-source-witness/, owned-item-witness-result-semantics/ |원 증인8820B와 fail-closed1829B 후속 |
| candidates/direct-skill-attack-type-input/ |HELD4014B patch·완전 원문 join·후보 전체 파일 |
| candidates/foe-weapon-range-source-research/ |Foe 원문/공식 검색17질의·발견/미확정 구분 |
| candidates/land0-environment-fix/, whole-equipment-local-followup/ |별도 Land0/82경로 후보; 순서 확인 전 중복 적용 금지 |

공식 근거는 검색 시점/버전 한계를 가진다:

- https://lineagem.plaync.com/guidebook/view?title=%EA%B8%B0%EC%82%AC+%EB%A7%88%EB%B2%95
  : 공식 색인에서 Taunt10칸 및 Energy Bolt10칸. 직접 열기는 SPA shell이었다.
  과거 답변의 기사+마법법 URL은 오타이며 실제 정책 URL은 위 정상 주소다.
- https://lineagem.plaync.com/guidebook/view?title=%EB%A7%88%EB%B2%95%EC%82%AC+%EB%A7%88%EB%B2%95
  : Fire Storm3칸 맥락. raw→host 스케일 증거는 아니다.
- https://rc-wstatic.plaync.co.kr/lineagem/guidebook/game_class_fairy.html
  : 공식 색인의 Triple Arrow10칸. 직접 본문은 시간 초과했고 내부 ID는 공개하지 않았다.
- https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4
  : Static Field 영역 효과 맥락; patch523 반경3/내부 ID를 독립 확정하지 못했다.
- https://lineagem.plaync.com/board/update/view?articleId=6aa06238fa34c1011d627666
  : 후대 무기 사거리 변경 맥락. Foe의 patch523 add/replace 공식 근거가 아니다.

13 클래스 가이드 이름 대상35질의와 추가 Foe17질의를 남겼다. 이는 클래스별
모든 스킬/같은 패치의 ID 대응을 완료했다는 뜻이 아니다. 커뮤니티 게시물은
공식 도메인에 있더라도 공식 기술 선언으로 쓰지 않았다. 다른 Lineage 게임의
수치를 전용하지 않았다. SpellClass 거리 필드에 Unit FK가 없으며 Unit10392
LocationRange를 이름만으로 붙이지 않았다. 값이 맞는 공개 셀 표기도 native
내부 스케일을 증명하지 않는다. 과거 실패 로그는 현재 코드의 통과 증거가 아니다.

## 6. 재개 시 통합 순서와 코드 복구

아래는 **후속 사용자 재시작/적용 승인 이후의 절차**다. 현재는 실행하지 않는다.

1. branch/dirty/선택/pin을 먼저 보존하고 최신 main과 owner 산출물을 좁게 비교한다.
   118e를 최신 Monster/World 전체 파일 위에 덮어쓰지 않는다.
2. 코드만 복구하려면 로컬 commit118e가 있을 때 그 이력을 우선 사용한다.
   원본/폰/세이브 checkout을 수행하지 않는다. 별도 code-only patch는
   `code-checkpoint-118e6f4df.patch`,74,192B, SHA
   `cf1cd6645dd9d71e505742f90ced2f75697bf2a5e3f72fa3f9b11f54357a8a78`다.
   정확한 부모0feeb와 완전한 기존 프로젝트 코드가 전제다. 이 patch는15파일
   diff이며 전체 프로젝트/원본 설치기나 full-history Git bundle이 아니다.
   patch 적용으로 commit SHA 자체가 복원되는 것은 아니다.
3. 다른 기준에 조합할 때 후보 manifest의 base/result blob·SHA를 확인하고 좁은
   hunk만 합친다. `git apply --check` 등 정적 patch 점검과 실제 코드 적용은
   재개 승인 후 수행한다. 맞지 않으면 강제 적용하지 않는다.
4. Map은 Land0/환경 API와 RefCounted batch를 먼저 맞춘 후 actual selected-M
   encounter/field/population 준비→commit→실패 시 stale-safe restore를 연결한다.
   기존 registration/receipt/suppression·현재 NPC 입장 신원을 재사용한다.
5. 장비는 같은 모델/단위/물리 ID로 입력을 공급하고 guardian 예산에 한 번만
   연결한다. 실제 catalog/binding/model 산출물 및 선택·채택이 없으면 input pending이다.
6. owned-item witness는 최종 fb65 버전으로 쓴다. Integration의 신규 native
   fail-closed와 mutable blessing 비교 수정 후 prospective 영수증을 조합한다.
   native eqc 매핑94개와 기존 진행도는 별도 미해결이며 이 단계가 해결하지 않는다.
7. Rune damage/permission 수신자와 Foe 거리 결합은 정확한 계약을 받은 뒤 별도
   후보로 조합한다. 원본 의미/권한을 수치 추정으로 만들지 않는다.
8. 모델 생성/컴파일/파서/테스트/게임/CI/폰 적용/게시·업로드·병합은 현재 미승인이다.
   검증을 나중에 허용받더라도 과거 성공을 후속 변경의 검증으로 대체하지 않는다.

주요 순서별 지문:

| 자료 | SHA256/중요 blob |
| --- | --- |
|3거리 patch13955B | `ffa479206e88139f7af52e7882782db4883c8948ff1a73650af98f0882f4f10a` |
|repeat 후속2040B | `0273e7b5f5249570ef6169026ca3c7fc0020e4f0e0d87c511668b5ece60e8f2c` |
|NPC batch18558B | `1c14f2f31842a6a6982e53de3fb6d57562590410ced33e69293764defdf7f8ed` |
|RefCounted 후속3396B | `1e21a31fcff6157e4ef3296a5242d587a8b248fe435a3d8180fabb23efd98d3d` |
|NPC4파일11076B | `271da1f75432cef154ed58e13c4ec2a4bc062cc81963b3a3e0b865501b925079` |
|NPC catalog: RefCounted 후속→ordinary | base `8fb3d8b2eb877e40285bad827b501d92a4380ff8` → result `26224dc1cb74f1fadfd227d7a80c59986776ba73` |
|roster ordinary | base `82288539dd530b852947d168388f4b83718f05d0` → result `845f1f6dff28925bb2df1c0ae426a48369a5bc9d` |
|장비5파일16137B | `03713b6a926a365197f043909d37466b7c10b48d041f42d90fee85aecab39d50` |
|증인8820B→fail-closed1829B | `f35ff4a6f511833c15fab2b3d0080e0c63a90b82de902df9b59e349b36036215` → `9ae165395fa722a565f6a5c347ecd83097270dc309afc0b9473c5c61aa7a7c1e` |
|최종 witness | blob `fb65f1cc69e2757ce1d382b9827740a866f5cfb0`, file SHA `107685be8c80f29da56594e229332eea81c660453b18b34825b474c9e34a24eb` |
|132 canonical CSV | `58303ba836620624d386d75dc746bfd3d22b32b614e84732ef8af545cccc03f1` |

이미118e에 포함된 patch를 재적용하면 안 된다. 상대 후보는 코드 복구/다른 owner
기준 조합을 위한 자료다. baseline이 다른 전체 ItemOptions/guardian/NPC catalog를
서로 교체하지 않는다. source producer는 Data, 효과·소유·거래·저장은 Integration,
M 필드/선택/배치 lifecycle는 Map, 표시 타깃은 UI, 원본 자산은 Image/Sprite가 소유한다.

## 7. 하지 않은 것과 인계 종료

이 코드는 로컬 저장됐지만 신규 실행 검증은 하지 않았다. 테스트/컴파일/모델
생성/GDScript 파서/게임/렌더/CI, 원격 ref/blob/PR 편집·push·merge·upload,
폰 설치/명시 선택/세이브/원본 변경은 하지 않았다. private 자료는 프로젝트의
ignored 보존 위치에 있지만 사용자 외부 전달이나 다른 executor의 파일 존재를
증명하지 않는다. /tmp만을 내구 보존소로 주장하지 않는다. 초기 체크포인트의
tracked/nonignored tree는 clean이었고 보류 원문/후보는 ignored로 따로 남아 있다.

문서 저장·로컬 커밋 후 Data는 계속 PAUSED다. 주기 상태 조회나 다른 owner의
인계 메시지는 자동 재시작 승인이 아니다. 정확한 소유자 계약이 새로 도착해도
명시적인 사용자 재시작 지시 전에는 새 구현·수정·실행을 하지 않는다.
