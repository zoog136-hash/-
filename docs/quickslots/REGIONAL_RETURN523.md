# 지역별 귀환 주문서 전환 — patch523

기준 main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`. 별도 기능 브랜치이며 다른 PR 코드나 main을 병합하지 않았다.

## 원본에서 확인한 범위

`QuickSlotChange` 3행은 원본 아이템 239(귀환 주문서 각인), 282783(유일한 귀환 주문서 각인), 295514(무한한 귀환 주문서 각인)다. `QuickSlotChangeData` 9행은 각 그룹을 Land 44544(잊혀진 섬 필드), 44614(골렘 연구소), 47722(NEW 골렘 연구소)에서 아이템 126424(잊혀진 귀환 주문서 각인)로 전환한다. 일반 퀵슬롯 페이지나 자동사냥 목적지 표가 아니다.

아이템 이름은 ItemClass→DescData_Korean, 무한 소모 방지는 ItemBonus→Bonus→BonusType.InfiniteAmount에서 확인했다. 추가 아이템을 지급하거나 구매·유일 카드 소유 자격을 부여하지 않는다. 이미 보유한 아이템만 등록·사용한다.

원본 표 ZIP: `lineagem_patch523_all_content_validated_and_508_520_deltas.zip`, 25,031,173 bytes, SHA256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`. ZIP 전체 CRC 검사 통과. 구현 데이터에 각 원본 표 SHA256을 기록했다. 이 ZIP은 523 Content 표 조사 결과이며 전체 게임 클라이언트나 네이티브 엔진 구현이 아니다.

기존 `TWILIGHT_source_implementation_guide_20261103.zip`(SHA256 `99149dafd92d629f4cd5f55d7d6eb74d4da46081d49f0276ffbe589b0ef5e135`)도 대조했다. 이 인계 묶음에는 QuickSlotChange 상세 분석이 없어 실제 523 표를 직접 조인했다. main에서 해당 표 이름/실행 기능은 없었다. 열린 PR 목록 및 관련 #235(자동사냥), #233(표현/설정), #246(수호성)의 변경 파일을 확인했다. 기능 중복은 없으며 world.gd/renewal_settings.gd 공유 파일의 향후 통합 충돌 가능성은 남는다.

