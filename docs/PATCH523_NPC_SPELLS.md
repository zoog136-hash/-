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

검증된 표준 PNG 2개는 `normal_cloud.png`와 `Map_Icon_Forge.png`이며 보스 효과가 아니다. 포함된 bbox/EOF 후보 디코더 결과도 픽셀 순서·색상·알파·FPS·액션 승인으로 승격하지 않았다. 이 직접 ID 대조 시점에는 원본 보스 VFX 픽셀/정확한 시전 동작/전체 boss 아트가 **미전달**이었다. 후속 SPR/69 DAT 소비와 후보 표시 구현은 아래 최신 절에 기록한다. 감사 도구는 아래와 같이 원본을 실행하지 않고 registry/SHA/CRC와 참조를 대조한다.

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

## v1 기록: 전체 선택 SPR 추적과 원본 유래 효과의 자체 재생

추가 정식 Library materialize에서 현행 SPR 원문30개와 `originalSprite69`의 네 체크포인트를 실제 수신했다. xattrs·ZIP CRC·각 DAT의 현행523 manifest 증거/바이트/SHA를 확인했다. 최신 manifest가 그대로 유지한508 바이트를 사용했으며 구형 소스1·2나 PC 이미지로 교체하지 않았다.

| 입력 | 바이트 | SHA256 |
|---|---:|---|
| SPR graph156 선언 팩 | 84,488,816 | `311b22774e923a48640e677d15c5ebcc0bc4035487debea435806a0747d0dae8` |
| currentSprite originals18 checkpoint01 | 190,728,359 | `7dfd47a9cb0f1073437933febee72a26a27159c868220b51b476226d4e9632ae` |
| originalSprite69 checkpoint02 | 189,340,512 | `2280a66e69fca0f4853a6b460a9a2c315f3ebc86d46efaf83582297d6fa1091c` |
| originalSprite69 checkpoint03 | 190,535,985 | `3e47d38afadc8b8c55d7528acaba5148ec4c101151fa16bc7202f66e1b23da71` |
| originalSprite69 checkpoint04 | 185,164,962 | `4d6045fc087a8b2e1794776635ac84a6729423e1182a7627fe6bff17ae5a7770` |

효과70종과 보고서11멤버의 선언을 합친 시작점73개에서 **선언170개·명시 참조97개**를 끝까지 따라갔다. 선택 범위에서 중복/누락 선언이나 header alias는 없었다. 독립 원문 스캔으로 alias/shadow/clothes/clothe 구문과 전체 선택 참조가 일치함을 확인했다. 앞선 직접ID 교집합0을 alias 부재의 근거로 사용하지 않았다. 69개 현행 DAT에서 이 그래프의 SP2 **46개**를 새로 찾았다. 122개 미수신 후보의 정확한 컨테이너/멤버/크기/CRC는 비공개 감사 팩에 별도로 기록하며, 실제 수신하지 않은 멤버의 SHA를 만들지 않는다. 보고서11개는 이69 DAT에도 없다.

현재 실행 팩은 효과17종 / root+child 트랙34개 / PNG526개(9,811,262B)다. 단일 계층5종은218·2177·2232·11736·11737이고 나머지12종은 모든 필요한 child 파일을 확보한 자체 합성이다. 정확한 액션0·flag0만 소비한다. 누락 child, 범위 밖 프레임, 미지원 액션/방향은 전체 효과를 보류하며 부분 body나 다른 효과로 대체하지 않는다.7361은 전체 decoded texture가64MiB를 초과해 제외했다. 런타임도 효과 전체/동시 표시64MiB와16노드 예산을 검사한다.

