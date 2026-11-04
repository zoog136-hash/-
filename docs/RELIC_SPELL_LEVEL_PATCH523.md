# 성물 소환 스킬 레벨 규칙 — 부분 연결

기준은 main `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`이다. **기존 성물 화면, 원본 자료 설치, 보유·장착·조건에 따른 등급별 레벨 계산을 연결했다. 현재 스킬별 전투 수치 반영은 미완료다.** 이름이나 기존 스킬 DB의 등급만으로 원본 스킬을 대응시키거나 피해 배율을 만들지 않았다.

## 확인한 원문

- 정식 Library 자료: `libfile_f3e9e5b322cc8191ae441565bbd24c27`, `lineagem_patch523_all_content_validated_and_508_520_deltas.zip`.
- 실제 ZIP: 25,031,173 bytes, SHA-256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`. 전체 ZIP CRC 검사 통과. 원문은 수정하지 않았다.
- `BuffCardTranscendence`: 59개 서로 다른 성물의 그룹 매핑. 기존 main과 정확히 대조되는 카드 58개, 신규 세계수의 꽃잎 `25162` 1개. 신규 카드는 자동 등록하거나 지급하지 않는다.
- `BuffCardTranscendenceBonus`: 7그룹·13행. 모두 `SpellLevelUp`, `Unit=Value`, `BonusApplicationType=Grade`, 값 `+1`. 대상 원본 GradeID는 `1/4/5/32`다. 영웅 성물 그룹은 일반, 전설 그룹은 일반·영웅, 신화 그룹은 일반·영웅·전설, 유일 그룹은 일반·영웅·전설·신화를 가리킨다.
- 카드 매핑에 직접 사용되지 않는 그룹 `58/68/78`도 원문대로 보존한다. 다른 카드에 전용하지 않는다.
- 이 표에 초월 시도, 비용, 성공률, 무료 승급이나 100% 승급 규칙은 없다. 그런 동작·버튼·세이브 필드를 추가하지 않았다. 기존 각성 비용·상태도 변경하지 않는다.

## 실제 연결 경로

게임 메뉴 → 성물 → 선택 상세에서 **등급별 스킬 레벨 보너스**와 **원본 규칙 자료 불러오기**를 사용한다. 파일 선택기는 위의 정확한 최신523 ZIP만 수용한다. ZIP을 검증한 뒤 `user://source_rules/relic-patch523.zip`에 원자적으로 설치하며, 손상·다른 버전·쓰기 실패 시 기존 규칙을 보존한다. 원본 ZIP과 별도 실행 자료를 공개 Git에 추가하지 않는다.

선택 카드의 원본 매핑은 미보유 상태에서도 조회할 수 있다. 계산 활성화는 기존 게임의 영구 보유와 현재 소환 카드가 정확히 일치해야 한다. `source:m508:98:<BuffCardID>`의 기존 저장 정체성을 유지하고 규칙의 출처만 patch523으로 구분한다. 제공된 레코드의 임의 수치 대신 현재 정식 카탈로그를 다시 조회한다.

원본 서버 조건은 기존 `source_collection_conditions.gd` 평가기에 최신523 행을 공급하여 검사한다. 서버를 지도나 언어로 추정하지 않는다. 이벤트 카드 1개의 날짜 조건은 미해석으로 유지한다. 컬렉션의 기간 해제 정책을 별도 성물 패시브에 확대 적용하지 않는다.

실제 Main의 `world.source_relic_spell_level(source_grade_id, base_level)`은 해당 등급에 대한 `base_level`, `bonus`, `effective_level`, 조건 코드와 `combat_values_connected=false`를 반환한다. 다른 카드 선택·미보유·해제·조건 미충족은 레벨을 더하지 않는다. 반복 조회는 중첩되지 않는다.

