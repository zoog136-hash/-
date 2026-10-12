"""Refresh public reference metadata; NEVER activate undated current DB data.

Usage: python3 tools/research_original_skills.py --cache /absolute/cache
The cache is reference material, not redistributable game art. Only factual
metadata and references are promoted to data/skills by build_original_skills.py.
"""
import argparse
import html
import json
from pathlib import Path
import re
import urllib.request
from concurrent.futures import ThreadPoolExecutor

JOBS = {1: "기사", 2: "요정", 3: "마법사", 4: "다크엘프", 5: "투사", 7: "광전사",
        8: "군주", 34: "총사", 52: "암흑기사", 81: "신성검사", 94: "사신", 111: "뇌신", 142: "마검사"}


def read_props(page):
    for match in re.finditer(r'data-props="([^"]+)"', page):
        value = json.loads(html.unescape(match.group(1)))
        if "skills" in value or "skill" in value:
            return value
    raise ValueError("Skill metadata not found; website format changed")


def request(url):
    req = urllib.request.Request(url, headers={"User-Agent": "TWILIGHT-Research/1.0"})
    with urllib.request.urlopen(req, timeout=20) as response:
        return response.read().decode("utf-8")


def refresh(cache):
    cache.mkdir(parents=True, exist_ok=True)
    roster_path = cache / "current-skill-roster.json"
    if roster_path.exists():
        roster = json.loads(roster_path.read_text())
    else:
        roster = []
        for job_id, job in JOBS.items():
            url = f"https://lineagem.inven.co.kr/db/skill/?job={job_id}"
            props = read_props(request(url))
            roster.append({"job": job, "url": url, "skills": props["skills"]})
        roster_path.write_text(json.dumps(roster, ensure_ascii=False, indent=2))
    codes = sorted({int(row["code"]) for group in roster for row in group.get("skills", [])})
    priority = [82, 99841, 55484, 55404, 55524, 65, 1, 80]
    codes = [x for x in priority if x in codes] + [x for x in codes if x not in priority]
    errors = []

    def fetch(code):
        target = cache / "details" / f"{code}.json"
        target.parent.mkdir(exist_ok=True)
        if target.exists():
            return code, True, "cached"
        try:
            props = read_props(request(f"https://lineagem.inven.co.kr/db/skill/{code}"))
            target.write_text(json.dumps(props["skill"], ensure_ascii=False, indent=2))
            return code, True, "fetched"
        except Exception as exc:
            return code, False, str(exc)

    with ThreadPoolExecutor(max_workers=4) as pool:
        for index, (code, ok, message) in enumerate(pool.map(fetch, codes), 1):
            if not ok:
                errors.append({"code": code, "error": message})
            if index % 25 == 0 or not ok:
                print(f"{index}/{len(codes)} details; failures={len(errors)}", flush=True)
    result = {"unique_current_ids": len(codes), "class_assignments": sum(len(g.get("skills", [])) for g in roster),
              "errors": errors, "historical_completeness": "UNKNOWN",
              "warning": "Current metadata has no historical validity guarantee. Never use it as the cutoff snapshot."}
    (cache / "fetch-summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2))
    print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", type=Path, required=True)
    refresh(parser.parse_args().cache)
