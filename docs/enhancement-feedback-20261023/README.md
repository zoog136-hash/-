# TWILIGHT 강화 연출 — 2026-10-23

기준 main: `a6fc6dec49f4f9a05c1e82df9a4e021b4cbe44ec`.
브랜치: `feature/twilight-enhancement-effects-20261023`.

## 변경

- 기존 중앙 결과 글자를 실제 아이템 아이콘을 사용하는 전용 강화 화면으로 교체.
- 1.85초 마력 수렴 → 결과 공개 → 3.45초 잔광 종료. 확인/ESC로 닫고, 건너뛰기는 이미 결정된 결과만 표시.
- 성공: 청백색 섬광·확산 고리·금색 입자·아이템 광택. 고강화일수록 확산 범위/입자 길이/잔광 강화.
- 실패 유지: 고리 감쇠 및 아이템 보존. 하락: 보라색 하강 광선 및 변경 수치. 소실: 적색 균열·파편·연기 및 아이콘 소멸.
- 저효과 설정은 입자/광원 레이어 수 축소. 움직임 감소는 회전/흔들림/확산/이동을 줄이고 성공 섬광 강도 축소. 기존 Master 음량/음소거 사용.
- 별도 CanvasLayer에서 표시해 강화 대상 목록 갱신과 주문서 소진 시에도 연출 유지. 키보드/터치 월드 입력과 중복 강화 요청 차단.
- 기존 장비 ID·확률·소모·강화폭·저장 형식 보존. 저장 호출을 연출 생성 전으로 이동. 결과 화면과 오디오에 RNG/지급/소모/저장 콜백 없음.

## 원작 참조와 한계

- NC 공식 앱 소개의 인챈트 청색 빛 표현: https://apps.apple.com/kr/app/id1474589366
- NC 공식 연출 건너뛰기 관련 과거 수정: https://lineagem.plaync.com/board/update/view?articleId=5ebab1b1d7a85c0001c70410&page=1&viewMode=list
- 자체 CanvasItem 연출과 합성한 자체 효과음이다. 원작 강화 CSB/SPR 또는 음원을 추출·복제한 작업이 아니다. 원작 실제 영상과 프레임 단위 비교를 확보하지 못했으므로 원작과 동등한 시각 품질/동일 타이밍 검증 완료로 보고하지 않는다.
- Android 실기기 GPU 성능 및 청취 품질 검토는 남아 있다. 원본 팩 전체 적용과도 별개다.

## 검증

Godot `4.7.2.stable.official.ed1daf0bf`.

- 리소스 무결성: 723시트 / 41,442프레임 / SHA 검증 통과.
- `test_project.py`: import, bake_navigation, boot, enhancement_reveal_test, enhancement_feedback_gameplay_test, per_instance_enchantments_smoke_test, ui_stage4_item_instance_test — 7/7 통과.
- 강화 화면 40검사. 실제 거래 추가검사 후 17검사: 중복 요청의 소모·RNG 차단, 선택 개체만 강화/파괴, 소실 아이콘 유지, 결과 공개 전 레벨·주문서·소실 디스크 저장, 잠금 거절 확인.
- 기존 물리 장비 강화/속성/저장 회귀 통과. 강화 UI 20검사, 실제 OpenGL 포인터 회귀 49검사 통과.
- Mesa llvmpipe Compatibility OpenGL 실제 렌더 14화면: 4결과 × 수렴/공개/잔광, 1920×1080 및 900×1480 저효과/움직임 감소. 화면 저장 성공과 성공 섬광의 밝기 상승 확인. 워크플로는 캡처를 CI artifact로 보관하도록 구성했으며 저장소에는 넣지 않는다.
- 전체 회귀 및 CI 최종 결과는 PR의 해당 SHA Actions에서 별도 확인. 로컬 집중 검사를 전체 회귀 완료로 계산하지 않는다.

## 새 바이너리

`python3 tools/build_enhancement_audio.py`로 재현 가능. 3개 / 총 196,376바이트 / 22,050 Hz mono PCM16.

| 경로 | 바이트 | SHA-256 |
| --- | ---: | --- |
| assets/enhancement/charge.wav | 81628 | d07c0f88c3f2bcf5314f26c75e08d9eb0d9f430939290f7d6517142f45411435 |
| assets/enhancement/success.wav | 70604 | 7c3986343a271630c8683b89d4e04b9ff35d317f51179505a4bcb6fa021a9113 |
| assets/enhancement/failure.wav | 44144 | 1cce7b18cb6b0d31948ac96981ae89dedd985b1f8688d2fb1f547708942181e5 |

새 `.github/workflows/enhancement-feedback-validate.yml`이 강화/개체/실제 입력·렌더링 증거를 검사한다. main 병합 전 사용자 승인과 최종 CI 확인이 필요하다.

## 저장 / 원격 전달 상태

- 구현과 검증 코드 커밋: `1fb6b865f112283902498ca7f115864721b20f93`.
- 최초 공개 업로드는 자동 승인 심사에서 차단되었으나, 이후 사용자가 공개 저장소 `https://github.com/zoog136-hash/-`에 업로드하고 PR을 생성하도록 명시적으로 승인했다.
- 승인에 따라 기존 feature 브랜치를 업로드하고 main 대상 PR을 생성한다. 최종 원격 SHA·PR 번호·CI 상태는 PR에서 확인한다.
- main 병합과 원작 영상 대조·Android 실기기 품질 검증은 별도 단계다.
