# 누적523 일반 플레이어 스킬 연결

기준 main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`. 다른 PR을 병합하지 않은 독립 작업이다. 이것은 전체 원본 전투 복원 완료가 아니다.

사용자 승인 후속 작업으로8종은 [TWILIGHT 추정 실행](ESTIMATED_NODES523.md)까지 연결했다. 이후 [기존7종 자기 회복·해제·보호 경로와 설정 UI](SELF_RECOVERY523.md), [기존9종 패시브·ON/OFF·반복 발사](EXISTING_SKILLS523.md)를 추가했다. 아래 보류/참고 전용 원칙에서 이 명시적 실행 경로를 구분하며, 원본 동일 복원 완료로 집계하지 않는다. 최신 로컬 적용팩은441 프로필에 회복15개 하위 주문과 추가 실행10개 주문/Invoke 정의를 더한 v3다. v3의 Drive 업로드는 거절되어 LOCAL_ONLY이며, Drive에서 검증된 v2와 기존 Library 버전1을 최신 v3 보관 성공으로 쓰지 않는다.

## 소비 경로와 범위

`player_skills523_bindings.json`은 기존125 항목 중119개, 현재 공식 참고354 항목 중322개의 정확한 원본 행을 고정한다. 합계441개 **화면 항목의 정체성 연결**이며,441개 스킬 구현 완료라는 뜻이 아니다. 라이프 스트림은 메인 주문95662와 마검사142의 일반 학습 행을 추가 대조해 정확히 연결했다. 같은 공통 주문을 여러 직업 화면에서 참조할 수 있다. 런타임에서 이름·가장 작은 ID·NPC/이벤트/카피 스킬을 검색해 선택하지 않는다. 바인딩마다 원본 행 SHA와 일반 `SpellLearnLimit` 연결을 검사한다. 현재 카운터 배리어의 학습 ID99841과 과거581을 구분한다.

원본 외부팩 → `skill_catalog.resolve` → 기존 수동 시전/퀵슬롯/AUTO 서비스로 이어진다. 기존 안정 ID·습득·직업·무기 제한·책 가격·장비·저장은 유지한다. 확인된 일반 액티브에는 다음의 좁은 투영만 적용한다.

- 절대 단위 HP/MP 및 명시된 재료 수량. 기존 화살 소비는 별도 호스트 규칙으로 유지한다. 재료의 native ItemClass→ItemBonus→BonusType89 연결을 검증한다. 바인딩의 기존 인벤토리 키와 별도 검토한 현 도감의 각인 표기7개만 사용하고, 두 묶음에 나뉜 수량도 합산 후 한 번에 지불한다. 부족하면 어느 묶음도 일부 차감하지 않는다. Inven ID와 native ID를 같다고 간주하거나 이름으로 다른 품목을 대신 쓰지 않는다.
- 현재 PvE에서 표현 가능한 자기/적/언데드/자신 제외 대상과 원본 단일 대상 형태. PC 전용 슬로우·파워 그립 등의 몬스터 시전은 비용·RNG·쿨타임을 소모하기 전에 거부한다. 실제 타격 대상 목록과 AUTO에도 같은 제한이 적용된다.
- `Unit.Seconds`가 확인된 단일 무조건 버프 지속 및 직접 주 버프의 `Stunned`/`CannotCastSpell`과 연결된 상태 지속 범위. 레벨별 보너스를 합산하지 않고, 중복·조건부 지속은 기존 값을 유지한다. 확률과 보스 보정은 기존 TWILIGHT 정책이다.
- 블러드 투 소울349·마나 체인지18304의 무조건 `MPRestoration / Unit.Value / MinSpellLevel=0`을 실제 변환 시전에 연결한다. 각각 HP90+정령옥1개→MP96, 정제석40개→MP80이다. `learned=1`은 기존 게임의 습득 표시이므로 원본 강화1단계97/81로 해석하지 않는다. 조건부·중복·백분율 회복을 정수 MP로 바꾸지 않는다. 실제 최대 MP를 넘지 않으며 가득 차면 UI에서 이유와 함께 사용을 막고 비용·RNG·쿨타임을 쓰지 않는다. 회복 결과는 기존 HUD와 메시지에 표시한다. 원본 `UseLowMpOnly`의 임계값은 없으므로 기존 AUTO의 MP/HP 기준과 재사용 정책은 유지한다.

상위 효과가 활성화된 경우, 복합 노드·대상별 대체 비용·미지원 대상/단위·원본 패시브와 기존 액티브의 불일치는 적용 보류 사유를 표시하고 시전을 거부한다. 새로운 참고 스킬(`lmref_`)은 원본 비용·대상·확인된 지속 자료를 화면에서 볼 수 있지만 **이 연결로 활성화하거나 기존 로컬 설계를 덮어쓰지 않는다**. 미연결38 화면 항목도 삭제하지 않는다.

`evidence_for(id)`는 보존된 SpellClass 전체행, 대상/범위/사거리/시전지연/자원 소비, 원순서 SpellBonus·Bonus·BonusType·Unit, 주/부가 BuffClass와 보너스, 학습 제한, SpellCost 대체행, 직업별 CastGroup행을 반환한다. 반환값 변경은 활성 스냅샷에 영향을 주지 않는다.

## UI

기존 **스킬 화면 → 선택 → 사용 정보 / 습득·출처 → 구입·습득·스킬 사용·퀵슬롯** 경로를 사용한다. 실제 `resolve` 결과로 MP/HP·재료·상태 지속을 표시하고, 미지원 대상은 이유와 함께 사용/등록 버튼을 잠근다. 참고 스킬의 원본 수치도 기존 실행 보류 화면에서 조회한다. 사거리·CastDelay는 원문으로 보존하지만 단위/그룹/엔진 변환이 확정되지 않아 기존 거리·시전 시간은 바꾸지 않는다.

## 재현

원본 ZIP과 생성 팩은 공개 Git에 넣지 않는다. 원본은 Library 정식 경로로 이 소비 환경에 반입하고 ID xattr·실제 바이트·SHA256·전체ZIP CRC를 검사했다.

| 자료 | 파일 | SHA256 |
| --- | --- | --- |
| 전체523 Content | `lineagem_patch523_all_content_validated_and_508_520_deltas.zip` | `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832` |
| 명중/AC 조건 경계 | `TWILIGHT_523_hit_evasion_ac_conditions_20261104.zip` | `cba8fd3e9ea15dfbd6ec2c45ffe81bf8177da525f7afb0f3126b41d3b1330cb0` |
| 현행 아케인 럽처 효과 연구 | `TWILIGHT_current523_ArcaneRupture_changed_effect_20261104.zip` | `016af7fe1c3dc4a9a6ee80e9503335ab9c617666088d3683946126e66dcd1d9a` |

최신 로컬 적용팩 `player_skills523_apply_v3.json`:4,415,307 bytes, SHA256 `256f0ba0944e05b86134b40ed3aea97c71e1073b3947ea6e46cb018b6179926a`다. 실제 게임 로드·시전은 검증했으나 Drive 업로드는 자동 승인 검토가 실행 전에 거절했으며, 외부 보관·새 Drive 소비 폴더 정식 다운로드는 미완이다. 세부 상태는 [추가9종 기록](EXISTING_SKILLS523.md)을 따른다.

이전 v2 `player_skills523_apply_v2.json`은4,345,285 bytes/SHA256 `3f9656d03a7a3ac040e8e16ebfcc13ac09bfe93079cac55f067673155e1713d6`이며 비공유 Drive 저장·새 소비 폴더 정식 다운로드·실제 Main 실행을 확인했다. v2는 기존7경로와 읽기 호환되지만 추가9종 실행 자료는 없다. 이전 Library 버전1은4,141,471 bytes/SHA256 `66f5258c82a160e9cfa174664adb8d856981143c716e6e0d99d4e6e77b6026d6`이다. 비공개 확정 링크는 별도 인계에 기록한다. Drive 보관만으로 게임에 자동 적용되지 않는다. 원본 백업 ZIP과 적용팩을 분리하며 원본 아트 전체 전달 장부를 승격하지 않는다.

```sh
python3 tools/skills/build_player_skills523.py \
  --source-zip /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  --output /private/player_skills523_apply_v3.json

