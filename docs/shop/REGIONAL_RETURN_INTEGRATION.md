# PR247 상점과 지역 귀환 통합

일반 귀환과 전용 귀환을 실제 상점에서 구매·수령한 뒤 같은 실행본의 퀵슬롯에서 사용하도록 연결했다. PR252의 `04139b16e31f0fcdd3d79b5bb53a1413bde8b8cb` 기능 코드·검사를 기존 PR247에 선택적으로 통합했다. PR252 브랜치, 다른 공급자 PR, main은 변경하지 않았다. PR252의 별도 병합은 통합 담당 범위다.

기존 상점 결제·보관함·수령·정확한 Normal 소지 키·중복 지급 보호를 유지한다. `world.gd`의 저장 로드에는 지역 설정 유효성 검사와 기존 상점 백업/검증 훅을 함께 보존했다. 카탈로그 정의 등록은 아이템 지급이 아니다. 공급 어댑터는 기존 소비자의 설명·정체를 보존하고 판매 메타데이터만 보완한다.

## 동작과 출처

설정 화면의 **지역별 귀환 주문서 자동 변경**은 기본 꺼짐이다. 켜면 해당 지역에서 슬롯의 표시·사용 대상만 전용 주문서로 바꾸며 저장된 원래 슬롯은 수정하지 않는다. 지역 이탈·설정 해제 시 원래 슬롯으로 돌아간다. 정확한 ID·이름·Normal 축복을 확인하고 소지한 한 스택만 소비한다. 전용 주문서 부족·다른 축복·미연결 목적지는 일반 귀환으로 대신 소비하지 않는다. 이동과 전용 주문서 감소는 함께 저장하고 저장 실패 시 위치·수량을 원복한다.

검증된523 원본의239/282783/295514→126424, 세 Land의9관계와 InfiniteAmount 의미를 컴파일한 기능 정책은 `data/quickslots/regional_return_523.json`이다. 빌더는 고정 원본 ZIP SHA·CRC·정확한9관계를 확인한다. 원문 행·원본 Land 메타데이터·캡처·보고서는 공개 코드에 복사하지 않는다.

`source_70`→Land44544는 **TWILIGHT 자체 대응 설정**이다. 기존 PC 지도와 이미 검토된 시작 지점을 재사용하며 M 지형·좌표와 같다는 뜻이 아니다. 설정 UI와 사용 결과에도 대응 지도임을 표시한다. 기존 Git의 정상 개별 manifest·49chunks·충돌 grid 총51파일을 이 환경의 기존 맵 소비 폴더에 확인해 실제 로드했다. 새 맵 좌표·NPC·무료 공급·가격은 만들지 않았다. 두 M 연구실 Land44614/47722는 선택 관계만 확인했으며 실제 지도 진입·귀환 목적지가 연결되지 않아 주문서를 보존한다.

## 실제 검증

공식 Godot4.7.2, 실제 Main/OpenGL, 격리 QA 저장, 이미 설치/검증한 기존 상점/NPC v2 CLI 팩과 실제 기존 `source_70` 바이트를 사용했다. 사용자 세이브는 변경하지 않았다.

| 검사 | 결과와 범위 |
| --- | --- |
| `source523_npc_local_main_test.gd` | 364검사 통과. 현재67판매행의 실제 결제·보관함·수령·재수령 거부,3NPC 화면과 기존6소모품 UI 사용 |
| `source523_regional_purchase_main_test.gd` | 40검사 통과. 상점 UI로 일반239 1개/1,000아데나와 전용126424 3개/150,000아데나 구매·수령. 실제 설정·HUD 슬롯으로 한 개 소비·귀환, 이탈·설정 해제·저장/재로드·저장 실패 원복·스턴·축복 오류 보호 |
| `source523_regional_purchase_restart_test.gd` | 같은 QA 저장을 새 프로세스로 읽어7검사 통과. 원래 슬롯·결제/수령 기록·전용2개 보존 후 실제 사용2→1과 저장 확인 |
| `regional_return_main_test.gd` | 38검사 통과. 실제 대응 지도1개와 합성 정체/무한/미연결 지역 사례. 원본 연구실 플레이0개 |
| core/current-map 저장 보존 | 32검사 통과 |
| 합성 거래 / 동일 저장 / 지연 저장 | 75검사 / 오류0 / 오류0 |

실제 구매 테스트는 다음 두 검사를 같은 격리 XDG 프로필에서 순서대로 실행한다. 첫 검사의 새 QA 재화는 해당 프로필에만 존재하며 원본 일반/전용 주문서는 무료 주입하지 않는다. `TWILIGHT_SOURCE_MAP_PACK`은 실제 기존 대응 맵 파일이 있는 설치 폴더다. 공급자 fixture 검사를 이 결과에 합산하지 않는다.

```sh
TWILIGHT_SOURCE_MAP_PACK=/private/maps godot --path /path/to/game --rendering-method gl_compatibility --script res://tests/source523_regional_purchase_main_test.gd -- <검증된 상점/NPC 팩의 네 CLI 인자>
TWILIGHT_SOURCE_MAP_PACK=/private/maps godot --path /path/to/game --rendering-method gl_compatibility --script res://tests/source523_regional_purchase_restart_test.gd -- <같은 네 CLI 인자>
```

최종960×540 화면3장을 직접 확인했다. 캡처·감사 결과·로그는 LOCAL_ONLY다. PR238의 별도 공급자 BIN을 요구하는 `regional_return_supply*_test.gd`는 정체 계약/제어된 바닥 입력 fixture를 보존한 것이며 이번에 실행하지 않았다. 무한 주문서의 실제 공급, M 전체 지형·두 연구실 진입, 카드/스킬/던전 소비자의 전 상품 효과는 완료로 집계하지 않는다. 전체 원본 판매/기간/자격 참조 감사와 실제67상품 실행 범위는 [전체 범위 문서](SHOP523_SCOPE_AND_INSTALL.md)에 구분한다.

상점/NPC v2 데이터는 불변이며 기존 정상 Drive와 설치본을 재사용한다. 새 팩·캡처·원문·상세 보고서 업로드, 전체/수동 CI, 다른 PR/main 병합은 수행하지 않았다.
