"""下载同行 beta 所需的历史行情与上市前财报；不使用当前网页展示的 beta。

行情：Yahoo Finance 原始日收盘价，2018-09-01 至 2020-09-04。
PDF：各公司在农夫山泉上市前已公布的财务资料。首次下载后保留原件；
再次运行读取本地快照，避免历史供应商修订悄悄改变结果。
"""
from pathlib import Path
from datetime import datetime, timezone, timedelta, date
from urllib.request import Request, urlopen
from urllib.parse import quote
import argparse
import csv
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data/raw/peer_beta"
RAW.mkdir(parents=True, exist_ok=True)
SYMBOLS = ["0322.HK", "0220.HK", "0345.HK", "0506.HK", "^HSI"]
REPORTS = {
    "tingyi_2020_interim.pdf": "https://www.hkexnews.hk/listedco/listconews/sehk/2020/0827/2020082700586_c.pdf",
    "unipresident_2020_interim.pdf": "https://www.hkexnews.hk/listedco/listconews/sehk/2020/0820/2020082000374.pdf",
    "vitasoy_202003_annual.pdf": "https://www.hkexnews.hk/listedco/listconews/sehk/2020/0716/2020071600474.pdf",
    "chinafoods_2020_interim.pdf": "https://www.hkexnews.hk/listedco/listconews/sehk/2020/0907/2020090700362.pdf",
}
PAGES = {
    "tingyi_2020_interim.pdf": [8, 17],
    "unipresident_2020_interim.pdf": [34, 57],
    "vitasoy_202003_annual.pdf": [88, 112],
    "chinafoods_2020_interim.pdf": [27, 46],
}
HK = timezone(timedelta(hours=8))
START = int(datetime(2018, 9, 1, tzinfo=timezone.utc).timestamp())
END = int(datetime(2020, 9, 5, tzinfo=timezone.utc).timestamp())

def obtain(path, url):
    if not path.exists():
        with urlopen(Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=45) as response:
            content = response.read()
        if path.suffix == ".pdf":
            assert content.startswith(b"%PDF"), "Source did not return a PDF"
        else:
            assert json.loads(content)["chart"]["error"] is None
        path.write_bytes(content)
    return {"file": path.relative_to(ROOT).as_posix(), "url": url,
            "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prices-only", action="store_true")
    args = parser.parse_args()
    manifest, daily = [], []
    for symbol in SYMBOLS:
        url = ("https://query1.finance.yahoo.com/v8/finance/chart/" + quote(symbol, safe="") +
               f"?period1={START}&period2={END}&interval=1d&events=div%2Csplits")
        path = RAW / (symbol.replace("^", "index_") + ".json")
        manifest.append(obtain(path, url))
        result = json.loads(path.read_bytes())["chart"]["result"][0]
        assert result["meta"]["currency"] == "HKD"
        quotes = result["indicators"]["quote"][0]
        events = result.get("events", {})
        splits = events.get("splits", {})
        # 使用原始价格收益率，股票与恒指保持同一价格口径。
        # 若出现拆合股，应先处理公司行动，不能把机械除权当作收益率。
        assert not splits, f"Split adjustment required for {symbol}: {splits}"
        dividends = {datetime.fromtimestamp(v["date"], HK).date(): v["amount"]
                     for v in events.get("dividends", {}).values()}
        for timestamp, close in zip(result["timestamp"], quotes["close"]):
            day = datetime.fromtimestamp(timestamp, HK).date()
            if close is not None and date(2018, 9, 1) <= day <= date(2020, 9, 4):
                daily.append({"symbol": symbol, "date": day.isoformat(), "close": close,
                              "cash_dividend": dividends.get(day, 0)})
        print(symbol, "historical observations", sum(r["symbol"] == symbol for r in daily))
    with (ROOT / "data/peer_daily_prices.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["symbol", "date", "close", "cash_dividend"])
        writer.writeheader()
        writer.writerows(daily)
    if not args.prices_only:
        for filename, url in REPORTS.items():
            manifest.append(obtain(RAW / filename, url))
            print("Saved", filename)
    manifest_path = RAW / "sources_manifest.json"
    # --prices-only 不移除此前已经保存的财报来源记录。
    if args.prices_only and manifest_path.exists():
        manifest.extend(r for r in json.loads(manifest_path.read_text(encoding="utf-8"))
                        if r["file"].endswith(".pdf"))
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    if not args.prices_only:
        import pdfplumber
        extracts = []
        for filename, pages in PAGES.items():
            with pdfplumber.open(RAW / filename) as pdf:
                extracts.extend({"file": filename, "physical_page": n,
                                 "text": pdf.pages[n-1].extract_text() or ""} for n in pages)
        target = ROOT / "intermediate/source_extracts/peer_beta_financials.json"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(extracts, ensure_ascii=False, indent=2), encoding="utf-8")

if __name__ == "__main__":
    main()