godot --path . -- \
  --player-skills523-pack=/private/player_skills523_apply_v3.json \
  --player-skills523-sha256=256f0ba0944e05b86134b40ed3aea97c71e1073b3947ea6e46cb018b6179926a
```

팩 경로·해시 두 인수가 모두 필요하다. 누락·해시/버전/바인딩/행 불일치는 현재 팩과 저장을 교체하지 않는다. 미설치 실행은 기존 규칙을 유지하며, 실패한 설치 요청은 스킬 화면에 기존 규칙 사용 상태를 표시한다. 팩의 프로필은 세션에 고정된다. 명시적으로 API로 재적재하면 revision으로 resolve 캐시만 무효화하고 대기 중인 공격의 스냅샷이나 저장은 수정하지 않는다.

```sh
PLAYER_SKILLS523_SOURCE=/private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  python3 tools/skills/test_player_skills523.py -v
python3 tools/ci_core_map_pack.py --output /private/current-map
TWILIGHT_SOURCE_MAP_PACK=/private/current-map python3 tools/ci_core.py \
  --stage /private/core-project --godot /path/Godot_v4.7.2-stable_linux.x86_64 --logs /private/core-results
```

실제523 비용/화면/전투 검사는 `tests/player_skills523_live.gd`, `active_source_test_positions.gd`, `combat_test_clock.gd`를 동일한 임시 core 프로젝트에 추가하고 별도 XDG 저장소에서 스킬 팩 인수로 실행한다. core 게이트는 스킬 화면의 동적 아이콘을 모두 가져오지 않으므로 저장소의 실제 `assets/skills/`도 같은 경로에 복사한 후 다시 import한다. 대체 그림을 생성하지 않는다. `--source523-captures=/private/captures`는 실제 OpenGL 실행에서만 사용한다. 실제 상세 탭을 열고 요청한1280×720/960×540 렌더 크기를 확인한다. 전투 대상은 현재 원본 맵의 통행 가능한 위치에 둔 제어된 dummy이며 population을 멈춘다. 일반 몬스터 AI/출현이나 headless 실행을 화면 검증으로 세지 않는다.

## 이번 직접 검증

추가9종은 실제 Main/current source-map/OpenGL109검사, 최종 발사 비용/정밀 설정 UI16검사, 실행 그래프/이전 v2 호환/정확한 사본 캐시12검사, 컴파일러7검사를 통과했다. 기존 정책42검사와 Main/세이브32검사, 기존 회복7종의 headless Main/UI77검사도 통과했다. 참고327개와 PC 대상6개는 활성화하지 않으며 전체146개 실플레이 완료라는 뜻이 아니다. 상세 내용은 [추가9종 기록](EXISTING_SKILLS523.md)에 있다.

최신7종 경로는 실제 Drive 다운로드 팩으로 Main/current source-map/OpenGL81검사, 설정 화면13검사, 컴파일러6검사, 기존 정책42검사 및 Main/세이브32검사를 통과했다. 설정 손상 입력 검사는 예상 parse 오류1회와 기존 파일 보존을 별도로 확인했다. 자세한 범위와 실제 적용·백업 구분은 [추가 경로 기록](SELF_RECOVERY523.md)을 따른다. 아래는 이전 단계의 검증 이력이다.

후속 작업의 최종 검증은 Godot4.7.2 규칙35검사와 실제 OpenGL60검사가 모두 통과했다. 기존41검사에 두 직업의 실제 변경·스킬 사용, 기본 MP96/80 회복, 재료40개 부족 시 무소모, 혼용 지불, 최대 MP 제한, 가득 찬 MP의 UI 차단을 추가했다. 캡처4장 중 블러드 투 소울의 시전 전·후 화면에서 비용/MP 회복96 표시, HP1832→1742와 MP0→96, 결과 메시지를 직접 확인했다. 최종 실행에 스크립트·리소스 오류는 없고 소프트웨어 OpenGL의 V-Sync 지원 경고만 있다. 로그는 `/workspace/skills523-core-results/player_skills523_policy_followup_final.txt`, `player_skills523_live-delivery.txt`, 캡처는 `/workspace/skill-sources523/ui-captures-delivery`이다. 원본1065표의 구조 조사 결과는 로컬 `player_skills523-audit.json`에 있고, 라이프 스트림1개 추가를 포함한441 프로필 전수 대조 Python5검사도 다시 통과했다. 별도 팩은 같은 Library 파일의 버전1로 보존했고, 위 새 SHA를 사용한다. 이전 버전0 팩은 추가 바인딩과 해시가 달라 새 코드에서 안전하게 거부되므로 새 팩으로 갱신해야 한다. 공개 리소스723시트/41,442프레임 무결성도 다시 통과했다.

아래는 초기 연결 단계에서 수행한 검사다.

Godot4.7.2에서 원본440개 프로필·보너스 원행/순서/레벨 조건/부정 입력 Python5검사, 기존 staging7검사, 원본 어댑터·재료 거래·기본 규칙 보존30검사, 실제 Main/current source map/세이브 보존32검사, 동일 저장 생략·외부 수정 보호와 deferred-save 검사가 통과했다. 동일 저장 결과의 `skips:1`은 검사를 생략했다는 뜻이 아니라 동일 payload의 중복 쓰기를 막은 횟수다. 원본 팩을 실제 로드한 OpenGL41검사에서 UI 책 구입·습득·사용·퀵슬롯, 각인/기존 재료 혼용과 무소모 실패, PC 전용 효과 차단, 실제 버프 시간과 저장 ID를 확인했다. 최종 실행에 스크립트/리소스 오류가 없고 캡처2장의 실제 크기는1280×720/960×540이다. 처음 축소 프로젝트에서 누락된 동적 아이콘은 실제 Git 파일을 추가해 해결했으며, 최종 캡처를 직접 열어 비용·재료·보류 표시를 확인했다.

Git 추적723시트/41,442프레임 SHA와 기존125개 styled skill icon 검사도 통과했다. CI 수동 실행·재실행은 하지 않고 사용자 지시에 따라 커밋에 `[skip ci]`를 사용한다. 원격 CI 미실행을 성공으로 보고하지 않는다. 캡처와 상세 로컬 로그는 작업 환경의 `/workspace/skills523-core-results` 및 `/workspace/skill-sources523/ui-captures-verified`에 있으며 공개 Git이나 Library에 화면 이미지를 업로드하지 않았다.

## 남은 경계

### 후속 원문 조사: 거리·시간과 복합/연쇄 효과

아래 표는 추가 회복 경로 연결 전 조사 이력이다. 클리어·드래곤 포스·플라즈마 다이브·라이프 스트림의 **자기 기본 단계**는 이후 연결했다. 원문에 없는 두 회복량과 호스트 재사용/보호막 상한은 표시·설정 가능한 자체값으로 처리하며, PvP·파티·미구현 상태·상위 단계는 완료 범위에 넣지 않는다.

다음 명령은 동일 ZIP의 SHA/CRC 및 읽은 표의 index SHA/바이트/행수를 검사하고 로컬 진단 JSON을 출력한다. 런타임 팩이나 Library 파일을 교체하지 않는다.

```sh
python3 tools/skills/audit_player_skills523.py \
  --source-zip /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip
