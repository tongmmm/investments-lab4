"""保留课程材料的逐页文本和小米参考模型的单元格值（只读原件）。"""
from pathlib import Path
import csv
import hashlib
import json
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "intermediate" / "source_extracts"
OUT.mkdir(parents=True, exist_ok=True)
manifest = []
for path in sorted(ROOT.glob("*.pdf")):
    if path.name == "报告.pdf":
        continue
    reader = PdfReader(path)
    pages = [{"page": i + 1, "text": p.extract_text() or ""}
             for i, p in enumerate(reader.pages)]
    (OUT / (path.stem + ".txt")).write_text(
        "\n\n".join(f"===== PDF page {p['page']} =====\n{p['text']}" for p in pages),
        encoding="utf-8")
    (OUT / (path.stem + ".json")).write_text(
        json.dumps(pages, ensure_ascii=False, indent=2), encoding="utf-8")
    manifest.append({"file": path.name, "pages": len(pages),
                     "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
try:
    import openpyxl
    path = ROOT / "小米IPO估值分析.xlsx"
    wb = openpyxl.load_workbook(path, data_only=False)
    rows = []
    cached = openpyxl.load_workbook(path, data_only=True)
    for ws in wb:
        for row in ws:
            for cell in row:
                if cell.value is not None:
                    rows.append([ws.title, cell.coordinate, cell.value,
                                 cached[ws.title][cell.coordinate].value])
    with (OUT / "xiaomi_reference_cells.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["sheet", "cell", "value_or_formula", "cached_value"])
        writer.writerows(rows)
    manifest.append({"file": path.name, "sheets": wb.sheetnames,
                     "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
except ImportError:
    print("openpyxl unavailable; PDF extraction completed")
(OUT / "source_manifest.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(manifest, ensure_ascii=False, indent=2))
