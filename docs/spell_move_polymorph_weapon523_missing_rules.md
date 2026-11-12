# 523 스펠 이동 효과 · 변신 무기 제한 — 구현 범위와 표에 없는 세부 규칙

기준: 리니지M 523 원본 정의 ZIP(`tables/source.zip`, 기존 `current523_definition_rows.gd` 로더).
원칙: 표에 숫자가 있는 것만 실행하고, 표에 없는 규칙은 만들지 않고 아래 목록에 남긴다.
원본 표·추출물은 저장소에 넣지 않았다(테스트는 합성 값 + 설치된 원본이 있을 때만 실제 값 확인).

## A. 스펠 이동 효과 (SpellMoveEffect 129행, SpellMoveEffectSet 75행)

### 표가 실제로 담고 있는 것
- `SpellMoveEffectSet`: SpellID → Begin/Middle/End 효과 행 ID.
- `SpellMoveEffect`: `EffectSpriteID`, `ScreenEffectID`, `SpeedMultiplier`, `EffectSpriteWatchTargetKind`.
- 이동 거리·방향·속도 숫자는 이 두 표에 **없다**. 같은 주문의 기본 레벨(`MinSpellLevel=0`) `SpellBonus` 행에 있다.

### 구현(`scripts/skills/spell_move523.gd`)
| 종류 | 판정 근거(SpellBonus) | 적용 수치 |
|---|---|---|
| 시전자 돌진 | `SpellMoveMultiple` | 최대 이동 `SpellMoveMultiple`칸, `SpellMoveLimitPathCount`칸 이하로 추가 제한, 대상에서 `CasterMoveLimitMaxRange`칸 앞에서 정지, 속도 = 현재 이동 속도 × `CastSpeedAlterMoveSpeedMultiplier`% |
| 끌어오기 | `TargetMove=1` | 대상이 시전자 쪽 직선으로 이동, 시전자에서 `TargetMoveLimitCellCount`칸 거리에 놓임 |
| 넉백 | `TargetKnockback=1` 또는 `KnockBack=1` | 시전자 반대 방향 `SpellMoveMultiple`칸, 시전자 기준 최대 거리 `MaxKnockbackDistanceByWeaponType`(BonusApplicationType 22, Target=WeaponType) 또는 `MaxKnockbackDistance` |

- 사거리: `SpellClass.CastRange`칸. 칸→픽셀은 기존 표시 정책 `data/skills/current523_distance_input_policy.json`의 `cast_range_to_host_length`(32)를 그대로 쓴다(기존에 이미 "TWILIGHT 추정"으로 표시된 환산).
- 장애물: 직선이 막히면 기존 `find_world_path`를 쓰되 원본 경로 칸 수 제한을 넘으면 거부. 대상 이동은 장애물 직전 마지막 빈 칸에서 멈춤, 안전지대에는 몬스터를 놓지 않음(기존 몬스터 이동 규칙).
- 실행 경로: `TwilightOriginalSkillService.cast()` → `_cast_spell_move()`. 검증(대상·거리·경로)이 끝난 뒤에만 MP/재료/재사용을 처리한다. 홀드·기절 시 진행 중 돌진은 중단.
- 계획(`spell_move523`)은 기존 523 스킬 프로필 연결(`player_skills523.apply_to`)에서 바인딩된 모든 스킬 기록에 붙는다. 실행 보류 화면에는 "원본 이동 효과는 연결됨" 또는 부족한 항목이 표시된다.

### 해석 근거(표에 이름이 명시되지 않은 단위)
- `SpellMoveMultiple` = 이동 칸 수: 넉백 전용 주문(예: 데스 샷)은 이 값 하나만 갖고, 돌진 주문은 값이 `CastRange`와 거의 같다(차지 6/6, 플래시 5/5, 다크 디멘션 8/8). 차징 샷은 4칸 + 무기별 최대 10/9칸이며 이는 라이플·핸드캐넌 `WeaponType.AttackRange`(10/9)와 같다.
- `CastSpeedAlterMoveSpeedMultiplier`는 단위가 `ValuePercent`로 명시되어 있어 이동 속도 배율로 사용.
- `SpellMoveEffect.SpeedMultiplier`(400/24/200/80/500)는 단위가 확인되지 않는다. 같은 주문에서 `CastSpeedAlter…`=400인데 이 값이 24인 경우(광전사 차지)가 있어 이동 속도로 쓰지 않고 보존만 한다.

