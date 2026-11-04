# 523 원본 상점 카탈로그와 게임 UI

기준 main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`.
기존 상점의 **원본 상품 안내**에서 상품·NPC 판매·재화·누적 보상을 검색하고 상세 조건을 확인한다. 팩을 선택하지 않은 일반 실행에는 이 진입점을 노출하지 않는다. 원본을 넣어 실행하는 조회 기능이며, 원본 상품의 실제 구매·결제·보관함 수령·누적 보상 수령은 아직 구현하지 않았다. 이 PR을 상점 전체 구현 완료로 취급하지 않는다.

## 입력과 실행

Library에서 정식 materialize한 `lineagem_patch523_all_content_validated_and_508_520_deltas.zip`의 실제 크기 25,031,173바이트, SHA256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`와 전체 ZIP CRC를 확인했다. 함께 제공된 상점 심층 ZIP은 310,481바이트, SHA256 `b5d682539e411f8d84618f7ed6d54c48043aec79980b2c9444834d24f16d0d7b`다. 원본 JSON 바이트·Library 원본은 변경하지 않았다.

```sh
python3 tools/shop/build_source523_shop.py /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip /private/shop523.json
godot --path . -- --source523-shop-pack=/private/shop523.json --source523-shop-sha256=<빌더가 출력한 SHA256>
```

빌더는 저장소 밖에만 파생 팩을 쓰며, 원본 ZIP 해시·CRC·엄격한 JSON을 검사한다. 원본 27표의 모든 행·순서와 필요한 한국어 설명 부분집합을 보존한다. 각 표의 원문 바이트 SHA·크기·원문/팩 행수를 기록한다. 상품 6,819개, NPC 판매행 4,328개, 구매 제한 9,215행, 재화 272개·원천 279행, 누적 보상 3개·18단계를 포함한다. 별도 팩은 `PRIVATE_LOCAL_ONLY`이며 공개 Git에 포함하지 않는다. 기존 원본 리소스 장부의 전달 상태도 승격하지 않았다.

로더는 별도로 제공한 팩 SHA·523 형식·필수 표·정수 필드·고유 ID·연결 행을 검사한다. 결제 ID0의 중복 시스템 행은 임의로 하나를 선택하지 않는다. 교체 실패 시 기존 레지스트리를 유지한다. 조회 결과는 복사본이다.

## 실행 경계

- `MarketPayment_Korean`의 단위·대상·금액과 상품의 1회 지급량, 별도 보너스를 분리한다. 수량 견적은 정확한 정수 범위 안에서만 계산하며 구매 권한을 부여하지 않는다. 기존 TWILIGHT 가격·확률·용옥 제한·구매 처리와 저장 형식은 바꾸지 않는다.
- NPC `Cost × Percentage × Amount`는 원시 곱 검사다. 최종 가격·세금·분모·반올림을 추정하지 않는다. 실제 127,500,000,000 중간값을 64비트 범위에서 확인했다.
- 제한은 Type·ValueUnit·DurationUnit별 원문 행으로 유지한다. 계정·혈맹·성·서버 조건, 일반 주와 수요일 주를 합치지 않는다. NPC의 서로 다른 혈맹 레벨·공성·카드 조건도 합치지 않는다.
- `CurrencyUnitClass.ForGive`와 소비 후보·`ConsumePriority`를 따로 조회한다. 지급용 원천이 없는 재화를 삭제하거나 소비 후보를 임의 지급하지 않는다. 소비 순서 방향과 혼합 소모는 아직 연결하지 않았다.
- `MarketProductAdditional`은 해당 원문의 클래스체인지 조건이다. 추가 아이템으로 지급하지 않는다. 이동 재화 할인은 상점·외부 결제 할인으로 적용하지 않는다.
- `OnSale`, 현재 진열, 실제 날짜 객체, 서버세트를 별도로 보존한다. DateTime ID 숫자로 기간을 비교하지 않는다. 구매그룹은 `Index`로 정렬하며 순차 구매 의무를 만들지 않는다. 현재 코드의 시계·로컬 시간 정책은 변경하지 않았다.
- 결제 완료와 보관함 수령, 일일 활성화, 보상 수령·주간 초기화는 별도 미구현 단계다. 종료한 이벤트를 활성화하지 않는다. 누적 보상의 아이템·수량을 표시하지만 지급하지 않는다.

