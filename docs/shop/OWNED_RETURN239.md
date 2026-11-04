# 원본239 소지품 소비 계약

PR262 등 보상 생산자는 보상·수령 영수증을 자신의 원자 저장에서 확정한 뒤 이미 소유한 정확한 키를 소비자에 넘긴다. PR247은 퀘스트 발급/영수증을 만들거나 PR262를 변경하지 않는다.

```gdscript
world.consumable_service.use_owned_native_return(item_key: String) -> Dictionary
```

이 결과형 API는 원본239 Normal 전용이다. 성공은 `ok:true`, `saved:true`, `handled:true`, `consumed:1`, `source_item_id:239`, `inventory_key`, `map_id`, `position`이다. 실패는 `ok:false`, `saved:false`, `consumed:0`, `reason`이며 저장 실패에는 `save_error`가 있다. `handled`는 인식 여부이며 저장 성공이 아니다. 기존 `try_use_regional_return()`의 bool 또한 처리 경로 여부뿐이다.

정확한 소지 키는 `귀환 주문서 (각인) · 원본#239`이다. 등록 레코드는 `name`도 같은 키이며 `source=lineagem_patch523`, `source_snapshot=patch523`, `sourceId=m523:item:239`, `source_item_class_id=239`, `source_m_native_item=true`, `source_display_name=귀환 주문서 (각인)`, `source_bless_raw=1`, `source_is_consumable=true`, `source_test_item=false`, `slot=consumable`, `grade=일반`을 보존한다. 이 계약은 기존 PR238 정체 어댑터를 사용한다. 생산자는 자신이 검증한 실제 원본 정의로 등록해야 하며 이 문서의 예를 무료 공급이나 이름 접합으로 사용하지 않는다. 다른 축복/저주·기존 일반 이름·상점의 각인 키와 합치지 않는다.

소비자는 기존 인벤토리 사용 경로에서도 같은 API를 호출한다. 잠금·보유량·생존·스턴/공포·정체를 확인하고 현재 검증된 `aden_world`의 기존 안전 지역 또는 시작 위치를 재사용한다. 통행/충돌 검증 후 위치와 정확한 스택 감소를 기존 실제 저장기에 함께 저장한다. 실패하면 위치·수량과 저장 바이트를 보존한다. 재접속 후 소비된 스택은 복구되지 않는다.

**현재 목적지 범위는 같은 아덴 지도 안이다.** 다른 원본 지도에서 나가는 원자적 귀환은 지도/이동 소유자의 검증된 목적지·상태 이전 계약이 필요하므로 소모 없이 차단한다. 기존 `return_from_original_map()`의 bool과 후속 소모 호출은 외부 보상 API의 원자 저장 증거로 사용하지 않는다. 새 native 목적지나 좌표를 추가하지 않았다.

지역 자동 전환은 기존 슬롯 표시/사용 대상을126424로 바꾸는 별도 기존 정책이다. 이 API는126424를239로 대체하지 않고 정확한239 호출만 처리한다. source70의 PC 대응 시작점은 M 원본 지형·좌표 증거가 아니다. PR262 실제 보상→수령 영수증→이 소비자까지 합친 실행은 아직 이 환경에서 수행하지 않았다.

실제 Main/OpenGL의 격리 발급자 소지 fixture17검사에서 정확한 키·인벤토리 활성화 경로·성공 결과·저장 실패 원복·축복/잠금/스턴·다른 지도 보존·일반 스택 분리·같은 프로세스 재로드를 확인했다. 실제 퀘스트 지급을 실행한 검사는 아니다.

같은 저장을 새 프로세스에서 읽는 추가4검사도 통과했다. 커밋된 아덴 목적지·정확한 native 스택 소진·재사용 거부와 저장 바이트 보존을 확인했다.
