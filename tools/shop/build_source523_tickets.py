#!/usr/bin/env python3
"""Build a PRIVATE ticket extension; never write source probabilities into Git."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile
from build_source523_restoration import SOURCE

TICKETS={166744:57244,254088:86258,342064:91082,342074:91052,352054:63803,352064:63793}


def build(archive):
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=SOURCE:raise ValueError("source archive identity mismatch")
    with zipfile.ZipFile(archive) as pack:
        if pack.testzip() is not None:raise ValueError("source CRC failure")
        def rows(name):return json.loads(pack.read("content/"+name+".json"))["rows"]
        items={r["ID"]:r for r in rows("ItemClass")};labels={r["ID"]:r["Description"] for r in rows("DescData_Korean")}
        grades={r["ID"]:labels[r["DescID"]] for r in rows("Grade")}
        bonuses={r["ID"]:r for r in rows("Bonus")};types={r["ID"]:r["Name"] for r in rows("BonusType")}
        purchases={r["ID"]:r for r in rows("MarketPurchase_Korean")};products={r["ID"]:r for r in rows("MarketProduct")}
        relations=rows("MarketPurchaseProduct");extra=rows("MarketBonusForPurchase");gotcha=rows("GotChaEntityView")
        tickets={};pools={}
        for item_id,market_id in TICKETS.items():
            item=items[item_id];values={}
            for row in rows("ItemBonus"):
                if row["ItemClassID"]!=item_id:continue
                b=bonuses[row["BonusID"]];kind=types[b["BonusTypeID"]]
                if kind not in ["MarketPurchaseID","CannotExtendDeleteTime"] or row["IsPossession"] or b["BonusApplicationTypeID"] or b["BonusApplicationTargetID"] or kind in values:raise ValueError("unhandled ticket restriction")
                values[kind]=b["Value"]
            if item["TestItem"] or values.get("MarketPurchaseID")!=market_id or market_id not in purchases:raise ValueError("ticket/market identity mismatch")
            grants=[]
            for relation in relations+extra:
                if relation["MarketPurchaseID"]!=market_id:continue
                product=products[relation["MarketProductID"]]
                if product["UnitID"]!=35 or product["Amount"]<1 or product["Amount"]>100:raise ValueError("unsupported non-gotcha/unsafe grant")
                pool_id=product["ClassID"];grants.append({"product_id":product["ID"],"pool_id":pool_id,"count":product["Amount"]})
                if str(pool_id) not in pools:
                    entries=[r for r in gotcha if r["GotChaClassID"]==pool_id]
                    if not entries or sum(r["Probability"] for r in entries)!=1000000 or any(r["UnitID"]!=33 or r["ClassID"]!=r["BuffCardID"] or r["Probability"]<0 for r in entries):raise ValueError("incomplete original card distribution")
                    pools[str(pool_id)]=[{"card_id":r["BuffCardID"],"weight":r["Probability"],"grade_id":r["Grade"]} for r in entries]
            if not grants:raise ValueError("ticket has no original output")
            tickets[str(item_id)]={"name":labels[item["DescID"]],"grade":grades[item["GradeID"]],"original_item":item,"market_id":market_id,"cannot_extend_expiry":bool(values.get("CannotExtendDeleteTime",0)),"grants":grants}
        return {"schema":"twilight.source523.inventory-ticket-extension.v1","source_sha256":SOURCE,"tickets":tickets,"pools":pools,"owned_use_policy":"twilight_one_owned_ticket_for_linked_products","redeem_owned_when_market_not_on_sale":True}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("archive",type=Path);p.add_argument("output",type=Path);a=p.parse_args()
    target=a.output.resolve()
    if target==a.archive.resolve() or target.exists() or target.is_relative_to(Path(__file__).resolve().parents[2]):raise ValueError("choose a new private extension outside Git; preserve inputs")
    payload=(json.dumps(build(a.archive),ensure_ascii=False,separators=(",",":"))+"\n").encode();target.parent.mkdir(parents=True,exist_ok=True)
    with target.open("xb") as output:output.write(payload)
    print(json.dumps({"bytes":len(payload),"sha256":hashlib.sha256(payload).hexdigest(),"tickets":6,"pools":4,"delivery":"LOCAL_ONLY; rebuild from existing verified original backup"}))


if __name__=="__main__":main()
