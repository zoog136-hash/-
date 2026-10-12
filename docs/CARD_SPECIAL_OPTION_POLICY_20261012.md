# TWILIGHT card special option policy (2026-10-12)

This policy is part of a dependent PR based on PR #85; the main branch and PR #59 are not modified.

## Removal and retention rules

- Transformations: remove six named proc effects, two active skills, and two stand-alone unique techniques; keep job-specific skill modifiers and connect supported skills. Convert **375** recorded casting-speed options to a cooldown reduction of the same percentage (TWILIGHT-specific interpretation; not an official conversion formula). Remove charging-time reduction, dark immunity, dragon damage, absolute recovery, bleed accuracy, and the named Life/Death bonuses.
- Dolls: remove five named procs and two exclusive skills; leave other special traits in the catalog, visibly marked as not implemented where their original behavior is absent.
- Relics: remove four named procs, the exclusive Ultimate Dignity skill and the stand-alone Ultimate Growth ability; keep original skill-level/tick/magic penetration and other non-unique pending options explicitly displayed as unimplemented until the actual mechanics exist.
- PvP-exclusive skill execution remains out of scope as decided earlier; an offline card must never re-enable network combat.
- Regular stats (EXP, HP, weight, combat stats), classic PvE skills, item drops and saves remain intact.

## Snapshot before/after
- 변신: 413 records, 1799 original options → 1770 game options
- 마법인형: 166 records, 887 original options → 880 game options
- 성물: 144 records, 745 original options → 739 game options
- Total game catalog sourceOptions: 9561.
- Conversion: 375 transformation cast-speed entries.
- Retained: 20 skill-name modifier entries, 165 doll blessing-reduction records, 58 relic skill-level records, 144 relic cooldown records.
- Removed entries are preserved in historical Git commits and review audit; they must not be reinstated by save load.

## Removed options audit
- 변신 / 해방된 할파스: 차징 시간 감소 40% (차징 감소)
- 변신 / 해방된 할파스: 암흑 면역 (암흑 면역)
- 변신 / 해방된 할파스: 발동: 어비스 크래시 2% (고유 발동)
- 변신 / 해방된 할파스: 어비스 쉐도우 (전용 기술)
- 변신 / 지배자 기르타스: 발동 : 얼티밋 크래시 2% (고유 발동)
- 변신 / 지배자 기르타스: 차징 시간 감소 40% (차징 감소)
- 변신 / 신화-뇌신(여): 차징 시간 감소 +25% (차징 감소)
- 변신 / 진 드래곤 슬레이어: 드래곤 추가 대미지 40 (드래곤 피해)
- 변신 / 진 드래곤 슬레이어: 발동: 슬레이어 퓨리 2% (고유 발동)
- 변신 / 진 드래곤 슬레이어: 차징 시간 감소 25% (차징 감소)
- 변신 / 신화-뇌신(남): 차징 시간 감소 +25% (차징 감소)
- 변신 / 플래티넘 바포메트: 발동: 이럽션 (고유 발동)
- 변신 / 플래티넘 바포메트: 액티브 스킬: 데몬 대시 (전용 액티브)
- 변신 / 플래티넘 바포메트: 차징 시간 감소 25% (차징 감소)
- 변신 / 플래티넘 데스나이트: 발동: 헬파이어 (고유 발동)
- 변신 / 플래티넘 데스나이트: 액티브 스킬: 서먼 언데드 (전용 액티브)
- 변신 / 플래티넘 데스나이트: 콜 오브 데스 (전용 기술)
- 변신 / 플래티넘 데스나이트: 차징 시간 감소 25% (차징 감소)
- 변신 / 도펠겡어: 발동: 도펠갱어 그랩 3% (고유 발동)
- 변신 / 도펠겡어: 차징 시간 감소 25% (차징 감소)
- 변신 / 신화-기사(여): 차징 시간 감소 25% (차징 감소)
- 변신 / 신화-기사(남): 차징 시간 감소 25% (차징 감소)
- 변신 / 벨라: 차징 시간 감소 +10% (차징 감소)
- 변신 / Mr. 스모커: 차징 시간 감소 +10% (차징 감소)
- 변신 / 과거의 나이트발드: 차징 시간 감소 15% (차징 감소)
- 변신 / 세마: MP 절대 회복 +25 (절대 회복)
- 변신 / 혼돈의 연금술사: 생명 +1 (생명)
- 변신 / 질서의 연금술사: 죽음 +1 (죽음)
- 변신 / 이실로테(총): 출혈 적중 +2% (출혈 적중)
- 마법인형 / 할파스: 발동: 어비스 플레임 (고유 발동)
- 마법인형 / 할파스: 전용 스킬: 어비스 디텍션 (전용 액티브)
- 마법인형 / 지배자 기르타스: 전용 스킬: 얼티밋 디텍션 (전용 액티브)
- 마법인형 / 린드비오르: 발동:린드비오르 디스펠 +2% (고유 발동)
- 마법인형 / 발라카스: 발동:발라카스 브레스 +3% (고유 발동)
- 마법인형 / 파푸리온: 발동:파푸리온 블레싱 +3% (고유 발동)
- 마법인형 / 안타라스: 발동:안타라스 홀드 +1% (고유 발동)
- 성물 / 지배자 기르타스의 뿔: 얼티밋 그로우스 (이름형 고유 기술)
- 성물 / 지배자 기르타스의 뿔: 전용 스킬: 얼티밋 디그니티 (전용 액티브)
- 성물 / 진명황의 보주: 발동:집행3% (고유 발동)
- 성물 / 영광의 면류관: 발동:카이저1% (고유 발동)
- 성물 / 그랑카인의 현신: 발동:암흑1% (고유 발동)
- 성물 / 아인하사드의 현신: 발동:섬광1% (고유 발동)

## Validation boundary
- These counts are static data assertions, not a Godot runtime test.
- Some skill modifiers target named skills not present in the base 257-skill catalog. Retain such descriptions; they become operational only once that named PvE skill is actually implemented. Do not fabricate placeholder attacks.
- Any CI results must be verified at the new HEAD before merging; keep main and ongoing PRs separate.
