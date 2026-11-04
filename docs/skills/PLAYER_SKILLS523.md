# 누적523 일반 플레이어 스킬 연결

기준 main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`. 다른 PR을 병합하지 않은 독립 작업이다. 이것은 전체 원본 전투 복원 완료가 아니다.

## 소비 경로와 범위

`player_skills523_bindings.json`은 기존125 항목 중118개, 현재 공식 참고354 항목 중322개의 정확한 원본 행을 고정한다. 합계440개 **화면 항목의 정체성 연결**이며,440개 스킬 구현 완료라는 뜻이 아니다. 같은 공통 주문을 여러 직업 화면에서 참조할 수 있다. 런타임에서 이름·가장 작은 ID·NPC/이벤트/카피 스킬을 검색해 선택하지 않는다. 바인딩마다 원본 행 SHA와 일반 `SpellLearnLimit` 연결을 검사한다. 현재 카운터 배리어의 학습 ID99841과 과거581을 구분한다.

원본 외부팩 → `skill_catalog.resolve` → 기존 수동 시전/퀵슬롯/AUTO 서비스로 이어진다. 기존 안정 ID·습득·직업·무기 제한·책 가격·장비·저장은 유지한다. 확인된 일반 액티브에는 다음의 좁은 투영만 적용한다.

- 절대 단위 HP/MP 및 명시된 재료 수량. 기존 화살 소비는 별도 호스트 규칙으로 유지한다. 재료의 native ItemClass→ItemBonus→BonusType89 연결을 검증한다. 바인딩의 기존 인벤토리 키와 별도 검토한 현 도감의 각인 표기7개만 사용하고, 두 묶음에 나뉜 수량도 합산 후 한 번에 지불한다. 부족하면 어느 묶음도 일부 차감하지 않는다. Inven ID와 native ID를 같다고 간주하거나 이름으로 다른 품목을 대신 쓰지 않는다.
- 현재 PvE에서 표현 가능한 자기/적/언데드/자신 제외 대상과 원본 단일 대상 형태. PC 전용 슬로우·파워 그립 등의 몬스터 시전은 비용·RNG·쿨타임을 소모하기 전에 거부한다. 실제 타격 대상 목록과 AUTO에도 같은 제한이 적용된다.
- `Unit.Seconds`가 확인된 단일 무조건 버프 지속 및 직접 주 버프의 `Stunned`/`CannotCastSpell`과 연결된 상태 지속 범위. 레벨별 보너스를 합산하지 않고, 중복·조건부 지속은 기존 값을 유지한다. 확률과 보스 보정은 기존 TWILIGHT 정책이다.

상위 효과가 활성화된 경우, 복합 노드·대상별 대체 비용·미지원 대상/단위·원본 패시브와 기존 액티브의 불일치는 적용 보류 사유를 표시하고 시전을 거부한다. 새로운 참고 스킬(`lmref_`)은 원본 비용·대상·확인된 지속 자료를 화면에서 볼 수 있지만 **이 연결로 활성화하거나 기존 로컬 설계를 덮어쓰지 않는다**. 미연결39 화면 항목도 삭제하지 않는다.

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

별도 데이터 팩 `player_skills523.json`:4,133,066 bytes, SHA256 `ea75b8a478fed6bfdbc5f797f2f547f65ce3a937d033d8f3c2ce4a902bb734be`. 개인 Library에 저장 성공했고 비공개 식별자는 별도 보고한다. 자동 공유하지 않았으며 원본 아트 전체 전달 장부를 승격하지 않는다.

```sh
python3 tools/skills/build_player_skills523.py \
  --source-zip /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  --output /private/player_skills523.json

godot --path . -- \
  --player-skills523-pack=/private/player_skills523.json \
  --player-skills523-sha256=ea75b8a478fed6bfdbc5f797f2f547f65ce3a937d033d8f3c2ce4a902bb734be
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

Godot4.7.2에서 원본440개 프로필·보너스 원행/순서/레벨 조건/부정 입력 Python5검사, 기존 staging7검사, 원본 어댑터·재료 거래·기본 규칙 보존30검사, 실제 Main/current source map/세이브 보존32검사, 동일 저장 생략·외부 수정 보호와 deferred-save 검사가 통과했다. 동일 저장 결과의 `skips:1`은 검사를 생략했다는 뜻이 아니라 동일 payload의 중복 쓰기를 막은 횟수다. 원본 팩을 실제 로드한 OpenGL41검사에서 UI 책 구입·습득·사용·퀵슬롯, 각인/기존 재료 혼용과 무소모 실패, PC 전용 효과 차단, 실제 버프 시간과 저장 ID를 확인했다. 최종 실행에 스크립트/리소스 오류가 없고 캡처2장의 실제 크기는1280×720/960×540이다. 처음 축소 프로젝트에서 누락된 동적 아이콘은 실제 Git 파일을 추가해 해결했으며, 최종 캡처를 직접 열어 비용·재료·보류 표시를 확인했다.

Git 추적723시트/41,442프레임 SHA와 기존125개 styled skill icon 검사도 통과했다. CI 수동 실행·재실행은 하지 않고 사용자 지시에 따라 커밋에 `[skip ci]`를 사용한다. 원격 CI 미실행을 성공으로 보고하지 않는다. 캡처와 상세 로컬 로그는 작업 환경의 `/workspace/skills523-core-results` 및 `/workspace/skill-sources523/ui-captures-verified`에 있으며 공개 Git이나 Library에 화면 이미지를 업로드하지 않았다.

## 남은 경계

원본 사거리·반경의 거리 함수/픽셀 환산, CastDelay의 시간·그룹·직업별 우선순위, 새 스킬 전투 구현, 조건부/대체 비용, 패시브·토글 전환, 단계별·복합·연쇄 효과, 전 상태 종류, 서버 최종 피해·명중·AC 계산, Windows/Android 실기기 검증은 미완료다. 차지의 PC 전용 후속 그로기를 NPC의 AC 감소로 만들지 않았다. Formula111은 방어111로 해석하지 않았다. 아케인 럽처119971은 무기 발동 연구이므로 일반 학습 스킬로 추가하거나 미확정 음원을 연결하지 않았다. 사용자 지정 드랍 확률·각성 비용은 변경하지 않았다.

필수 공개 리소스 검사723시트/41,442프레임은 별도다. 역사적 `--source-dir` 검사는 이 세 ZIP이 아니라 `a1.zip` 등 구형6ZIP을 요구하여 해당 파일 부재로 실패했다. 이 작업은 원본 그림 복원을 수행하지 않으며, 그 실패를 성공으로 기록하지 않는다. 세 개의 이번 자료는 위 해시/CRC와 컴파일러의16표 원문 해시/행수 대조로 직접 검증한다.
