# 입장 비용 및 아덴 자료 후속 조사

입장 생성 경로의 반복 폴리곤 변환을 준비된 좌표/경계 검사로 바꾸고, 비활성 캐시용 격자 스냅샷 생성을 생략했다. Native PNG는 엔진에서 빈 격자를 한 번 채운 뒤 폴리곤 버킷 안의 셀만 기존의 정확한 포함 검사로 채운다. 지형·충돌·좌표·몬스터 수는 바꾸지 않는다.

동일 PC llvmpipe/Godot 4.7.2에서 `tests/map_entry_probe.gd`로 각 버전을 한 번 측정했다. 각 단계는 별도 생성 호출이므로 합계가 입장 시간과 일치하지 않는다. 고정 전투 seed를 사용한 프레임 벤치와 별개의 입장 검사이며 통계적 성능 보장은 아니다. Android 실기는 사용하지 않았다.

| 측정(ms) | 기존 | 최종 |
| --- | ---: | ---: |
| 아덴 실제 set_map | 1668.679 | 951.016 |
| 아덴 geometry configure | 1368.934 | 425.477 |
| 에스카로스 실제 set_map | 5059.104 | 2665.222 |
| 에스카로스 geometry configure | 3432.087 | 1285.350 |

아덴 77/77, 에스카로스 165/133 슬롯/생성 개체와 각각 413/929 물리 shape는 동일하다. 에스카로스 생성 지연을 몬스터 수만의 문제로 볼 수 없었다. 잔여 입장 비용 및 실제 기기 측정은 남아 있다. `entry-before.json`, 중간 `entry-after.json`, 최종 `entry-final.json`을 보존한다.

준비 전후 영역 검사 22,708개가 일치했다. 기존 전체 셀 순회와 최적화된 순회를 독립 실행하여 5개 맵 2,432,528개 셀의 solid runs, 도달 가능 영역, 스폰 후보와 순서를 비교했고 25개 검사를 통과했다. 기존 검수 통행 구조를 그대로 보존한 최적화이며 아덴 전체 도로 재구성은 아니다.

## 원본 위치 및 부족 자료

- 현재 `external_map_packs/source_pngs/Aden.png.part001/002`: 복원 SHA c0af339cbc2dbba5fb2e65c3c7f01d9467507545d7b91cbb331f5bbd51128730, 15728×7987. 이미 확보됐으며 59개 청크와 RGBA가 일치한다.
- `assets/maps/aden_world_visuals_v1/SOURCES.md`, `assets/maps/aden_giran_review_v1/SOURCES.md`: 별도 제작 아트임을 명시한다. 원본 상세 타일로 대체하지 않았다.
- `docs/aden-png-integration-20261018/SOURCE_ACCESS.json`의 과거 [Aden.png](https://drive.google.com/file/d/10M_JcAmkJa9Terc5eOoa9-vHasV1IgDD/view)는 SHA 9ce95ca285f9bee72bab355c5015779122dd354fd26e73d9664a355bf9c86be3, 동일 15728×7987이다. 더 높은 해상도라는 근거가 없고 현재 원본과 버전이 다르다.
- 같은 기록의 a3.zip(159,837,941 bytes, SHA 2d25c6d5408aaf29443167c4c82c30b32d1a83b16039d988471ba0c832eb7d20)은 [4개 분할 출처](https://drive.google.com/drive/folders/1KQ42RjHIfL3eMUhietgzQ8lru4smFoW0)를 기록한다. MAP/S32 자료가 있지만 `original_til_images: NOT_AVAILABLE_IN_A3`다.
- `data/map_remake/private/aden/NOTICE.md`의 [A3 내비게이션 팩](https://drive.google.com/file/d/1B4TM2IbNMslFcoUxcemvbeB2G7teahZe/view)은 그림이 아니다. `navigation-00.bin` 및 `definitions/aden_world.json`도 경로 데이터다. `data/l1j/maps/raw/4.bin`의 작은 CI fixture를 원본으로 취급하지 않았다.
- `data/maps/aden_png_alignment.json`은 과거 PNG의 기란 후보 정렬조차 역변환 오차 25.7576 world px로 검증 목표 4px를 넘는다고 기록한다. 현재 PNG에 자동 적용하지 않았다.

부모가 연결 자료에서 찾을 대상은 **현재 Aden.png와 같은 판의 원본 지형 TIL 및 오브젝트 그림, 타일 ID/발 기준점 대응표**다. 기존 수집 스크립트가 찾는 이름은 `*.til`, `tile.pak`, `tile.idx` (`tools/map_restore/build_giran_review.py`, `tools/l1j/recover_map_catalog.py`)이며 정확한 미전달 ZIP 이름은 기록에서 확인되지 않는다. 고해상도 전체 지형 원화와 정렬된 충돌·전경 자료도 대안이다. 현재 개요도 재업로드만으로 흐림/전체 통행을 해결할 수 없다.

PR152의 별도 발 반경/대각선 통행 변경과 중복되지 않도록 가져오지 않았다. PR122/154 자산·기능을 변경하지 않았다. 상세 원본 또는 전체 지형 수동 검수 없이는 아덴 재구성을 완료로 보고하지 않는다.

## 최종 후속 회귀 검사

최초 선택 검사 8/9 PASS. 캐시 검사는 선택 목록에서 표준 `bake_navigation` 준비 단계를 빠뜨려 기존 캐시 signature가 맞지 않아 25개 cache-hit 기대값만 실패했다(나머지 200개 정확성 검사는 통과). 기존 도구의 bake를 포함한 재검사 2/2 PASS, 225개 캐시 검사 전체 통과. 실패 로그와 재검사 로그 모두 보존한다. 생성된 캐시는 실행 증거 디렉터리에 남기고 저장소의 기존 바이너리 캐시는 그대로 보존했다. 최종 선택 10개 항목(import, bake, boot, Main 138, 번개 51, 캐시 225, raster 25, 폴리곤 인덱스, prepared 22708, terrain)이 모두 통과했으며 전체 CI 결과는 아니다.
