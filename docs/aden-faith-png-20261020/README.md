# 아덴·신념의 탑 실제 PNG / 이동 중 청크 처리

기준 main: `5a5c4ff54565e26c58a145dabe749e8c41fc7a24`. 기존 PR #128은 작업 시작 전에 외부에서 병합되어 있었다. 이 변경은 별도 브랜치에서 시작했고 PR #122/#126과 main을 변경하지 않는다.

## 실제 소스와 구현 범위

`data/maps/aden_faith_png_plan.json`에 원본 5개의 해상도, 바이트 크기, SHA-256, 알파 경계와 수동 검수 좌표가 있다. 모두 Drive 원본의 실제 바이트를 내려받아 전체 RGBA 디코딩했다. `Aden.png`는 기존 `aden_png.py`의 과거 해시와 다르므로 그 보정값을 재사용하지 않는다. PNG 번호와 서버/충돌 ID의 대응은 미확인이다.

| 기존 저장 ID | 실제 소스 | 표시/통행 |
|---|---|---|
| aden_world | Aden.png | 전체 원본 청크 표시; 궁전 앞 광장의 검수 바닥만 통행 |
| faith_01 | 13398.png | 전체 원본 표시; 중앙 남쪽 홀 검수 |
| faith_02 | 13401.png | 전체 원본 표시; 파손 바닥 경계를 별도 검수 |
| faith_03 | 13417.png | 전체 원본 표시; 중앙 카펫 홀 검수 |
| faith_04 | 13472.png | 전체 원본 표시; 폐허 홀 경계 별도 검수 |

이 다섯 ID는 기존 ID를 재사용한다. 전체 지형의 벽·물·문·가구 검수는 **미완료**다. 미검수 구역은 통행을 닫아 둔다. 신규 팩의 전경 가림 복원과 기존 몬스터/보스의 정확한 좌표 변환도 미완료다. DB, 기존 지역 JSON, 종별 수치/보상/드롭, AI, 애니메이션은 바꾸지 않았고, 좌표를 추측해 새 지형에 몬스터를 배치하지 않는다. 원래 전투 배치를 사용하려면 `--legacy-map-layouts`로 실행한다. 이 제한 때문에 전체 맵 제작 완료로 보고하거나 PR을 병합하면 안 된다.

검증된 팩을 설치하면 일반 실행에서 해당 5개 ID에 PNG가 연결된다. 팩이 없으면 기존 맵을 유지한다. PNG 저장에는 **지역별 팩 계획 해시**를 기록한다. 팩 누락/변경으로 저장 복원이 불가능하면 저장을 덮어쓰지 않는다. 기존 저장의 다른 레이아웃 좌표는 검수 진입점으로 이전하고 캐릭터 진행 데이터는 보존한다. `--native-png-maps`는 기존과 같이 별도의 검증 저장 공간을 사용한다.

## 재설치

실제 이미지는 공개 Git에 넣지 않는다. 사용자 Drive 원본 폴더에는 `Aden.png`, `13398.png`, `13401.png`, `13417.png`, `13472.png`가 있다. 변환 팩은 `TWILIGHT-Aden-Faith-PNG-20261020-private-v1.zip.part001`~`003`이며 합본/조각 해시는 `data/maps/aden_faith_png_archive.json`에 있다. Drive 업로드/재다운로드 완료 여부는 PR의 전달 상태를 확인한다. 로컬 파일만 있을 때는 영구 전달 완료가 아니다.

Drive에서 받은 조각들을 같은 폴더에 저장한 뒤:

```sh
python3 tools/map_restore/install_native_png_pack.py \
  --parts-dir /private/downloads \
  --destination /private/aden-faith-png-v1 \
  --receipt data/maps/aden_faith_png_archive.json \
  --plan data/maps/aden_faith_png_plan.json \
  --pack-receipt data/maps/aden_faith_png_pack.json
TWILIGHT_ADEN_FAITH_PNG_PACK=/private/aden-faith-png-v1 godot --path .
```

Android Godot 편집기에서 프로젝트를 실행하는 경우 검증한 설치 폴더의 내용을 프로젝트의 `external_map_packs/aden_faith_png_v1/`로 복사하면 같은 검증 경로로 자동 로드한다. 이 경로는 비공개 로컬 설치용이며 Git에 추가하지 않는다. 설치된 APK는 앱의 `user://aden_faith_png_maps/`를 사용한다. Android 앱 데이터 접근/설치 절차 및 실기 성능은 이 환경에서 검증하지 못했다. 기존 Termux ZIP 업데이터는 추적하지 않는 이 폴더를 삭제하지 않는다.

원본 5개로 재생성할 경우 기존 13474 소스는 필요 없다:

