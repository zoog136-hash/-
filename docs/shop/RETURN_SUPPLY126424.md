# 아이즈의 전용 귀환 주문서 공급

기존 PR247의 아이즈 상점에서 `잊혀진 귀환 주문서 (각인)`의 정확한 공급 바인딩이 빠져 있었다. 기존 원격 NPC 목록과 거래 엔진에 판매행16884를 연결한다. 후속으로 PR252의 지역 귀환 소비 코드를 같은 PR247 실행본에 통합했다. [통합 범위와 검증](REGIONAL_RETURN_INTEGRATION.md)을 참고한다.

원본과 기존 상점 팩을 대조한 값은 ItemClass126424, Merchants514, SellList Action1, Bless1(Normal), 강화0, 속성 강화0, Amount1, Cost50000, Percentage100이다. 기존 가격 계산·아데나·80레벨 원격 접근 규칙을 사용하므로 개당50000아데나이며 새 가격이나 무료 지급을 만들지 않는다. 같은 아이템의 행17234/그룹39는 Action2 매입이므로 구매 공급으로 사용하지 않는다.

구매는 아데나와 미수령 주문을 함께 저장하고, 보관함 수령 때 정확한 키 `잊혀진 귀환 주문서 (각인)`에 지급한다. 일반 귀환 주문서·각인239·다른 축복 스택에 합치지 않는다. 시작 시 명시한 기존 상점 팩을 검증한 뒤 정의를 등록하므로, 재시작 후 상점을 먼저 방문할 필요가 없다. 부족·취소·무게 초과·저장 실패·중복 수령은 기존 거래 보호를 그대로 사용한다.

## 소비자에게 전달하는 계약

[PR252의 확인 ref](https://github.com/zoog136-hash/-/blob/04139b16e31f0fcdd3d79b5bb53a1413bde8b8cb/scripts/quickslots/regional_return.gd)의 `stack_identity`가 허용하는 정식 이름 분기를 사용한다.

```text
inventory key / name: 잊혀진 귀환 주문서 (각인)
source: twilight-shop523-consumable
source523_shop_item_id: 126424
source_item_class_id: 126424
source_bless_raw: 1
source_is_consumable: true
source_test_item: false
grade: 일반
slot: consumable
source523_shop_supply_only: true
```

`source_m_native_item`이나 다른 공급자의 접미사 키를 만들지 않는다. 기존 소비자가 같은 이름·정확한126424 ID의 일반 소모품 정의를 먼저 등록한 경우에는 그 설명과 동작을 보존하면서 확인한 판매행의 공급 메타데이터만 더한다. 다른 ID·명시적인 축복/저주 상태에는 바인딩하지 않는다. 등록은 아이템을 지급하지 않는다.

상품 상세·확인창·인벤토리에는 전용 귀환과 TWILIGHT 대응 지도임을 표시한다. 공급 어댑터는 효과를 복제하지 않고 통합한 지역 귀환 소비자에 위임한다. 설정의 자동 변경을 켜면 기존 `source_70`에서 일반 귀환 슬롯의 표시·사용 대상을 전용 주문서로 바꾸고, 원래 저장 슬롯은 보존한다. 전용 주문서가 없거나 목적지가 미연결이면 일반 주문서를 대신 소비하지 않는다. 구매한 전용 주문서로 기존 PC 대응 지도 시작 지점에 귀환하는 실제 실행을 검증했다. M 원본 지형·두 연구실 지역의 최종 플레이 검증은 남아 있다.

## 집중 검증 재현

기존 검증된 상점/NPC 팩의 네 CLI 인자, 현재 맵 팩과 격리 XDG 경로를 사용한다. 공식 Godot4.7.2의 실제 Main/OpenGL에서 다음을 순서대로 실행한다. 두 번째 검사는 첫 번째의 QA 저장을 같은 프로필의 새 프로세스로 읽는다.

```sh
godot --path /path/to/game --rendering-method gl_compatibility --script res://tests/source523_return_supply_main_test.gd -- <기존 팩의 네 CLI 인자>
godot --path /path/to/game --rendering-method gl_compatibility --script res://tests/source523_return_supply_restart_test.gd -- <같은 네 CLI 인자>
```

첫 검사는 실제 상점 UI 구매/취소·50,000아데나 가격·부족·구매 저장 실패 원복·보관함·무게/수령 저장 실패·정확한 키 수령·일반 스택 보존·중복 거부·재로드를 확인한다. 재시작 검사는 상점 방문 전 정의와 저장된 실구매품·한 번 수령 기록, 기존 소비자 정의와의 공존 및 잘못된 ID/축복 거부를 확인한다. 제품 재화·무게·이동 규칙은 바꾸지 않고 검사 프로필만 사용한다.

원본 팩은 불변이며 기존 정상 사본을 재사용한다. 이번 변경으로 새 원본/적용팩·캡처·상세 비공개 보고서를 외부에 올리지 않는다. 수동/전체 CI나 다른 PR/main 병합은 수행하지 않는다.

로컬 결과: 실제 Main/OpenGL 공급36검사, 별도 프로세스17검사(실제 Main 재접속/등록7·정의 공존/ID·축복 보호 fixture10), core/current-map 저장 보존32, 기존 거래 합성75가 통과했다. 960×540 화면3장을 직접 확인했고 최종 가져오기·실행 로그에 스크립트/리소스 오류는 없다. 소프트웨어 GL의 V-Sync 경고만 있다. 기존66행 전수 검사 전체를 새로 실행한 것으로 집계하지 않는다.

후속 통합 검증은 현재 코드에서 67판매행의 실제 구매·보관함·수령364검사, 별도 실제 구매품→슬롯→귀환40검사와 새 프로세스7검사가 통과했다. 위 공급 전용36/17검사는 이전 단계 기록이며 이번 통합에서 다시 실행한 수로 합산하지 않는다.