### 원본 표 기준 상태(75세트)
- 실행 자료가 모두 갖춰진 주문: 69381 [뇌신] 플래시, 86778 / 123612 [투사] 하트 시커 체인 그랩(끌어오기), 120692 [정령] 엘븐 윙 슈즈 대시, 87618(이름에 [미사용]).
- 종류: 돌진 54, 끌어오기 8, 넉백 1, 종류 미기재 11, SpellID 0 기본 세트 1.
- 자료 부족으로 보류(중복 집계): 돌진 정지 거리 없음 34, 돌진 속도 없음 16, 논타겟/방향 지정(TargettingType 34) 15, CastRange 0 14, PC 전용 대상(TargetKind 52) 14, 기타 PC/특수 대상(581·681·694) 4, 이동 종류 미기재 11.

### 실제 게임에서 아직 시전되지 않는 이유
바인딩된 이동 주문 8개(광전사 차지, 다크엘프 쉐도우 대시, 뇌신 플래시, 암흑기사 다크 디멘션, 마검사 트리니티, 신성검사 세인트 체이서, 요정 피닉스, 총사 대시)는 모두 기존 `lmref_` 참고 스킬이며 다음 자료가 없어 기존 실행 보류를 유지한다.
1. 재사용 대기시간: `CastDelay`(예: 플래시 9000)의 단위·의미(시전 지연/재사용/그룹)가 확정되지 않음(기존 문서 정책과 동일). 공식 참고 자료에도 재사용 시간 없음.
2. 습득 경로: 원본 스킬북(예: 플래시 아이템 223031)은 상점 91·833·1164에서만 팔리고, 기존 스킬북 연결은 상점 10만 읽는다. 상점 91·833·1164의 정체(NPC) 표가 없음.
3. 후속 주문: 돌진 뒤 피해·스턴은 `NextSpellClassID`(ApplicationType 5)·`SuccessChangeSpellClassID`·`ActiveComboSpell` 등 별도 주문이며 실행 순서·조건 규칙이 표에 없음. 이동만 단독 실행된다.
4. (해결됨, `docs/skill523_source_hold_report.md`) 예전에는 재료 6 흑마석의 원본 아이템 713이 `TestItem=true`라서 스킬 프로필 전체가 `native_material_binding_unconfirmed`로 보류됐다. 이제 그 재료만 보류하고 441개 프로필이 모두 연결되어 이동 계획 8개가 기록에 붙는다. 위 1~3 때문에 시전 보류는 그대로다.

### 표에 없는 세부 규칙(구현하지 않음)
- 돌진 정지 거리가 없는 돌진(`CasterMoveLimitMaxRange` 없음: 차지·쉐도우 대시·다크 디멘션 등 34건)과 속도가 없는 돌진(트리니티 등 16건).
- 끌어오기·넉백의 이동 속도/시간: 해당 행에 속도 값이 없어 즉시 배치로 처리(연출 시간 없음).
- 넉백 무기별 최대 거리에 현재 무기가 없을 때의 처리(제한 없음으로 둠), `MaxKnockbackDistanceCompareAttackRange`.
- `SpellMovePathFindRange`(20)의 정확한 의미(탐색 범위 칸/노드). 기존 경로 엔진 사용.
- `IgnoreMoveOccupy`, `IgnoreCannotMoveTarget`, `IgnoreSpellMoveLimit`의 반대 경우 규칙(점유 칸 차단, 이동 불가 대상 면역, 이동 제한의 기본값) — 값은 보존, 차단 규칙은 만들지 않음.
- `SaveLocation`(다크 디멘션 5초 후 복귀), `HideMovePath`/`HideMovePathByClient`, `AttackMotionAfterSpellMove`, `SkipCloseRangeDashEffects`, `UseDirectionalDashOnOutOfRange`, `EnableSpellMoveChaseTarget`, `MoveCasterDistanceFromTarget`, `BackwardMovementOfTarget`, `ChargeRush`, `TargetSpellPositioning`, `RandomPlatePositioning`, `PathBasedCastRange`, `PathFailurePenaltyCooltime`, `ExcludeObstacleAroundPoint`, `AllowSplashTargetMove`/`TargetMoveEmptyCellRadius`/`SpellTargetAreaMinRadius`(다중 끌어오기), `CheckObstacleToTarget`, `NoTargetTransformSpellClassID`(대상 없을 때 논타겟 변환), `CastReverseDirOnForceFixTarget`, `IgnoreInvokeDefenceSpellMove`.
- 논타겟·방향 지정(TargettingType 34/4/1) 이동의 방향·지점 결정, `SpellMoveNode`(총사 대시).
- `MinCastRange`가 있는 이동(세인트 체이서(디바인) 2칸).
- SpellID 0 세트(ID 1)가 다른 이동 주문의 기본 연출인지 여부.
- 이펙트 연출: `EffectSpriteID`/`ScreenEffectID`는 보존만 함. 기존 원본 이펙트 출력기(`notify_current_source_spell_event`)는 SpellClass 행 단위라 이동 단계(Begin/Middle/End)별 스프라이트 요청 계약이 없음. 이미지는 만들지 않았다.
- 몬스터(NPC)가 쓰는 이동 주문: 원본 NPC 공격 표에서 이동 세트 주문을 참조하는 행이 없음.
- PvP(PC 대상) 전용 이동은 PvE 게임에 확대하지 않음.