## 검증과 남은 작업

`tests/test_source523_shop_compiler.py`는 잘못된 원본·JSON·저장소 내 원문 쓰기를 거부하고, 선택한 실제 ZIP의 27개 전체 표와 설명 부분집합을 전수 대조한다. `tests/source523_shop_catalog_test.gd`는 합성 계약 검사와 실제 원본 검사를 구분한다. `tests/source523_shop_main_ui_test.gd`는 실제 Main에서 기존 상점 → 원본 안내 → 네 분류의 검색·상세 → 기존 상점 복귀와 골드·인벤토리·장비 개체·저장 바이트 보존을 확인한다.

실제 원본 검사 선택:

```sh
SOURCE523_SHOP_ZIP=/private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip python3 -m unittest discover -s tests -p test_source523_shop_compiler.py -v
godot --headless --path . --script res://tests/source523_shop_catalog_test.gd -- --source523-shop-pack=/private/shop523.json --source523-shop-sha256=<SHA256>
godot --headless --path . --script res://tests/source523_shop_main_ui_test.gd -- --source523-shop-pack=/private/shop523.json --source523-shop-sha256=<SHA256>
```

게임 테스트는 별도 XDG 사용자 디렉터리와 검증된 현재 맵 팩을 사용한다. OpenGL 실행에 `--source523-capture-dir=/private/captures`를 추가하면 실제 UI 캡처를 남긴다. Android 실기기 검증·원본 아트 전체 동등성·원본 팩의 영구 배포는 범위 밖이다. 과거 장부의 `--source-dir` 검사는 이 환경에 `a1.zip`이 없어 실패했다. 위 523 입력의 실제 SHA/CRC 검증과 구분한다.

2026-11-04 로컬 결과: Python 원문 전수·보호 검사 7개, Godot 카탈로그 검사 38개, 실제 Main/UI 17개, OpenGL 1280×720 및 960×540 각 25개가 통과했다. 실제 Main/current-map·세이브 보존 32개와 동일 저장·지연 저장 검사도 통과했다. 기존 상점 권한·매입 검사와 실제 구매 회귀 73개를 통과했다. 화면 검사에서는 각 해상도에 네 분류의 실제 캡처를 남기고 확인했다. Linux llvmpipe 결과이며 Android 실기기 승인이 아니다.

초기 UI 검사에서 터치 선택 실패를 확인한 뒤 기존 공통 Browser의 터치 경로로 고쳤다. 확장 UI/게임플레이 검사에는 core stage가 생략했던 기존 몬스터 초상화 한 장을 저장소의 실제 바이트로 추가하고 임포트했다. 게임 코드·기존 이미지·검사 기준은 바꾸지 않았다. 기존 상점 매입 검사에 필요한 원래 테스트 fixture도 stage에 복사했다. 이 보완 후 오류를 포함하지 않는 최종 로그에서 통과를 확인했다.

파생 팩은 68,250,624바이트, SHA256 `f9e0582927bfad5c13b6c478ed583d38979e5b69b64f2980441f1525af5ef13a`다. 팩과 화면 캡처는 이 실행 환경의 로컬 산출물이며 영구 전달 또는 공개 Git 포함 상태가 아니다. 원격 CI는 수동 실행·재실행하지 않았고 `[skip ci]` 커밋의 Draft PR로 제출한다. 원격 필수 검사 통과나 병합 가능 상태를 주장하지 않는다.

다음 단계에는 NPC 최종 가격 공식, 제한 enum과 계정/혈맹/성 카운터 범위, 서버·기간 활성 정책, 재화 소비 및 지급의 실제 아이템 매핑, 결제/보관함 트랜잭션과 저장 실패 원복을 확정해야 한다. 확인 전에는 원본 구매·수령 버튼을 활성화하지 않는다. 다른 PR 병합·원격 CI 수동 실행·워크플로 변경은 수행하지 않는다.