```sh
python3 tools/map_restore/build_native_png_maps.py \
  --sources /private/originals \
  --plan data/maps/aden_faith_png_plan.json \
  --output /private/new-aden-faith-pack
python3 tools/map_restore/verify_native_png_pack.py \
  --pack /private/new-aden-faith-pack --plan data/maps/aden_faith_png_plan.json
```

검증 팩은 원본 배율 1:1, 최대 1024px 청크 176개다. 검수 바닥/충돌 계획을 바꾸면 계획 해시와 팩을 함께 재생성해야 한다. 기존 v5 6맵 팩은 바이트를 바꾸지 않는다. `build_world_regions.py` 재생성으로 두 PNG 팩의 정의가 덮어써지지 않는지 검사한다.

## Android 이동 중 끊김 수정

이전 렌더러는 카메라 이동으로 새 청크가 나타날 때 화면 스레드에서 PNG 디코딩과 전경 픽셀 분리를 실행했다. 단일 저우선순위 worker로 CPU 작업을 옮기고, GPU 업로드는 프레임당 청크 하나로 나눈다. 512px 주변을 미리 읽으며 돌아온 경로는 LRU 텍스처를 재사용한다. 모바일은 가시 청크·미리 읽기·캐시 합계 RGBA 48 MiB, 데스크톱은 96 MiB로 제한한다. worker는 별도로 청크 하나와 해당 전경 조각만 CPU에 보유한다. 진입 시 첫 화면 준비는 동기로 수행한다. 지역 전환 시 이전 worker를 정리한다. 과도한 축소는 청크를 누락하는 대신 카메라 표시 범위를 제한한다.

에스카로스의 바닥 다각형 114개는 공간 색인으로 후보만 찾은 뒤 기존과 동일한 정확한 다각형 판정을 사용한다. 17,696개 점의 경계/무작위 비교에서 원래 합집합 판정과 일치했다. 전체 프레임의 다른 비용은 남아 있으므로 Android 이동 렉이 모두 해결됐다고 단정하지 않는다.

실제 Main과 기존 v5 원본으로 동일 경로 480프레임씩 측정한 결과는 `performance.json`에 있다. 소프트웨어 OpenGL 수치는 Android FPS 증명이 아니다. 실제 PNG 통합 검사는 비공개 팩으로 따로 실행하고, 공개 CI에서 팩 없는 통합 검사는 명시적으로 SKIP한다.

## 로컬 검증 기록

- 원본 5개 → 176개 실제 PNG 청크 전수 디코딩/SHA 검증. 별도 재생성 결과와 설치 팩의 index SHA 일치. 3조각 합본 CRC/해시/설치 검증 통과. **Drive 업로드는 자동 심사 거절 후 별도 승인 대기**이며 아직 영구 전달 완료가 아니다.
- 일반 실행 실제 Main: 새 5맵 219검사 통과(이동, 물리 경계, 카메라/축소, 포털/층 이동/귀환, 저장/재진입, 팩 누락 시 현재 필드·저장 보존). 별도 native 저장 실행도 219검사 통과.
- 기존 v5 실제 Main: 643검사, 101개 경로 목표, 실제 캐릭터 이동 101,493px 통과. 이 경로 검사는 물리 60Hz를 유지하며 `--fixed-fps 10`으로 시뮬레이션 시간을 가속했다. 지역 인구의 wake loop가 정지시킨 몬스터를 다시 깨워 경로 검사 중 캐릭터를 죽이는 문제는 검사에서 인구 wake loop까지 정지시켜 분리했다. 실제 인구/전투 검사는 별도로 유지한다.
- 기존 v5 실제 전경 픽셀 소유권/Y 정렬/물리 그리드: 3,870검사 통과. 모든 1,015,688개 그리드 셀과 실제 물리 사각형 일치.
- 비동기 로딩·되돌아가기 캐시·교체 중 worker 정리·48 MiB 정책: 실제 PNG 29검사 통과. 이동 중 main-thread decode 0회, Linux에서 모바일 메모리 정책으로 실제 텍스처 최대 46,238,536바이트. Android 기기를 대신한 성능 검사는 아니다.
- 공개 코드 로컬 회귀: 16개 중 11 PASS / 실제 팩 없는 통합 검사 5 SKIP. Python 코드 회귀 11 PASS; 원본 이미지 성공으로 집계하지 않음. 기존 25개 ID 검사도 각 ID의 보존과 등록된 추가 ID의 중복/누락 여부를 검증하도록 확장했다.
- 723개 기존 시트 / 41,442프레임 / 233,420,026바이트 무결성 검사 통과. 몬스터·보스 DB와 기존 5개 지역 데이터는 변경하지 않았다.
- Android 실기, 전체 지형 통행, 신규 5맵 전경 및 원래 스폰 좌표는 미검증/미완료다. Draft를 유지한다. CI 및 깨끗한 clone 결과는 PR에서 해당 커밋 SHA와 함께 확인한다.
