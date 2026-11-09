# 원본 클라이언트 계약 적용 — P0·P1·P2 첫 단위 (2026-11-09)

인계 자료: 승인 01–46 `TWILIGHT 원본 클라이언트 계약 적용 인계 (01-46_20261109)`. 13개 파일 SHA-256을 인계 `SHA256SUMS.txt`와 대조해 전부 일치함을 확인했다. 기준은 임시 TWILIGHT 구현이 아니라 정정된 승인 01–46의 계약이다. 원본 EXE/DLL은 실행·로드·에뮬레이션하지 않았고 서버에도 접속하지 않았다. 아래 모든 인터페이스는 **DESIGN_NOT_RECOVERED_API**이며 원본 C++/API를 복원한 것이 아니다.

## 이번에 한 것

기존 게임 코드와 분리된 `scripts/original_client/`에 새 어댑터를 추가했다. **기존 런타임에는 연결하지 않았다.**

| 파일 | 계약 | 내용 |
| --- | --- | --- |
| `oc_vocab.gd` | 공통 | 증거 상태 어휘, int8/16/32 부호·폭 도우미, 바이트 단위 ASCII tolower |
| `source_identity.gd` | C01 / P0 | `SourceIdentity`, EXE/DLL 해시 고정(기원524·데이터525 분리), 다른 빌드 차단, manifest hit ≠ payload/render 성공 |
| `resource_environment.gd` | C02 / P1 | AssetPath(`../Client/`, `..` 유지), `use_packing_resource` 문자열 해석, 검색 경로 순서, delegate 교체 |
| `resource_reader.gd` | C03 / P1 | `ReadResult`(Missing/ReadFailed/EmptySuccess/Decoded/DecodeFailed), 대소문자 무시 manifest 조회, 빈 성공 시 loose 미호출, Brotli probe 실패 ≠ 평문 성공, Bundle stream 불가 |
| `resource_record.gd` | C04 / P1 | `ResourceRecord`, `NativeLayoutEvidence`, 네트워크 Land ↔ 리소스 Land join 금지, payload/entry 기준 불명 시 변환 거부, descriptor type ≠ wire type |
| `asset_resolver.gd` | C05 / P2 | IconID·AssetID 타입 분리, ItemClass→Icon→Asset→`AssetType.Path+FilePath`, 슬래시 미추가, SpellIconByWeapon 우선순위 |
| `sprite_selection.gd` | C06·C08 / P2 | action key, 1회 remap, `word0+direction`→low16/file_b/direction, FFFF fallback 분리, 방향 clamp 구분, picture 선택, 누락 방향 |
| `sprite_timing.gd` | C07 / P2 | 저장 delay, 유효 delay(폭·부호 명시), 자동 action 46..53, ordinal 종료 규칙 |

보조 자료: `data/original_client/source_lock.json`(45개 승인 출처 해시 + 정정 목록), `fixtures/p0_p2_first_fixture.json`, `acceptance_checklist.json`(95개 중 실행한 28개만 결과 기록), `tools/original_client_acceptance.py`(미실행 항목을 PASS로 바꾸지 않는 기록 도구).

## 첫 fixture (인계 지시 그대로)

- ItemClass 26 → Icon 2932 → Asset 30962 → `icon/Item/adena_3.png` (`26.png` 아님)
- 전체 remap 27255 → 23095 (1회만, 19678로 재귀하지 않음)
- `word0=7`, directional, `direction=1` → low16=8, file_b=8, asset direction=0, 주 파일 `Sprite/23095-8.sp2`

**주의:** 이 환경에는 참조 DB(`...참조DB...sqlite.xz`, 승인 43–46 `native_resource_reference.sqlite`)가 없어 실제 테이블 행을 읽지 못했다. 체인 ID와 최종 경로, remap, word0 값만 계약 문장·수치 벡터에서 옮겼고, `AssetTypeId` 등 나머지 행 값은 fixture용 합성이다(fixture JSON에 명시).

## 완료 보고 (브리프 형식)

