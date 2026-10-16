# 2026-10-14 지역 테스트 타임아웃 분할 및 A3 원본 맵 복원

기준 main: a7c0390a698e43fde61ec6deea867143ead59484.

## 지역 테스트
24개 지역을 한 Godot 프로세스에서 반복 검사하고 아덴으로 24번 복귀하여 540초 타임아웃이 발생했다. faith_03까지 23개 지역 완료 기록이 있고 faith_04 자체 장애로 확인된 것은 아니다.

새 tools/world_region_shards.py는 기존 --prefix= 인수를 사용해 오만(10), 지배(1), 에스카로스(5), 알비노(4), 신념(4) 총 24개를 5개 프로세스로 검사한다. 각각 다른 임시 홈과 저장 데이터를 사용한다. 맵 진입·충돌·경로·모바일 터치·포탈·이동·자동사냥·경험치·저장/복귀의 기존 assertion은 삭제하지 않았다.

각 지역의 REGION CHECKED 표식, 각 지역군의 완주 개수, 양의 assertion 수, 종료 코드/오류, WORLD_REGIONS_OK를 모두 검증한다. 한 지역이라도 빠지거나 제한시간 초과, 오류/실패가 있으면 전체 실패 처리한다. 각각 360초 제한을 둔다. REGION TIMING 로그로 지도별 지연을 분리한다.

실행:
python3 tools/test_world_region_shards.py
python3 tools/world_region_shards.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --path . --logs test-results/world-region-shards --timeout 360

전체 테스트 실행기와 Godot Validate workflow도 분할 검사기로 연결했다.

## 맵 원본 복원(별도 팩)
사용자가 업로드한 a3.zip 및 jp-master.zip으로 기존 tools/l1j/convert_maps.py --all을 실행해 PC A3 서버 맵 캐시 1,000개를 행 우선 raw/*.bin 및 source_maps.json으로 변환했다. 1,000개 모두 타일 수와 SHA-256 검증을 통과했다. 사용자에게 ZIP으로 별도 전달한다. 공개 저장소에는 제3자 원본 바이너리를 커밋하지 않는다.

맵 ID 4: 원점 [32448,32064]; 2048 x 1536; SHA-256 c22aa61ed083a3680230c659202503d7afaef30cb41b86d4655e9f843c81a7c4.
맵 ID 101: 원점 [32704,32704]; 192 x 192; SHA-256 5e0ea64c017c6d09a8df12d4e7aa267f48a4eb150f10cd6429a199d6625e1aca.

재생성:
python3 tools/l1j/convert_maps.py --a3 /path/a3.zip --jp /path/jp-master.zip --out /tmp/twilight-a3-maps --all

이 A3 파일은 PC Lineage 서버의 맵 타일/통행 데이터이며 리니지M 배경 그래픽이나 실제 게임의 25개 맵에 자동 적용된 결과가 아니다. 라이브 data/maps/*.json, PR #100 애니메이션, 사용자 저장 파일은 건드리지 않는다. 그래픽 타일, S32 구조물, 리니지M 판본/좌표 검증은 남아 있다.

검증 완료: Python 분할 검사 단위 테스트 3개, A3 mapcache 1,000개 전체 데이터·해시 검사, 별도 ZIP CRC.
미검증: 실제 Godot 4.7.2에서 5개 지역군 완주와 A3 설치 상태 Godot 임포트 및 렌더링. 원본 WebP 일부가 없는 과거 로컬 스냅샷에 대해 게임 PASS를 주장하지 않는다.
