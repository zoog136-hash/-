# 87개 착지 영역의 실제 이동 연결 재검토

조사 기준: main `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`,
PR235 `298fe99818d2b7ab78d5483efd9a22d760f0f079`,
PR232 `1be258b6dd90b41934c100a013dee927e3c03942`.

기존 게임의 안전한 이동 장치는 재사용 가능하다. 그러나 제공된523 원문과
위 PR232에는 **523 영역 안의 유효한 셀을 판정하고 선택할 검증 계약**이 아직 없다.
따라서 이번 재검토에서도 원본 이동은 활성화하지 않는다. 사각형이라는 이유만으로
불가능하다는 판단이 아니라, 아래 세 연결이 아직 검증되지 않았기 때문이다.

1. 원본 Land/영역 좌표 → 실제523 필드의 셀/발 위치.
2. 해당 셀의 통행·몸체·점유·입장 규칙 판정.
3. 복수 착지 영역과 영역 내부 셀의 선택·재시도 정책.

## 원문 전수 대조

이미 정식 materialize한 누적523 ZIP의 원문을 다시 읽었다. ZIP과10개 입력 테이블의
고정 SHA는 `tools/build_auto_hunting523.py`와 기존 검증 영수증에 있다.
이동 심층 자료의 분석은 영역 포함/겹침 관계를 판정한 것이며 타일 경로나 착지 선택 구현이 아니다.

| 확인 항목 | 실제 결과 | 이동 구현에서의 의미 |
| --- | --- | --- |
| 메뉴/착지/Land | 80/87/22 | 각 namespace와 다중성을 보존해야 한다. |
| 아덴 내부 메뉴 | 55 | 같은 맵 이동을 거절하는 기존 NPC API에 그대로 보낼 수 없다. |
| 그 외 메뉴/착지 | 25/32 | PR232의 Land4/Aden 표시 화면만으로 나머지21개 Land를 처리할 수 없다. |
| 정확한 단일점 착지 | 0 | 87개 모두 Start와 End가 다른 영역이다. |
| X/Y 차이가 모두1인 착지 | 54 | End 제외 규약이면1셀, 포함 규약이면4셀이다. 규약 확인 없이 한 셀로 축약하지 않는다. |
| 복수 착지 메뉴 | 메뉴604에5개,614에4개 | 첫 행·최근접·균등 추첨으로 임의 축약하지 않는다. |
| 전체 비제로 Territories의 단일점 정의 | 8,870/25,464 | 원문은 단일점 정의도 별도로 갖는다. 작은 사각형을 모두 단일점이라고 간주할 근거가 아니다. |

다음은 원문 테이블의 **모든 필드 이름**을 검사한 결과다.

- `LandTeleport`: ID, TeleportCost, CurrencyID, AllowInterTeleport, AllowMapTeleport, NoTicketSpend.
- `LandTeleportTerritories`: ID, LandTeleportID, TerritoryID.
- `Territories`: ID, Name, DescID, LandID, StartX, StartY, EndX, EndY,
  ShowInSourceList, IsVillage, CanMoveToEarthObject.

이 세 테이블에는 셀 선택 알고리즘·가중치·충돌 마스크·좌표 변환 필드가 없다.
`ConstantData.ScheduleTeleportRetryCount=20`은 존재하지만 후보 생성, 영역 경계 포함 규약,
유효 셀 검사, 실패 시 선택 변경 방법은 제공하지 않는다. 20회 임의 좌표 추첨의 근거로 확대하지 않는다.
`ServerAutoScheduleLimitLevel=55`, `AutoScheduleCategory.Range=5`도 각각의 작동 문맥이
확인되지 않아 전 메뉴 MinLevel55 또는 착지 탐색 반경5로 바꾸지 않았다.

대상22개 Land의 관련 `LandAttribute` 문맥에는 NoTeleportCome32행과 NoTeleport6행이 있다.
NoTeleportCome32행은 비제로 Territory 범위이며, NoTeleport6행은 TerritoryID0 문맥이다.
이는87개 착지에 전부 적용된다는 뜻이 아니다. 범위 겹침과 AllowMapTeleport 등의 우선순위는
별도 검증이 필요하다. 모든 이동을 NoTeleport로 일괄 차단하거나 이 속성을 무시하지 않는다.

## PR232에서 새로 생긴 기능과 남은 경계

