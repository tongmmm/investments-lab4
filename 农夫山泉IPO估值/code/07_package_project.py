"""将新建报告、输入、代码、结果与过程说明打包；排除原课程文件和渲染缓存。"""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT=Path(__file__).resolve().parents[1]
files=[]
for name in ["农夫山泉IPO估值分析.qmd","README.md","report_config.R",
             "references.bib","requirements.txt",".gitignore"]:
    files.append(ROOT/name)
for folder,patterns in {
    "code":["*.py","*.R"], "data":["*.csv","*.md"],
    "notes":["*.md"], "outputs/tables":["*.csv"], "outputs/figures":["*.png"],
    "data/raw":["public_sources_manifest.json"],
    "data/raw/peer_beta":["*.json"],
    "intermediate":["R_sessionInfo.txt","independent_audit.json"],
}.items():
    for pattern in patterns:
        files.extend((ROOT/folder).glob(pattern))
files=sorted(set(files))
manifest=[{"file":p.relative_to(ROOT).as_posix(),"bytes":p.stat().st_size,
           "sha256":hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]
manifest_path=ROOT/"intermediate/delivery_manifest.json"
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
files.append(manifest_path)
target=ROOT/"农夫山泉IPO估值_复现材料.zip"
with zipfile.ZipFile(target,"w",compression=zipfile.ZIP_DEFLATED) as z:
    for p in files:
        z.write(p,p.relative_to(ROOT).as_posix())
with zipfile.ZipFile(target) as z:
    assert z.testzip() is None
    assert not any(n.lower().endswith((".pdf",".xlsx")) for n in z.namelist())
print("Packaged",len(files),"files; bytes:",target.stat().st_size)
