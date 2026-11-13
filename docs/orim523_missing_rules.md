# 오림의 흔적(OrimsTrail) 523 — 연결 범위와 표에 없는 규칙

기준: 원본 523 정의 ZIP(`source.zip`, sha256 `d5192c3c…4f1832`)의 `OrimsTrail*` 26개 표 +
`UIOrimsTrailCharacter`/`UIOrimsTrailStage` 2개 표(합 28개). 오프라인 1인 플레이.
코드: `scripts/orim523/orim523.gd`(표 모델), `scripts/orim523/orim523_run.gd`(진행 규칙),
`scripts/orim523/orim523_hud.gd`(필드 패널), `scripts/dungeons/dungeon_play_service.gd`(실행·저장),
`scripts/maps/current523_aden_play_controller.gd`(`enter_source_land`).

## 1인 콘텐츠 여부

- 오림의 흔적 10개 Land(48752~48842, AssetPath `13459/`~`13468/`)는 모두 `Land.IdealNumberOfPlayer = 1`.
  → **파티던전이 아니라 1인 콘텐츠**로 판단해 연결했다.
- UI 추가 팩의 `Mission_Popup_Party_Orim.csb`, `CutScene_Dungeon_Party_Orim_{Experiment,Followers,Trap}.csb`는
  별도의 "파티 오림" 던전이다. 사용자 결정(파티던전 제외)에 따라 **연결하지 않았다**.

## 표별 행 수와 연결 상태

| 표 | 행 | 연결 |
| --- | ---: | --- |
| OrimsTrailStage | 20 | 일반 10 + 하드 10. TeleportTerritoryID → Territories → Land로 **원본 지도 입장**, TimeLimit 420초 |
| UIOrimsTrailStage | 11 | StageIndex별 이름·이야기(0번 "테스트" 행은 Stage가 없어 미사용) |
| OrimsTrailCharacter | 6 | 영웅 HP(250~450)·시작 스킬 적용. 6명 모두 선택(히든 2명 제온·메이브도 처음부터 열림 · 사용자 결정) |
| UIOrimsTrailCharacter | 5 | 영웅 칭호·부제·이야기 표시 |
| OrimsTrailExperience | 198 | 일반 99 + 하드 99 레벨 누적 경험치 |
| OrimsTrailSpellGroup | 48 | 스킬 그룹 이름·설명 |
| OrimsTrailSpellClass | 288 | 48그룹 × Lv0~5, 유형(Attack/Utility/Synergy), IsHidden |
| OrimsTrailSpellType / SpellMaxCount | 3 / 3 | 유형별 보유 한도 Attack 5 · Utility 3 · Synergy 1 |
| OrimsTrailMultipleSpellCastGroupEntity | 729 | 스킬 레벨별 시전 묶음(Order) → 원본 SpellClass 373종 |
| OrimsTrailSynergySpellCombination(+Requirement) | 7 (+28) | 4개 그룹 보유 시 시너지 스킬 카드 제시 |
| OrimsTrailSynergySpellCombinationReward | 7 | 시너지별 최초 1회 원본 보상 상자 지급(사용자 결정) |
| OrimsTrailRerollCurrencyCost | 10 | 스킬 카드 다시 고르기 1~5회 10, 6~10회 20 |
| OrimsTrailBuff | 4 | 준비 강화 비용(아데나 20만/30만/50만, 다이아 20) + BuffClass 원본 보너스(이동·공격속도 25/25/10%) |
| OrimsTrailNpc / NpcType | 244 / 8 | 역할(Monster/MiddleBoss/Boss/HealingSphere/PointBox/OpalBox/Last*) + NpcClass HP·MP·AC·MR·Exp, NpcAttack 243종 |
| OrimsTrailSpawn | 2110 | 초 단위 웨이브, NpcClassID/NpcGroupID(그룹 140개), Count, TerritoriesID(20행) |
| OrimsTrailReward | 80 | 클리어 보상 → **원본 523 아이템으로 지급** |
| OrimsTrailBossKillRewardSection | 60 | 남은 시간 구간별 행운 보상 개수 |
| OrimsTrailCareReward | 60 | 구간별 케어 보상(기존 자체 규칙: 시간 초과 시) |
| OrimsTrailLuckyReward | 140 | 가중치 행운 보상(합 390) |
| OrimsTrailConstant | 20 | 표시만(유형 이름 없음, 아래) |
| OrimsTrailSeason | 1 | 2026-09-09 KR 시즌 — 기존 "종료 시즌 로컬 반복" 결정 유지 |
| OrimsTrailMessage / MessageType / StageMessage | 872 / 54 / 886 | **미연결**(아래) |
| OrimsTrailExpSound | 20 | 사운드 — 사용자 결정으로 범위 밖 |

