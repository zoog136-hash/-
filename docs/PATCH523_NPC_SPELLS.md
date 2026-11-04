# 누적523 NPC 기술 연결

기준 main은 `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`이다. PR218(508 전투/원본 동작/VFX)과 PR230(523 포탈/출현 정의)은 수정·병합하지 않았다. 이 변경은 선택형 523 기술 그래프와 호스트 전투 어댑터, 실제 Main의 기술/지역 상태 UI를 추가한다.

## 원본과 비공개 팩

세 Library 입력을 이 소비 환경에 정식 materialize하고 Library xattrs·바이트·SHA-256·ZIP CRC를 확인했다. 추가 Drive ZIP은 연결 계정의 정식 파일 조회·다운로드로 가져와 바이트·SHA·CRC와 내부 989개 원본 registry를 대조했다.

| 입력 | 바이트 | SHA-256 |
|---|---:|---|
| 전체523 Content | 25,031,173 | `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832` |
| 보스 심층 보고서 | 67,318 | `4416cd46675f5d4984c13e6a0b9a8d1df8cba4b8fa2cae6ef4c89a48e6422e97` |
| 맵 NPC 버프 보고서 | 172,953 | `1b807fd288ff75ad473d92886d627798ca8148467e0f8d1b3caad3a61ec8d332` |
| Drive SP2 989개 후속 전달 | 76,907,660 | `b6f665d03e84e7cd01b3dd15b60d94091b3ff762cdc58fcfd820c724aa622182` |

컴파일러는 두 보고서의 선택 원문을 전체 Content의 **1-based 행 위치·원문 동등성·테이블 SHA/CRC/크기/행 수**와 대조한다. 작은 BuffGroup/ElementalType 정의는 같은 SHA 고정 원본에서 직접 읽는다. 원문 행을 공개 Git에 넣지 않는다.

- 보고서 보스 15종 / 공격 270행 / 주문 126개와 맵 NpcBuff 183개를 보존한다. 현재 main의 정확한 커츠 호스트 바인딩 60303 그래프를 추가해 최종 팩은 NPC 16종 / 공격 288행 / 주문 134개 / 버프 208개 / Invoke 17개다.
- 보고서 15종과 현재 main의 14개 호스트 바인딩 교집합은 0이다. 그래서 기존 커츠 바인딩 60303의 블레이즈 스워드 43423을 전체523에서 추가 확인했다. 이름 조인·새 배치·구형 스킨의 원본 actor 승격은 없다. 기존 선택형 원본 몬스터 픽셀 팩이 설치되어 정확한 actor가 생성될 때 연결하며, 그 팩이 없으면 legacy 객체를 보존한다.
- 팩은 6,894행의 선택 그래프와 공식 enum/그룹 정의를 포함한다. 전체 1,065표 또는 원본 AI 전체 복원이 아니다.
- `npc_spells.json`: 1,453,711B, SHA `2d43c3da5e26afc917cb73e599181eb0c57d7982cee13e496576cd6d9bda808b`.
- `manifest.json` SHA: `ca260fc0481076fd9de0327cbb4b24df45d75d47d16b4fc6578713a44aff4a64`.
- 비공개 Library ZIP: `libfile_17daaf1ce5e08191839aff95e8fd002d`, 119,650B (Library version 1), SHA `bc34770cdd2a6821410df2949dec232f0c4abb266146aef197dc8d7701cb1712`.

## 게임 연결과 사용

비공개 ZIP의 두 파일을 Godot 사용자 데이터 디렉터리의 `source_npc523/`에 풀면 다음 실행부터 고정 manifest SHA를 검사하고 **보스 기술** 버튼을 표시한다. 버튼에서 보스·공격·간접 후속 기술과 **지역 NPC 상태**를 조회한다. UI의 전투 적용 체크는 현재 세션에만 적용되며 기존 저장 형식은 확장하지 않는다.

별도 경로를 사용할 때:

```sh
godot --path . -- \
  --patch523-npc-catalog=/private/pack/manifest.json \
  --patch523-npc-sha256=ca260fc0481076fd9de0327cbb4b24df45d75d47d16b4fc6578713a44aff4a64
```