**남은 연결:** 현재 스킬 DB의 실행 ID와 원본 `SpellClassID`, 원본 스킬 GradeID, 각 레벨의 수치와 효과를 검증하여 소비해야 한다. 이 PR은 그 검증 없이 현재 커스텀 스킬의 피해·회복·지속시간을 바꾸지 않는다. UI에도 전투 수치 연결이 확인 중이라고 표시한다. 별도 일반 스킬 작업에서 이 계약을 소비할 수 있으며, 스킬 각성 레벨과는 별개다.

## 검증과 재현

원본과 current main의 독립 대조:

```sh
python3 tools/audit_relic_spell_levels.py --source /absolute/path/to/authorized-patch523.zip
godot --headless --path . --script res://tests/relic_spell_levels_test.gd -- --source-zip=/absolute/path/to/authorized-patch523.zip
```

Godot 기준은 공식 4.7.2다. 집중 검사 285개가 통과했다. 58개 기존 카드의 정확한 조인, 등급별 대상, 미보유·다른 장착·서버·이벤트 조건, 비정규 ID 거부, 미등록 신규 카드, 미리보기 변경 격리, 잘못된 자료 교체 시 기존 상태 보존, ZIP과 기존 세이브 바이트 보존을 검사했다.

프로젝트 Python 구문 검사와 기존 core staging 검사 7개가 통과했다. 실제 Main/current source-map 검사 32개, 동일 저장 payload 보호와 deferred-save 게이트도 로컬에서 통과했다. committed resource 검사는 723개 atlas·41,442 frame·233,420,026 bytes의 SHA 및 추적을 확인했다. 이는 원본 아트 전달이나 원작 전투 동등성 증명이 아니다.

실제 UI 검증은 `tests/relic_spell_levels_main_ui_test.gd`에서 기존 성물 목록·자료 선택·소환 확인·결과·해제·다른 화면 이동과 두 해상도의 접근성을 검사한다. core staging이 지연한 몬스터 초상 `assets/monsters/reviewed_source/l1j_tw380_npc_45027/portrait.png`는 최신 main의 실제 Git blob을 별도로 추가해 UI 검증한다(1,027 bytes, SHA-256 `bd3e2b71fd8b98f228a0b9424377210ff6f8abf31b30c4f28cf7bc5feae275d8`). 대체 이미지를 생성하지 않는다.

최종 실제 OpenGL(X11/Mesa llvmpipe) UI 검사 **26개 통과**, 1280×720·854×480 캡처 2장을 확인했다. 실제 포인터로 파일 선택기를 열고 원본 규칙을 설치한 뒤 기존 소환 확인과 해제를 거쳐 표시가 자동 갱신된다. 보너스와 기존 ‘현재 적용’ 문구가 함께 갱신되도록 HUD의 기존 상태 게시 경로를 연결했다. 두 해상도의 버튼은 화면 변환 후의 실제 창 경계와 스크롤 경계를 모두 만족한다. 오디오 장치가 없는 검증 환경이므로 최종 화면 검사는 Godot `--audio-driver Dummy`를 사용했으며 소리·Android 실기기는 검증하지 않았다. 초기 작은 창 경계 검사의 좌표계 혼용과 UI staging의 누락 초상 오류도 별도로 확인·수정한 뒤 최종 검사를 통과했다.

일반 원본 장부의 `--source-dir` 검사는 이 환경에 구형 `a1.zip`이 없어 실패했다. 이 작업에 사용한 최신523 ZIP의 크기·SHA·CRC는 별도로 확인했다. 원본 아트 복원·원본 팩 전달 상태는 승격하지 않는다.

PR #231의 변경 파일 13개와 겹치는 파일은 없다. 타 PR과 main을 병합하지 않는다. 사용자 지시에 따라 커밋에 `[skip ci]`를 사용하며 수동 CI 실행·재실행 및 워크플로/보호 규칙 변경을 하지 않는다. 원격 필수 CI 미실행을 통과로 표시하지 않는다.
