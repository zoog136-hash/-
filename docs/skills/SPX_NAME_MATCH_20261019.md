# SPX 스킬 이펙트 이름 일치 우선 연결 (2026-10-19)

## 적용 의도

사용자 지시에 따라 원작 영상과의 시각적 비교는 이번 스킬 이펙트 연결 조건에서 제외합니다.
원본 SPX는 PC 리니지 계열 자료로서 리니지M 원작 이펙트와 동일하다고 표시하지 않습니다.
공개 GitHub에는 외부 원본 SPX 이미지가 포함되어 있지 않습니다. 개인 ZIP 팩 설치 시
해당 이펙트 프레임이 우선 재생되고, 팩을 설치하지 않았으면 기존 자체 도형 효과를 유지합니다.

| TWILIGHT 스킬 | 스킬 ID | 대응하는 소스 SPX | 현재 실행 |
| --- | --- | --- | --- |
| 포우 슬레이어 | lm_45d35daedfc527c9 | cast:21930·21931, impact:21928·21929 | 기존 액티브 유지 |
| 포우 슬레이어(임팩트) | lm_42262935d6f53b07 | 위 계열 공유 | BLOCKED, 시각 연결만 |
| 아우라키아 | lm_816e9fd2e2e8a4e8 | cast:19521·19522, impact(PvE):21970·21971, PvP:21968·21969 | BLOCKED, 시각 연결만 |

PvP 원본 21968·21969는 개인 팩에 pvp_impact로 준비하지만 PvE에서는 재생하지 않습니다.
신화/유일 스킬북 21916~21923은 개별 스킬명과 일치하지 않는 UI 연출이라 연결하지 않았습니다.
Enter the Dragon / Chain Reaction / Exposure of Weak Point 역시 현재 스킬명과 직접 일치하지 않으므로
드래곤 포스·체인 플레임 등으로 임의 연결하지 않았습니다.

## 개인 소스 파일을 Godot용 팩으로 만들기

이미 확보된 Google Drive a2002.zip.part001~part004 또는 합쳐진 a2002.zip가 필요합니다.
Python Pillow / numpy 와 현재 리포지토리의 tools/l1j/spx_decode.py 를 사용합니다.

명령 예시:

    python3 -m pip install Pillow numpy
    python3 tools/l1j/build_name_matched_skill_spx_pack.py \
      --source '/개인자료/a2002.zip.part001' \
      --output '/개인자료/TWILIGHT_skill_SPX_private.zip' \
      --install-root .

install-root를 생략할 경우 출력 ZIP 안의 assets/ 와 data/ 폴더를 프로젝트 루트에 직접 풉니다.
Godot 에디터에서 프로젝트를 열어 PNG를 임포트한 뒤 포우 슬레이어를 사용하면 됩니다.
화면에 표시되는 이펙트용 텍스처는 모바일 메모리 절약을 위해 긴 변 기준 최대 384px로 리샘플링합니다.
위 명령은 SPX 물리 소스 10개에서 시전·타격·PvP 보관용으로 5개 논리 재생 클립을 구성합니다.

## 기존 기능 보존

이 패치는 프레임 표시 계층에만 영향을 줍니다. 명중, 피해, 스킬 배율, MP, 쿨타임,
상태이상, 퀵슬롯, 기존 저장 데이터, 스킬 습득 여부는 변경하지 않습니다.
아우라키아 및 임팩트 파생 스킬의 BLOCKED 상태도 해제하지 않습니다.

## 검증 및 전달 상태

- 연결 설정: data/skills/external_spx_name_bindings.json
- 런타임: scripts/skills/skill_spx_bridge.gd / scripts/skills/skill_vfx.gd
- 로컬 원본 변환기: tools/l1j/build_name_matched_skill_spx_pack.py
- synthetic 테스트: tests/source_spx_skill_effect_test.gd
- 원본 10 SPX 바이너리, 생성된 개인 팩 및 Android 실기기 검증: 이 PR에 포함되지 않음
- 공개 CI의 synthetic 테스트 성공은 실제 원본 이미지의 Godot 재생 성공을 의미하지 않음
- 원본 아트의 별도 공개 배포 권한은 시각적 이름 매칭과 별개임
