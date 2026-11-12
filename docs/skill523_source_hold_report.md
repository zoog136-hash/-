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
- `lmref_` 참고 스킬 318개, 그 가운데 `official_pending`/`runtime_blocked` 295개(액티브 116, 패시브 179). 재사용 대기시간·습득 경로·후속 주문 규칙이 표에 없어서 기존 실행 보류를 유지한다. 이동 스킬 8개의 세부 내용은 `docs/spell_move_polymorph_weapon523_missing_rules.md`에 있다.
- `lm_` 기록 59개(stats 43, upgrade 11, proc 5 등)는 원본 증거만 붙고 효과는 기존 게임 실행부가 담당한다.

## 별건: 원본 523 제작식 0개 (원인만 기록, 이번 PR에서 고치지 않음)
같은 원본 ZIP에서 `patch523_equipment.recipes`는 0개다(수정 전후 같음). 거부 사유: `unresolved_item_state` 773, `unresolved_player_or_server_condition` 488, `non_single_guaranteed_result` 327, `unverified_random_result_contract` 62. 테스트용 아이템 판정(`unresolved_item_condition`)은 0건이라서 **스킬 보류와는 원인이 다르다**.
- `scripts/crafting/patch523_rules_projection.gd` `_item_reason()`의 `row.ItemBlessCodeID not in [1,2]` 검사가 원인이다. 원본 표 행의 숫자는 실수(JSON/PackedFloat64Array의 `1.0`)이고, Godot 4.7에서 `1.0 in [1,2]`는 `false`다(직접 확인함). 그래서 품목 검사까지 온 제작식 773개가 모두 떨어진다. 원본 표에서 실제로 이 검사에 걸릴 행은 `ItemHoningEpithetID≠0`인 6개뿐이다.
- 같은 방식의 비교가 `_recipe()`에도 있다: `ItemCraftOutputTypeID not in [0,1,2]`, `int(craft_id) in delegated_protection_recipe_ids`(정책 JSON 값도 실수). 이 비교들은 확률 제작식 판정에 영향을 줄 수 있다.
- 고치는 방법: `int(...)`로 바꾼 뒤 비교한다. 다만 제작은 공용 영역이고 획득처 작업과 겹치므로 따로 작업한다.
