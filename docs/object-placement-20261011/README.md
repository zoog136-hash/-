# 기존 에셋을 사용한 월드 오브젝트 배치

`feature/twilight-reference-expansion-20261011`의 원격 최신 `21ac99ee9ae0833dccafa4abf9920927a0df0e55`에서 이어서 작업했다. 이전 대륙 지형·오만 1층 외곽·몬스터 구역·포털·좌표 체계는 유지하고 실제 건물과 자연물의 배치를 추가했다. 신규 그래픽 제작은 0개이며 기존 PNG와 절차적 소품을 그대로 사용한다.

## 적용 범위

| 실제 지도 | 이번 변경 | 검증 범위 |
|---|---|---|
| 아덴 대륙 | 기존 집과 탑을 유지하고 집 54채, 시장 11곳, 탑 6개, 성벽 15개 등을 배치. 11개 마을 구획, 숲·산악·습지·강둑에 기존 에셋 인스턴스 2,782개 추가. 기존 자연물 160개를 외곽으로 이동하고 대응 충돌도 이동. | 건물·시장 입구 65곳의 이동 경로, 서비스 NPC, 포털, 몬스터 생성 공간과 실제 물리 충돌 검사. |
| 오만 1층 | 기존 소품 21개를 유지하고 외곽 벽·기둥·횃불, 구덩이 가장자리 바위와 잔해 223개 배치. 넓은 내부 공간과 기존 입출구 유지. | 새 물리 장애물 138개, 포털·NPC 접근, 몬스터 생성 공간 검사. |
| 다른 23개 지도 | 이번 배치 패스에서 변경하지 않음. | 같은 Godot 렌더러로 전체 지도 화면 회귀 캡처. 이동·전투 회귀 결과는 검증 로그 참조. |

새 장애물은 AStar 데이터와 실제 StaticBody2D에 동시에 연결된다. 새 집·시장에는 접근 가능한 입구 좌표를 저장한다. 도로, 포털과 서비스 NPC 주변을 비워 두고, 가까운 청크만 게임 카메라에 로딩한다. 경로 검사의 최대 활성 소품은 아덴 708개, 오만 131개다. 이 숫자는 FPS나 원작 완성도를 의미하지 않는다.

글루디오의 탑 충돌·이동 격자에 막히던 창고·이동·제작 NPC와 오만 입구 안내인의 위치를 조정했다. 기란에는 기존 NPC 시각 자료와 역할을 재사용한 상인·창고·이동 안내인을 배치했다. 이 로컬 좌표와 이름은 원작의 NPC ID·서버 좌표를 복원한 결과가 아니다.

## 실제로 확인한 참고 자료