## B. 변신 무기 제한 (PolymorphEntityWeaponLimit 4871행)

### 구현(`scripts/cards/polymorph_weapon_limit523.gd`)
- 장착 중인 원본 변신 카드 → `BuffClass` → `BuffBonus`(PolymorphSetID/SpecialPolymorphSetID/SubSlotBuffClassID, 무조건 행만) → `PolymorphEntityForSet` → `PolymorphEntity`, 캐릭터 원본 직업·성별로 걸러 한 형태를 고른다(외형 선택과 같은 연결). 활성 외형 옵션(`BuffCardSpriteCustomizingOption`)이 있으면 그 세트를 쓴다.
- 그 형태의 `WeaponTypeID` 목록 = 사용 가능 무기. (원거리 형태는 활·건틀렛·라이플·핸드캐넌, 근거리 형태는 근거리 무기 12종이 나열되어 허용 목록으로 해석.)
- 무기 종류: 원본 아이템은 `ItemBonus.WeaponType`, 그 외 기존 검토된 로컬→원본 대응표(`source_weapon_actions.json`).
- 검사 위치: 무기 장착(`_equip_or_acquire_item`), 일반 공격(`_attack`), 변신 교체 시 안내 로그.
- 예: 오크 궁수(카드 66) — 한손검 장착 거부 "오크 궁수 변신 상태에서는 한손검 무기를 사용할 수 없습니다", 활 허용. 블랙 위자드(카드 4) — 한손검 허용, 활 거부. 천상의 기사(카드 102, 형태 71) — 행 없음 → 제한 없음.

### 저장/로드 영향
- 새 저장 필드 없음. 판정은 저장된 변신 기록의 `source_card_id`와 장착 무기에서 매번 계산.
- 금지 무기를 든 채 저장·로드하거나 무기 착용 뒤 변신하면 무기는 그대로 착용되고 일반 공격만 거부된다(장비 손실 없음).
- 원본 ZIP이 없으면 제한이 적용되지 않는다(기존과 동일).

### 표에 없는 세부 규칙(구현하지 않음)
- 변신할 때 금지 무기를 자동 해제할지, 변신 자체를 막을지.
- `WeaponTypeID 0`(None) 행의 의미: 271개 근거리 형태에 0이 없어도 맨손 공격을 막지 않음.
- 표에 행이 없는 형태 192개(전체 615개 중)의 제한 여부 — 제한 없음으로 둠.
- 한 카드에서 직업·성별 형태가 여럿이고 목록이 서로 다른 경우, 직업/성별 미선택 상태 — 제한 없음.
- 스킬 사용 시 무기 제한(기존 스킬 무기 조건과의 관계), 보조 무기·방패, `PolymorphEntityEquipSlotLimit`(523에서 0행).
- `PolymorphEntity.CanCast`(변신 중 마법 사용 가능 여부)는 이번 범위 밖으로 연결하지 않음.