공개 동작 근거: [NC 2021-03-24 패치 노트](https://lineagem.plaync.com/board/update/view?articleId=605a19402ca8620001245389). 지역 입장 시 귀환 슬롯 전환 및 설정의 On/Off 기능. 웹의 본문 직접 읽기는 JS 셸만 반환해 공식 URL의 검색 결과와 원본 표를 함께 확인했다. 공개 검색에서 기본 On/Off 값·주문서 미보유 시 동작까지 입증하지 못했다.

## 실제 연결과 조정값

- `설정 → 퀵슬롯 귀환 주문서 → 지역별 귀환 주문서 자동 변경`. 캐릭터 저장의 `ui_preferences.regional_return_enabled`에 보존한다. 구형 저장/새 게임 기본값은 **꺼짐(TWILIGHT 조정값)**이다.
- 저장하는 슬롯 배열은 유지한다. 표시 및 클릭 실행 시에만 지역 아이템을 투영한다. 지역 이탈·설정 해제·재접속·직업 전환에서도 원래 배치를 사용한다.
- 전용 주문서 미보유 시 0개로 표시하고 사용을 거절한다. 일반 귀환 주문서로 되돌려 소모하지 않는 정책은 **TWILIGHT 조정값**이다.
- 현재 main의 플레이 가능한 `source_70` 잊혀진 섬은 별도 PC 좌표계다. M의 Land44544와 **이름/용도 기반 추정 대응**하며, 귀환 목적지는 그 지도의 기존 검증된 시작 지점이다. M 원본 마을 좌표나 동일 지형 복원으로 주장하지 않는다. `data/quickslots/regional_return_523.json.host_bindings`에서 이 대응을 조정/제거할 수 있다. 설정 화면과 성공 메시지에도 TWILIGHT 대응을 표시한다.
- 잊혀진 주문서는 해당 지역에서만 사용한다. 이동 불가·목적지 미연결·통행 불가 시 비소모. 지역 귀환 저장 실패 시 수량과 위치를 되돌린다. 잘못된 저장 설정 타입은 진행 상태를 읽기 전에 거절하고 원본 저장을 보호한다.
- 유일한/무한한 귀환 주문서의 비소모는 확인된 원본 보너스다. 일반 지역 귀환 목적지는 기존 TWILIGHT 소모품 경로를 따른다.

## 미완료와 검증 한계

원본 전환 관계는 **3그룹 × 3 Land = 9행**을 구현했다. 실제 현재 게임 지도에 대한 대응은 **source_70 한 곳**이다. M 원본 Land44544/44614/47722의 지형·좌표·진입 및 원본 시작 마을 귀환을 이 PR이 새로 설치하지 않는다. 연구소 두 지도는 main에 실행 가능한 지도 연결이 없어 실제 입장/귀환 검증은 0곳이다. 향후 원본 지도 연결은 명시적 `source_land_id` 문맥과 검증된 귀환 목적지 연결이 필요하며, 목적지 미연결 상태에서는 주문서를 보존한다. 제외된 콘텐츠를 재도입하지 않았다.

새 원본 아트/아이콘/효과음/팩 업로드는 0개다. 아이템 표시에는 기존 카탈로그 UI의 리소스/폴백 경로를 사용한다. 이 변경은 전체 원본 리소스 전달·네이티브 동등성·실기 검증이 아니다.

재생성:

```sh
python3 tools/build_regional_return523.py --source-dir /private/table-extraction --archive /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip --output /tmp/regional_return_523.json
```

검증 결과와 재현 명령은 `docs/quickslots/validation.json`에 기록한다. 수동 CI 실행 없이 `[skip ci]` 커밋으로 draft PR을 유지한다.

전용 주문서의 신규 획득·드롭·판매 경로는 추가하지 않았다. 현재 보유하거나 기존 공급 시스템이 지급한 아이템에 전환을 적용한다. 테스트의 3개 지급은 격리 프로필의 fixture이며 일반 플레이 초기 인벤토리를 바꾸지 않는다. 후속 [공급 대조 및 소비 어댑터](SUPPLY_AUDIT523.md)는 PR238의 정확한 Normal 스택 키를 연결하며, 전용 126424의 일반 플레이 획득 완료를 뜻하지 않는다.

실제 Main 검사는 별도 사용자 프로필과 명시적 테스트 플래그가 필요하다. 이를 지정하지 않으면 게임 상태를 만들기 전에 종료한다. 전체 main의 기존 원본 지도 팩을 사용한다.

```sh
task_profile="$(mktemp -d)"
TWILIGHT_REGIONAL_RETURN_TEST=1 XDG_DATA_HOME="$task_profile/data" XDG_CONFIG_HOME="$task_profile/config" XDG_CACHE_HOME="$task_profile/cache" TWILIGHT_SOURCE_MAP_PACK="/absolute/main/external_map_packs/source84_v3" godot --headless --path . --script res://tests/regional_return_main_test.gd
```

화면 재현은 같은 격리 환경에서 `tests/capture_regional_return.gd`를 실행한다. Linux 가상 디스플레이에서는 `--audio-driver Dummy`를 사용했다. 1280×720 및 854×480에서 설정과 슬롯을 캡처하며, 음향·실기기·FPS 품질 승인은 아니다. CI의 아덴 중심 축소 stage를 이용할 경우 아덴 및 source_70의 동적 source3/local habitat 몬스터 21종에 필요한 기존 main 파일도 함께 복원해야 한다. 프로덕션 리소스를 대체하거나 몬스터 배치를 변경하지 않는다.


## PR263 통합: 현행 원본 지도와 자체 대응 지도 경계

위 source_70 이름·용도 기반 정책은 별도 TWILIGHT 대응 정책으로 보존한다. 현행 source_map84 지도는 별도 원본 Land/cell/provider identity를 가지므로 host ID가 같다는 이유로 이 추정이나 PC aden_world 귀환 목적지를 상속하지 않는다. 명시적인 동일 원본 identity·지역·검증된 목적지 연결이 없는 현행 원본 지도에서는 위치와 주문서를 보존한다. 이번 통합은 새 원본 좌표나 무료 귀환을 만들지 않는다.

기존 source_70 host-ID 동일성만 믿던 테스트는 현행 원본 지도에서 미이동·무소모를 확인하도록 구분했다. 이는 원본 귀환 정책의 실행 회귀 통과가 아니라 통합 경계용 fixture 수정이다. 기존 host 추정 정책의 순수 규칙 확인은 남기며, 현재 원본 지도와 연구소의 실제 귀환 성공을 주장하지 않는다. 수정한 테스트는 이번 정적 검사 준비에서 실행하지 않았다.
