#!/usr/bin/env python3
"""Generate data/experience_progression_v1.json (curve version 2).

Goal: TWILIGHT levels about 3x faster than Lineage M, measured as
"monster kills per level" with Ainhasad blessing (4x) active.

Lineage M reference points (public community data, not official):
  * Lv65: one hour at Dream Island = 581 kills, 1.6677% of a level whose
    100% is 1,381,106,060 EXP  -> ~39,643 EXP per kill, ~34,839 kills/level.
    https://www.inven.co.kr/board/lineagem/5056/14150
  * Lv81-90 absolute requirements (2019).
    https://www.inven.co.kr/board/lineagem/5019/182850
  * Lv71-85 daily progress rates at a fixed daily EXP (relative curve).
    https://www.inven.co.kr/board/lineagem/5019/221186
  * Lv45: three Dragon's Holy Water (31.92M each) = 1-2 levels.
    https://www.playforum.net/news/articleView.html?idxno=634068

Assumptions (replace when better data exists):
  * Lv35-64 follow a constant 1.166x per level (fits the Lv45 holy water
    estimate against the Lv65 measurement).
  * Lv66-70 interpolate geometrically between Lv65 and Lv71.
  * Lv91 = 6x Lv90 (earlier TWILIGHT reference); Lv92+ keep the legacy
    TWILIGHT growth (x1.14 + 120) because no Lineage M data was found.
  * Lineage M per-kill EXP scales with level like TWILIGHT monster XP, so the
    TWILIGHT table is the Lineage M table times one constant.

Calibration: Lv65 TWILIGHT reference monster (화룡의 둥지 화염전사, XP 1200)
with blessing 4x = 4,800 EXP per kill.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "experience_progression_v1.json"

SPEEDUP = 3.0
LM_REQ_65 = 1_381_106_060
LM_KILLS_65 = LM_REQ_65 / (0.016677 * LM_REQ_65 / 581)  # ~34,839
TW_EXP_PER_KILL_65 = 1200 * 4
SCALE = (LM_KILLS_65 / SPEEDUP) * TW_EXP_PER_KILL_65 / LM_REQ_65

LM_ABS = {
    81: 20_001_626_310, 82: 22_415_537_902, 83: 25_086_518_006,
    84: 28_038_385_232, 85: 31_296_843_514, 86: 93_890_530_542,
    87: 375_562_122_168, 88: 1_502_248_488_672, 89: 6_008_993_954_688,
    90: 24_035_975_818_752,
}
DAILY_RATE = {71: 13.32, 72: 11.23, 73: 9.48, 74: 8.04, 75: 6.84, 76: 5.84,
              77: 5.0, 78: 4.28, 79: 3.67, 80: 3.16, 81: 2.81}
LOW_RATIO = 1.166


def lineage_m_curve() -> dict:
    lm = {65: float(LM_REQ_65)}
    for level, rate in DAILY_RATE.items():
        lm[level] = LM_ABS[81] * DAILY_RATE[81] / rate
    lm.update({k: float(v) for k, v in LM_ABS.items()})
    step = (lm[71] / lm[65]) ** (1 / 6)
    for level in range(66, 71):
        lm[level] = lm[level - 1] * step
    for level in range(64, 34, -1):
        lm[level] = lm[level + 1] / LOW_RATIO
    lm[91] = lm[90] * 6
    return lm


def build() -> dict:
    lm = lineage_m_curve()
    table = {}
    for level in range(35, 92):
        table[level] = max(1, int(round(lm[level] * SCALE)))
    for level in range(92, 101):
        table[level] = int(round(table[level - 1] * 1.14 + 120))
    return table


def holy_water_exp() -> int:
    # Lineage M holy water (31.92M) keeps 3x its share of a level.
    return int(round(31_920_000 * SCALE * SPEEDUP))


def main() -> int:
    table = build()
    holy = holy_water_exp()
    gd = (ROOT / "scripts" / "experience_progression.gd").read_text(encoding="utf-8")
    if f"const HOLY_WATER_EXP: int = {holy}" not in gd:
        print(f"HOLY_WATER_EXP in scripts/experience_progression.gd must be {holy}")
        return 1
    document = {
        "version": 2,
        "profile": "twilight_lineagem_x3_v2",
        "official_lineagem_values": False,
        "note_ko": "리니지M 공식 표가 아닙니다. 공개 커뮤니티 자료로 리니지M 레벨당 처치 수를 추정하고, TWILIGHT가 약 3배 빠르도록(아인하사드 축복 4배 기준) 환산한 값입니다. 생성: tools/generate_experience_curve.py",
        "basis_ko": "리니지M 65레벨 실측(1시간 581마리, 레벨당 약 34,839마리)의 1/3을 TWILIGHT 65레벨 기준 몬스터(경험치 1200×축복 4배)에 맞춤. 71~90은 리니지M 공개 수치의 비율, 35~64는 레벨당 1.166배, 66~70은 보간, 91은 90의 6배, 92 이후는 기존 TWILIGHT 증가율(×1.14+120).",
        "speedup_vs_lineagem": SPEEDUP,
        "calibration": {
            "lineagem_level": 65,
            "lineagem_kills_per_level": round(LM_KILLS_65),
            "twilight_reference_monster": "화룡의 둥지 화염전사",
            "twilight_reference_xp": 1200,
            "blessing_multiplier": 4,
        },
        "references": [
            "https://www.inven.co.kr/board/lineagem/5056/14150",
            "https://www.inven.co.kr/board/lineagem/5019/182850",
            "https://www.inven.co.kr/board/lineagem/5019/221186",
            "https://www.playforum.net/news/articleView.html?idxno=634068",
        ],
        "required_for_level": {str(k): v for k, v in sorted(table.items())},
    }
    text = json.dumps(document, ensure_ascii=False, indent=2) + "\n"
    if "--check" in sys.argv:
        current = OUT.read_text(encoding="utf-8")
        if current != text:
            print("experience_progression_v1.json is out of date; run without --check")
            return 1
        print("experience curve OK")
        return 0
    OUT.write_text(text, encoding="utf-8")
    print("wrote", OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
