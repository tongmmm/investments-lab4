# 实践4：农夫山泉 IPO 案例与估值分析

最终报告：**`农夫山泉IPO估值分析.qmd`**。原有的 `报告.qmd` 和 `报告.pdf` 是第二次作业参考文件，均保留原样。

`农夫山泉IPO估值_复现材料.zip` 是可单独解压使用的整理包，包含新报告、输入、代码、结果及过程说明，可用于上传GitHub。原始课程资料和试渲染缓存不包含在压缩包内，均仍在当前文件夹留存。

报告完整回答五道案例题。估值日期为2020-09-08，使用截至当时的历史信息，以FCFF绝对估值为主，包含同行贝塔估计、三情景、WACC与永续增长率敏感性、市场价格反向估值以及IPO股权桥接。历史行情于2026年下载，计算样本截止2020-09-04；财报披露日均早于估值日。

## 在 RStudio 中渲染

1. 将工作目录设为本文件夹，并打开 `农夫山泉IPO估值分析.qmd`。
2. 点击 **Render** 即可。报告会自动读取输入、重算模型和更新四幅图。
3. PDF使用XeLaTeX、ctexart及中文字体，排版沿用第二次作业。需要已安装Quarto、R、`knitr`、`rmarkdown`及中文LaTeX环境。

也可在R控制台运行：

```r
# 首次缺包时按需安装，不必每次运行
# install.packages(c("knitr", "rmarkdown", "quarto"))

source("code/run_all.R", encoding = "UTF-8")
quarto::quarto_render("农夫山泉IPO估值分析.qmd", output_format = "pdf")
```

命令行方式：

```text
Rscript code/run_all.R
quarto render 农夫山泉IPO估值分析.qmd --to pdf
```

模型只依赖base R；渲染不依赖Python、联网或付费终端。图表是PNG，Windows使用微软雅黑。更换电脑为macOS/Linux时，脚本自动采用系统sans字体，需自行保证系统有中文字体。

## 上传 GitHub 与修改报告链接

仓库地址：<https://github.com/tongmmm/investments-lab4>。报告中的仓库链接由作者直接在qmd引言中填写；更换仓库时，修改正文中的对应地址即可。`report_config.R`保留供现有setup读取，其中的`github_url`不再自动插入正文，无需填写。

解压最新的`农夫山泉IPO估值_复现材料.zip`，将解压后的文件和文件夹按原有结构上传到仓库根目录。包内qmd以作者最新手工编辑的版本为准，不使用此前评阅或试渲染目录中的副本。更新已有仓库时覆盖同名文件，并保留`code/`、`data/`等目录层级。最终PDF可由作者Render后另行上传。

建议上传本报告、新建的 `code/`、`data/` 中CSV和数据字典、`notes/`、`outputs/`、`references.bib`、`report_config.R`、`requirements.txt`及README。`.gitignore`已排除课程原始PDF、Excel、第二次作业源文件、下载PDF和渲染缓存，避免把无关课程材料一并上传。公开一手PDF在本地保留，且下载代码可在他人电脑重新获取。

## 分析过程与文件

