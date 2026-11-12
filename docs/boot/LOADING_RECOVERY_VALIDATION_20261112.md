# 실제 완료 작업 기반 로딩과 첫 데이터 준비

## 변경 범위

통합 기준은 2026-11-12에 공개 main을 읽기 전용으로 확인한 `1c1bd94033b29b0642c79bf8c2473d73ba2953b3`이다. PR #421의 준비 데이터 streaming과 PR #422의 스킬 계약을 포함한 기존 코어 검사 123개를 유지하고 이 변경의 검사 10개를 추가한다.

- 하단 로딩바와 %는 완료한 원본 검증 작업 및 장면 load/change/ready 이정표의 개수로 계산한다. 경과 시간이나 프레임 수는 진행률을 올리지 않는다. 측정할 수 없는 단계에서는 마지막 완료 수와 상태를 유지한다.
- Main의 `_ready()` 이후 deferred 지도·선택 캐릭터 복원까지 확인한다. 누락된 지도, 보호된 저장, 명시적 초기화 거부는 100%가 되지 않는다. 준비 응답 누락 시 60초 후 재시도·오류 화면 보기를 제공하며 이 시간은 진행률 계산에 사용하지 않는다.
- 원본 metadata 검증은 순차 worker로 실행하고 완료 결과를 join한다. Main과 GL 관련 리소스 로딩은 기존 main thread를 유지한다. 검증 성공과 기기 캐시 저장 실패를 구분하고 캐시 실패 안내를 유지한다.
- 검증한 지도·타일 reader는 원본 manifest와 persisted bake SHA를 재확인해 한 번 인계한다. 개별 S32/TI2/atlas를 사용하는 기존 원본 bytes 검증은 유지한다.
- 단일 ID 정의 조회는 기존 검증된 relation index의 단일 offset을 사용한다. 원본 pin, bake/schema, 중복 거부·진단, 새 Dictionary 반환을 유지한다.
- 원문 아이템 첫 등록 범위에서 ItemData static API 확인과 Class 도메인을 재사용한다. 각 아이템의 describe·참조 검증은 계속 실행하고 source key·reset 세대로 scope를 무효화한다. 즉시 버리던 bag 증거 복사와 실제 TemplateStore의 중복 binding 병합만 줄이며 공개 API·일반 fallback·복사 계약을 보존한다.
- optional 캐릭터 모듈은 기존 profile의 로비 허용 정책을 따른다. 로비에서는 미사용 지도 준비를 Main 진입까지 미룬다. 캐릭터 모듈·선택 lease·저장 로직은 이 변경에 포함하지 않는다. 기존 버전 표시와 지난 실행 hitch 진단 표시를 유지한다.

## 복구와 검증의 구분

과거 로컬 체크포인트 `4acfa626`의 전체 보존본은 환경 교체 후 확보되지 않았다. 작성 기록과 개별 파일 SHA를 바탕으로 소스를 복원했으며 로더·일부 테스트는 동작 요구에 따라 새로 보강했다. **이 소스 전체가 과거 4ac 트리와 바이트 단위로 같다고 주장하지 않는다.** 게시 대상은 복구 후 별도로 동결·검증한 새 커밋이다.

공식 Godot 4.7.2 Linux headless와 별도 XDG 프로필을 사용한다. 소스·원본 팩·기존 사용자 저장을 변경하지 않는다. Linux 검증 stage에서만 ETC2/ASTC import를 꺼서 불필요한 Android 파생물을 만들지 않으며 production 설정은 유지한다. 새 이미지·원본 리소스 대체물은 만들지 않는다.

이 저장소의 코어 검사 목록은 133개다. 복구 후 집중 검사와 원격 CI 결과는 PR의 해당 커밋 결과를 기준으로 확인해야 한다. 이전 커밋의 통과나 합성 fixture를 현재 전체 게임·원본 지도·Android 검증으로 계산하지 않는다. 과거 AGENTS가 지시하는 `tools/check_resource_integrity.py`는 현재 main에 없어, 현행 required workflow의 `tools/check_no_legacy_resources.py` 및 negative 검사를 사용한다.

## 과거 측정 기록과 한계

다음 수치는 유실 전 대화에 기록된 `b488fb3` 기준과 `af43ebe` 코드의 순차 1회 producer 관측이다. 원시 측정 로그가 현재 복구되지 않았으므로 이 표는 **과거 기록**이며 새 커밋의 통과 근거·최신 main 전체 기동 시간·기기 성능 보장이 아니다.

| 과거 producer 관측 | b488 기준 | af43 코드 |
| --- | ---: | ---: |
| 원문 아이템 첫 등록 | 87.651882 s | 69.234864 s |
| 장비 규칙 첫 생성 | 47.322429 s | 41.402554 s |

이전 원문 정의 ZIP의 고정 identity는 25,031,173 bytes, SHA-256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`이다. 새 측정은 동일한 검증 원문, 코드별 자체 cache, 별도 profile, 전체 출력·payload 동등성을 확인해야 한다. OS cache를 비우지 않은 fresh application profile과 물리적 cold boot를 구분한다.

첫 생성에는 여전히 원본 검증과 상당한 준비 작업이 남는다. 원본 지도/media가 설치된 정상 입장, Android 실기기의 cold/warm, GPU 화면·터치 배치는 별도 검증 대상이다. SP2·텍스처 후속 작업의 효과를 이 변경의 개선으로 계산하지 않는다.

## 재현과 게시 대상

`tools/boot/benchmark_catalog_loading.py`와 `tools/boot/compare_catalog_loading.py`는 별도 원문·동결 프로젝트·새 profile을 사용하는 producer 비교 도구다. 정상 사용자 저장이나 원본 파일을 삭제하지 않는다.

게시 대상은 소스·테스트·도구·README·이 문서뿐이다. 개인 원문 ZIP, 원문에서 만든 device bake, 사용자 저장, 원시 측정 payload와 로그, 복구 중간 파일은 포함하지 않는다. 원본 전체 리소스 통합이나 원격 CI 통과를 이 문서만으로 주장하지 않는다.
