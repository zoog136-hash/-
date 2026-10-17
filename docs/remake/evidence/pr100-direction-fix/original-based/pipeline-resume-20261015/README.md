# PR100 2D 모션 제작 파이프라인 재개 검증

완료 수량은 **389/498, 잔여109**, 실제 Main 개별118종/canonical249보고서로 유지한다. 이 체크포인트는 제작 입력 방식과 CI 회귀 검사 수정이며 신규 개체 완료를 뜻하지 않는다.

`pose_files_v1`은 104/112개 개별 원본 PNG, `mixed_sources_v1`은 온전한 다중 자세 시트와 개별 PNG를 함께 연결한다. 두 방식 모두 PNG 바이트를 그대로 복사하고 AtlasTexture 영역·가상 캔버스·검토된 발 기준점만 기록한다. PNG 합성·리사이즈·잘라낸 새 PNG는 만들지 않는다. 전체8방향/5역할, 최소2/3/3/2/3자세, 전체104/112 고유 자세, 모든 선택 PNG의 모든 몸체를 정확히 한 번 사용하도록 제한한다. 보이는 픽셀 중복·잘린 몸체·무시한 행·빈 프레임·미사용 개별 PNG를 거부한다. 기존 입력의 parser/2행 이상 검사/기하 검사/출력 방식은 유지한다. 실제 작화·기준점·비율·방향·Main 검토는 별도 필수다.

읽기 전용 검사는 `python3 tools/import_original_based_motion.py --root . --validate-candidate CANDIDATE.json --actor FOLDER --key TARGET`로 실행한다. 새 optional mode의 성공 후 명시적인 `--candidate ... --apply`만 적용한다. `--validate-candidate`는 두 optional 입력 방식에만 지원한다. 기존 legacy CLI는 `--apply` 없이도 에셋을 쓰므로 legacy 후보의 읽기 전용 검사는 각 원본의 analyze/전체 영역 검사를 별도로 수행한다. optional parser에는 제외 영역/미사용 행/phase offset 도피 인터페이스가 없다. 시트 역할은 해당 방향의 전역 phase 수 전체를 제공해야 한다.

독립 리뷰에서 발견한 링크 중 catalog 갱신 손실과 링크/최종 replace 직후 KeyboardInterrupt를 수정했다. catalog 마지막 SHA 재확인은 비협조적 동시 writer에 대한 완전한 CAS는 아니다. 최종 catalog 상태가 불명확하면 참조 중일 수 있는 새 에셋을 보존하고 오류를 반환한다. 기존50개+신규29개 검사 통과; 4개 새 경계 상황은 두 입력 방식 모두 검사한다. 기존 정상 파일은 교체하지 않고, 임시 staging·배타적 링크 후 catalog를 마지막에 갱신한다.

86b49b1 전체 CI 중 Godot·리소스·Android 빌드/정적 검사는 성공했고 애니메이션은 38개 job 중 presentation 한 개가 실패했다. 원인은 웨링의 실제 서쪽 전용 `attack_4`에 예전 좌우 반전의 음수 X 조건을 적용한 검사였다. 기존 단일 이미지의 음수 X 검사는 유지하고, native8에는 실제 W 프레임·E와의 구별·무반전·원래 texture/transform·회복 및 방향 전환 후 고정된 잔상/월드 위치를 검사한다. 수정 전 웨링과 아직 미완료 쿠거에서 실패, 수정 후 60보스/728검사 통과. 게임의 돌진·타격·그림 방향 코드는 바꾸지 않았다.

328의 실제 선택48 PNG/112자세를 별도 프로젝트에서 기존 lossless 설정 그대로 전부 로드했다. 원본 SHA와 물리/논리 치수48개를 보존했고 소프트웨어 GL GPU texture 증가량은 **383.835MiB**, 전체 실행22.078초/최대 RSS516.37MiB였다. 첫 DISPLAY 없는 GL 시도의 실패도 별도 보존했다. Main·Android·시각 품질 검증을 뜻하지 않으며 메모리 비용/압축은 HOLD다. 제작용 크기 축소나 압축 설정 변경은 없다.

정확한 코드 SHA·실패/성공 로그·독립 리뷰·메모리 probe와 결과는 validation.json 및 ZIP에 보존한다. Android 실기기 미검증, main 충돌 미해결/미병합. CI를 기다리는 동안 미완료109종의 제작·시각검토·Main 배치를 계속한다.
