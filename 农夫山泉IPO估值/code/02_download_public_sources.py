"""下载公开一手资料，保留来源、下载日期及 SHA-256；原始文件不覆盖。"""
from pathlib import Path
from urllib.request import Request, urlopen
from datetime import datetime, timezone
import hashlib
import json
from pypdf import PdfReader
import pdfplumber

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
OUT = ROOT / "intermediate" / "source_extracts"
RAW.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
SOURCES = {
    "nongfu_20200825_prospectus_zh.pdf":
    "https://www1.hkexnews.hk/listedco/listconews/sehk/2020/0825/2020082500026_c.pdf",
    "nongfu_20200907_allotment_summary.pdf":
    "https://www1.hkexnews.hk/listedco/listconews/sehk/2020/0907/9432500/2020090700028_c.pdf",
}
manifest = []
for filename, url in SOURCES.items():
    path = RAW / filename
    if not path.exists():
        req = Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urlopen(req, timeout=90) as response:
            path.write_bytes(response.read())
    reader = PdfReader(path)
    target = OUT / (path.stem + ".json")
    # 部分中文字体的 CMap 会被 pypdf 错读。用 pdfplumber 提取选定的核对页。
    selected = ([9, 188, 189, 192, 198, 199, 200, 201, 207, 213, 215, 217,
                 312, 314, 315, 320, 321, 369, 430] if "prospectus" in filename
                else list(range(len(reader.pages))))
    with pdfplumber.open(path) as doc:
        pages = [{"page": i + 1, "text": doc.pages[i].extract_text() or ""}
                 for i in selected]
    target.write_text(json.dumps(pages, ensure_ascii=False, indent=2), encoding="utf-8")
    target.with_suffix(".txt").write_text("\n\n".join(
        f"===== PDF page {p['page']} =====\n{p['text']}" for p in pages), encoding="utf-8")
    manifest.append({"file": str(path.relative_to(ROOT)), "url": url,
                     "retrieved_utc": datetime.now(timezone.utc).isoformat(),
                     "pages": len(reader.pages), "extraction": "pdfplumber selected physical pages",
                     "selected_physical_pages": [i + 1 for i in selected],
                     "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
(RAW / "public_sources_manifest.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
print("Public sources saved:", len(manifest))
