# 소지 원본 티켓 소비 API — PR243 인계 계약

PR243의 이미 소유한 정확한 티켓을 소비하여 원본 연결 결과를 기존 카드 소유/중복 원장에 지급한다. 탐험 기능·카드 정의·기존701풀을 복제하거나 확장하지 않는다. 기존 일반 뽑기/합성 가중치·천장·각성 비용과 일반 뽑기 난수는 변경하지 않는다.

## 입력과 원본 결과

6종 모두 ItemBonus의 MarketPurchaseID → MarketPurchaseProduct → Unit35/GotChaClassID → GotChaEntityView의 Unit33/BuffCardID 사슬이다. 이6종에 원본 선택 결과는 없다. 일반 뽑기권11회 규칙에 맞추려고5/10회 결과를 늘리지 않는다.

| ItemClass | 마켓 참조 | 원본 풀 | 원본 결과 횟수 | 현재 단독701 정의 |
| ---: | ---: | ---: | ---: | --- |
| 166744 | 57244 | 1288 | 1 | 대상76개 연결 |
| 254088 | 86258 | 1648 | 1 | 대상65개 중25162 부재: 소비 차단 |
| 342064 | 91082 | 121 | 5 | 대상232개 연결 |
| 342074 | 91052 | 121 | 10 | 대상232개 연결 |
| 352054 | 63803 | 563 | 5 | 대상190개 연결 |
| 352064 | 63793 | 563 | 10 | 대상190개 연결 |

각 풀의 원본 가중치 합1,000,000을 그대로 사용한다. 누락/서버·기간/등급·교체/합성 제한/분류/정체 문제가 있는 양수 후보를 빼거나 확률을 다시 정규화하지 않는다. 현재 성물25162는 양수 확률이므로254088 전체를 보존한다. 카드 담당의 정식 등록 후 현재 소유 API에 정확한 정체가 등록되어야 사용할 수 있다. 성물 원본 덱은98이며 분류 이름/번호를 추정하지 않는다.

**소지 티켓1개 → 연결 상품의 원본 결과 횟수**는 원본 연결을 사용하는 TWILIGHT 소비 정책이다. 마켓 구매와 구분하여 이미 소유한 티켓에 연결 마켓의 추가 결제 금액을 부과하지 않는다.342064/342074의 원본 OnSale=false는 그대로 두고 마켓을 활성화하지 않는다. 비활성 마켓을 참조하는 소지 티켓의 사용은 확장팩의 `redeem_owned_when_market_not_on_sale` 자체 설정으로 분리한다. 원본 마켓/카드 기간·서버 제한과 TestItem은 계속 검사한다. 기존 공급자의 `expires_at`/`source_expires_at`이 있으면 정수 Unix 시각으로 검사하고 만료를 연장하지 않는다. CannotExtendDeleteTime은 기한 생성/연장을 허용하는 값으로 해석하지 않는다.

## 함수와 선택 필드

```gdscript
world.source_shop.quote_inventory_ticket(item_key: String, selection: Dictionary = {}) -> Dictionary
world.source_shop.use_inventory_ticket(item_key: String, selection: Dictionary = {}) -> Dictionary
```

`selection`은 이6종에서 빈 사전만 허용한다. 대상 카드·인덱스·가중치·수량·기한을 호출자가 지정할 수 없다. quote는 `ok`, `inventory_key`, `source_item_id`, `bless_raw:1`, `enchant:0`, `category`, `draw_count`, 출처를 돌려준다. 미등록 원본 대상은 실패 응답의 `missing_card_ids`로 구분한다. quote의 복사본을 바꿔도 실제 정책/등록 카드를 바꿀 수 없으며 소비 직전에 조건을 다시 검사한다.

성공 use는 `ok:true`, `handled:true`, `consumed:1`, `inventory_key`, `source_item_id`, `category`, `count`, `results`, `message`를 돌려준다. 각 결과에는 기존 안정 `id`, 이름/등급/신규 여부, `source_buff_card_id`, `category`가 있다. 오류는 `ok:false`, `reason`이며 인식된 티켓의 `handled:true`를 유지하여 일반 재료/장비 소비로 넘어가지 않는다. 빈 스택·잠금·다른 축복/강화·결과 연출 중 재진입은 소비하지 않는다.

## 정확한 소지 키와 발급자 계약

