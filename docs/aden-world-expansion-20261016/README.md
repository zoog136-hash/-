# 아덴 전역 확장 — 실제 엔진 검수 기록

기란 1차 검수는 **2026-10-16 사용자 승인 완료**로 반영한다. 승인 기준 커밋은
`8e888fe92a095166676755ae27a88240d32da49d`이다. 그 커밋의 과거 FAIL/NOT_RUN
보고와 원본 기란 파일은 그대로 보존한다. 이번 변경은 별도 전역 시각 레이어와
경계 보완이며, 최종 고증·플랫폼 검증의 통과 여부는 아래 새 기록으로 판단한다.

- [실제 Godot 화면과 원작 비교](COMPARISON.md)
- [지역별 화면 목록](SCREENSHOTS.md)
- [완료 조건별 현재 판정](VALIDATION.json)
- [S32 전역 조사](S32_ANALYSIS.json), [PC/M 차이와 남은 문제](REFERENCES_AND_DIFFERENCES.md)
- [기존 파일 보존 감사](PRESERVATION_AUDIT.json), [신규 바이너리·데이터 해시](ASSET_MANIFEST.json)
- [엔진 실행·회귀 결과](REGRESSIONS.json), [원본/자료 접근 상태](SOURCE_ACCESS.json)

새 경로는 `assets/maps/aden_world_visuals_v1/`, `data/aden_world_visuals/`,
`scripts/maps/aden_world_visuals/`이다. 기존 TWILIGHT 아트·맵 정의와 승인된
기란의 PNG/표면/71개 배치는 변경하지 않는다. 기존 아덴 팩 5개+NOTICE,
2048×1536 원본 격자와 768개 통행 청크도 재생성하지 않는다.

이전의 셀별 즉시 재질 교체와 미분류 장애물 둘레의 반복 돌벽을 제거했다.
원본 셀 좌표에 고정된 재질 룩업을 전역에서 공유하고, 경계 한 셀 안쪽의
질감을 섞는다. 아틀라스의 반대쪽 끝으로 샘플이 점프하던 반복도 연결되는
미러 샘플로 바꿨다. 실제 S32 화단 여섯 곳의 낮은 테두리는 유지한다.
자연 지형의 시각 경계를 원본 충돌선으로 대체하거나 충돌을 깎지 않는다.

613개 표준 S32 세그먼트는 읽기/쓰기 바이트 왕복과 개별 CRC를 확인했다.
대체 `_1` 세그먼트와 비표준 이름, 손상된 `tempseg.s32`는 별도로 기록한다.
S32 없는 634,880셀은 전부 원본 빈/비통행 셀이다. 이동 가능한 셀의 S32
배치 자료는 확보됐지만 **타일 ID의 원본 그림 의미는 식별 완료가 아니다**.
743,203개 자료 내 셀은 명시된 재질 가족에 대응되지 않아 인접 재질을 추론했다.

장거리 아덴 이동은 원본 마스크에서 파생한 32셀 내부 연결 성분과 실제 경계
통행선 인덱스를 사용한다. 각 구간은 검증된 공통 탐색기로 계산하고, 원본
통행선과 코너 제한을 다시 확인한다. 기존 65,536 노드 제한으로 실패하던
폭젠 구역 경로를 포함해 장거리 경로를 검사했다. 다른 맵 탐색기는 그대로다.

재현은 Godot **4.7.2 official**, Compatibility/OpenGL, X11, Mesa llvmpipe에서
독립 저장 폴더로 실행한다. Android 실기기/GPU와 동일하지 않다.

```bash
python3 tools/check_resource_integrity.py --root .
python3 tools/check_aden_world_delivery.py

# DISPLAY/Xvfb가 준비된 환경에서 각 실행마다 별도 XDG_DATA_HOME을 사용한다.
godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --script res://tests/aden_world_visuals_test.gd -- \
  --output=/tmp/aden-world --capture --overview
godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --script res://tests/aden_world_visuals_test.gd -- \
  --output=/tmp/aden-entries --capture --entrances-only
godot --headless --path . --script res://tests/aden_source_routes_test.gd
godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --script res://tests/aden_world_systems_test.gd -- --capture
```

전체 지도 PNG는 QA에서만 모든 실제 시각 청크를 함께 그린 엔진 화면이다.
실제 플레이 스트림의 49청크 제한을 해제한 성능 자료로 사용하지 않는다.
대표 지점의 이동·물리 질의·미는 입력과 전 청크 생성은 전 구간을 사람이
연속 도보로 완주했다는 뜻이 아니다. 해당 수동 검사는 NOT_RUN이다.

모든 변경은 기존 PR #120과 지정 브랜치에만 제출한다. PR #100/#121과 main은
수정하거나 병합하지 않는다. 최종 고증/입구/회귀/Android 미완료를 엔진 로딩
성공으로 바꾸지 않는다.

구현·아트·엔진 증거 커밋은 `973ee8ab8f53fe175a6145d0b9e4f171c3389b9c`이다.
원격 Git 객체 2,112개와 실제 내려받은 바이너리 45개(88,348,804 bytes)를
대조했다. [전달 영수증](REMOTE_DELIVERY.json)에 SHA가 있다. 후속 문서 커밋은
전달 상태만 기록하며 게임/아트/검사 코드는 바꾸지 않는다. 이 커밋의 엔진 CI를
중복 실행하지 않도록 문서 커밋에만 `[skip ci]`를 사용한다. 기존 구현 SHA의
CI는 별도로 유지하며 대기/실패를 통과로 표시하지 않는다.
