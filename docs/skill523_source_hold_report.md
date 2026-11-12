# 523 스킬 원본 연결 보류 보고 (2026-11-12)

원본 523 정의 ZIP(SHA `d5192c3c…4832`)을 설치한 실제 게임(Main)에서 측정했다. 원본 표 내용은 저장소에 넣지 않았고, 아래 ID·이름은 이미 저장소에 있는 바인딩/스킬 기록의 값이다.

## 원인
- `scripts/skills/player_skills523.gd` `_source_materials()`는 `data/skills/player_skills523_bindings.json`의 재료 15종을 원본 `ItemClass`로 확인하면서, 하나라도 `TestItem==true`이면 **false**를 돌려줬다. `_load_source_profiles()`는 그 결과로 스킬 프로필 441개 전체를 `native_material_binding_unconfirmed`로 보류했다.
- 걸린 재료는 재료 종류 6 `흑마석` → 원본 아이템 713(`[재료] 흑마석`)이다. 원본 ZIP `content/ItemClass.json`의 713 행 `TestItem`이 실제로 `true`다. 흑마석 이름(DescID 3641)을 가진 아이템은 713 하나뿐이고, `ItemBonus`(BonusTypeID 89, Value 6)으로 재료 6과 연결된 아이템도 713 하나뿐이다. 그래서 흑마석에는 테스트가 아닌 원본 대체품이 없다.
- 바인딩된 441개 스킬 가운데 흑마석을 쓰는 것은 없다. `SpellClass.SpellMaterialTypeID=6`은 바인딩되지 않은 주문 105781·105791 두 개뿐이고, `SpellCost`와 `InvokeOption`에는 재료 6 행이 없다.

## 수정
- `source_material_holds()`: 재료마다 따로 판정한다. 원본 아이템이 없거나 `TestItem`이 false가 아니거나 BonusType 89 정체가 없으면 **그 재료만** 보류한다. 공개 바인딩 형식이 깨진 경우에만 예전처럼 전체를 보류한다.
- 프로필 로드: 각 스킬이 쓰는 재료(SpellClass, SpellCost 1~3, 회복 하위 주문, 검토된 실행 그래프 주문, InvokeOption)에 보류된 재료가 있으면 그 스킬만 `held_source_material:<종류>`로 보류한다.
- 시전 비용: 보류된 재료를 쓰는 비용은 `523 원본 재료 보류: <이름>(원본#<ID>)`로 막고, 재료는 차감하지 않는다(`apply_to`, 연속 공격 `progression_runtime523.gd`).
- 원본 재료 차감(`current523_native_stack.gd` `plan_spell_material`): 예전에는 재료 15종 전체가 확인돼야 차감할 수 있었다. 이제는 그 비용의 재료만 확인한다(`material_ready`).
- 원본 데이터는 새로 만들지 않았다. 흑마석 대체품도 지정하지 않았다.