실제 팩(Main, `--source523-pack`)에서 읽은 수: 스테이지 20, 영웅 6, 스킬 그룹 48, 스킬 레벨 288,
시전 묶음 288, 원본 SpellClass 373, 시너지 7, NPC 244(공격 243), NPC 그룹 140, 레벨 99+99,
다시 고르기 10, 준비 강화 4.

## 연결한 규칙(표 값 그대로)

- 입장: 스테이지의 원본 Land로 이동(Territory 상자 안 첫 통행 가능 셀). Land 속성 `MinLevel 80` 확인.
  `NoTeleport`·`TurnOffAutoForTeleport`·`NoPurplePushOnDie`·`NpcBuff`는 Land 안 규칙이라 입장을 막지 않는다.
  끝나면(클리어·실패·포기) 출발 지점으로 돌아온다.
- 영웅: 선택한 영웅의 HP가 오림 HP. 오림 몬스터의 NpcAttack 주사위 피해는 플레이어가 아니라 영웅 HP를 깎고,
  0이 되면 실패.
- 경험치: 처치한 NpcClass.Exp(오림 NPC 대부분 100) × (1 + 보유 `ExperienceAdditionPercent`) → OrimsTrailExperience 레벨.
- 스킬 카드: 레벨업마다 후보 = 보유 스킬(최고 레벨 미만) + 새 스킬(유형 한도 미만, Lv0 IsHidden 제외)
  + 요구 그룹을 모두 보유한 시너지. 고르면 해당 그룹 레벨 +1.
- 자동 시전: 보유 스킬의 시전 묶음 각 SpellClass를 `CastDelay`(ms) × (1 − `OrimsTrailSpellCastDelayDecreasePercent`)
  주기로, `CastRange` 안 가장 가까운 대상 주변 `TargetAreaRadius`(셀) 범위에 `SpellDamageBase` 피해,
  `ChainReactionCount`만큼 추가 대상. Self 스킬은 영웅 주변.
- 지속 효과: `HPPlus`(영웅 최대 HP), `MoveSpeedBonus`/`AttackSpeedBonus`(%), `BossPierceDamageReductionPercent`(보스 피해 %).
  백분율은 `BonusType.UnitID → UIUnit.Denominator(10000)`로 해석.
- 웨이브 배치: `TerritoriesID`가 있는 20행은 원본 Land의 그 Territory 상자 안에 배치.
- 보상: Reward 행의 ItemClassID·Amount·ItemBlessCodeID를 기존 523 아이템 공급자(`patch523_stage_view.stage_one`)로
  원본 아이템 지급. 공급자에 없는 아이템은 이름과 이유를 남기고 **지급하지 않는다**(대체 없음).
- 오림 NPC 외형: NpcClass.Sprite를 523 원본 스프라이트 뱅크에서 그대로 사용(`orim523_actor_view.gd`, 필드 NPC와
  같은 기본 동작 묶음). 팩에 없는 스프라이트(105종 중 2종)는 그리지 않고 기존 차용 경로로 남긴다(대체 그림 없음).
- 오림의 증표(226862): 기존 523 아이템 공급자가 "비장비 물리 수량·소비 소유자 연결 대기"로 거절한다.
  이 한 품목만 기존 던전 대응 아이템 `TWILIGHT · 오림의 증표`로 받는다(원본 소유자가 생기면 원본으로 바뀜).
- 저장: 영웅 HP·레벨·경험치·보유 스킬·제시 카드가 `source_dungeon_play.active.orim`에 저장되고 다시 불러온다.
  처치 기록은 10초 묶음 저장(사용자 결정), 보스·종료·보상은 즉시 저장.

## 표에 없는 규칙(만들지 않음 / 자체값으로 표시)

