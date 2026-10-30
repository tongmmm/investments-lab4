# 农夫山泉 IPO 估值。货币单位：人民币亿元；股数单位：亿股。
# 仅依赖 base R。可独立运行，也可由报告 source() 调用。
if(.Platform$OS.type=="windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
options(stringsAsFactors = FALSE, scipen = 20)
read_input <- function(name) read.csv(file.path("data", name), check.names = FALSE,
                                    fileEncoding = "UTF-8-BOM")
historical <- read_input("historical_financials.csv")
assumptions <- read_input("forecast_assumptions.csv")
ipo_table <- read_input("ipo_inputs.csv")
ipo <- setNames(ipo_table$value, ipo_table$key)
get_ipo <- function(key) unname(ipo[[key]])
valuation_date <- as.Date("2020-09-08")
cash_date <- as.Date("2020-07-31")
end2020 <- as.Date("2020-12-31")
remaining_fraction <- as.numeric(end2020 - valuation_date) / 366
bridge_fraction <- as.numeric(valuation_date - cash_date) / 366
shares_post <- get_ipo("pre_ipo_shares") + get_ipo("new_shares")
source("code/09_peer_beta.R",encoding="UTF-8")
peer_beta <- estimate_peer_beta(read_input("peer_daily_prices.csv"),
  read_input("peer_financial_inputs.csv"),get_ipo("debt_weight"),get_ipo("tax"),
  get_ipo("rmb_per_hkd"),valuation_date)
beta_equity <- peer_beta$beta_equity
ke <- get_ipo("rf") + beta_equity * get_ipo("erp")
wacc_base <- ke * (1-get_ipo("debt_weight")) +
  get_ipo("kd") * (1-get_ipo("tax")) * get_ipo("debt_weight")

historical$gross_profit <- historical$revenue-historical$cost_of_sales
historical$reported_ebit <- historical$pretax_profit+historical$finance_cost
# 自定义主营利润代理：毛利减销售与行政开支，不是公司披露的调整后利润。
historical$core_ebit_proxy <- historical$gross_profit-historical$selling-historical$administration
historical$da <- historical$depreciation_ppe+historical$depreciation_rou+historical$amortization
historical$nwc_trade <- with(historical, int_inventory+trade_receivables+
                               prepayment_suppliers-trade_payables-contract_liabilities)
historical$gross_margin <- historical$gross_profit/historical$revenue
historical$core_margin <- historical$core_ebit_proxy/historical$revenue
historical$net_margin <- historical$net_profit/historical$revenue
historical$cash_conversion <- historical$operating_cash_net/historical$net_profit
historical$cash_after_capex <- historical$operating_cash_net-historical$capex
historical$effective_tax <- historical$income_tax/historical$pretax_profit
historical$revenue_growth <- c(NA, diff(historical$revenue)/head(historical$revenue,-1))
h19 <- historical[historical$year==2019, ]

build_forecast <- function(scenario="base", uniform_growth=NULL) {
  a <- assumptions[assumptions$scenario==scenario, ]
  a <- a[order(a$year), ]
  if(!is.null(uniform_growth)) a$revenue_growth[a$year>=2021] <- uniform_growth
  f <- a
  f$revenue <- h19$revenue*cumprod(1+a$revenue_growth)
  f$ebit <- f$revenue*f$ebit_margin
  f$tax <- f$ebit*get_ipo("tax")
  f$nopat <- f$ebit-f$tax
  f$da <- f$revenue*f$da_ratio
  f$nwc_trade <- f$revenue*f$nwc_ratio
  f$required_cash <- f$revenue*get_ipo("minimum_operating_cash_ratio")
  f$invested_wc <- f$nwc_trade+f$required_cash
  opening_wc <- h19$nwc_trade+h19$revenue*get_ipo("minimum_operating_cash_ratio")
  f$delta_wc <- f$invested_wc-c(opening_wc, head(f$invested_wc,-1))
  f$delta_required_cash <- f$required_cash-c(
    h19$revenue*get_ipo("minimum_operating_cash_ratio"), head(f$required_cash,-1))
  # 新增收入需要新增投入资本。2020-2021采用招股书计划；以后按资本周转率约束再投资。
  f$delta_revenue <- f$revenue-c(h19$revenue,head(f$revenue,-1))
  f$reinvestment_required <- f$delta_revenue/f$incremental_capital_turnover
  f$capex <- ifelse(is.na(f$capex_override),
                    f$da+f$reinvestment_required-f$delta_wc, f$capex_override)
  f$fcff_annual <- f$nopat+f$da-f$capex-f$delta_wc
  # 上市日前的现金流不再计入经营价值。2020 年按剩余天数折算。
  f$included_fraction <- c(remaining_fraction, rep(1, nrow(f)-1))
  f$fcff_included <- f$fcff_annual*f$included_fraction
  # 各年年末支付。首年真实剩余天数/365.25，后续每年增加1。
  f$discount_years <- as.numeric(end2020-valuation_date)/365.25+seq(0,nrow(f)-1)
  f
}

value_forecast <- function(f, wacc=NULL, terminal_g=NULL, terminal_roic=NULL) {
  if(is.null(wacc)) wacc <- wacc_base+f$wacc_shift[1]
  if(is.null(terminal_g)) terminal_g <- f$terminal_g[1]
  if(is.null(terminal_roic)) terminal_roic <- f$terminal_roic[1]
  stopifnot(wacc>terminal_g, terminal_roic>terminal_g, nrow(f)==10)
  f$discount_factor <- (1+wacc)^(-f$discount_years)
  f$pv_fcff <- f$fcff_included*f$discount_factor
  last <- tail(f,1)
  terminal_revenue <- last$revenue*(1+terminal_g)
  terminal_nopat <- terminal_revenue*last$terminal_margin*(1-get_ipo("tax"))
  terminal_reinvestment <- terminal_nopat*terminal_g/terminal_roic
  terminal_fcff <- terminal_nopat-terminal_reinvestment
  terminal_value <- terminal_fcff/(wacc-terminal_g)
  terminal_pv <- terminal_value*last$discount_factor
  enterprise_value <- sum(f$pv_fcff)+terminal_pv
  # 7月末现金已含此前现金流；只推算7月末至上市日的现金变化。
  # FCFF扣除的必要现金增加仍属于账面现金，故在现金余额桥接中加回。
  bridge_interest <- get_ipo("debt_june30")*get_ipo("kd")*(1-get_ipo("tax"))*bridge_fraction
  bridge_cashflow <- (f$fcff_annual[1]+f$delta_required_cash[1])*bridge_fraction-bridge_interest
  ipo_net_rmb <- get_ipo("ipo_net_proceeds_hkd")*get_ipo("rmb_per_hkd")
  cash_at_ipo <- get_ipo("cash_july31")+bridge_cashflow-get_ipo("special_dividend")+ipo_net_rmb
  operating_cash <- f$required_cash[1]
  equity_adjustment <- cash_at_ipo-operating_cash-get_ipo("debt_june30")-get_ipo("lease_june30")
  equity_value <- enterprise_value+equity_adjustment
  price_rmb <- equity_value/shares_post
  price_hkd <- price_rmb/get_ipo("rmb_per_hkd")
  summary <- data.frame(scenario=f$scenario[1], wacc=wacc, terminal_g=terminal_g,
    terminal_roic=terminal_roic, explicit_pv=sum(f$pv_fcff), terminal_fcff=terminal_fcff,
    terminal_reinvestment=terminal_reinvestment, terminal_value=terminal_value,
    terminal_pv=terminal_pv, enterprise_value=enterprise_value,
    bridge_cashflow=bridge_cashflow, cash_at_ipo=cash_at_ipo, operating_cash=operating_cash,
    equity_adjustment=equity_adjustment, equity_value=equity_value,
    shares=shares_post, price_rmb=price_rmb, price_hkd=price_hkd,
    terminal_share=terminal_pv/enterprise_value,
    offer_premium=get_ipo("offer_price_hkd")/price_hkd-1,
    opening_premium=get_ipo("opening_price_hkd")/price_hkd-1,
    offer_downside=price_hkd/get_ipo("offer_price_hkd")-1,
    opening_downside=price_hkd/get_ipo("opening_price_hkd")-1)
  list(forecast=f, summary=summary)
}

models <- setNames(lapply(c("bear","base","bull"), function(s) value_forecast(build_forecast(s))),
                   c("bear","base","bull"))
scenario_results <- do.call(rbind,lapply(models, function(m) m$summary))
base <- models$base$summary
forecast_base <- models$base$forecast
sensitivity <- expand.grid(wacc=seq(0.055,0.095,0.005), terminal_g=seq(0.02,0.04,0.005))
sensitivity$price_hkd <- mapply(function(w,g) value_forecast(build_forecast(),w,g)$summary$price_hkd,
                              sensitivity$wacc,sensitivity$terminal_g)
sensitivity_base_check <- value_forecast(build_forecast(),wacc_base,0.03)$summary$price_hkd

reverse_results <- do.call(rbind,lapply(c(get_ipo("offer_price_hkd"),get_ipo("opening_price_hkd")),
  function(target) {
    implied_wacc <- uniroot(function(w) value_forecast(build_forecast(),w)$summary$price_hkd-target,
                            c(0.035,0.20),tol=1e-11)$root
    implied_growth <- uniroot(function(g) value_forecast(build_forecast(uniform_growth=g))$summary$price_hkd-target,
                              c(-0.05,0.35),tol=1e-11)$root
    data.frame(target_hkd=target, implied_wacc=implied_wacc,
               implied_constant_growth_2021_2029=implied_growth)
  }))
bridge <- data.frame(item=c("经营价值","7月末非受限存款","上市前估计现金增加",
  "上市前特别分红","IPO净募资折人民币","必要经营现金","计息借款","租赁负债","股权价值"),
  amount=c(base$enterprise_value,get_ipo("cash_july31"),base$bridge_cashflow,
    -get_ipo("special_dividend"),get_ipo("ipo_net_proceeds_hkd")*get_ipo("rmb_per_hkd"),
    -base$operating_cash,-get_ipo("debt_june30"),-get_ipo("lease_june30"),base$equity_value))
robustness <- data.frame(change=c("基准","上市日现金少5亿元","上市日现金多5亿元",
  "IPO超额配股权全部行使"),price_hkd=c(base$price_hkd,
  (base$equity_value-5)/shares_post/get_ipo("rmb_per_hkd"),
  (base$equity_value+5)/shares_post/get_ipo("rmb_per_hkd"),
  (base$equity_value+12.27*get_ipo("rmb_per_hkd"))/(shares_post+0.582346)/get_ipo("rmb_per_hkd")))

beta_alternatives <- peer_beta$alternatives
beta_alternatives$wacc <- (get_ipo("rf")+beta_alternatives$beta_equity*get_ipo("erp"))*
  (1-get_ipo("debt_weight"))+get_ipo("kd")*(1-get_ipo("tax"))*get_ipo("debt_weight")
beta_alternatives$price_hkd <- sapply(beta_alternatives$wacc,function(w)
  value_forecast(build_forecast(),wacc=w)$summary$price_hkd)
# 原先0.85仅保留为对照，不再作为基准输入。
old_wacc <- (get_ipo("rf")+0.85*get_ipo("erp"))*(1-get_ipo("debt_weight"))+
  get_ipo("kd")*(1-get_ipo("tax"))*get_ipo("debt_weight")
beta_alternatives <- rbind(beta_alternatives,data.frame(method="原0.85假设（对照）",
  beta_unlevered=NA_real_,beta_equity=0.85,wacc=old_wacc,
  price_hkd=value_forecast(build_forecast(),wacc=old_wacc)$summary$price_hkd))

validation <- data.frame(check=c("三年利润表勾稽","三年所得税后利润勾稽","发行股本加总",
 "基准敏感性回到原模型","悲观低于基准且基准低于乐观","永续期增长再投资约束","现金余额为正"),
 passed=c(max(abs(with(historical,gross_profit+other_income-selling-administration-other_expense-
                        finance_cost-pretax_profit)))<1e-8,
          max(abs(with(historical,pretax_profit-income_tax-net_profit)))<1e-8,
          abs(shares_post-111.882318)<1e-10,
          abs(sensitivity_base_check-base$price_hkd)<1e-10,
          all(diff(scenario_results$price_hkd)>0),
          all(scenario_results$terminal_g/scenario_results$terminal_roic<1),
          all(scenario_results$cash_at_ipo>0)))
validation <- rbind(validation,peer_beta$checks)
stopifnot(all(validation$passed), all(is.finite(scenario_results$price_hkd)))

write_outputs <- function() {
  dir.create("outputs/tables",recursive=TRUE,showWarnings=FALSE)
  dir.create("intermediate",showWarnings=FALSE)
  save_csv <- function(x,name) write.csv(x,file.path("outputs/tables",name),
                                        row.names=FALSE,fileEncoding="UTF-8")
  save_csv(historical,"historical_ratios.csv")
  save_csv(scenario_results,"scenario_results.csv")
  save_csv(do.call(rbind,lapply(models,function(m)m$forecast)),"forecast_all_scenarios.csv")
  save_csv(sensitivity,"wacc_growth_sensitivity.csv")
  save_csv(reverse_results,"reverse_valuation.csv")
  save_csv(bridge,"enterprise_to_equity_bridge.csv")
  save_csv(robustness,"bridge_robustness.csv")
  save_csv(validation,"validation_checks.csv")
  save_csv(peer_beta$estimates,"peer_beta_estimates.csv")
  save_csv(peer_beta$weekly_prices,"peer_weekly_prices.csv")
  save_csv(peer_beta$weekly_returns,"peer_weekly_returns.csv")
  save_csv(beta_alternatives,"peer_beta_alternatives.csv")
  capture.output(sessionInfo(),file="intermediate/R_sessionInfo.txt")
}
write_outputs()
if(sys.nframe()==0) print(scenario_results[,c("scenario","wacc","price_hkd","terminal_share")])