```

실제 index1065표와 바인딩441개를 대조한 결과다. 테이블 수와 게임에서 기능을 사용할 수 있는 수는 다르다.

| 검토 지점 | 원문에서 확인한 것 | 실제 차단 이유 |
| --- | --- | --- |
| 사거리·최소 사거리·반경 | SpellClass의 `CastRange`, `MinCastRange`, `TargetAreaRadius`, `IsAttackRange` | 해당 열의 단위 연결, 거리 함수, 좌표/타일→픽셀 변환과 장비 사거리 결합 규칙이 이 자료에 없다. |
| CastDelay | 별도 `NextSpellDelay`, 절대 시전 지연 증감 보너스는 `Unit.MilliSeconds`로 명시된다. `FixedCastDelay`, 최소/상한, 그룹 지연 상수 및 직업별 그룹 전환 행도 있다. | 보너스의 단위만으로 기본 CastDelay가 시전 모션/타격 접촉/재사용 중 어느 시간인지, 고정 지연·그룹·직업 전환과 어떤 순서로 결합되는지 확정할 수 없다. `/1000`을 기존 `cast_time`이나 `cooldown`에 바로 넣지 않는다. |
| 조건 구성 | 바인딩의 구성 값10종 중2개만 SpellNode.ID와 숫자가 같다. 전체 구성 값85개 중 직접 ID 일치는16개뿐이라 외래키 관계는 확정하지 못했다. | 이전의 “누락 노드8종”은 직접 ID 조인 실패이며 실제 원본 노드 누락으로 단정할 수 없다. 명시적8종은 별도 TWILIGHT 추정 규칙으로 실행하고 나머지는 보류한다. |
| 클리어54703 | 일괄 하위 주문66431(홀드 계열 해제),66391(버프),66692(회복)의 원순서 연결이 있다. 버프68641의 보너스는 `PVPDamageReduction`이다. | 그룹별 해제와 회복의 별도 실행 연결이 필요하다. PvP 전용 감소를 PvE 방어로 주거나 모든 디버프 해제로 확대하지 않는다. |
| 플라즈마 다이브69601 | 기본 하위4종과 강화 추가 주문이 있고,69631의 회복은 `RestorationID`2/12/22/32이다. | `Restoration` 정의표가 없어 단계별 회복량을 정할 수 없다. 피해 모션·상태 해제·충돌 무시·공성 제한·공격 시 종료도 각각 구현해야 한다. |
| 라이프 스트림95662 | 자신과 파티원 회복이 다른 주문이다. 회복 주문이 `RestorationID`152/242/252/262 및272와 오버힐 보호막을 참조한다. | 회복 정의표, 보호막 변환 규칙과 파티 대상 실행이 없다. 파티원 회복을 자신에게 더하거나 참조 ID를 회복 수치로 사용하지 않는다. |
| 룬 스턴95102 | `NextSpellClassID`97572와 해당 후속 자기 버프가 존재한다. | 참조만으로 적중/성공/실패 시 발동 조건과 호출 시점을 확정할 수 없다. 기본 상태 지속 투영은 유지하고 추가 연계 효과의 보류를 UI에 표시한다. |

원본 전체 스킬을 적용하려면 나머지 런타임 단위·분기 정의/실제 호출 구현과 검증이 필요하다. 원문·기존 보고서·공개 설명을 우선하고 없는 값은 TWILIGHT 자체값으로 구분한다. 위8종과 추가7경로 밖의 복합 스킬은 계속 보류하며, 확인된 기본 효과에 후속 참조만 있는 경우는 기본 투영 범위와 연계 미완료를 구분해 표시한다. 원본 사거리·시간과 최종 전투 수식은 기존 게임 규칙을 유지한다.

원본 사거리·반경의 거리 함수/픽셀 환산, CastDelay의 시간·그룹·직업별 우선순위, 새 스킬 전투 구현, 조건부/대체 비용, 패시브·토글 전환, 단계별·복합·연쇄 효과, 전 상태 종류, 서버 최종 피해·명중·AC 계산, Windows/Android 실기기 검증은 미완료다. 차지의 PC 전용 후속 그로기를 NPC의 AC 감소로 만들지 않았다. Formula111은 방어111로 해석하지 않았다. 아케인 럽처119971은 무기 발동 연구이므로 일반 학습 스킬로 추가하거나 미확정 음원을 연결하지 않았다. 사용자 지정 드랍 확률·각성 비용은 변경하지 않았다.

필수 공개 리소스 검사723시트/41,442프레임은 별도다. 역사적 `--source-dir` 검사는 이 세 ZIP이 아니라 `a1.zip` 등 구형6ZIP을 요구하여 해당 파일 부재로 실패했다. 이 작업은 원본 그림 복원을 수행하지 않으며, 그 실패를 성공으로 기록하지 않는다. 세 개의 이번 자료는 위 해시/CRC로, 최신 적용팩은 컴파일러의22표 원문 해시/행수 대조로 직접 검증한다.