| # | 규칙 | 표에 있는 것 | 없는 것 | 현재 처리 |
| --- | --- | --- | --- | --- |
| 1 | 레벨업 카드 수 | 후보 조건 | 몇 장 보여 주는지 | **자체 3장**(`OFFER_COUNT`) |
| 2 | 카드 선택 중 정지 | — | 시간 정지 여부 | 정지하지 않음 |
| 3 | 히든 영웅 해금 | `PortraitNode = Nd_Hidden_*`, `Probability 150` | 해금 조건 | **사용자 결정: 처음부터 열림** |
| 4 | 영웅 `Probability`(175/150) | 값 | 의미 | 미사용 |
| 5 | 영웅 `Sp 20`, 스킬 `MPCost`/`SpellMaterialItemAmount` | 값 | SP 소모·회복 규칙 | 미사용(스킬 비용 없음) |
| 6 | 영웅 외형 | `SpriteID`(6종 모두 팩에 있음) | — | **미연결**: 플레이어 외형을 영웅 스프라이트로 바꾸는 경로 없음(남은 작업) |
| 7 | 시전 묶음 `TargettingTypeID` | 원시값 5종(2/12/22/32/44, 729행) | 이름 표(TargettingType에 없는 번호) | 각 SpellClass의 TargettingTypeID 사용 |
| 8 | 시전 묶음 `NextSpellDelay` | 416행 > 0 | 묶음 안 순서 시전 방식 | 각 항목이 자기 CastDelay로 따로 시전 |
| 9 | 피해 공식 | `SpellDamageBase` | 명중·저항·치명 | 고정 피해(마법) |
| 10 | 미적용 보너스 | 1177행 | `InvokeOption`(대미지 증가), `SpecialResistanceTypeID`, `SpellDebuff*Duration`, `SpellHitProbability*`, `UncontrollableCompanionID`(소환), `NpcSummonSetID`, `SpellDrainHP`, `SpellMoveMultiple`, `DeathReaper`, `SpellCastGroupClear`, `OrimsTrailSpellTypeClear`, `SpellPlate*`, 조건부 행 등 실행 규칙 | 보관만, 적용 안 함 |
| 11 | 스킬 연출 | `EffectSpriteID` | — | 미연결(피해 숫자만) |
| 12 | 웨이브 배치 모양 | `RelativeShapeID`(2090행, 10종) | RelativeShape 표 없음 | 영웅 주변 무작위(자체) |
| 13 | `Randomly`(2090행) | 값 | 의미 | 미사용 |
| 14 | `Second > 420` 웨이브 | 220행 | 420초 이후 의미 | 생성하지 않음(기존) |
| 15 | 그룹 웨이브 수 | `NpcGroupID` + `Count`(1080행) | 그룹 크기와 Count의 관계 | 기존 자체 설정 `group_size` |
| 17 | 회복 구슬 회복량 | NPC 역할만 | 회복량 | 자체 20%(기존 `heal_percent`) |
| 18 | 증표/오팔 상자 내용 | `NpcItemDropView`: 오림 NPC 220종이 226862(오림의 증표) 드롭 | 확률·수량(View 표) | 기존 자체 증표 드롭 유지 |
| 19 | 증표 드롭 강화 버프 72362 | `NpcItemDropProbabilityMultiple 10000`(적용 조건 112/462) | 조건 의미 | 원본 값 미적용(기존 자체 ×1.1) |
| 20 | 시너지 보상 | 7행 → Reward 314131(299361 시너지 스킬 보상 상자) | 지급 시점(최초 1회/매회) | **사용자 결정: 시너지별 최초 1회** |
| 21 | 입장 재화·횟수 | Constant 22=174, 92=10 등 | Constant 유형 이름(19종 번호만) | 기존 자체 설정(아인 174 × 10, 하루 1회) |
| 22 | 다시 고르기 재화 | 횟수별 비용 | 재화 종류 | 기존 자체 설정(다이아 4) |
| 23 | 보스 처치 시간 구간 경계 | 60행(0~28/28~40/…) | 경계 포함 규칙, 420/480 | 기존 자체 규칙(높은 하한 우선) |
| 24 | 케어 보상 발동 | 60행 | 발동 조건 | 기존 자체 설정(시간 초과 시) |
| 25 | 행운 보상 추첨 | 가중치 | 복원 여부·분포 | 기존 자체 설정(복원 추첨) |
| 26 | 대사·안내 | Message 872, StageMessage 886, MessageType 54 | `RemainTime`(92~405, 16종)의 의미(초가 아님) | 미표시 |
| 27 | 원본 UI 창 | UI 추가 팩 `main_pack5`에 `Mission_Dungeon_TracesOrim{,_Chapter,_Achievement}.csb`, `Mission_Dungeon_PanelOrim.csb`, `Hud_Minimap_Orim{Boss,Box,HealingSphere}.csb`, `Atlas_Orim_Traces1` | 창 노드 바인딩 | **미연결**: 던전 메뉴 + 필드 패널(일반 컨트롤). 그림은 만들지 않음 |
| 28 | Land `NpcBuff 73001` 등 | 값 | NPC 버프 적용 규칙 | 미적용 |
| 29 | 영웅 부활 | — | 규칙 없음 | HP 0 = 실패 |

