if(.Platform$OS.type=="windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
# 在 RStudio 中把工作目录设为本项目文件夹后运行 source("code/run_all.R")。
source("code/03_valuation.R",encoding="UTF-8")
source("code/04_figures.R",encoding="UTF-8")
cat("分析及图表已更新。\n")