| 항목 | 값 |
| --- | --- |
| 단계 ID | P0 (C01), P1 (C02–C04), P2 첫 단위 (C05–C08) |
| 구현 commit | `84f41cd50978aef032e60dc2f8bd98de46c88555` |
| fixture hash | `f44a096f6b4825fa03e5b3ea76140b4220d2c65645087569275e846e3cb28433` (`p0_p2_first_fixture.json` SHA-256) |
| 테스트 실행 결과 | `tests/original_client_contract_p0_p2_test.gd`: 28개 acceptance 테스트(C01-T01 … C08-T04) 전부 PASS, 확인 항목 다수, 오류·경고 0. 변형 검사(file_b 마스크 변경, 재귀 remap)는 테스트가 실패로 잡음 |
| source ID | C01 S001·S002 / C02 S003 / C03 S004·S005 / C04 S001·S002 / C05 S006–S008 / C06 S009–S012 / C07 S010·S012·S013·S014 / C08 S009·S010·S012·S015 |
| 실행하지 않은 항목 | acceptance 95개 중 **67개(C09–C28)** 미실행. `acceptance_checklist.json`에 `NOT_RUN_ON_IMPLEMENTATION`으로 남김 |

## 원본과 달라진 DESIGN 동작

원본이 방어하지 않는 입력은 위험하게 복제하지 않고 DESIGN 검증층에서 거절하거나 표시한다. 정상 도메인의 계산은 그대로다.

- FPS 0, runtime rate 0 → 거절(`FPS_ZERO_REJECTED`, `RATE_ZERO_REJECTED`). `INT_MIN / -1` IDIV도 거절.
- actor+178 bucket shift는 confirmed 범위(bucket 0·1)만 계산하고 그 외는 `BUCKET_SHIFT_UNVERIFIED`.
- stored delay × 1000000이 signed32 범위를 넘으면 호환 값은 계산하되 `OUTSIDE_NORMAL_DOMAIN_COMPAT_VALUE`로 표시.
- actor 경로의 direction 0..7 밖 입력은 clamp하지 않고(원본 actor 경로에 clamp 없음) `OUTSIDE_NORMAL_DOMAIN_NO_ORIGINAL_CLAMP`로 표시.
- EXE 해시가 고정값과 다르거나 모르는 모듈이면 어댑터 진입 차단.
- AssetPath 입력은 끝 구분자가 없으면 거절(`splitpath` 결과 형식 전제).
- 한 번 읽은 loose 파일은 decode 단계가 없으므로 `Decoded`로 표시하되 provenance에 `loose_read_ok_no_decode_step`을 남김.
- JSON에서 읽은 id(float)는 정수일 때만 정수 키로 정규화하여 조회.

## 남은 미검증·미구현

- C09–C28(보조 레이어, 캐시 수명, 지도/입력, actor/효과, UI, 장면 통합 등)은 아직 시작하지 않았다.
- `2500` 구간 폴더 fallback 이름 규칙은 인계 JSON에 구체 형식이 없어 `fallback_name=null`로 두었다(참조 DB `logical_assets.fallback_name`에서 확인 필요).
- 실제 current 테이블 행·참조 DB·SP2 payload는 사용하지 않았다. SP2 payload decode와 frame 수는 caller가 줄 때만 사용하며 그 외는 `UNVERIFIED`.
- 자동 action의 "source frame start0 copy 생략 예외"는 모델링하지 않았다.
- 새 어댑터를 현재 게임 로직에 연결하지 않았다. CI 필수 게이트(`tools/ci_core.py`)에도 등록하지 않았다. 등록은 사용자 결정이 필요하다.
- 테스트는 전체 프로젝트가 아니라 필요한 파일만 담은 최소 Godot 4.7.2 프로젝트(headless)에서 실행했다. 전체 프로젝트 임포트는 에셋 용량 때문에 이 환경에서 제한 시간 안에 끝나지 않았다.
- 원본 바이너리를 실행하지 않았으므로 native 동등성이나 실제 화면 완성을 주장하지 않는다.
- 서버 경계: 전투·AI·spawn·drop·경제는 이 모듈에 포함하지 않았다(P8, 별도 설계).

## 재실행 방법

```bash
godot --headless --path <최소 프로젝트 또는 저장소> --script res://tests/original_client_contract_p0_p2_test.gd
python3 tools/original_client_acceptance.py --run-log <출력 파일> --commit <SHA>
```