- PR243 키는 `ItemClass.Name + " (탐험 " + item_id + ":1:0)"`이다. 번역 이름이나 이름 일부로 접합하지 않는다. 등록 레코드의 `source=lineagem_patch523`, `source_snapshot=patch523`, `sourceId=m523:expedition:<item_id>:1:0`, `source_item_class_id`, 원본 전체 `source_item`, `expedition_key=<item_id>:1:0`를 확인하고 `world.expedition_local.state.issued[key] == item_key`도 확인한다. 레코드가 기본값으로 생략한 축복은 발급 키의 정확한`:1:0`으로 확인한다.
- 원본 드랍 공급자는 실제 설치된 PR238 provider의 원본 ItemClass·Normal 변형·`matches()` 계약을 확인할 때만 허용한다. provider/정의가 없으면 보존한다.
- PR247의 정식 카탈로그 키는 원본 한국어 이름이다. 시작 시 등록되는 정의는 공급이나 소유를 생성하지 않으며, 정확한 ID/Normal/확장팩 해시를 가진 실제 소지 스택만 소비한다.

PR243의 `inventory_activation()`에서 이6종을 기존 미연결 재료 handoff로 보내기 전에 위 API에 넘겨야 한다. 합친 world에서는 PR247의 티켓 라우팅을 PR243의 미연결 fallback보다 앞에 유지한다. 이 작업에서 PR243 브랜치/탐험 로직을 수정하거나 병합하지 않았다.

## 원자 저장과 재접속

기존 카드 엔진의 소유/중복 수령기를 별도 계산 상태에서 사용한다. 소지 키1개 감소, 카드 원장, `source_shop.ticket_redemption`의 정책 해시/독립 난수 상태/성공 소비 횟수를 기존 실제 저장기에서 한 번에 저장한다. 성공 후에만 메모리와 결과 UI를 게시한다. 저장 실패·누락 후보·중복 카드 저장 한도 초과에서는 티켓·카드·일반/전용 난수·재화를 보존한다. 일반 뽑기 난수를 사용하거나 천장 카운터를 올리지 않는다. 결과는 기존 카드 공개 화면에 표시하며 연출 닫기/재생으로 다시 지급하지 않는다.

## 비공개 확장팩과 검증 범위

원본 확률 행은 공개 Git에 넣지 않는다. 이미 검증/보존된 동일 원본 ZIP으로 별도 기능 확장팩을 재생성하며 기존 상점/NPC v2 바이트·SHA와 지급 대기 주문을 바꾸지 않는다.

```sh
python3 tools/shop/build_source523_tickets.py /private/source.zip /private/inventory-tickets523-v1.json
godot --path /path/to/game -- <기존 상점/NPC 네 CLI 인자> --source523-ticket-pack=/private/inventory-tickets523-v1.json --source523-ticket-sha256=d25d89d1e16800141e1d7ac2e4341515931b857878b50e76eb0431f2622ae08e
```

확장팩은30,859바이트, 위 SHA256이다. 이번 환경에서 생성·해시 검증·실제 로드는 검증하지만 새 Drive/Space 업로드는 하지 않는다. 이 생성본의 보관 상태는 LOCAL_ONLY이며, 기존 정상 원본 백업과 게시 빌더로 같은 바이트를 재생성할 수 있다. Drive의 기존 상점 v2만 설치하면 이 새 티켓 확장팩까지 자동 적용되는 것은 아니다.

`source523_inventory_tickets_main_test.gd`와 restart 검사는 실제 Main/OpenGL·실제 소비/카드/저장/UI를 사용하지만 소지는 **명시된 격리 QA 발급원장 fixture**다. 탐험 완주/보관함을 통한 실제 획득을 이 검사로 주장하지 않는다. PR243의 실제 수령→이 API까지 합친 실행은 통합 담당/발급자 환경에서 추가 검증이 필요하다.5종의 소비 API와254088의 정체 차단을 구분하고 단순 정의 등록을6종 전체 소비 완료로 세지 않는다.

현재 실제 Main/OpenGL 소비 계약85검사와 새 프로세스8검사가 통과했다. 제어된 소지 티켓5종을 두 번씩 소비해 원본 수량대로 카드/중복62개를 지급하고, 실패 저장·축복·기한·결과 임의 선택·빈 스택 재사용·기존701풀/일반 난수 보존을 확인했다. 재접속에서 발급 키/소비 횟수/카드와 누락25162 차단, quote 복사본 격리와 결과 화면 재진입 보존을 확인했다. 실제 탐험 획득 횟수는0이며 발급자 통합 확인이 남는다. UI는 탐험 보상 형식에서도 사용 버튼·TWILIGHT 정책 설명을 표시하고 자동 퀵슬롯 등록을 막는다.

현재 갱신 가방 화면은 기본 상세를 다시 작성하므로 같은 정책 문구를 갱신 화면에도 연결했다. 저장된 발급원장 fixture를 새로 지급하지 않고 재사용한 실제 상세/사용 버튼·정책·퀵슬롯 거부·누락 카드 보존7검사를 통과했고 해당 화면을 직접 확인했다.
