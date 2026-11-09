#!/usr/bin/env python3
"""Rebuild data/shop/source523_cash_market.json (KRW price -> TWILIGHT diamonds).

Inputs: the private shop523.json pack (offer/goods rows) and public NC Lineage M
notices ("[안내] ... 상품 안내"), fetched from the official community API.
Only the KRW price is taken from notices; box contents come from the original
523 definitions at runtime (scripts/shop/source523_cash_packages.gd).

  python3 tools/shop/build_cash_market_prices.py /private/shop523.json out.json
"""
import collections, html, json, math, re, ssl, sys, urllib.parse, urllib.request

API = "https://api-community.plaync.com/lineagem/board/notice"
VIEW = "https://lineagem.plaync.com/board/notice/view?articleId="
RATE = {"diamonds": 2000, "krw": 55000, "rounding": "ceil"}
TOPUPS = ["120 다이아", "400 다이아", "1200 다이아", "2000 다이아", "4000 다이아"]
# Prices not found in notices: source and value recorded explicitly.
MANUAL = {"빛나는 드래곤의 다이아몬드 상자 패키지": (55000, {"kind": "apple_app_store_iap_list",
    "url": "https://apps.apple.com/kr/app/%EB%A6%AC%EB%8B%88%EC%A7%80m/id1474589366",
    "title": "리니지M App Store 앱 내 구입", "posted": "2026-11-09", "note": "App Store 표시 가격"})}
CTX = ssl.create_default_context()


def get(url):
    request = urllib.request.Request(url, headers={"Referer": "https://lineagem.plaync.com/", "User-Agent": "TWILIGHT-price-tool"})
    return json.load(urllib.request.urlopen(request, context=CTX, timeout=30))


def notices():
    out, previous = [], 0
    while True:
        query = urllib.parse.urlencode({"isVote": "true", "moreSize": 100, "moreDirection": "BEFORE", "previousArticleId": previous})
        page = get(API + "/article/search/moreArticle?" + query)
        rows = page.get("contentList", [])
        out += [{"id": r["id"], "title": r["title"], "posted": (r.get("timestamps") or {}).get("postedAt", "")} for r in rows]
        if not rows or not page.get("hasMore"):
            return out
        previous = rows[-1]["id"]


def text(article_id):
    body = get(API + "/article/" + article_id)["article"]["content"]["content"]
    body = re.sub(r"</(div|p|tr|li)[^>]*>|<br[^>]*>", "\n", body)
    body = re.sub(r"</t[dh]>", "\t|\t", body)
    return html.unescape(re.sub(r"<[^>]+>", "", body))


def price_rows(body):
    """Product table rows: name | price | components | limit."""
    rows, current = [], None
    for line in body.split("\n"):
        if line.startswith("\t|\t"):
            if current is not None:
                current.append(line[3:])
        elif not line.strip() or line.strip() == "​":
            continue
        elif current is not None and len(current) > 1 and line.lstrip().startswith("-"):
            current[-1] += "\n" + line
        else:
            if current:
                rows.append(current)
            current = [line.strip()]
    if current:
        rows.append(current)
    found = {}
    for row in rows:
        if len(row) < 3:
            continue
        match = re.search(r"\d[\d,]*\s*원", row[1])
        if match and row[2].strip().replace("\xa0", " ").startswith("-"):
            found.setdefault(re.sub(r"\s+", "", row[0]), int(re.sub(r"\D", "", match.group())))
    return found


def main(pack_path, out_path):
    pack = json.load(open(pack_path, encoding="utf-8"))
    tables = {k: (v["rows"] if isinstance(v, dict) and "rows" in v else v) for k, v in pack["tables"].items()}
    desc = {r["ID"]: r["Description"] for r in tables["DescData_Korean"]}
    pay = {r["ID"]: r for r in tables["MarketPayment_Korean"]}
    displayed = {r["PurchaseID"] for r in tables["MarketDisplay"]}
    groups = collections.defaultdict(list)
    for row in tables["MarketPurchase_Korean"]:
        payment = pay.get(row["MarketPaymentID"], {})
        if payment.get("UnitID") == 37 and row["ID"] in displayed and row["OnSale"]:
            groups[desc.get(row["DescID"])].append((row, payment))
    articles = [n for n in notices() if "상품" in n["title"] or "패키지" in n["title"] or "상자" in n["title"]]
    cache = {}
    entries = {}
    for name, rows in sorted(groups.items()):
        if name in TOPUPS:
            continue
        rows.sort(key=lambda x: (0 if ".lineagem19_g" in x[1]["UniqueKey"] else 1 if ".lineagem_g" in x[1]["UniqueKey"] else 2, x[0]["ID"]))
        krw, origin = MANUAL.get(name, (0, None))
        for article in articles:  # newest first
            if origin:
                break
            if article["id"] not in cache:
                cache[article["id"]] = price_rows(text(article["id"]))
            value = cache[article["id"]].get(re.sub(r"\s+", "", name))
            if value:
                krw, origin = value, {"kind": "nc_official_notice", "url": VIEW + article["id"], "title": article["title"],
                                      "posted": article["posted"][:10], "note": "판매 가격은 구글 플레이 스토어 기준(공지 문구)"}
        if not origin:
            raise SystemExit("price not found: " + name)
        entries[str(rows[0][0]["ID"])] = {"name": name, "krw": krw, "diamonds": math.ceil(krw * RATE["diamonds"] / RATE["krw"]),
            "store_key": rows[0][1]["UniqueKey"], "duplicate_store_purchase_ids": [r[0]["ID"] for r in rows[1:]], "origin": origin}
    doc = {}
    doc.update({"schema": "twilight.source523.cash-market.v1", "enabled": True,
        "origin": "TWILIGHT 자체 환산 · 사용자 지정 2000다이아=55,000원 · 원작 현금 결제를 게임 다이아로 대체 (2026-11-09)",
        "rate": RATE, "payment": {"unit_id": 201, "class_id": 4, "name": "다이아"},
        "strip_products": [{"unit_id": 34, "class_id": 2, "name": "다이아", "reason": "사용자 결정: 현금 상품 구성의 다이아는 지급하지 않음"}],
        "excluded_names": TOPUPS, "excluded_reason": "다이아 충전 상품은 다이아 맞교환이 되므로 사용자 결정으로 제외", "entries": entries})
    json.dump(doc, open(out_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(entries), "offers")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