## 남은 작업과 이유

- 영웅 원본 외형(6/6 스프라이트가 팩에 있음): 플레이어 외형을 영웅 스프라이트로 바꾸는 경로가 필요하다.
  그림을 만들거나 대체하지 않았다.
- 오림의 증표 226862의 523 소유자(소비처) 연결.
- 원본 오림 UI csb 창 바인딩: csb는 있으나 노드별 데이터 연결 규칙이 없다.
- 위 표의 "없는 규칙" 중 1·3·20·21·오림의 증표는 아래 사용자 결정으로 정했다.

## 실제 Main 확인(실제 팩 `--source523-pack`, 레벨 85 저장)

- 오림 NPC 정의: 부속 자료 없이 표에서 244종(유형 244, 그룹 140) 생성 → 입장 가능(이전: "실행 부속 자료 필요"로 입장 불가).
- 1스테이지(일반, Stage 2) 카스파로 입장 → 아덴(Land 4)에서 원본 Land 48752 "게렝의 집"으로 이동.
- 원본 외형 오림 NPC 16마리 동시 생성(외형 실패 0), 자동 시전(파이어 볼 CastDelay 2000ms)으로 28마리 처치,
  NpcClass.Exp로 오림 Lv 8, 스킬 카드 3장 → 다시 고르기(10 다이아) → 선택, 준비 강화(헤이스트) 이동속도 +25%.
- 저장 → 불러오기: 같은 도전, 영웅 HP·레벨·경험치·스킬·카드 유지.
- 320초 보스 "대마법사 게렝" 등장 → 처치 → 클리어(보상 9행) → 출발 지점(아덴)으로 귀환.
- 보상 받기: 명예 코인 1100, 마법인형 제작 코인 1100, 변신 제작 코인 1100, 성물 제작 코인 1000,
  드래곤의 성수(이벤트, 원본 #231162) 1 = 원본 523 아이템, 오림의 증표 350 = 대응 아이템.
- 저장 → 불러오기: 영수증 유지, 인벤토리 변화 6종 유지.
- 오림 Land 안에서 저장한 뒤 다시 시작해도 523 원문 필드로 복원(Land 속성 `NoTeleport` 등이 복원을 막지 않음).

## 사용자 결정 2026-11-13

| 항목 | 결정 | 구현 |
| --- | --- | --- |
| 레벨업 카드 수 | **유지: 3장** | `orim523_run.gd` `OFFER_COUNT = 3` |
| 입장 재화·횟수 | **유지: 아인하사드 174 × 10, 하루 1회** | 기존 자체 설정(`entry_currency 174`, `entry_cost 10`, `attempts 1`) |
| 오림의 증표 | **유지: 대응 아이템 지급** | 523 공급자에 없을 때 `TWILIGHT · 오림의 증표` |
| 히든 영웅(제온·메이브) | **처음부터 열기** — 영웅 6명 모두 선택. HP·시작 스킬은 원본 그대로 | `HIDDEN_SELECTABLE = true`, 던전 메뉴 영웅 목록 6명 |
| 시너지 보상 상자 | **시너지별 최초 1회** — 처음 그 시너지 스킬을 배울 때 지급, 저장에 지급 기록, 다시 도전해도 다시 주지 않음. 상자는 원본 표 그대로 | `OrimsTrailSynergySpellCombinationReward.RewardID → Reward`의 아이템(299361 시너지 스킬 보상 상자)·수량·축복을 523 아이템 공급자로 지급. 지급 기록은 `source_dungeon_play.receipts["orim_synergy:<CombinationID>"]`. 공급자가 거절해 아무것도 지급하지 못하면 기록을 남기지 않아 나중에 지급 가능 |
