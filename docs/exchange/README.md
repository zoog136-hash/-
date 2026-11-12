# 거래소: 1회 실측 스냅샷 기반 구현 초안

**상태: Draft, 전 서버 초기 매물 수집은 미완료.** 운영 데이터는 `not_captured` / 상품 0개다. 아래 기능 테스트의 합성 매물을 원작 실측 데이터로 사용하지 않는다. 공식 공개 API의 실제 일부 응답은 `evidence/exchange/`에 별도 보존했다.

최초 구현 기준 main: `8634f931b6b749865c52dd6437b2d18d5f91c174`. 재개 작업은 최신 main `11df08720afdb988884ad1c2b316d937fb7dc64d`에 통합했다. 다른 기능·기존 브랜치·원본 데이터·사용자 저장은 수정하지 않는다.

## 구현된 계약

- 전체 메뉴 → **거래소**. 서버/이름 검색, 묶음당 수량·묶음 가격, 현재/초기 묶음 재고, 강화·속성·특수 정보, 구매 전 명시 확인/취소.
- 실행 중 네트워크 요청이나 가격 재수집 없음. 검증된 한 스냅샷만 읽는다. 단가 평균·임의 시세·묶음 쪼개기 없음.
- 재고는 `floor((UTC unix + 14400) / 86400)` 일자 기준. 한국 오전 05:00에 **초기 묶음 수량**으로 돌아간다. 화면이 열려 있으면 다음 1초 갱신 때 표시되며, 앱이 꺼져 있으면 다음 조회/구매 때 적용한다. 가격·품목은 바꾸지 않는다. 별도 서버/스케줄러가 필요 없다.
- 기존 `source_shop` 원자 저장·재화 바인딩·거래 잠금·시계 역행 보호를 사용한다. 다이아·지급 아이템/물리 개체·소비 재고를 같은 저장에 반영하고 저장 실패 시 라이브 재화를 바꾸지 않는다. 응답이 불확실하면 정상 저장 재로드 전 재거래를 막는다.
- 재고는 기존 상점 저장의 선택적 `frozen_exchange` 필드다. 과거 저장에 없으면 빈 상태로 읽으며 탐색만으로 저장을 변경하지 않는다. 첫 거래 이후 원본 스냅샷 SHA가 바뀌면 재고를 조용히 다시 채우지 않고 구매를 잠근다.
- 실제 `ItemClass` ID/이름·바인딩이 맞고 제외/기간/삭제/이벤트 조건에 걸리지 않는 일반 상품만 구매 경로를 연다. 강화·축복/저주·속성·정련·특수 상품은 원형을 표시하되 정확한 원본 개체 연결이 검증될 때까지 구매 잠금. 강화 상품을 일반 아이템으로 잘못 지급하지 않는다.

## 확인된 공식 데이터와 한계

공식 페이지: https://lineagem.plaync.com/price/itemprice/index

로그인·CAPTCHA 없이 공식 API GET 일부 성공:

- `/lms/v2.0/game/server`: 30월드 / 300서버.
- `/lms/v2.0/game/market/world`: 월드 거래소 목록.
- `/lms/v2.0/price/search/item?size=30&page=1&sale=true`: 관측 total 196,785, 검색 상한 10,000.
- `/lms/v2.0/price/search/item/{itemId}/stock?serverId=…&enchantLevel=…&blessedType=0&page=1&size=5`: 실제 매물 `quantity`, `salePrice`, 강화·축복·정련 응답.

호스트는 `https://api-goats.plaync.com`이다. 요청 size=100이어도 품목 페이지 30행, stock 10행 제한을 관측했다. 서버 응답에는 해당 월드 거래소가 섞인다. **단순 서버별 합산은 중복**이며, 동일값 매물 두 행도 서로 다른 판매분일 수 있어 값 기반 dedupe는 누락을 만든다. 매물 고유 ID/원자적 스냅샷 토큰은 확인하지 못했다. API 품목 ID를 클라이언트 `ItemClass.ID`와 동일하다고 추정하지 않는다.

이번 작업은 제한된 경로 검증만 했다. 모든 서버·페이지를 수집하지 않았으며 전체 규모·특정 시점 무누락을 증명하지 못했다. 첫 다섯 증거의 시간은 파일 기록 시각만 있고 요청 시작·HTTP Date는 미기록이다. 마지막 두 receipt에는 요청 시작/완료 UTC와 HTTP Date가 있다. 현재 매물은 나중에 달라질 수 있으며 이 응답을 실시간 시세로 제공하지 않는다.

