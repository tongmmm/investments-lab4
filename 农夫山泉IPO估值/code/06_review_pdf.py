"""保存试渲染页文本与接触表，用于人工核对分页和图表布局。"""
from pathlib import Path
import json
from PIL import Image, ImageDraw
import pdfplumber

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"intermediate/render_check"
pdf=OUT/"农夫山泉IPO估值分析.pdf"
with pdfplumber.open(pdf) as doc:
    pages=[]
    for i,p in enumerate(doc.pages):
        s=p.extract_text() or ""
        pages.append({"page":i+1,"text":s})
    (OUT/"rendered_pages.json").write_text(json.dumps(pages,ensure_ascii=False,indent=2),encoding="utf-8")
    (OUT/"rendered_text.txt").write_text("\n\n".join(f"=== page {p['page']} ===\n{p['text']}" for p in pages),encoding="utf-8")
imgs=sorted(OUT.glob("page-*.png"))
for start in range(0,len(imgs),9):
    chunk=imgs[start:start+9]
    canvas=Image.new("RGB",(3*480,3*710),(225,229,233))
    draw=ImageDraw.Draw(canvas)
    for j,path in enumerate(chunk):
        im=Image.open(path).convert("RGB")
        im.thumbnail((460,670))
        x=(j%3)*480+10; y=(j//3)*710+28
        canvas.paste(im,(x,y))
        draw.text((x,y-20),path.stem,fill="black")
    canvas.save(OUT/f"contact_{start+1:02d}_{start+len(chunk):02d}.png")
print("Pages:",len(pages),"; review sheets:",(len(imgs)+8)//9)
print("Text lengths:",[len(p["text"]) for p in pages])