`--patch523-host-combat`은 UI 체크와 같은 명시적 시작 옵션이다. 팩이 없거나 SHA·크기·경로·스키마가 다르면 이 기능을 활성화하지 않는다. 팩의 세션 중 자동 갱신은 없다.

- 원본 NPC ID와 Sprite가 일치하는 실제 원본 actor만 연결한다. 이름·구형 NPC ID·비슷한 외형으로 조인하지 않는다. TestNPC는 실행에서 제외하되 원문은 UI에 남긴다.
- 호스트 순환 선택은 소유 NPC의 원본 공격 그래프 시작점만 사용한다. 성공적으로 처리한 타격 시도 뒤 같은 NPC의 정확한 `NextAttack`만 큐에 넣고 기존 회복·공격 대기시간 뒤 실제 Monster AI가 실행한다. 명중 성공을 원본 후속 발동 조건으로 주장하지 않는다. 명시한 시작 ID가 없으면 다른 공격으로 바꾸지 않는다. 누락·다른 NPC·지원 불가·순환 연결은 중단하며 건너뛰지 않는다.
- 기존 시전 시간·픽셀 사거리·명중/치명/저항/방어/반격/사망 경로를 사용한다. 이를 원본 Prob, FixedDelayTime, CastDelay, 셀 단위 또는 AI 페이즈의 복원으로 부르지 않는다. `NpcClass.AI`는 정수 원문만 보존한다. 제공 Content에는 이 값에 대응하는 NPC AI 정의를 확인하지 못했다.
- 기본 공격은 NpcAttack의 DiceBonus/Count/Spots를 기존 물리 채널로, Self/SingleObject Enemy 직접 공격은 SpellBonus의 기본값과 dice를 기존 마법 채널로 한 번만 보낸다. Self Enemy는 기존 호스트 도달 범위에서 현재 플레이어만 처리하며 원본 반경·전체 광역 피격 복원이 아니다. 취소·중복 release·life 재사용·motion 교체·대상/맵 세대 변경·복귀·침묵 상태를 검사한다. 원본 기술에 관계없는 기존 actor 상태 부여값은 이 타격 동안 억제한 뒤 같은 life에 복원한다.
- 상태는 확인 가능한 CannotUseItem/CannotMove와 MeleeHit/ArmorClassBonus의 호스트 연결만 적용한다. 지속시간은 Seconds가 명시된 값을 사용한다. CannotCastSpell을 전체 플레이어 스킬 침묵으로 확대하지 않는다. 치유 감소 백만분율과 반사 최종식은 원문을 보존하며 계산하지 않는다.
- 아이템 제한은 가방/퀵슬롯/직접 HP 물약, 일반 소모품 서비스, 카드 팩, 시간제 아이템, 아인 소모품, 강화/축복 시도에서 소비 전에 검사한다. 이동 제한은 기존 이동 잠금이나 상태 타이머를 덮어쓰지 않는다. 디지즈의 호스트 AC는 `기존 AC - ArmorClassBonus`로 연결한다.
- 무조건·단위 TrueFalse가 확인된 `IgnoreCannotCastSpell`만 해당 시전자의 호스트 침묵을 통과한다. `IgnoreCannotCastSkill`이나 조건부 보너스를 대신 적용하지 않는다. 대상의 시전 제한 상태와는 별개다.
- 다른 비중첩 그룹 버프가 이미 있으면 새로운 변형을 거절한다. 미확인 숫자 우선순위를 추정하지 않는다. 만료·사망·맵 전환·기능 끄기는 임시 상태와 소유한 시전을 정리한다.
- 지원 불가 회복/장판/소환 기술을 일반 피해나 기존 창작 특수 공격으로 바꾸지 않는다. 기본 모드에서 기존 전투는 유지된다. 적용 모드의 대상 actor는 지원 기술이 없으면 공격을 보류한다.