정적 정의 점검 기록은 비공개 인계로만 보존하며 이 공개 PR에 원본 ZIP이나 그 파생 메타데이터를 게시하지 않는다. 정적 원본 JSON은 카테고리/정의·표시 관계의 근거일 뿐, 현재 등록 매물·가격·재고가 아니다. 본 PR은 원본 523 ZIP이 이 환경에 설치되었다고 주장하지 않는다. 사유 원본을 공개 저장소에 새로 올리지 않았다.

## 수집 재개 및 고정 데이터 설치

```sh
# 기본 10요청 상한, 최소 1초 간격. 실패/429에서 즉시 중단하고 자동 재시도 안 함.
python3 tools/exchange/probe_official.py --kind servers --output /tmp/exchange-capture
python3 tools/exchange/probe_official.py --kind catalog --server-id 1 --page 1 --pages 2 --output /tmp/exchange-capture
python3 tools/exchange/probe_official.py --kind stock --server-id 10014 --item-id 111852 --enchant-level 0 --pages 1 --output /tmp/exchange-capture
# 검증된 원형/receipt를 재사용하며 기존 파일·고아 파일을 덮어쓰지 않는다.

python3 tools/exchange/import_snapshot.py --validate-only /path/complete-snapshot.json
python3 tools/exchange/import_snapshot.py /path/complete-snapshot.json /path/new-frozen-snapshot.json
```

수집기는 **부분 probe 도구**이며 전수 수집/production 승격을 자동 수행하지 않는다. 완료하려면 서버·월드 조회 범위, 검색 cap 분할, 각 페이지 완주·응답 total 일치, 시각 구간·페이지 변동·중복/누락 위험을 별도 검증해야 한다. 현재 API만으로 단일 순간 무누락을 보장할 수 있다고 말하지 않는다.

스냅샷 검증기는 `coverage.complete=true`와 예상/완료 서버 집합 일치를 요구하지만 **그 선언의 진실을 자동 증명하지 않는다**. 검증 후 증거를 검토해 최초 production 파일을 결정해야 한다. 이미 존재하는 파일은 importer가 덮어쓰지 않는다. 최초 placeholder 교체는 새 검토 커밋으로만 한다. 이미 사용한 스냅샷을 임의 교체·재수집하지 않는다.

각 실제 응답 행은 원래 `quantity`를 `bundle_size`, `salePrice`를 `bundle_price`, `initial_bundles=1`로 보존한다. 똑같아 보이는 행을 합치지 않는다. `listing_id`는 원본 ID가 아닌 **관측 스냅샷 내부 식별자**임을 증거에 명시한다. 서버/월드 범위 ID는 명시적으로 구별한다. `item_class_id`는 별도로 검증한 클라이언트 ID다. 축복·정련·미해석 필드는 `attributes`에 그대로 남기고 구매를 잠근다.

## 검증 범위

`evidence/validation.json`과 보존한 로그 참고. Godot 4.7.2 실제 Main 부팅, 탐색/닫기/재열기와 저장 바이트 보존을 headless로 검사했다. 합성 상품 기반 거래/재고/시계/저장실패/UI 확인 취소 계약 검사와 원본 API 접근 증거는 별개다.

전체 역사 기능 suite, 실제 GPU 캡처, Android 실기기, 전 서버 수집, 강화/정련 상품 실제 거래는 미완료. 이 환경에 Xvfb가 없어 실제 OpenGL 화면 캡처는 실행하지 못했다. 기존 원본523 정의/아트 팩이 없어 해당 경로는 기존 정책대로 미설치 경로만 확인했다. CI 초록색이나 테스트를 원작 매물·리소스 전체 전달로 해석하지 않는다.

집중 Godot 검사는 다음 명령으로 별도 실행한다. 이 PR은 기존 필수 core 검사 목록을 변경하지 않으며, 새 Godot 검사가 자동 core CI에 등록됐다고 주장하지 않는다. Python importer/probe 검사는 기존 CI Python 단계에 추가했다.

```sh
TWILIGHT_SOURCE_MAP_PACK=/path/to/isolated-pack-dir python3 tools/test_project.py --godot /path/to/Godot4.7.2 --only frozen_exchange_test,frozen_exchange_main_test,core_runtime_save_test --logs /tmp/exchange-tests
```

## 재개 검증과 수집 시도

[2026-11-12 재개 기록](CONTINUATION_20261112.md)에 원본 native 지급 연결 수정, 명시적 일반형 조회, 실제 묶음 가격·서버/월드 경계, 새 자동 집중 검사와 페이지 총량 변동으로 중단한 전수 수집 시도를 기록한다. 최초 로그와 합성 fixture 검사는 이 재개 결과와 구분한다.
