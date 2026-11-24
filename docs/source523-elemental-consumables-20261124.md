# 523 원본 소모품 속성 저항 연결

원본 정의 아카이브 SHA-256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`의 ItemClass → ItemBonus → BuffClass/BuffBonus → Bonus/BonusApplicationType/ElementalType/Unit/UIUnit 조인을 확인했다. `ElementalResistanceType`은 속성 축 선택이며 캐릭터·직업·스킬 레벨 제한이 아니다. `All`은 패치의 불·물·바람·땅 네 속성만 뜻한다.

점검표에서 이 항목만 막혀 있던 요리/음료 36종에 기존 유한 버프 실행기를 연결한다. 원본의 30분과 채널별 5% 9종, 7% 3종, 10% 24종을 그대로 읽는다. 대상·출처·소유 영수증·잠금·레벨/직업·은신·재사용·종료 정책은 기존 실행기의 판정을 따르며, 저장이 승인되지 않으면 효과나 차감이 적용되지 않는다. 기존 오프라인 기간 순환 정책을 변경하지 않는다. 저장된 버프는 기존 타이머로 해제된다.

새 경로는 기존 속성 단위/대상 해석과 피격 계산에 연결한다. 명시적 CharacterLevel/CharacterClass/MinSpellLevel 제한, 알 수 없는 unit/target, 다른 미지원 버프·아이템 조건은 이 연결로 해제하지 않는다. 원본 아카이브/이미지나 합성 대체물은 커밋하지 않았다.

검증: `godot --headless --path . --script tests/item_use523_element_resistance_test.gd` (격리 프로필의 기존 `user://growth96_definitions/source.zip`에 위 원본 ZIP 설치). 36개 실제 레코드의 네 채널과 타이머, 실제 Main 인벤토리 선택 사용, 만료·잠금·재사용 거절, 저장 실패 후 불변, 저장 재로딩 및 만료를 검증한다. Android는 별도다.

큰 카탈로그의 콜드 부트를 함께 실행할 메모리가 부족하면 원본 ZIP이 사전 설치되지 않은 격리 프로필로 실행하고, 명령 끝에 `-- --bounded-source=/absolute/path/source.zip`을 붙인다. 이 경로는 실제 Main 부트 후 동일한 SHA 검사를 거친 ZIP에서 해당 두 DTO만 가져와 실제 카탈로그 인덱스에 넣는다. 전체 등록/콜드 부트는 입증하지 않지만 보유 영수증·선택·차감·실제 저장은 동일한 실행 경로다.
