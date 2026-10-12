# 실제 렌더 프리뷰

`tests/capture_original_skills.gd`는 Godot 4.7.2 Compatibility를 Xvfb/OpenGL에서 실행하여 스킬 도감, 프리뷰, 반격 오라, 다수 효과 장면을 PNG로 저장합니다. 결과는 `Original Skill Migration Validation` Actions 산출물에 포함됩니다.

현재 PNG 4장은 코드 `4911340464177de5a22167df14aceb522818d062`의 [CI 실제 실행](https://github.com/zoog136-hash/-/actions/runs/38002894586) 결과입니다. Godot 4.7.2, 1280×720, llvmpipe Compatibility에서 저장하고 이미지 내용을 확인했습니다. 원본 산출물 해시와 확인 항목은 [manifest.json](../evidence/ci-4911340/manifest.json)에 기록했습니다.

| 파일 | 실제 확인 내용 |
|---|---|
| [01-knight-catalog.png](01-knight-catalog.png) | 직업 목록, 설명, MP·HP·재사용·지속 시간; 하단 상세는 스크롤 |
| [02-skill-preview.png](02-skill-preview.png) | 독립 프리뷰의 자체 방어 효과 |
| [03-counter-aura.png](03-counter-aura.png) | 성공한 시전 후 지속 오라, 버프 표시, MP·HP 비용 반영 |
| [04-effect-crowd.png](04-effect-crowd.png) | 여러 효과 계열의 동시 출력 |

headless 부팅이나 코드 기반 SVG 아이콘을 실제 렌더 캡처로 간주하지 않습니다. 원작 영상과의 프레임 비교 및 Windows/Android 실기기 검증은 UNKNOWN입니다. 성능 수치는 소프트웨어 렌더의 효과 데모로만 해석합니다.