정적 지원 분류는 주문 공격 성분 108행, 기본 공격 성분 37행, 일부 상태 성분 9행이다. TestNPC·실제 출현·원본 아트·서버 활성 조건을 통과한 플레이 가능 기술 수가 아니다. 나머지 134행은 조건/자원/주문 종류/수식 등으로 실행 보류한다. 전체 선택 그래프의 NextAttack 연결 66개 중 커츠 209083→209073의 대상은 제공된 전체 NpcAttack 23,501행에도 없다. 209093→208983은 실제 Main/Monster/ActorMotion 경로로 검증했다.

## 후속·환경·시각효과의 경계

`NextSpellClassID`는 ApplicationType/Target을 보존하여 재귀 그래프에서 조회한다. 전조88822→88832와 3000ms를 표시하지만, 트리거 기준점·취소·대상·TargetClass2712와 장판 기하가 없으므로 자동 후속 시전은 하지 않는다. NpcSummonSet 본체나 NPC0을 만들어 넣지 않는다.

배리어 생성 Spell, 상태 StatusEffectAttr, 방어 Invoke의 효과를 별개로 유지한다. AttackType42의 BySpellAttack 분기와 그룹82, 빈 BuffBonus의 메타데이터도 보존한다. EffectSprite2232와 StatusEffect2232를 같은 네임스페이스로 합치지 않는다.

`--patch523-effect-manifest=/private/manifest.json --patch523-effect-manifest-sha256=<64자리 SHA>`를 주면 크기와 SHA를 먼저 확인하고 기존 원본 overlay 렌더러에 **523의 정확한 Sprite 필드**를 전달한다. 숫자가 같은 508 주문의 효과 매핑을 대신 사용하지 않는다. nonzero EffectSpriteActionNo, 미설치 효과, 예산 초과는 보류하며 아이콘·링·합성 이펙트로 대체하지 않는다. 설치 가능한 외부 overlay의 설정 성공도 원본523 픽셀·색상·알파·FPS·시전 동작 동등성 승인을 뜻하지 않는다. 각 필드의 미설치/동작 미해석/핀 실패 상태를 진단 API에 남긴다.

정식 인증으로 전달받은 추가 비공개 SP2 989개 ZIP은 실제 원본 75,664,378B와 서로 다른 filename ID 973개를 포함한다. 현재 그래프의 Spell/Invoke 효과 Sprite 참조 70종과 직접 ID 교집합은 0이며, 보스 보고서가 구체적으로 선언한 물리 SP2 멤버 11개도 이 ZIP에 없다. NPC 몸체 Sprite와 직접 ID 교집합도 없다. 이는 이 전달본의 직접 파일명·선언 멤버 대조 결과이며, 전체 클라이언트 부재나 완전한 SPR alias 전개 결과로 확대하지 않는다.

검증된 표준 PNG 2개는 `normal_cloud.png`와 `Map_Icon_Forge.png`이며 보스 효과가 아니다. 포함된 bbox/EOF 후보 디코더 결과도 픽셀 순서·색상·알파·FPS·액션 승인으로 승격하지 않았다. 따라서 이번 산출물의 원본 보스 VFX 픽셀/정확한 시전 동작/전체 boss 아트 상태는 **미전달**이다. 감사 도구는 아래와 같이 원본을 실행하지 않고 registry/SHA/CRC와 참조를 대조한다.

```sh
python3 tools/monsters/audit_patch523_boss_payload.py \
  --payload /private/boss_followup_sp2_989.zip \
  --content /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  --catalog /private/npc523/npc_spells.json \
  --crosscheck /private/RESOURCE_DECLARATION_CROSSCHECK.json \
  --output /private/boss-payload-audit.json
```

지역 버프 183개는 Territory 경계를 보존해 UI/API로 조회한다. 실제 위치 변환·입퇴장 수명주기·반사식이 확정되지 않아 자동 부여하지 않는다. 오림·시련 스테이지 생성/보상, 일반 출현·자동 포탈, 드랍 확률·수량·사용자 각성 비용은 변경하지 않았다.

## 재현과 검증

