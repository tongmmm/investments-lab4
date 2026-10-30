# 同行 beta：同一香港交易日的原始价格 -> 周收益率回归 -> 去杠杆 -> 重加杠杆。
# 只定义函数，由 03_valuation.R 调用；不联网、不写回输入文件。
estimate_peer_beta <- function(prices, financials, target_debt_weight, target_tax,
                               rmb_per_hkd, valuation_date) {
  symbols <- c("0322.HK", "0220.HK", "0345.HK", "0506.HK")
  stopifnot(setequal(unique(prices$symbol), c(symbols,"^HSI")),
            setequal(financials$symbol,symbols),
            !anyDuplicated(paste(prices$symbol,prices$date)),
            !anyDuplicated(financials$symbol),
            all(is.finite(prices$close)),all(prices$close>0),
            all(as.Date(prices$date)<valuation_date),
            all(as.Date(financials$published_date)<valuation_date),
            all(as.Date(financials$balance_date)<=as.Date(financials$published_date)))
  prices$date <- as.Date(prices$date)
  wide <- reshape(prices[,c("date","symbol","close")],idvar="date",timevar="symbol",
                  direction="wide")
  wide <- wide[order(wide$date),]
  stopifnot(all(complete.cases(wide)))
  # 同一周所有证券共同交易的最后一天；周末/休市周不向前填充。
  week <- cut(wide$date,breaks="week",start.on.monday=TRUE)
  weekly <- wide[!duplicated(week,fromLast=TRUE),]
  rownames(weekly) <- NULL
  stopifnot(as.character(weekly$date[1])=="2018-09-07",
            as.character(tail(weekly$date,1))=="2020-09-04",nrow(weekly)==105)
  values <- as.matrix(weekly[,paste0("close.",c(symbols,"^HSI"))])
  returns <- values[-1,,drop=FALSE]/values[-nrow(values),,drop=FALSE]-1
  colnames(returns) <- c(symbols,"HSI")
  estimates <- do.call(rbind,lapply(symbols,function(symbol) {
    fit <- lm(returns[,symbol]~returns[,"HSI"])
    fs <- summary(fit)
    data.frame(symbol=symbol,observations=nobs(fit),beta_levered=unname(coef(fit)[2]),
               alpha_weekly=unname(coef(fit)[1]),beta_standard_error=fs$coefficients[2,2],
               r_squared=fs$r.squared)
  }))
  estimates <- merge(financials,estimates,by="symbol",sort=FALSE)
  estimates <- estimates[match(symbols,estimates$symbol),]
  last_prices <- setNames(as.numeric(tail(values,1)[1,1:4]),symbols)
  estimates$price_hkd <- unname(last_prices[estimates$symbol])
  estimates$equity_hkd_million <- estimates$price_hkd*estimates$shares/1e6
  estimates$debt_local_million <- with(estimates,borrowings_current_million+
    borrowings_noncurrent_million+leases_current_million+leases_noncurrent_million)
  estimates$debt_hkd_million <- estimates$debt_local_million/
    ifelse(estimates$currency=="RMB",rmb_per_hkd,1)
  estimates$debt_equity <- estimates$debt_hkd_million/estimates$equity_hkd_million
  estimates$beta_unlevered <- estimates$beta_levered/
    (1+(1-estimates$tax_normalized)*estimates$debt_equity)
  unlevered_mean <- mean(estimates$beta_unlevered)
  target_debt_equity <- target_debt_weight/(1-target_debt_weight)
  target_factor <- 1+(1-target_tax)*target_debt_equity
  beta_equity <- unlevered_mean*target_factor
  alternatives <- data.frame(method=c("同行等权均值","同行中位数",
                                      paste0("剔除",estimates$company)),
    beta_unlevered=c(unlevered_mean,median(estimates$beta_unlevered),
      sapply(seq_len(nrow(estimates)),function(i) mean(estimates$beta_unlevered[-i]))))
  alternatives$beta_equity <- alternatives$beta_unlevered*target_factor
  checks <- data.frame(check=c("行情截止上市前","财报披露早于上市日","同期105个周价格与104个周收益率",
                                "回归斜率等于协方差比率","债务口径含借款及租赁"),
    passed=c(max(prices$date)<valuation_date,
             all(as.Date(financials$published_date)<valuation_date),
             nrow(weekly)==105&&nrow(returns)==104,
             max(abs(estimates$beta_levered-sapply(symbols,function(s)
               cov(returns[,s],returns[,"HSI"])/var(returns[,"HSI"]))))<1e-12,
             all(estimates$debt_local_million>=estimates$borrowings_current_million)))
  stopifnot(all(checks$passed))
  list(estimates=estimates,weekly_prices=weekly,
       weekly_returns=data.frame(date=weekly$date[-1],returns,check.names=FALSE),
       unlevered_mean=unlevered_mean,beta_equity=beta_equity,
       target_debt_equity=target_debt_equity,alternatives=alternatives,checks=checks)
}