위 SHA의 [지도 보고서](https://github.com/zoog136-hash/-/blob/1be258b6dd90b41934c100a013dee927e3c03942/docs/CURRENT523_ADEN_SOURCE_RUNTIME.md)를
읽고 코드와 대조했다. 기존 설정 → 폴더 선택 → 원문 보기 → 게임 복귀 UI는 추가됐지만,
이 화면은 검토 카메라를 사용하고 기존 게임을 정지하며 저장을 막는다.

- `current523_tile_review_pack.gd.SEMANTICS`는 coordinates/projection/movement/collision을 UNKNOWN으로 선언한다.
- `current523_aden_review.gd.project_half_storage`는 원문 저장 위치의 표시 가설이며 M의 실행 좌표 계약이 아니라고 명시한다.
- 화면 진단도 `movement_implemented=false`, `M_projection_verified=false`를 반환한다.
- 원문 API는 각 S32의 attributes16,384바이트를 해시와 함께 보존한다. 이 바이트가 존재한다는 것과
  이동 마스크로 해석됐다는 것은 다르다. 이미지의 불투명 픽셀·표시 타일 유무를 통행으로 바꾸지 않는다.

따라서 이 검토 화면의 투영 함수를 가져와 플레이어를 옮기거나 기존 PC 통행 비트를 덮어쓸 수 없다.
PR232 코드를 이 브랜치에 병합하거나 수정하지 않았다.

## 실제로 재사용 가능한 기존 이동

별도 임시 사용자 저장소에서 실제 Main을 열고 기존 포탈을 직접 호출했다.
새 좌표·경로·임시 포탈은 만들지 않았다. 원본 입력·기존 사용자 세이브는 변경하지 않았다.
실행 영수증은 [arrival_reuse_evidence.json](arrival_reuse_evidence.json)에 있다.

| 기존 경로 | 확인한 재사용 범위 | 523에 그대로 붙일 수 없는 이유 |
| --- | --- | --- |
| `world.use_field_portal` | 같은 아덴 맵의35개 포탈 목적지가 현재 revision2026102904와 point_clear 검사를 통과했다. 기존 `aden_hunting_entry`를 실제 실행해 [41256,-2184] → [43440,-3708] 이동·통행·재화/인벤토리 보존을 확인했다. | 목적지는 자체 게임의 검증된 로컬 좌표다. 523 Schedule/LandingLink와의 대응표가 없다. |
| `world._npc_teleport_requested` | 상태 검사 → 맵 검증/로드 → 성공 확인 → 비용 차감의 흐름. | 같은 맵이면 거절한다. 타 맵에서 아덴으로 오는 자체 요금0과 원본 LT73 요금8000이 다르다. 이 API의 가격/입장표를 원본표 대신 사용하지 않는다. |
| `source_travel.enter` | `l1_` 카탈로그의 실제 필드를 미리 열고 원본 좌표 통행을 검사한 뒤 이동하는 흐름. | 해당 카탈로그/PC 좌표 계약은 현재523 M의 Land/AssetPath/좌표/충돌 계약이 아니다. |
| `random_landing`, 직업 텔레포트 | 현재 로컬 필드의 도달 가능한 점 또는 주변 임의 점을 찾는다. | 523의 선택된 착지 영역에 속한다는 보장이 없으며 원본 셀 선택 규칙이 아니다. |

현재84개 런타임 지도에서 원본 목적 Land와 **숫자만** 맞는 것은4/35/280/283이다.
같은 번호만으로 판본과 지리를 연결하지 않는다. 특히 현 통행 구현은
`source_v1_grid.gd`의 PC L1J3.80c 방향 바이트와 사용자 승인 로컬 overlay를 사용한다.
`point_clear`에 통과했다는 것만으로 해당 점을 M의 검증된 착지점이라고 주장할 수 없다.

## 실제 이동을 열기 위해 필요한 자료/검증

이미 받은 원문 ZIP을 다시 요청할 필요는 없다. 필요한 것은 보존된 자료의 검증된 해석 또는
동일 판본의 실행 근거다.

1. **지도 계약:** edition=LineageM, version523, LandID/AssetPath, 원문/팩 SHA와 실제 필드 ID,
   셀 원점·축·발 위치의 대응. 시각적으로 타일이 붙는 것 외에 실제 지점 대조가 필요하다.
2. **이동/착지 판정:** attributes 또는 동등 원문의 검증된 해석과 통행 가능한/불가능한 셀 사례,
   몸체·점유·일방통행·문·영역 경계 사례. 허용 비트를 만들거나 PC 비트를 옮겨 적지 않는다.
3. **영역 선택 계약:** Start/End 포함 규약, 복수 영역 선택 방법, 후보 셀 선택·재시도20의 작동,
   빈 영역과 전부 막힌 영역의 실패 처리. 자체 로컬 정책을 채택하려면 원본 구현과 구분해 명시해야 한다.
4. **오프라인 입장/재화 정책:** 원문 MinLevel·AllowMapTeleport·LandAttribute의 적용 관계,
   Gem23메뉴의 재화 매핑과 티켓/비용 처리. 실제 서버를 요구하는 것이 아니라 이 로컬 게임에서
   채택할 규칙을 확인해야 한다는 뜻이다.

이 계약이 확인되면 기존 포탈의 이동 정리 코드를 재사용하고, 검증된 목적 필드/셀을 먼저 준비해
실패 시 현 맵·위치·재화·AUTO·세이브를 보존하는 트랜잭션으로 연결할 수 있다.
이번 변경은 조사 문서/영수증뿐이며 수동 CI·추가 전체 게임 검사·워크플로 변경은 하지 않았다.