```sh
python3 tools/monsters/build_patch523_npc_catalog.py \
  --source-zip /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  --boss-report /private/TWILIGHT_BOSS523_spell_buff_effect_chains_20261104.zip \
  --npc-report /private/TWILIGHT_NPC523_map_buffs_stage_boundaries_20261104.zip \
  --host-npc-id 60303 --output /private/npc523
python3 tools/monsters/test_patch523_npc_catalog.py
godot --headless --path . --script res://tests/patch523_npc_combat_test.gd
godot --headless --path . --script res://tools/monsters/patch523_npc_source_contract.gd -- \
  --patch523-npc-catalog=/private/npc523/manifest.json \
  --patch523-npc-sha256=ca260fc0481076fd9de0327cbb4b24df45d75d47d16b4fc6578713a44aff4a64
```

합성 46검사는 lifecycle/중복/취소/그룹/원본 공격 그래프/채널/침묵/미해석 기능 거절 회귀이며 원본 아트 증명이 아니다. 별도 실제 원문 25검사는 그래프/네임스페이스/시간 단위/맵 경계/시전자 플래그를 검사한다. 실제 Main/Monster/ActorMotion·아이템·UI 경로는 `tools/monsters/patch523_npc_main_contract.gd`로 별도 검사한다. `--patch523-screen-dir`은 실제 렌더러에서만 사용한다.

필수 리소스 검사는 723시트/41,442프레임/233,420,026B의 실제 추적·SHA 일치를 확인했다. `--source-dir`의 구형 6 ZIP 검사에는 `a1.zip`이 없어 실패한다. 이번 세 입력의 가용성·바이트 검증과 별개이며 원본 픽셀 전달 완료로 바꾸지 않았다. 원격 CI는 사용자 지시에 따라 수동 실행·재실행하지 않으며 작업 커밋에 `[skip ci]`를 사용한다.


초기 커밋 로컬 검증: Python 컴파일러4검사, Godot 4.7.2 합성 전투20검사, 실제 원문20검사, 실제 Main/Monster/ActorMotion·소모품·UI 이벤트/렌더23검사, 현재 Main 세이브 보존32검사와 identical-payload/deferred-save 게이트를 통과했다. 1280×720 화면2장과 480×800 검증용 뷰포트1장을 캡처했다. 작은 뷰포트는 테스트의 Window content_scale_size만 변경했으며 생산 프로젝트 설정/Android 실기기 승인과 별개다. 기존 핵심 staging의 늦은 생성 경로에서 누락된 현재 맵 portrait PNG 1개는 동일 main Git blob/SHA로 보충해 렌더 검사했다. 필수 워크플로·테스트 임계값은 변경하지 않았다.

후속 커밋 검증: 합성 전투46 / 실제 원문25 / 실제 Main·Monster AI 연속 타격·아이템·UI·OpenGL 렌더28 / 현재 Main 세이브32검사 통과. SP2 989개 registry의 모든 바이트·SHA·CRC와 PNG2개 chunk CRC를 확인했다. Main 검사는 현재 source field/renderer와 bootstrap 정상 상태를 먼저 확인하며, 고정 RNG와 테스트 전용 임시 최대 HP로 두 타격을 검사한 뒤 원래 값을 복구한다. 숨긴 정확한 ID 실행 fixture이며 자연 출현·보스 몸체 픽셀 승인과 별개다.

실제 Main 검사는 검증된 현재 맵 팩을 지정한 생산 코드 staging에서 실행한다. 아래의 `--patch523-screen-dir`은 OpenGL 렌더 실행에서만 추가한다.

```sh
TWILIGHT_SOURCE_MAP_PACK=/private/verified-current-map \
  godot --audio-driver Dummy --path /private/current-code-stage \
  --script res://tools/monsters/patch523_npc_main_contract.gd -- \
  --patch523-npc-catalog=/private/npc523/manifest.json \
  --patch523-npc-sha256=ca260fc0481076fd9de0327cbb4b24df45d75d47d16b4fc6578713a44aff4a64 \
  --patch523-screen-dir=/private/screens
```
