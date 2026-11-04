# 누적523 NPC 기술 연결

기준 main은 `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`이다. PR218(508 전투/원본 동작/VFX)과 PR230(523 포탈/출현 정의)은 수정·병합하지 않았다. 이 변경은 선택형 523 기술 그래프와 호스트 전투 어댑터, 실제 Main의 기술/지역 상태 UI를 추가한다.

## 원본과 비공개 팩

세 Library 입력을 이 소비 환경에 정식 materialize하고 Library xattrs·바이트·SHA-256·ZIP CRC를 확인했다.

| 입력 | 바이트 | SHA-256 |
|---|---:|---|
| 전체523 Content | 25,031,173 | `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832` |
| 보스 심층 보고서 | 67,318 | `4416cd46675f5d4984c13e6a0b9a8d1df8cba4b8fa2cae6ef4c89a48e6422e97` |
| 맵 NPC 버프 보고서 | 172,953 | `1b807fd288ff75ad473d92886d627798ca8148467e0f8d1b3caad3a61ec8d332` |

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
- 명시적 호스트 순환 선택과 기존 시전 시간·픽셀 사거리·명중/치명/저항/방어/반격/사망 경로를 사용한다. 이를 원본 Prob, FixedDelayTime, CastDelay, 셀 단위 또는 AI 페이즈의 복원으로 부르지 않는다.
- 단일 적 대상의 직접 공격은 명시된 기본값과 dice를 기존 피해 resolver로 한 번만 보낸다. 취소·중복 release·life 재사용·motion 교체·대상/맵 세대 변경을 검사한다. 원본 기술에 관계없는 기존 actor 상태 부여값은 이 타격 동안 억제한 뒤 같은 life에 복원한다.
- 상태는 확인 가능한 CannotUseItem/CannotMove와 MeleeHit/ArmorClassBonus의 호스트 연결만 적용한다. 지속시간은 Seconds가 명시된 값을 사용한다. CannotCastSpell을 전체 플레이어 스킬 침묵으로 확대하지 않는다. 치유 감소 백만분율과 반사 최종식은 원문을 보존하며 계산하지 않는다.
- 아이템 제한은 가방/퀵슬롯/직접 HP 물약, 일반 소모품 서비스, 카드 팩, 시간제 아이템, 아인 소모품, 강화/축복 시도에서 소비 전에 검사한다. 이동 제한은 기존 이동 잠금이나 상태 타이머를 덮어쓰지 않는다. 디지즈의 호스트 AC는 `기존 AC - ArmorClassBonus`로 연결한다.
- 다른 비중첩 그룹 버프가 이미 있으면 새로운 변형을 거절한다. 미확인 숫자 우선순위를 추정하지 않는다. 만료·사망·맵 전환·기능 끄기는 임시 상태와 소유한 시전을 정리한다.
- 지원 불가 회복/장판/소환 기술을 일반 피해나 기존 창작 특수 공격으로 바꾸지 않는다. 기본 모드에서 기존 전투는 유지된다. 적용 모드의 대상 actor는 지원 기술이 없으면 공격을 보류한다.

정적 지원 분류는 공격 성분 91행, 상태 성분 9행이다. TestNPC·실제 출현·원본 아트·서버 활성 조건을 통과한 플레이 가능 기술 수가 아니다. 나머지 공격 188행에는 기존 기본 공격 37행도 포함된다.

## 후속·환경·시각효과의 경계

`NextSpellClassID`는 ApplicationType/Target을 보존하여 재귀 그래프에서 조회한다. 전조88822→88832와 3000ms를 표시하지만, 트리거 기준점·취소·대상·TargetClass2712와 장판 기하가 없으므로 자동 후속 시전은 하지 않는다. NpcSummonSet 본체나 NPC0을 만들어 넣지 않는다.

배리어 생성 Spell, 상태 StatusEffectAttr, 방어 Invoke의 효과를 별개로 유지한다. AttackType42의 BySpellAttack 분기와 그룹82, 빈 BuffBonus의 메타데이터도 보존한다. EffectSprite2232와 StatusEffect2232를 같은 네임스페이스로 합치지 않는다.

`--patch523-effect-manifest=/private/manifest.json`을 주면 기존 원본 overlay 렌더러에 **523의 정확한 Sprite 필드**를 전달한다. 숫자가 같은 508 주문의 효과 매핑을 대신 사용하지 않는다. nonzero EffectSpriteActionNo, 미설치 효과, 예산 초과는 보류하며 아이콘·링·합성 이펙트로 대체하지 않는다. 현재 제공된 세 ZIP에는 SP2/DAT 픽셀 payload가 없으므로 이번 산출물의 원본 VFX 픽셀/정확한 시전 동작/전체 boss 아트 상태는 **미전달**이다.

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

합성 20검사는 lifecycle/중복/취소/그룹/미해석 기능 거절 회귀이며 원본 아트 증명이 아니다. 별도 실제 원문 20검사는 그래프/네임스페이스/시간 단위/맵 경계를 검사한다. 실제 Main/Monster/ActorMotion·아이템·UI 경로는 `tools/monsters/patch523_npc_main_contract.gd`로 별도 검사한다. `--patch523-screen-dir`은 실제 렌더러에서만 사용한다.

필수 리소스 검사는 723시트/41,442프레임/233,420,026B의 실제 추적·SHA 일치를 확인했다. `--source-dir`의 구형 6 ZIP 검사에는 `a1.zip`이 없어 실패한다. 이번 세 입력의 가용성·바이트 검증과 별개이며 원본 픽셀 전달 완료로 바꾸지 않았다. 원격 CI는 사용자 지시에 따라 수동 실행·재실행하지 않으며 작업 커밋에 `[skip ci]`를 사용한다.


최종 로컬 검증: Python 컴파일러4검사, Godot 4.7.2 합성 전투20검사, 실제 원문20검사, 실제 Main/Monster/ActorMotion·소모품·UI 이벤트/렌더23검사, 현재 Main 세이브 보존32검사와 identical-payload/deferred-save 게이트를 통과했다. 1280×720 화면2장과 480×800 검증용 뷰포트1장을 캡처했다. 작은 뷰포트는 테스트의 Window content_scale_size만 변경했으며 생산 프로젝트 설정/Android 실기기 승인과 별개다. 기존 핵심 staging의 늦은 생성 경로에서 누락된 현재 맵 portrait PNG 1개는 동일 main Git blob/SHA로 보충해 렌더 검사했다. 필수 워크플로·테스트 임계값은 변경하지 않았다.