| 공개 자료 | 확인한 배치 | 적용 한계 |
|---|---|---|
| [공식 사이트의 기란 사용자 화면](https://lineagem.plaync.com/board/free/view?articleId=65143adae08a821fd62f20c9) | 넓은 광장, 상점 옆 기둥, 식재대, 창고·이동 NPC 주변 공간 | 일부 플레이 화면의 상대 구성. 전체 마을의 정확한 건물 좌표는 미확인. |
| [기란 상점 주변 플레이 화면](https://www.inven.co.kr/webzine/news/?news=263550&site=lineagem) | 광장 가장자리의 건물·상점과 중앙 기념물 | 기존 집·시장·기둥을 사용해 근사. 원작 건물이나 이벤트 동상을 새로 만들지 않음. |
| [오만 1층 외곽 플레이 화면](https://www.inven.co.kr/board/lineagem/5056/12423) | 외곽의 연속 난간과 기둥, 넓은 사냥 바닥 | 보유 에셋에 철제 난간이 없어 기존 석조 벽과 기둥으로 근사. 원작과 동일한 난간이라고 주장하지 않음. |
| [공개 아덴 대륙 지도](https://games.app-liv.jp/archives/397568) | 기존 구현의 마을·숲·산악·해안의 상대 위치 | 다른 10개 마을은 전경을 직접 대조한 복원이 아니라 지리와 보유 에셋에 따른 배치. |
| [역사적 오만 1층 지도](https://www.gamechosun.co.kr/webzine/article/view.php?no=145842) | 기존 구현의 외곽과 구덩이 위치 | 현재 버전의 개별 소품 좌표와 정확한 서버 축척은 미확인. |

참고 이미지는 조사용으로 실제 다운로드하여 열어 보았다. 프로젝트에는 해당 이미지 픽셀을 포함하지 않았으며 URL과 관찰만 기록했다. 상용 게임 원본 그래픽을 새로 편입하지 않았다. 두 기존 아틀라스와 석조 집 PNG의 바이트·SHA-256은 이전 커밋과 동일하다.

## 실행 증거

- Godot 4.7.2 Compatibility, Linux 소프트웨어 OpenGL(llvmpipe)로 실제 게임 씬을 실행했다.
- [배치 검증](evidence/validation.json): 9,251개 조건, 실패 0개. 물리 공간 조회, 이동 격자와 실제 건물 입구 경로를 검사한다.
- 전·후 각각 45장, 합계 90장. 모든 대응 화면의 카메라 위치·줌·실제 중심 좌표가 같다는 것을 [매니페스트](evidence/manifest.json)로 확인했다.
- [기란 전후](evidence/aden_world-giran-before-after.jpg), [글루디오 전후](evidence/aden_world-gludio-before-after.jpg), [동부 숲 전후](evidence/aden_world-eastern_forest-before-after.jpg), [오만 외곽 전후](evidence/oman_01-western_rail-before-after.jpg).
- [11개 마을 변경 후](evidence/after-towns.jpg), [전체 25개 지도 변경 후](evidence/after-all-25-maps.jpg). 전체 지도 캡처 성공을 원작 지도 완성으로 집계하지 않는다.
- 원본 로그: [변경 전 캡처](evidence/validation-logs/before-capture.txt), [변경 후 캡처](evidence/validation-logs/after-capture.txt), [배치 검사](evidence/validation-logs/placement-test.txt). 전체 프로젝트 검증 결과는 별도 요약과 로그에 기록한다.
- [전체 프로젝트 최종 검증](evidence/project-validation-summary.json): 110개 중 107개 통과, 실패 0개, 원본 팩 미제공 3개 건너뜀. 단일 전체 실행은 1,800초 제한에 도달해 나머지를 별도로 완료했다. 시간 초과·초기 실패와 최종 성공 로그를 함께 보존했다.
- [24개 필드 이동·전투·저장 검사](evidence/validation-logs/world_regions_test.txt): 5개 지역 계열, 5,673개 조건 통과. 기존 검사의 고정 몬스터 위치 `[1700,2416]`가 새 오만 바위 `[1728,2404]`의 이동 격자와 겹쳤으므로, 실제로 이동 가능한 직선 구간에 참가자를 놓도록 시험 장면만 수정했다. 접근 이동·처치·경험치 조건은 유지하고 참가자 위치의 유효성 검사도 추가했다.
- [실제 아덴·오만 장거리 이동](evidence/world-structure-validation.json): 907개 조건 통과. [전체 25개 지도 렌더링 검사](evidence/validation-logs/world_terrain_coverage_test.txt): 414개 조건 통과.

## 수정 소스와 재개 지점

- `data/maps/aden_field.json`, `data/maps/oman_01.json`: 실행 시 사용하는 실제 배치와 충돌 데이터.
- `data/maps/reference_object_placement.json`: 적용 범위·개수·참고 자료와 미확인 상태.
- `scripts/maps/field_renderer.gd`: 배치마다 기존 두 아틀라스 중 선택할 수 있게 연결.
- `tools/place_reference_world_objects.py`: 기준 구조 위에 기존 에셋을 배치하고 자연물 이동 장부를 남기는 도구. `object_layout_version=1`인 저장 결과 위에 재실행하지 않는다.
- `tests/reference_object_placement_test.gd`, `tests/reference_object_capture_test.gd`, `tools/build_reference_object_evidence.py`: 충돌·접근·렌더링 검증 및 동일 카메라 증거.
- `.github/workflows/pr84-world-terrain.yml`: 위 배치 검증과 게임 캡처를 기존 PR 검사에 추가.
- `tests/world_regions_test.gd`, `tools/test_project.py`: 유효한 전투 시험 위치를 사용하고 큰 아덴으로 24회 복귀하는 검사에는 제한시간 540초를 적용. CI 전체 검사에는 2,400초 제한을 적용.

다음 작업은 최신 원격 HEAD를 확인하고 저장된 배치를 유지한 채, 남은 탑 층의 실제 지도·전경 자료를 확보해 기존 오브젝트를 배치하는 것이다. 원작에 없는 방·기둥 격자를 복제하지 않는다. 정확한 원작 건물 좌표, 철제 난간 그래픽, 현대 하이네·아덴 성 건물과 다른 23개 지도 배치 복원은 미완료다. 기존의 미확인 서버 좌표와 보스 리젠 상태도 변경하지 않는다.
