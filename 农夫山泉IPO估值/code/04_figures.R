# base R 绘图，输出可直接嵌入 qmd 的高分辨率 PNG。
if(!exists("models")) source("code/03_valuation.R",encoding="UTF-8")
dir.create("outputs/figures",recursive=TRUE,showWarnings=FALSE)
pal <- c(bear="#BD5849",base="#24577D",bull="#4B8476")
font_family <- if(.Platform$OS.type=="windows") "Microsoft YaHei" else "sans"
open_png <- function(name,height=1050) {
  png(file.path("outputs/figures",name),width=1800,height=height,res=200,type="cairo",family=font_family)
  par(mar=c(4.4,4.6,1.4,1.2),mgp=c(2.8,0.8,0),las=1,cex=1.0,
      col.axis="#444444",col.lab="#222222",bty="l")
}
open_png("01_historical_cash_quality.png")
par(mfrow=c(1,2),mar=c(4.4,4.4,2.5,1))
barplot(t(as.matrix(historical[,c("revenue","net_profit")])),beside=TRUE,
        names.arg=historical$year,col=c(pal["base"],pal["bull"]),border=NA,
        ylab="人民币亿元",ylim=c(0,270),main="收入与利润")
legend("topleft",c("营业收入","净利润"),fill=c(pal["base"],pal["bull"]),bty="n",cex=.9)
barplot(t(as.matrix(historical[,c("operating_cash_net","capex","cash_after_capex")])),
        beside=TRUE,names.arg=historical$year,col=c(pal["base"],"#B8BDC5",pal["bull"]),
        border=NA,ylab="人民币亿元",ylim=c(0,100),main="扣税后的现金创造能力")
legend("topleft",c("经营现金净额","资本开支","净额减资本开支"),
       fill=c(pal["base"],"#B8BDC5",pal["bull"]),bty="n",cex=.85)
dev.off()

open_png("02_forecast_fcff.png")
mat <- sapply(models,function(x)x$forecast$fcff_annual)
matplot(2020:2029,mat,type="o",pch=c(17,16,15),lty=c(2,1,3),lwd=2.5,
        col=pal,xlab="预测年份",ylab="全年 FCFF（人民币亿元）",xaxt="n",ylim=c(0,max(mat)*1.12))
axis(1,at=2020:2029,labels=2020:2029)
legend("topleft",c("悲观","基准","乐观"),col=pal,lty=c(2,1,3),pch=c(17,16,15),bty="n")
dev.off()

open_png("03_valuation_comparison.png")
x <- barplot(scenario_results$price_hkd,names.arg=c("悲观情景","基准情景","乐观情景"),
             col=pal,border=NA,
             ylim=c(0,max(scenario_results$price_hkd,get_ipo("opening_price_hkd"))*1.15),
             ylab="每股价值（港元）",space=.7,xlim=c(0,6.8))
text(x,scenario_results$price_hkd+1.5,sprintf("%.2f",scenario_results$price_hkd),font=2,cex=1.1)
abline(h=get_ipo("offer_price_hkd"),col="#7E6C39",lty=2,lwd=2)
abline(h=get_ipo("opening_price_hkd"),col="#BD5849",lty=3,lwd=2)
text(par("usr")[2],get_ipo("offer_price_hkd")+.9,"发行价 21.50",adj=1,col="#7E6C39",cex=.9)
text(par("usr")[2],get_ipo("opening_price_hkd")+.9,"首日开盘价 39.80",adj=1,col="#BD5849",cex=.9)
dev.off()

open_png("04_sensitivity.png",1100)
w <- sort(unique(sensitivity$wacc)); g <- sort(unique(sensitivity$terminal_g))
z <- matrix(sensitivity$price_hkd,nrow=length(w),ncol=length(g))
par(mar=c(4.5,4.8,1.5,1.5))
image(w*100,g*100,z,col=colorRampPalette(c("#F4ECE3","#CBDDE6","#4E85A2"))(50),
      axes=FALSE,xlab="WACC（%）",ylab="永续增长率（%）",xlim=range(w*100)+c(-.25,.25),
      ylim=range(g*100)+c(-.25,.25))
axis(1,at=w*100,labels=sprintf("%.1f",w*100)); axis(2,at=g*100,labels=sprintf("%.1f",g*100))
for(i in seq_along(w)) for(j in seq_along(g))
  text(w[i]*100,g[j]*100,sprintf("%.2f",z[i,j]),cex=.85,
       col=if(z[i,j]>max(z)*.8)"white" else "#20323C")
box()
dev.off()
