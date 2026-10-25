# 현재 실행 경로 성능 점검

과거 보고서 수치를 최신 결과로 재사용하지 않았다. 측정 원본은 `performance/`에 있으며 Linux llvmpipe 소프트웨어 GL이다. Android Godot 앱 실기기, GPU 하드웨어 지연, 장시간 메모리 안정성은 미측정이다.

| 점검 경로 | 현재 코드 확인 / 조치 | 남은 한계 |
|---|---|---|
| 미니맵 0.12초 redraw | `field_minimap.gd`의 정적 polygon clipping을 새 geography cache로 이동; configure/영역 변경에 재계산 | native PNG는 해당 polygon 자료가 없어 이 부분의 수혜 없음 |
| native 카메라 정지 | `native_png_renderer.gd`의 camera/zoom/viewport/budget/field 요청 비교로 정지 시 refresh 생략 | pump_stream은 매 프레임 유지; 움직이는 전투에서 효과 작을 수 있음 |
| AUTO 후보 경로 | world의 scene 순서별 가까운 후보마다 path 호출을 거리 정렬 후 첫 도달 가능 후보로 변경 | 동거리 scene 순서·거리 경계·도달 결과 보존; 전부 실패하면 여전히 전부 탐색. 안전한 nav revision 없는 실패 TTL 캐시는 추가하지 않음 |
| 화면 밖 몬스터 | `field_population.gd`에서 기존 monster_sleep_distance 기반 physics/visibility 관리 확인 | PR155가 해당 영역을 별도 개선 중이라 중복 시스템·수치 변경 없음 |
| 전투 효과 | `combat_vfx.gd`에 기존160레코드 재사용, 화면 밖 draw 제외, 상세 그리기 예산, 만료 반납 확인 | PR122/153 효과·프레임 소유를 보존하며 별도 VFX 풀 추가 없음; 투명 겹침 GPU 측정 미완료 |
| 지도 로딩 | native renderer의 단일 worker CPU decode, 프레임당 한 chunk upload, LRU/메모리 상한 유지 | 진입 tile 동기 decode는 기존 경로. PR155 아덴 새 원화/팩 최적화 미이식 |
| 메뉴 텍스처 | 공통 icon handle 캐시, 상태 재질 palette별 단회 생성, unknown icon의 단일 캐시 키 | 실제 메뉴 draw/열기 비용은 캡처·별도 벤치 결과와 구분; 전체 item DB 텍스처 총량 미측정 |
| 드랍 수명 | ground_loot_manager의 map hide/take/prune에서 queue_free와 view 제거 확인 | 사용자 아이템/드랍 수명 규칙은 변경하지 않음; 장기 대량 드랍 soak 미수행 |
| 음향 | 기존 skill_audio6음성 유지; 새 일반/UI 피드백4+2음성 고정 및 같은 이벤트 중첩 제한 | 기존 스킬 첫 WAV 동기 load 경로는 남음. 오디오 실청취 미수행 |

정지 Escaros에서 renderer CPU 호출 비용은 줄었지만 p95/max가 악화한 단일 비교도 그대로 보존했다. 평균이나 중앙값만 보고 게임 전체 끊김이 해결됐다고 주장하지 않는다. 대표 영상은 고정 simulation 속도 캡처이며 성능 증거가 아니다.