| 路径 | 用途 |
|---|---|
| `notes/01_作业要求与分析设计.md` | 五题对应关系、信息截止和分析顺序 |
| `notes/02_数据核对与口径.md` | 案例更正、来源定位、现金与币种口径 |
| `notes/04_正文精简记录.md` | 后半部分的语言、结构与图表取舍记录 |
| `notes/05_同行贝塔估计.md` | 同行选择、行情回归、去杠杆、重新加杠杆及修正影响 |
| `data/historical_financials.csv` | 2017—2019标准化历史金额 |
| `data/segment_revenue.csv` | 品类收入结构 |
| `data/ipo_inputs.csv` | 上市交易事实及资本成本等显式假设 |
| `data/forecast_assumptions.csv` | 三情景逐年经营参数 |
| `data/peer_daily_prices.csv` | 四家同行及恒生指数的原始日收盘价 |
| `data/peer_financial_inputs.csv` | 同行借款、租赁、股数、日期及财报页码 |
| `data/DATA_DICTIONARY.md` | 字段、单位、空白和正负号含义 |
| `data/raw/` | 公开一手资料原件及下载摘要 |
| `intermediate/source_extracts/` | 课程资料逐页文本、原模型单元格及公开资料核对页 |
| `code/01_extract_sources.py` | 只读提取课程原件，不覆盖原件 |
| `code/02_download_public_sources.py` | 下载招股书、配发概要及中文核对页 |
| `code/03_valuation.R` | 历史比率、同一预测函数、DCF、股权桥接及分析 |
| `code/04_figures.R` | 四幅分析图表，正文选用估值对比和敏感性两幅 |
| `code/05_independent_audit.py` | Python独立复算和来源金额检查 |
| `code/06_review_pdf.py` | 保存试渲染逐页文本和排版接触表 |
| `code/07_package_project.py` | 生成复现压缩包和交付文件哈希清单 |
| `code/08_download_beta_sources.py` | 下载同行行情和财报，保留原始快照及来源哈希 |
| `code/09_peer_beta.R` | 将日行情转为周收益率，估计同行贝塔并调整资本结构 |
| `code/run_all.R` | 一次更新模型、表和图 |
| `outputs/tables/` | 十二份计算结果CSV（保留完整精度） |
| `outputs/figures/` | 四幅报告PNG |
| `intermediate/R_sessionInfo.txt` | 实际运行R环境 |
| `intermediate/independent_audit.json` | 独立复核结果 |
| `intermediate/render_check/` | 试渲染与分页核验留存 |

八份原有结果分别是历史比率、三情景结果、全部逐年预测、WACC与增长敏感性、反向估值、经营价值至股权桥接、现金与超额配股影响、模型校验。另有同行贝塔估计、周价格、周收益率、贝塔取样方案比较四份结果。

## 重做来源整理与独立复核（可选）

安装Python及 `requirements.txt` 所列包，保留课程原件后执行：

```text
python code/01_extract_sources.py
python code/02_download_public_sources.py
python code/08_download_beta_sources.py
Rscript code/run_all.R
python code/05_independent_audit.py
```

仅从GitHub复现最终模型不需要教师原件，也不需要执行第一步。下载脚本用于追溯来源，下载失败不会影响已经提供的CSV与R模型计算。同行下载脚本优先读取本地快照；原始JSON和来源清单随复现包提供，PDF保留在本地并可按清单重新下载。

## 修改模型

- 改经营情景：编辑 `data/forecast_assumptions.csv`。2020—2021资本开支覆盖值优先，其后由增量资本周转率决定。
- 改无风险利率、风险溢价或目标资本结构：编辑 `data/ipo_inputs.csv`，百分比按小数填写。贝塔由同行数据重新计算，不再有独立的0.85输入。
- 改同行数据：编辑同行财务输入或重新整理日行情，保留日期、币种和财报定位；目前程序固定使用四家同行和既定样本期间。
- 改GitHub链接：直接编辑qmd引言中的仓库地址，并同步更新本README。
- 重新运行后，正文主要数值、预测表和图随模型更新；正文的经济解释及假设文字也应人工核对，不能假定任意大幅改动仍与叙述一致。

## 判断边界

本项目进行历史课堂案例估值。贝塔由上市前同行价格收益率回归并调整杠杆得到；无风险利率、风险溢价、规范化税率、目标资本结构及长期经营参数仍含分析假设。同行业务并非完全一致，回归使用价格收益率，债务和股数采用最近已披露财报近似，也未进一步剔除同行现金持有的影响。2020年全年为预测值；三情景无发生概率；估值结论与短期股价路径不同。财务口径差异及所作近似均保留在核对说明中。
