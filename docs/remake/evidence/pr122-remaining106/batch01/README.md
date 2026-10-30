# PR #122 batch01 — 이구아나112 / 아그니104

기존 보존 WIP를 새로 그리지 않고 복원하여 독립 시각 검토 후 production에 연결했다. **로컬 품질 단계 PASS와 CI/APK 미완료를 구분한다.** 현재 runtime 연결은 394종, 최종 완료 집계는 392종이다. 이 배치 2종은 CI/APK 대기이며 나머지 잔여는 HOLD16 + 미제작/미연결88이다. PR #100은 병합하지 않았다.

## 품질 증거

- 실제 production Main을 복사한 격리 환경에서 원래 HP·AI·공격·피격·사망·드랍·수동 습득 검사를 유지했다. headless2,499 / 기본 OpenGL2,749 / 가림 없는 실제 AI·생명주기 추가 OpenGL3,395 검사 PASS.
- 실제 Main의 production MotionController를 120Hz QA 시계로 진행하여 80방향/역할 구간과 **112+104 native 자세 전체216개**를 OpenGL로 캡처했다. 80,793검사 PASS. 직접 texture 프레임을 지정한 정적 샘플과 구분하며, 실제 벽시계 성능 영상으로 주장하지 않는다.
- 이구아나의 교대 지지다리·연결된 꼬리·창 그립·후방 해부 구조·완전한 사망 몸체, 아그니의 두 팔·연결된 불꽃 소용돌이·후방 얼굴 비노출·온전한 수축 사망을 전체 자세와 시간 순서에서 별도 검토했다. 화풍·소스별 native 크기·접지/기존 floating 표현을 실제 Main의 기존 완료 지옥의 쿠거 v3와 비교했다. 가림 없는 최종 비교295검사 PASS.
- 독립 검토는 원본 프레임을 제작하지 않은 재개 에이전트의 별도 사후 검토 단계다. 독립 사람 검토로 주장하지 않는다. 개체별 판정과 범위는 `*-independent-review.json`에 분리했다.
- 초기 아그니 나무 가림과 초기 비교 화면의 미니맵 인접 문제는 승인에 사용하지 않았다. 맵·지형·충돌·다른 개체·공격 거리를 바꾸지 않고 QA 위치/카메라만 조정했다. 기존 전경256×176 및 다른 개체192px 제외 검사를 유지했고, 실제 viewport·미니맵 가림 검사도 추가했다. 실패/초기 로그와 기존 원본은 보존했다.

## 원본·정상 자산 보존

새 production 이구아나31 PNG / 아그니16 PNG 및 두 SpriteFrames가 검토한 격리 Main/WIP와 SHA-256까지 같다. 새로 생성·필터·리사이즈한 production PNG는 없다. 두 runtime 프로필도 검토한 Main의 값과 같다. 이구아나 키 1개를 추가하고 미완료 아그니 fallback 1개만 갱신했다. 기존 다른 모든 프로필, 정상392종 에셋, 기존255개 canonical Main 보고서, 게임 코드·전투·맵·충돌·길찾기와 기존 workflow는 바꾸지 않았다. `batch01-production-preservation.json`에 실제 파일별 SHA를 기록했다.

`headless/`, `opengl/`의 네 보고서는 이번 개체별 실제 Main 증거다. 기존 canonical 보고서를 덮어쓰지 않았다. `captured-frames/`에는 **실제 framebuffer PNG378개와 파생 QA 보드15개**, 원본 로그/보고서 등을 32MiB 이하 독립 ZIP15개로 저장했다. 전체469,316,628바이트이며 각 ZIP CRC와 모든 멤버 SHA를 다시 확인했다. 모든216 native 시간 진행 프레임, 실제 AI/접촉/피격/사망/드랍/습득, 최종 같은-Main 비교와 넓은 전투 화면의 본문이 포함된다. 중복 정적 자세 스크린샷448개의 본문은 포함하지 않으며 별도 SHA 목록으로 명확히 구분했다. 이는 native 시간 진행 증거를 대체하지 않는다.

복원은 `captured-frames/manifest.json`의 ZIP SHA를 확인한 다음 **새 빈 폴더 하나**에 15개 독립 ZIP을 차례대로 풀고 멤버 SHA를 대조한다. 보고서의 당시 절대 경로는 manifest의 `source_root_at_capture` 이후 상대 경로로 해석한다. 옛 `/workspace/scratch/`가 존재한다고 가정하지 않는다. 도구 `tools/pack_remaining106_visual_evidence.py`가 같은 정책을 재현한다.

## 계속 진행할 작업

새 배치 OpenGL workflow를 추가했고 기존 필수 workflow도 이 PR의 정확한 코드 HEAD로 실행한다. CI·APK 대기를 이유로 제작을 멈추지 않는다. Android 실기기는 미검증이다. 다음 대상은 복원한 데스 서번트104자세의 고유 외형/모델/앵커/실제 근접 접촉 검토와 Main 검증이다. 유니콘은 보존된 실패 자세8개와 누락된 승인 이동 원본2개를 구분하여 HOLD를 유지하며, 무덤 가디언269는 새 E/NE 원본 선택과 남은72 nonwalk 앵커 검토부터 진행한다.
