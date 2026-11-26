# 원본 장비 제련 연결 및 설치 전제

가방에서 선택한 물리 재료가 원본 `EnchantScene.csb`의 보통/속성 제련 탭을 열고, 원본 화면에서 고른 장비와 재료 한 개를 기존 장비 가공 거래에 넘긴다. 다른 같은 이름 물리 스택의 수량을 대신 쓰지 않는다. 대상·장착 효과·가방 장부·거래 RNG는 한 저장으로 반영된다. 규칙/원본 UI/대상 조건이 맞지 않을 때는 소비하지 않는다. 비용과 `BlessCode=0` 해석은 기존 TWILIGHT 정책이며 원작 서버 처리의 복원으로 간주하지 않는다.

대상 재료: 생명의 돌 `289162`, 상시 속성 코어 `359652,359662,359672,359682,372058,372068,372078,372088`, 원본 기한 2027-02-24 05:00 KST인 `374544,374554,374564,374574`. 동일 이름의 종료된 시즌/테스트 코어 9종은 포함하지 않는다.

## 비공개 규칙 팩 생성 및 검증

이 경로는 제작/인장용 `patch523-equipment` 팩이 아니라 `patch523-five-systems-v1`을 사용하는 기존 `equipment523/pack_store.gd`이다. 원문 정의 ZIP, 규칙 팩, 설치 캔디데이트는 소스 저장소에 커밋하지 않는다. 다음 도구는 기존 고정 SHA 및 ZIP CRC, 원문 테이블 경로와 참조, 확률 행을 검증한다. 디스크와 RAM 여유가 있는 단일 작업 환경에서 승인된 ZIP/출력 디렉터리로 실행한다.

```sh
python3 tools/equipment/build_five_systems.py \
  --source-zip "$PRIVATE_SOURCE/definitions523.zip" \
  --catalog data/catalog_v19.json \
  --output "$PRIVATE_OUTPUT/equipment523-rules.json"
sha256sum "$PRIVATE_OUTPUT/equipment523-rules.json"
godot --path . -- \
  --equipment523-rules="$PRIVATE_OUTPUT/equipment523-rules.json" \
  --equipment523-sha256="$(sha256sum "$PRIVATE_OUTPUT/equipment523-rules.json" | cut -d' ' -f1)"
```

기존 관리 설치 경로는 `user://equipment523/<sha256>/rules.json` 및 원자적으로 활성화되는 `user://equipment523/active.json` (`schema`, `sha256`)이다. 활성화는 `pack_store.gd::install`의 SHA 및 스키마 확인을 사용한다. 별도로 설치한 전체 규칙이 우선이며, 설정했지만 손상된 전체 규칙을 제련 팩으로 덮어쓰지 않는다.

## Android 선택 설치용 작은 제련 ZIP

전체 규칙이 없는 경우 기존 원본팩과 원본 UI를 그대로 두고 다음 선택 추가 팩만 사용한다. 승인된 비공개 원본 ZIP에서 재현한다. 순차 요청을 확인하기 위한 테스트 파일은 공개 Git에 넣지 않는다.

```sh
python3 tools/equipment/build_native_smelt_sidecar.py \
  --source-zip "$PRIVATE_SOURCE/definitions523.zip" \
  --output "$PRIVATE_OUTPUT/smelt/smelt.json"
python3 tools/android/build_client523_addon.py \
  --equipment-smelt "$PRIVATE_OUTPUT/smelt" \
  --output "$PRIVATE_OUTPUT/smelt-addon"
sha256sum "$PRIVATE_OUTPUT/smelt-addon/twilight523-addon-equipment-smelt.zip"
```

생성물은 원본 정의에서 제련 5개 표 428행, 관련 ItemClass/효과만 투영한 129,620바이트 데이터 1개다. 배포 ZIP은 130,772바이트, SHA-256 `62286e8bde4f4b780f23bb1507cdafa1b24d3ebe77869af88ac26224e6a5e48b`다. 코드가 들어간 리소스 팩으로 마운트하지 않고, ZIP과 데이터 각각의 고정 해시를 확인해 설치한다. 자동 다운로드와 OTA 포함은 아니다.

지원 버전이 설치된 다음 게임의 **설정 → 추가 리소스 설치**에서 `twilight523-addon-equipment-smelt.zip`을 선택하고 앱을 완전히 닫았다가 다시 실행한다. 원본 UI와 표준 원본 정의가 연결된 상태여야 한다. 소량 파일의 해시·JSON 확인은 시작 시 별도 스레드로 준비하고, 먼저 눌러도 준비 중을 표시할 뿐 프레임 동기 파싱이나 재료 소비를 하지 않는다. 이미 있는 원본팩·UI·세이브는 교체하지 않는다. 이 작은 팩은 연금·세공·발동 옵션 등 다른 기능을 켜지 않는다.

## 확인 범위

`tests/native_smelt_inventory_main_test.gd`의 원본 조건 테스트는 정확한 정의와 별도로 검증한 규칙 및 UI 팩을 올린 Main에서 실행한다. UI용 `TWILIGHT_SOURCE_UI`/`TWILIGHT_SOURCE_UI_SHA256`, 테스트용 `TWILIGHT_NATIVE_SMELT_DEFINITIONS`와 `TWILIGHT_NATIVE_SMELT_REQUIRE_UI=1`, 규칙은 `TWILIGHT_NATIVE_SMELT_RULES`(전체) 또는 `TWILIGHT_NATIVE_SMELT_ADDON`(작은 ZIP) 중 하나가 필요하다. 후자는 `tests/source523_pack_test.gd`에서 기존 게임 설치 버튼 경로도 검사한다. 공개 Core에 비공개 용량 입력은 배포하지 않는다. 헤드리스 Original 버튼 터치와 실제 Android 화면, 사용자 휴대전화의 팩 설치 상태는 별개다.
