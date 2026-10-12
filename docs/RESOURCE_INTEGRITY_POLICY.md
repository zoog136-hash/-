# TWILIGHT 리소스 누락 재발 방지 규칙 (2026-10-11)

## 핵심 원칙

**소스 ZIP 업로드 ≠ Work 환경에 설치 ≠ Git 커밋 ≠ PR 병합 ≠ 사용자가 받을 수 있는 실행본 전달 ≠ Godot 실기동.** 자동 폴백은 화면 보호용이며 원본 아트 납품을 증명하지 않는다.

현재 공개 저장소는 생성된 723개 WebP 시트와 `data/visuals/runtime_manifest.json`의 ID·SHA-256을 갖고 있지만, **리니지 원본 이미지·맵 타일·SPX 전체를 모두 포함한 것이 아니다**. `data/resource_delivery_ledger.json`에서 원본 리소스가 **미전달**임을 별도로 기록한다. 원본 맵 지형 복원은 0/25다.

## 모든 신규 Work/PR 필수 절차

1. 최신 `main` SHA 및 `TWILIGHT_PROJECT_RULES.md`, 이 문서, 리소스 상태 장부 확인. 과거 Work의 임시 RAM/폴더를 영구 저장으로 간주하지 않는다.
2. 원본 ZIP이 필요한 작업은 **현재 환경에서** 파일 존재·바이트·SHA-256·ZIP CRC 검사. 동일 SHA로 이미 확인한 파일은 반복 재변환하지 않는다. `python3 tools/check_resource_integrity.py --root . --source-dir <원본ZIP폴더>`. 접근 불가 시 그 원본 작업을 중단하고 정확한 재개 지점 기록.
3. 새로 제작한 바이너리를 Godot의 실제 로딩 경로에 넣고 `git ls-files`, `git check-ignore -v`로 추적 여부 검사. `.gitignore` 누락 상태에서 '반영 완료'라고 보고하지 않는다. 그러나 권리 검토 없이 원본 제3자 이미지를 `git add -f`로 공개 업로드하지 않는다.
4. `python3 tools/check_resource_integrity.py --root .` 필수: 723개 실제 WebP, 총 41,442프레임, Git 추적, 바이트 SHA-256 매니페스트 일치, 소스 이미지 연결. 하나라도 빠지면 실패. 합성 CI fixture/폴백을 원본 통합으로 집계 금지.
5. **재배포 권리 확인된 경우에만** 외부 원본을 접근 제어된 장기 보관소에 저장한다. 임시 Work ZIP만 있으면 **미전달**. 별도 팩은 `TWILIGHT-original-resources.zip`으로 구성하고 적법한 원본 리소스 파일을 `assets/external_l1j/`, `assets/external_spx/`, `assets/l1j/verified/`, `data/l1j/maps/` 중 맞는 경로에 둔다.
6. 해당 팩이 실제로 존재하고 다운로드 가능한 보관 위치에 있을 때만 다음으로 영수증을 만들고 검증한다:

   ```bash
   python3 tools/make_resource_delivery_receipt.py --release-dir <배포폴더>
   python3 tools/check_resource_integrity.py --root . --release-dir <배포폴더>
   ```

7. 다른 **깨끗한 clone**에서 코드와 원본 팩을 복원해 Godot import, boot, 맵·몬스터·아이템 실제 렌더/ID 연동 확인. ZIP CRC 성공만으로 지도 시각 복원이나 Godot 실행을 완료했다고 보고하지 않는다.
8. 작업 보고서와 PR에 Git SHA, 변경 파일, 포함 리소스 개수·용량·SHA, 작업 결과를 다운로드할 수 있는 검증된 위치, 실제 실행 시험, 미완료 건수, 다음 재개 지점을 기록. 파일 전송이 실패하면 **미전달**로 보고한다.

## 강제 검사 범위

- `.github/workflows/resource-integrity.yml`: PR 및 main push마다 필수 **Git 포함 리소스** 전수 검사. 723개 시트가 로컬에서만 생성됐거나, `.gitignore`로 빠졌거나, 해시가 달라지면 실패.
- `--source-dir`: 사용자 업로드 원본 6개 ZIP에 대한 현재 환경 가용성/CRC/SHA 검사. 이것만으로 Git 또는 새 Work에 전달된 건 아님.
- `--release-dir`: 별도 원본 배포 팩이 **실제로 있는지** 영수증과 SHA/크기/ZIP CRC/원본 경로·파일 수로 비교. 영수증만 적고 파일 없으면 실패.
- 전체 복원 완료 주장: 게임 내 맵 25개, 아이템·몬스터의 원본 ID 매핑과 실제 렌더 증거까지 별도 확인되어야 한다.

**결론: CI 초록색은 공개 Git에 넣은 필수 시트 검증이며, 저작권/보관 문제가 남은 외부 원본 리소스가 자동 전달됐다는 뜻은 아니다.** '전체 원본 적용 완료'는 원본 배포 증거와 새 환경 실기동 검증 없이 사용 금지.
