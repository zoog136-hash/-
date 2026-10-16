# 아덴 월드: 오만과 같은 원본 격자 경로 연결

기준 main: `e2119c37293a783e93b421ee0055d1318271b071` (PR #119 병합 직후).

## 구현 범위와 현재 판정

**코드/원본 팩 생성 및 Python 검증 완료. Godot 실행·시각 검수는 NOT_RUN. main 병합 전 검증이 필요한 초안이다.**

`aden_world`를 별도 샘플이나 새 게임 ID로 만들지 않는다. 독립 아덴 팩이 설치되어 있으면 기존 `remake_registry.gd`가 `aden_remake_registry.gd`로 연결하고, 오만과 동일한 `RemakePlayableField` 및 `RemakeSourceRenderer`를 사용한다. 이 경로에서는 기존 아덴 폴리곤을 원본 지형이라고 재사용하지 않는다. 아덴 팩이 **없으면** 기존 지도를 유지하고, 팩이 **존재하지만 손상되면** 기존 world 로더의 실패 경로로 맵 전환을 거절한다.

A3 `data/mapcache/4.map`의 2,048 × 1,536칸 전체를 X-major에서 row-major로 무손실 변환했다. 64 × 64의 768개 청크, 3,145,728칸 전체와 이동 마스크를 대조했다. 원본 격자를 자르거나 지형 경계를 단순화하지 않았다. 항목별 체크 수는 셀/청크 검사 누계이며 게임 플레이 검사의 수가 아니다.

NPC 9개, 포털 3개, 사냥/보스 구역 18개의 ID·서비스 역할·몬스터 구성·개체 수·재출현 및 기존 비공간 설정을 보존한다. 새 위치는 **TWILIGHT용 임시 재배치**다. A3 getback 위치를 기준점으로 사용하되, 기존 구역과 원본 지명의 정확한 동등성이나 원작 NPC/보스 좌표를 주장하지 않는다. 특히 기존 `gludio`를 원본 `글루딘`과 동일 지명으로 판정한 것이 아니다. 기준점 주변 배치 후보를 기존 픽셀 거리로 변환한 뒤 원본 연결 영역의 유효 셀로 옮긴다. 최대 임시 보정 거리는 약 3,131픽셀이며 상세 전후 위치는 비공개 팩의 `build_report.json`에 남겼다. 스폰 반경·직사각형 크기·최대 개체 수는 넓히지 않았다.

오만 1층에서 돌아오는 기존 `previous` 포털에 구 아덴 픽셀 좌표가 남아 있음을 확인했다. 현재 world 코드의 `target_layout_revision` 검사는 새 원본 맵으로 전환할 때 구 버전 목적지를 그대로 쓰지 않고 검증된 입구를 사용한다. 이것은 코드 확인이며 실제 왕복 전환 테스트를 대신하지 않는다.

## 데이터 검증 결과

- Python 테스트: **16 실행 / 16 PASS / 0 FAIL**. 일부 테스트는 실제 비공개 팩과 export를 입력해야 실행되며, 미제공 시 SKIP으로 표시한다.
- 전체 원본 격자/768청크 해시·이동 규칙, 좌표 왕복, 막힌 경계, 배열 경계 순환 방지, 누락/중복 청크, 손상 데이터, 변경된 설정 및 오래된 export 거절을 검사했다.
- 입구와 연결된 셀: **1,706,373칸**. NPC·포털 및 스폰 셀의 데이터상 도달 가능성과 안전 구역/서비스 예약 영역을 검사했다.
- Drive 업로드 후 다시 내려받은 ZIP의 SHA-256·CRC와 전체 셀 검증을 다시 통과했다.
- 기존 오만 비공개 팩, main, PR #100, player/monster/animation 코드는 변경하지 않았다.

`VALIDATION.json`, `python-tests.log`, `drive-roundtrip.json`은 데이터 검증 증거다. 이 환경에는 Godot 실행기가 없었으므로 **GDScript 컴파일/실행, 실제 Main 화면, 충돌 물리, NPC 거래, 포털 왕복, 보스 전투·재출현, 저장/재접속, Android 성능을 통과로 표시하지 않는다.**

## 아덴 팩 복원 및 PR #120 업로드 (2026-10-15)

원본 ZIP은 기존 Drive 보관 위치에 유지한다. 2026-10-15 사용자가 이 공개 저장소에 대한 재배포 권리를 확인하고 PR #120의 기존 브랜치에 리소스 커밋을 요청했다. ZIP 원본 5개를 바이트 변경 없이 추적 대상으로 추가한다. 원 라이선스 문서는 ZIP에 없으며, 확인 범위와 출처는 `data/map_remake/private/aden/NOTICE.md`에 기록한다. 이를 별도 오픈소스 라이선스 부여로 해석하지 않는다.

- 파일: `TWILIGHT-aden-remake-private-20261015-v1.zip`
- 크기: **1,343,001바이트**
- SHA-256: `262f8bc34fd89dfbdb6b8ee71974ef554e5658d13c3fa80be43f4039886d8d09`
- [비공개 Drive 팩](https://drive.google.com/file/d/1B4TM2IbNMslFcoUxcemvbeB2G7teahZe/view)
- 위치: `data/map_remake/private/aden/` (기존 오만 `private/index.json`과 분리)

이 커밋부터 `data/map_remake/private/aden/`의 5개 파일과 고지가 Git 동기화에 포함된다. 파일별 크기·SHA-256은 `upload-manifest.json`에 있다. ZIP을 별도로 복원하는 경우 ZIP 해시를 확인하고, `aden/`이 이미 있으면 덮어쓰지 말고 백업·비교한다. 기존 오만 팩과 다른 private 리소스의 제외 규칙은 유지한다.

Python 3.11 이상과 NumPy가 필요하다. 기존 `tools/map_restore/formats.py`를 그대로 사용한다.

```bash
python3 tools/map_restore/build_aden_remake.py --verify \
  --layouts data/map_remake/private/aden/effective_layouts_build.json \
  --output data/map_remake/private/aden
ADEN_PACK="$PWD/data/map_remake/private/aden" \
ADEN_LAYOUTS="$PWD/data/map_remake/private/aden/effective_layouts_build.json" \
python3 -m unittest discover -s tools/map_restore -p test_aden_remake.py -v
```

동봉 export는 원래 빌드 입력을 검증하기 위한 것이며 미래 버전의 게임 설정과 일치한다는 보증이 아니다. 이 팩은 기존 오만 v2에 보관된 25개 맵 export(SHA-256 `0b851faa5374e193008fc42721f4af32ec017b74a3774d0118d7321c4c41f7c8`)를 사용했다. 이번 환경에서 최신 main을 Godot로 다시 export하지는 못했다. 병합 전 대상 브랜치에서 아래 명령으로 새 export를 만들고 기존 입력과 의미상 비교해야 한다. 다른 설정이라면 팩을 새 출력 디렉터리로 재생성한다.

```bash
"$GODOT" --headless --path . --script res://tools/map_restore/export_current_layouts.gd -- /tmp/aden-current-layouts.json
python3 tools/map_restore/build_aden_remake.py --a3 /path/to/a3.zip \
  --layouts /tmp/aden-current-layouts.json --output /tmp/aden-new-pack
```

생성기는 기존 출력 디렉터리가 있으면 거절한다. 새 결과를 검사한 뒤 기존 팩을 백업하고 교체한다.

## 실제 엔진 검증: 작성했지만 아직 실행하지 않은 명령

`GODOT`에는 프로젝트에 맞는 Godot 실행 파일 경로를 지정한다. Linux는 별도 `XDG_DATA_HOME`, Windows는 별도 `APPDATA`를 사용해 실제 사용자 저장 데이터를 보호한다.

```bash
export XDG_DATA_HOME="$(mktemp -d)"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --script res://tests/aden_remake_runtime_test.gd -- --output=/tmp/aden-runtime
# 실제 그래픽 디스플레이에서만 PNG 캡처. 헤드리스 요청은 실패로 표시한다.
"$GODOT" --path . --rendering-driver opengl3 \
  --script res://tests/aden_remake_runtime_test.gd -- --output=/tmp/aden-render --capture
```

작성한 런타임 검사는 실제 Main 로드, 원본 필드·렌더러 선택, 셀/스폰 확인, 기존 플레이어 입력 API를 통한 짧은 이동, 렌더 디스플레이의 PNG 저장을 검사하도록 구성했다. 해당 스크립트 자체의 컴파일/실행도 아직 검증하지 않았다. NPC 서비스 거래·보스 전투·포털 왕복·세이브 재접속·장거리 이동·Android 검증은 별도로 필요하다. 기존 `tools/map_restore/capture_maps.gd --maps=aden_world`도 같은 브랜치/팩으로 실행해 전후 화면을 확인한다. 이전 PR의 스크린샷이나 임의로 만든 그림을 이번 실행 증거로 쓰지 않는다.

## 아직 구현하지 않은 범위

S32 원본 타일·건물·오브젝트 그래픽 연결, 원본 문의 열림/닫힘 동작은 이번 변경에 들어 있지 않다. 기존 TWILIGHT 아틀라스와 오만의 격자 렌더링을 재사용한다. 원본 이미지 복원 완료, 최신 리니지M 아덴과의 일치, 실기기 품질 완료를 주장하지 않는다. 전체 격자의 큰 크기와 기존 65,536노드 경로 탐색 상한에 따른 장거리 성능/도달성도 실제 검증이 남는다.

**병합 조건:** 실제 Main에서 구 폴리곤이 아닌 원본 지형이 보이는지 확인하고, 이동/충돌·NPC·포털·보스·저장·화면 비교를 통과한 뒤 병합한다. 데이터 PASS만으로 완료 처리하지 않는다.