원본SP2를 commandwise 모델로 읽고, 모든 출력 프레임의 픽셀 범위가 해당 M 원문 half-open extent와 정확히 맞는지 검사했다. 기존 grouped-row 결과를 재활용하지 않았다. RGB565 변환·내부 픽셀 순서·알파·blend·층 동기화는 실제 M 런타임 동등성 승인이 아니다. [공개 PakViewer SP2 구현](https://github.com/tony1223/PakViewer/blob/fbad69239e3e3c12ec18dfc7722bed284be093cc/src/Lin.Helper.Core/Sprite/L1SP2.cs)을 확인했지만, PC 도구의 해석보다 제공된 M 원문/extent 반례 근거를 우선했다. 기본24FPS는 기존 TWILIGHT compatibility policy를 참고한 **자체 추정값**이며 M의 확정 기본값으로 기록하지 않는다.

UI는 `원본 효과 표시 · 추정 재생`과 `자체 계층 합성 · 동시 시작/1회 재생`을 각각 선택한다. 둘 다 기본은 꺼짐이다. 명시 SPR FPS가 있으면 우선하고, 없으면 설정 FPS(1~120)를 사용한다. 투명도·크기·일반/가산 합성을 조절할 수 있다. child에 자체 액션0이 있으면 우선하고, 없으면 부모의 정확한 프레임 인덱스를 공유하는 **자체 동작**으로 분리했다. clamp나 임의 프레임 치환은 하지 않는다. UI 미리보기는 패널을 닫고 실제 월드에서 재생한다. 전투에서는 정확한 Spell Sprite 필드의 기존 발동 경로에 붙으며, 데스 포션47873의 아이템 제한과2232 효과를 실제 Monster/ActorMotion에서 확인했다.

시각 설정은 `user://patch523_effect_settings.cfg`에 따로 저장한다. 성장·장비·아이템·재화/중복 지급·기존 게임 세이브 형식은 바꾸지 않는다. 원본 입력/원문 값은 보존한다. 효과 프레임이 피해·전투 시계·명중 판정을 구동하지 않는다. M 엔진/APK/XAPK 탐색은 사용자 지시에 따라 진행하지 않는다.

런타임 파일은 비공개 팩을 `user://source_npc523_effects/`에 풀거나 아래 경로/핀을 지정한다. 원본 이미지는 Git에 추가하지 않았다.

```sh
--patch523-effect-manifest=/private/effects/manifest.json \
--patch523-effect-manifest-sha256=f9e9ce484e45e83fa0cb98a60a3778dc0f482d59968bda4c7ac6a8a602b79f2d
```

컴파일은 `tools/monsters/build_patch523_effect_pack.py --spr-zip <SPR graph156.zip> --originals <4개 checkpoint 폴더> --catalog <npc_spells.json> --crosscheck <RESOURCE_DECLARATION_CROSSCHECK.json> --output <비공개 출력>`으로 재현한다. Python Brotli1.1.0/Pillow를 사용한다. Python4검사는 commandwise 행 이동/팔레트0/음수 floor 투영/EOF·extent 거절을 검사한다. 실제 팩114검사, Main 전투·UI·설정 재로딩·OpenGL37검사, 기존 전투46검사, 현재 Main 세이브32검사와 필수723시트 SHA 검사가 통과했다. 원본 동등성/전체 아트/Android 승인으로 확대하지 않는다.

비공개 후보 효과 ZIP은15,905,429B, SHA256 `3fb94d16030860066f4099c762b4eb30b5326a88e6bd60e44adf0c3eb06e3eec`이다. manifest pin은 위와 같다. 선택 PNG526개, 원문 SP246개, 선택 SPR 감사/미수신 후보 목록을 포함한다. 별도 빈 디렉터리에 복원해 모든 PNG SHA/크기/ZIP CRC와114검사를 다시 확인했다. 자연 출현/새 보스 배치나 원본 몸체 복원을 추가한 것은 아니며, 원본 actor 바인딩과 출현을 다루는 다른 PR의 범위는 유지한다.

## v1 기록: 적용팩과 원본 백업의 구분

코드 기준은 `d3f603b0c59d48064a6e5297c603e53c7b30d549`다. 게임이 소비하는 최신 효과 ZIP은 `TWILIGHT_PATCH523_BOSS_EFFECTS_RUNTIME_v1_d3f603b0_20261104.zip`이며9,871,450B / SHA256 `2165b10159a4c3ab156666e7281eca5a5ccb5a572ac2fa2c4469e7def21f22bf`다. manifest와PNG526개만 포함하며 원본 백업/감사/캡처를 설치하지 않는다. 효과 manifest pin은 `f9e9ce484e45e83fa0cb98a60a3778dc0f482d59968bda4c7ac6a8a602b79f2d`로 동일하다.

함께 필요한 기술 데이터는 `TWILIGHT_PATCH523_NPC_SPELL_RUNTIME_PRIVATE_20261104.zip`,119,650B / SHA256 `bc34770cdd2a6821410df2949dec232f0c4abb266146aef197dc8d7701cb1712`다. 이 데이터의 Library ID/version은 앞 절과 같은 version1이며 효과 최신 ZIP은 Drive에만 보관했다.

이전15,905,429B 혼합 팩은 `TWILIGHT_PATCH523_BOSS_EFFECTS_BACKUP_v1_d3f603b0_20261104.zip`으로 구분해 원본 백업 폴더로 이동했다. 바이트/SHA는 `3fb94d16030860066f4099c762b4eb30b5326a88e6bd60e44adf0c3eb06e3eec`로 동일하고, 선택 원문SP246개를 보존하는 혼합 백업이다. 전체69 DAT 백업이나 최신 lean 적용 ZIP으로 부르지 않는다. 원본69 DAT의 기존 Drive8개 분권과 Library4개 원본은 중복 업로드하거나 변경하지 않았다.

기존 비공유 프로젝트 Drive 아래 PR250의 실제 적용팩/원본 백업 폴더를 따로 사용한다. Drive 보관은 게임 자동 다운로드/설치가 아니다. 연결 계정의 정식 다운로드 후 ZIP 크기·SHA·CRC를 확인하고 기술 데이터의 두 파일을 `user://source_npc523/`, 효과 manifest/frames를 `user://source_npc523_effects/`에 설치해야 한다. 기존 게임 세이브/설정 파일을 덮어쓰지 않는다. 시작 후 보스 기술 UI에서 전투 적용/추정 표시/자체 계층 합성을 선택한다. 별도 경로를 쓸 때는 앞 절의 manifest 경로와 SHA 인자를 사용한다.

새 소비 폴더에서 최신 lean ZIP을 정식 Drive 다운로드했고, NPC 데이터는 현재 Drive 파일과 같은 기존 정식 다운로드 검증 바이트를 재사용했다. 두 ZIP과 모든 PNG SHA/크기/CRC를 검사해 빈 사용자 폴더에 설치했다. 팩 경로 인자 없이 기본 user 경로에서 효과114검사와 실제 Main/UI31검사를 통과했다. 이 회차는 headless 설치/로드 검증이며, 앞선 동일PNG의 OpenGL37검사와 구분한다. 작업환경의 PR250 코드 Main 실행 확인이며 사용자 PC 설치·main 병합·전체 원본 동등성 승인은 아니다. 이번 저장 구분 작업에서는 새 감사/보고서/캡처를 외부 업로드하지 않았다.

## 최신 v2: 조건부 후속 시전·지속 지면·자체 소환

`patch523_boss_compat.gd`는 원문에서 빠진 실행 계약만 별도 TWILIGHT 정책으로 보충한다. 보스 기술 UI에서 전투 적용과 `TWILIGHT 자체 보스 규칙 설정 → 자체 후속·지면·소환 켜기`를 선택한다. 기본은 꺼짐이며88822/88832의 확정 `TestSpell=true`는 지우지 않는다. 이 두 기술은 `원문 TestSpell을 자체 검증에 허용`까지 별도로 켜야 실행한다. 실제 원본 NPC ID/Sprite·life·generation·target·중단 검사는 그대로 적용한다. 자연 출현 위치나 미확보 원본 보스 몸체를 새로 만드는 기능은 아니다.

| 항목 | 원문 확인값 | TWILIGHT 자체 정책 |
|---|---|---|
| 후속 시전 |88822 →88832, NextSpellDelay3000ms, BonusApplicationType1의 네임스페이스는 SpellClass | 시전 방출 후 예약 또는 기존 호스트 명중 판정 통과 후 예약. 원문1을 ‘명중 성공’으로 바꾸지 않음. 원문 지연 이후 기존 회복·공격 시계와 시야/거리/침묵 권한을 모두 통과해야 시전 |
| 지면 피해 |88832의400000+10d10,100ms 간격, SequenceSpellPlate1=true | 기본 반경96px·정사각형·3초·반복. UI로 반경16~320px, 원/정사각형, 수명0.1~30초, 단일/반복, 같은 시전자 교체/중첩(전체8개 상한)을 선택 |
| 소환 |48013/48023의 category19, NpcSummonSet2053/2063, 확인된 소모량0 | 기존 FieldPopulation의 일반 지역 몬스터를 자체 소환물로 사용. 기본2개·20초, UI로1~4개·1~120초. 기존 소유자 상한4개와 모듈 전체8개 상한 적용. 원작 진주 구성·외형과 같다고 주장하지 않음 |

최신523 전체 Content와 기존 분석 보고서에는 해당 NpcSummonSet의 실제 멤버 테이블·장판 기하/지속시간 계약이 없다. [공식 파푸리온 업데이트](https://lineagem.plaync.com/board/update/view?articleId=64e50cb8dcb9de6d1abff1f9), [공식 레이드 업데이트](https://lineagem.plaync.com/board/update/view?articleId=6a690338065bf16436e45e12)도 확인했으나 이 정확한 ID의 실행 계약을 확보하지 못했다. 위 자체 값의 수치 근거로 해당 공지를 사용하지 않았다. 기존 호스트 API의 소환 수·상한과 명시한 자체 정책을 사용한다. 공개 검색값이나 원문을 나중에 확인하면 추정값보다 우선한다.

예고 지점을 방출 시 고정하고 동일 기하로 화면 표시와 범위 판정을 한다. 표시는 `TWILIGHT 예고/지속효과`이며 자체 도형이다. 원본 이펙트가 없는 것을 다른 원작 이미지로 대체하지 않는다. 장판의 각100ms 피해는 기존 authoritative 피해 경로로 한 번만 전달한다. 중복 방출·사망·재입장·맵 변경·취소·시야 차단·generation 변경 시 남은 호출과 표시가 정리된다. 지연된 틱은 프레임당32회로 제한한다.

소환물은 기존 `summoned=true` 보상 차단 경로를 사용한다. 경험치·아이템·재화·성장 보상을 지급하지 않으며 중복 사망 신호도 지급으로 이어지지 않는다. 설정은 `user://patch523_boss_rules.cfg`에 따로 저장한다. 예약 후속·장판·소환물은 임시 전투 상태이며 기존 성장 세이브에 넣지 않는다. 정상 로드는 임시 상태를 정리하고, 누락 맵 팩으로 거절된 로드는 기존 임시 상태/세이브 바이트를 보존한다.

### v2 원본 유래 효과와 설치

동일하게 확보한 최신 SPR30개·DAT69개·선택 SP246개에서 flag1의 실제 저장 그룹8개를 모두 컴파일하고, 단일 명시 액션3을0으로 바꾸지 않고 보존했다. 기존17종에4073·4183·7501·11738·11742를 더해 **22종·root/child 트랙42개·PNG868개(13,808,736B)**다. 각 출력은 원문 half-open extent와 대조한다. 원본 없는 방향의 mirroring/다른 프레임 치환은 하지 않는다.

UI에서 원문 그룹0~7과 호스트 방향 연동을 조절하며, 물리 방향의 대응은 추정이라고 표시한다. 명시 SpriteActionNo는 그대로 지킨다. 액션 미지정 필드의 단일 비영 액션 자동 선택은 별도 기본 꺼짐 설정이다. 수동 미리보기는 원문4183의 실제 액션3을 명시 선택할 수 있다. Invoke에서만 참조한 효과도 원문 선택기에 표시하지만, 미리보기를 원작 전투 발동 검증으로 취급하지 않는다. RGB/알파/기본FPS/합성/child 동기화의 원작 동등성은 여전히 미확정이다.

최신 게임 적용 ZIP은 `TWILIGHT_PATCH523_BOSS_EFFECTS_RUNTIME_v2_20261104.zip`, **13,902,126B**, SHA256 `c4cb57c88b71f2cb36a354ba514994477fee5cd82bfafe550bad01d503aa837d`다. manifest와PNG868개만 포함하며, 기존 비공유 Drive의 실제 적용 폴더에 보관한다. 새 원문/감사/보고서/캡처는 업로드하지 않았다. v1 혼합 원본 백업15,905,429B와 전체69 DAT의 기존 보관 사본은 변경하지 않았다. 기술 데이터119,650B도 같은 v1을 사용한다.

```sh
--patch523-effect-manifest=/private/effects-v2/manifest.json \
--patch523-effect-manifest-sha256=507d5e16fe860ad38960adabc2673693fb9479adff3e4b5294561c78c73c54cf
```

정식 Drive 재다운로드로 최신 ZIP의 바이트·SHA·CRC를 확인한 뒤 빈 소비 폴더에 설치했다. NPC 데이터는 기존 정식 다운로드의 동일 SHA 검증 바이트를 재사용했다. 모든 방향/child를 포함한 PNG868개의 크기·SHA를 다시 대조했다. 기본 `user://source_npc523_effects/` 및 `user://source_npc523/` 경로로도 읽는다. 기존 v1 효과 manifest pin 역시 계속 수용한다. Drive 저장이 사용자 PC의 자동 설치를 뜻하지는 않는다.

검증 도구는 `tools/monsters/patch523_boss_compat_contract.gd`, `patch523_boss_compat_main_contract.gd`, `patch523_effects_contract.gd`, 기존 `patch523_npc_main_contract.gd`다. 별도 XDG 사용자 디렉터리와 검증된 현재 맵 팩을 사용한다. 실제 Main 검사는 원본 몸체 대신 숨긴 정확한 ID 실행 fixture를 사용한다. 자체 규칙31검사, 실제 효과157검사/기존v1의114검사, 실제 Main 전투·효과/UI OpenGL43검사, 새 설치의 실제 Main 후속·장판·소환 타격/보상·설정/UI/저장 OpenGL27검사, 기존 전투46/원문25/현재 Main 세이브32, Python codec4/catalog4 및 필수723시트 SHA 검사가 통과했다. 화면11장·로그·설치 영수증은 LOCAL_ONLY이며 신규 외부 업로드하지 않았다. 원격 CI의 수동 실행·재실행과 다른 PR/main 병합은 하지 않는다.

남은 입력은 정확한11개 원문 SP2 멤버와 아직 수신하지 못한 다른 효과 후보다. 원작 AI/NextSpell 조건/장판/소환 구성 동등성을 완료했다고 주장하지 않는다. M 엔진/APK/XAPK·투기장·지구라트 기능은 작업에서 제외한다. 보스 SpellClass가 기존 효과 이름을 참조하는 것은 해당 던전 기능을 구현한 것이 아니다.