## 수치 (원본 ZIP, 실제 Main)
| | 수정 전 | 수정 후 |
|---|---|---|
| 로더 상태 | `deferred` / `native_material_binding_unconfirmed` | `loaded` / `original_bound_profiles` |
| 연결된 프로필 / 바인딩 | 0 / 441 | **441 / 441** |
| 보류된 프로필 | 441(전체) | 0 |
| 보류된 재료 | (전체 판정) | 1개: 6 흑마석(원본#713 `source_TestItem_true`) |
| 기록에 붙은 원본 정보(`source523`) | 0 | 441 |
| 원본 수치가 실제로 적용된 기록(자기 직업 기준) | 0 | 51 (+공용 7개는 직업마다 적용) |
| 이동 계획(`spell_move523`)이 붙은 기록 | 0 | 8 |

저장/로드: `original_skill_state`는 저장→로드 뒤에도 같다. 저장 파일에 원본 프로필 행이 들어가지 않는다(`row_json` 없음). 로드한 뒤에도 프로필 441개와 재료 보류가 그대로 남는다(`tests/skill523_source_hold_test.gd`).

## 남은 보류 목록 (표 근거 · 구현하지 않음)
### 재료
| 재료 종류 | 이름 | 원본 아이템 | 사유 |
|---|---|---|---|
| 6 | 흑마석 | 713 | 원본 `TestItem=true`이고 다른 원본 아이템이 없음. 이 재료를 쓰는 바인딩 스킬은 0개 |

### 시전 보류 (원본 표 값 그대로)
| 스킬 ID | 이름 | 직업 | SpellClass | 사유 |
|---|---|---|---|---|
| lm_f5125fc718ebf071 | 슬로우 | 마법사 | 47432 | 원본 대상이 다른 플레이어(TargetKind 52)라서 PvE에 확대하지 않음 |
| lm_4577052891abbbc4 | 블랙 핸드 | 마법사 | 345 | 같음 |
| lm_f3e3300d0862d21a | 다크 핸드 | 암흑기사 | 65638 | 같음 |
| lm_44e63d3719e2f526 | 파워 그립 | 광전사 | 48611 | 같음 |
| lm_ad6488f0cedbc544 | 사이드 그랩 | 사신 | 62684 | 같음 |
| lm_8187ff2de29d3853 | 데스 핸드 | 사신 | 63534 | 같음 |
| lm_2b058c083f711c56 | 큐어 포이즌(공용) | 기사·광전사·암흑기사만 | 73 | 그 직업의 `SpellLearnLimit` 행이 없음(다른 10직업은 적용) |
| lm_1ec7e7edbce9ac29 | 디크리즈 웨이트(공용) | 기사·광전사·암흑기사만 | 74 | 같음 |
| lm_f5a081bdcc706114 | 어스 재일(공용) | 기사·광전사·암흑기사만 | 1113 | 같음 |

### 원본 정보만 붙고 실행은 기존 규칙인 기록 (이번 수정과 무관한 기존 정책)
- `lmref_` 참고 스킬(원본 바인딩 322개) 가운데 실행 보류 **294개**(아래 "실행 쪽 막힘 조사" 참고, 수정 전 295). 이동 스킬 8개의 세부 내용은 `docs/spell_move_polymorph_weapon523_missing_rules.md`에 있다.
- `lm_` 기록 59개(stats 43, upgrade 11, proc 5 등)는 원본 증거만 붙고 효과는 기존 게임 실행부가 담당한다.

## 실행 쪽 막힘 조사 (2026-11-12, `feature/skill523-engine`)

참고 스킬 실행 보류의 세 가지 이유(재사용 대기시간·습득 경로·후속 주문)를 원본 표로 다시 확인했다. 원칙은 같다: 표에 있는 것만 실행하고, 표에 없는 규칙은 만들지 않고 아래에 남긴다. 수치는 모두 원본 ZIP을 설치한 실제 Main에서 `tests/skill523_engine_test.gd`로 측정했다(CI에는 원본이 없어 합성 값 단위 검사만 돈다).

### 1. CastDelay — 판정: **단위·의미를 수치로 확정하지 못함 → 재사용 시간 적용 안 함**
표가 선언하는 것:
| BonusType | 이름 | 단위(Unit) | 설명(DescData) |
|---|---|---|---|
| 8738 | SpellCastDelayDecreasePercent | Percentage | "스킬 쿨타임 감소" |
| 9412 | SpellCastDelayIncreaseAbsolute | MilliSeconds | (없음) |
| 12102 | EachSpellCastDelayIncreaseAbsolute | MilliSeconds | (다른 기능 문구가 들어 있음) |
| 144 | SpellCooltime | MilliSeconds | "마법 쿨타임" |

→ CastDelay를 고치는 보너스가 "스킬 쿨타임"으로 설명되고 절대값 보정이 밀리초라서, CastDelay = 스킬 재사용 대기시간(ms)일 가능성이 높다. 하지만 이것은 보너스의 설명이지 CastDelay 열 자체의 선언이 아니다.

툴팁 대조(사용자 지정 방법: "재사용/쿨타임 N초·분·시간" 문구와 CastDelay 비교):
- 문구가 있는 주문 15개(주문 자체 툴팁 1, `ItemBonus.SpellClassID`로 주문을 쓰는 아이템 47개의 툴팁), 비교 48행.
- **일치 4행(주문 3개)**: 45674 `[테스트] 인보크 쿨타임 테스트` 5000↔5초, 117984 `[엘모어전용스킬] 아인하사드의 심판` 12000↔12초(아이템 2), 122832 `[용계탈환작전 전용스킬] 어비스 크래시` 12000↔12초.
- **불일치 44행(주문 12개)**: 60661 `[이벤트] 아인하사드의 섬멸(원거리)` CastDelay 250 ↔ "쿨타임 : 1초"(아이템 16), 이벤트 소환 막대 11개(소나무·혈맹 소나무·밸런타인·단풍나무·은빛/황금빛) CastDelay 0 ↔ "재사용 시간 5초/30분"(아이템 28).
- 바인딩된 플레이어 스킬 441개 중 툴팁에 시간이 적힌 것: **0개**.
- 결론: 예외 없이 일치하지 않는다. 일치한 3개는 테스트/이벤트 전용 주문이라 열 수 있는 플레이어 스킬은 **0개**다. 아이템 툴팁의 시간이 아이템 쪽 재사용인지(아이템 재사용 표 `ItemUsageLimitGroupType`·`ItemConsumeDelay`에도 5초/1초 값은 없음) 주문 쪽인지도 표로 구분할 수 없다.
- 반영: 재사용 값은 바꾸지 않는다. 보류 화면에만 원시값을 그대로 보여 준다: "재사용 시간(원본 CastDelay 9000ms · 툴팁 대조 불일치로 미적용)" (`current_official_skills.gd` `blocked_reason`, 기록의 `source523_cast_delay_ms`).

### 2. 습득 경로(상점 91·833·1164) — 판정: **혈맹 상인이라 연결하지 않음**
- 표의 연결: `MerchantGoods.MerchantsID` → `EarthObjectUnit`(UnitID 25 = `MerchantsID`) → `EarthObjectClass`. 기존 상점 10은 `[공통] 마법상인`·`[요정] 수정 상인^사이먼`(판매 137행, 혈맹 레벨 조건 0행).
- 91 → 621 `[기란][라이브] 혈맹 상인 -22/9/7`, 833 → 4313 `[기란] 혈맹 상인 - 리부트 서버`, 1164 → 5464 `[기란] 혈맹 상인 - 신서버(그림리퍼)`. 판매 183/172/181행 중 혈맹 레벨 조건(`ClanLevelMin` 또는 `LimitMinClanLevel` > 0)이 182/172/181행이다. 예: 플래시 스킬북 223031은 혈맹 레벨 13 필요.
- 혈맹은 사용자 결정으로 맨 뒤로 미룬 범위이고, 게임에 혈맹 레벨 소유자가 없다. 혈맹 레벨을 지어내지 않으므로 이 상점의 스킬북은 연결하지 않는다. 같은 세 상점이 서버별 중복이라는 것(어느 서버 행을 쓸지)도 표에 없다.

### 3. 후속 주문(NextSpellClassID·InvokeOption 등) — 판정: **연결 0개**
- 바인딩 참고 스킬 322개의 기본 단계 후속 연결: `NextSpellClassID` 25(BonusApplicationType 0: 13, 1=SpellClass: 4, 5=ItemClass·Target 1: 8), `ActiveComboSpell` 2(ApplicationType 352), `AdditionalSpellClassID` 1, `SuccessChangeSpellClassID` 1.
- 적용 유형 1·5·352가 "언제 다음 주문이 나가는지"의 조건인데, 그 의미(ItemClass 1이 무엇인지 등)가 표에 없다.
- 예: 뇌신 플래시 69381 → 다음 주문 69391(적용 유형 5) → 묶음 시전 69401 `플래시 (공격)` 피해 150+1d1 + `SpellWeaponBasedDamage=1` + 69411 침묵(대상 PC 전용 TargetKind 52) + 70431 썬더 마크 연쇄. 피해에 무기 피해를 어떻게 더하는지가 표에 없어 "피해 공식이 있는 후속 주문" 조건을 만족하는 것이 없다.

### 4. 원본 표만으로 실행되는 참고 패시브 — **1개 열림**
새 계약(`player_skills523.gd` `source_direct_passive` / `prepare_source_direct`, 게임 시작 시 공유 스킬 기록에 반영):
- SpellType 3(패시브), 조건 노드·비용·재료 없음, 기본 단계(`MinSpellLevel=0`) 주문 보너스는 `BuffClassID` 하나뿐.
- 버프: `IsBuffGroup=false`이거나 그 BuffGroup의 `IsAllowOverlap=true`, `IsEraseOn*` 조건 없음.
- 버프 보너스: 캐릭터 레벨·직업 조건 없음, 적용 대상 조건 없음, 단위가 맞고 기존 `stat()` 수신부가 있는 평면 수치만(DamageReduction·ArmorClass(Bonus)·명중·피해·MR·HP·MP·STR/DEX/INT). 상위 단계(`MinSpellLevel>0`) 행은 기존 정책대로 쓰지 않는다. 이름이 `PVP`로 시작하는 행은 PvE 대상이 없어 자료로만 둔다.
- 학습: 그 직업의 `SpellLearnLimit`(변신 등급·카드 조건 없음) 레벨.
- 결과: **엘리멘탈 실드**(요정, SpellClass 37233, BuffClass 55363 `Buff_Normal` 중첩 허용) — 습득 Lv.50, `DamageReduction +2`(PvP `PVPDamageReduction 2`는 보존). 스킬북 177812 `정령의 수정 (엘리멘탈 실드)(각인)`이 기존 마법상인(상점 10)에서 판매된다.

### 실제 게임 확인 (원본 ZIP, Main, 요정)
- Lv.49: 가방에서 스킬북 사용 → 습득 거부, 스킬북 1개 그대로.
- Lv.50: 가방에서 사용 → 습득, 스킬북 0개, 대미지 감소 `stat("damageReduction")` 0 → **2**.
- 저장 → 습득 상태를 지운 뒤 불러오기 → 습득 1, 감소 2 유지. 저장 파일에 원본 행(`row_json`·`source_direct523`) 없음.
- 보류 스킬 예(뇌신 플래시): 시전 거부, MP 그대로, 보류 문구에 "원본 CastDelay 9000ms" 표시.
- 열린 액티브 스킬은 0개라서 MP 소모·쿨타임 시전 확인 대상은 없다(위 1·3 때문에 액티브는 하나도 열리지 않음).

### 수치 (원본 ZIP, 실제 Main, 전 → 후)
| | 수정 전 | 수정 후 |
|---|---|---|
| 참고 스킬(원본 바인딩 322개) 실행 보류 | 295 | **294** |
| 참고 스킬 실행 가능 | 27 | **28** |
| 원본 스킬북(BuffCard 연결 아이템 1,459, 테스트 57 제외) | 1,402 | 1,402 |
| └ 습득 가능(일반) | 377 (스킬 146) | **379 (스킬 147)** |
| └ 학습 전용 | 4 | 4 |
| └ "주문 실행 소유자 미지원"으로 보존 | 875 (스킬 293) | **873 (스킬 292)** |
| └ 원본 스킬 프로필과 불일치 | 71 | 71 |
| └ 스킬북 자체 조건으로 거부(직업 미지원 47·제한 카드 22·학습 제한 행 없음 6) | 75 | 75 |

### 남은 294개를 막는 첫 번째 이유 (오프라인 분류, 원본 표 기준)
패시브(SpellType 3) 191개 (예전 보고의 "액티브 116, 패시브 179"는 기존 기록의 activation 기준이고, 여기는 원본 SpellType 기준):
| 이유 | 수 |
|---|---:|
| InvokeOption(발동 옵션)의 발동 조건·계산 순서 없음 | 62 |
| SpellTransformID(다른 스킬로 바뀌는 규칙) 없음 | 39 |
| 하위/발동 주문(SpellClassID·PassiveCastSpell) 실행 규칙 없음 | 35 |
| RequiredSpellClassID(선행·강화 관계)의 의미 미확정 | 14 |
| CharacterLevel 조건 행(레벨 이상/정확히 등) 해석 없음 | 13 |
| 무기 조건 행 적용 규칙 없음 | 2 |
| 수신부 없는 효과(치명타%·무기별 피해·카운터·PvP 전용 등) | 26 |

액티브(그 밖의 SpellType) 103개:
| 이유 | 수 |
|---|---:|
| 하위 주문 묶음(SpellCastAll 등) 실행 순서 없음 | 24 |
| PC 전용 대상(TargetKind 52) — PvE에 확대하지 않음 | 18 |
| 후속/변환 주문(NextSpellClassID 등) 실행 순서 없음 | 12 |
| 이동(SpellMove) + 후속 주문 | 8 |
| InvokeOption 발동 조건 | 4 |
| 탄환·공격 교체(AmmoClassID) 규칙 없음 | 2 |
| 효과 수신부·조건 없음(상태이상 플래그·버프 해제 조건·흡수량·시전 대상 선택 등) | 35 |

### 표에 없는 세부 규칙 (이번 작업에서 구현하지 않음)
- CastDelay: 열 자체의 단위 선언, 툴팁과 다른 이벤트 주문(0 ↔ 5초, 250 ↔ 1초)의 해석, `CastGroupID` 공유 여부(`SpellCastGroup`·쿨타임 감소/초기화 표는 그룹 단위로 되어 있으나 "일반 스킬" 그룹 1을 모든 일반 주문이 공유하는지 없음), `SpellChangeCastGroup.CastDelay`(값 8·80 등)와의 우선순위, `NextSpellDelay`·`RepeatingSpellDelay`와의 순서.
- 혈맹 상인 91·833·1164: 혈맹 레벨·가입 일수·서버별 상점 선택 규칙.
- 후속 주문: BonusApplicationType 1/5/352 + Target의 발동 조건, `SpellWeaponBasedDamage`의 무기 피해 결합식, `SuccessChangeSpellProbability`의 판정 시점, `ActiveComboSpell`의 입력 창(QTE) 시간.
- 패시브: `RequiredSpellClassID` 강화가 기본 버프를 대체하는지 더하는지, `CharacterLevel` 행이 "그 레벨 이상"인지, `MeleeCritical`(ValuePercent) 등 치명타·무기별 보너스의 기존 계산 순서.
- 자기 버프 액티브(메디테이션 RegenMP, 헤이스트 속도 3종 등): 메디테이션은 `RegenMP` 회복 주기(기존 아이템도 TWILIGHT 회복 주기 정책), 헤이스트는 대상 지정(SingleObject/All)과 `RunSpritePoint`, 이레이즈 매직은 `IsEraseOnSpellAttacked`(마법 피격 시 해제) 수신부가 없어 보류했다.

## 별건: 원본 523 제작식 0개 (원인만 기록, 이번 PR에서 고치지 않음)
같은 원본 ZIP에서 `patch523_equipment.recipes`는 0개다(수정 전후 같음). 거부 사유: `unresolved_item_state` 773, `unresolved_player_or_server_condition` 488, `non_single_guaranteed_result` 327, `unverified_random_result_contract` 62. 테스트용 아이템 판정(`unresolved_item_condition`)은 0건이라서 **스킬 보류와는 원인이 다르다**.
- `scripts/crafting/patch523_rules_projection.gd` `_item_reason()`의 `row.ItemBlessCodeID not in [1,2]` 검사가 원인이다. 원본 표 행의 숫자는 실수(JSON/PackedFloat64Array의 `1.0`)이고, Godot 4.7에서 `1.0 in [1,2]`는 `false`다(직접 확인함). 그래서 품목 검사까지 온 제작식 773개가 모두 떨어진다. 원본 표에서 실제로 이 검사에 걸릴 행은 `ItemHoningEpithetID≠0`인 6개뿐이다.
- 같은 방식의 비교가 `_recipe()`에도 있다: `ItemCraftOutputTypeID not in [0,1,2]`, `int(craft_id) in delegated_protection_recipe_ids`(정책 JSON 값도 실수). 이 비교들은 확률 제작식 판정에 영향을 줄 수 있다.
- 고치는 방법: `int(...)`로 바꾼 뒤 비교한다. 다만 제작은 공용 영역이고 획득처 작업과 겹치므로 따로 작업한다.
