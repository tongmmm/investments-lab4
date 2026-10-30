"""用独立的 Python 实现复核 R 的基准估值，并核对一手来源关键数据。"""
from pathlib import Path
from datetime import date, timedelta
import csv
import json
import math
import hashlib
import statistics

ROOT = Path(__file__).resolve().parents[1]
def rows(name):
    with (ROOT / name).open(encoding="utf-8-sig",newline="") as f:
        return list(csv.DictReader(f))
ipo = {r["key"]: float(r["value"]) for r in rows("data/ipo_inputs.csv")}
h = [r for r in rows("data/historical_financials.csv") if r["year"]=="2019"][0]
h = {k: float(v) for k,v in h.items()}
a = [r for r in rows("data/forecast_assumptions.csv") if r["scenario"]=="base"]
results = rows("outputs/tables/scenario_results.csv")
base = next(r for r in results if r["scenario"]=="base")
# 独立从日行情选周末价格，再用协方差公式估计 beta；不读取 R 的 beta 作为输入。
prices = rows("data/peer_daily_prices.csv")
peer_financials = rows("data/peer_financial_inputs.csv")
symbols = ["0322.HK","0220.HK","0345.HK","0506.HK","^HSI"]
weekly = {s:{} for s in symbols}
for r in sorted(prices,key=lambda r:r["date"]):
    day=date.fromisoformat(r["date"])
    friday=day+timedelta(days=4-day.weekday())
    weekly[r["symbol"]][friday] = float(r["close"])
weeks=sorted(set.intersection(*(set(weekly[s]) for s in symbols)))
returns={s:[weekly[s][b]/weekly[s][a]-1 for a,b in zip(weeks,weeks[1:])] for s in symbols}
market=returns["^HSI"]
unlevered=[]; beta_checks=[]
reported_beta=rows("outputs/tables/peer_beta_estimates.csv")
for r in peer_financials:
    symbol=r["symbol"]
    beta=statistics.covariance(returns[symbol],market)/statistics.variance(market)
    debt=sum(float(r[k]) for k in ["borrowings_current_million","borrowings_noncurrent_million",
                                   "leases_current_million","leases_noncurrent_million"])
    debt_hkd=debt/(ipo["rmb_per_hkd"] if r["currency"]=="RMB" else 1)
    equity=weekly[symbol][weeks[-1]]*float(r["shares"])/1e6
    beta_u=beta/(1+(1-float(r["tax_normalized"]))*debt_hkd/equity)
    unlevered.append(beta_u)
    rr=next(x for x in reported_beta if x["symbol"]==symbol)
    beta_checks.append((symbol,abs(beta-float(rr["beta_levered"]))<1e-12 and
                        abs(beta_u-float(rr["beta_unlevered"]))<1e-12,beta,beta_u))
beta_equity=statistics.mean(unlevered)*(1+(1-ipo["tax"])*ipo["debt_weight"]/(1-ipo["debt_weight"]))
wacc = (ipo["rf"]+beta_equity*ipo["erp"])*(1-ipo["debt_weight"])+ipo["kd"]*(1-ipo["tax"])*ipo["debt_weight"]
remaining_days = (date(2020,12,31)-date(2020,9,8)).days
bridge_days = (date(2020,9,8)-date(2020,7,31)).days
old_rev = h["revenue"]
old_wc = (h["int_inventory"]+h["trade_receivables"]+h["prepayment_suppliers"]-
          h["trade_payables"]-h["contract_liabilities"]+old_rev*ipo["minimum_operating_cash_ratio"])
fcff = []; revenues=[]; factors=[]
for i,r in enumerate(a):
    rev=old_rev*(1+float(r["revenue_growth"]))
    wc=rev*(float(r["nwc_ratio"])+ipo["minimum_operating_cash_ratio"])
    capex=(float(r["capex_override"]) if r["capex_override"] else
           rev*float(r["da_ratio"])+(rev-old_rev)/float(r["incremental_capital_turnover"])-(wc-old_wc))
    cashflow=rev*float(r["ebit_margin"])*(1-ipo["tax"])+rev*float(r["da_ratio"])-capex-(wc-old_wc)
    revenues.append(rev); fcff.append(cashflow)
    factors.append((1+wacc)**(-(remaining_days/365.25+i)))
    old_rev=rev; old_wc=wc
terminal=revenues[-1]*(1+float(a[-1]["terminal_g"]))*float(a[-1]["terminal_margin"])*(1-ipo["tax"])*(1-float(a[-1]["terminal_g"])/float(a[-1]["terminal_roic"]))
ev=sum(c*(remaining_days/366 if i==0 else 1)*d for i,(c,d) in enumerate(zip(fcff,factors)))+terminal/(wacc-float(a[-1]["terminal_g"]))*factors[-1]
cash_change=(fcff[0]+(revenues[0]-h["revenue"])*ipo["minimum_operating_cash_ratio"])*bridge_days/366-ipo["debt_june30"]*ipo["kd"]*(1-ipo["tax"])*bridge_days/366
cash=ipo["cash_july31"]+cash_change-ipo["special_dividend"]+ipo["ipo_net_proceeds_hkd"]*ipo["rmb_per_hkd"]
equity=ev+cash-revenues[0]*ipo["minimum_operating_cash_ratio"]-ipo["debt_june30"]-ipo["lease_june30"]
price=equity/(ipo["pre_ipo_shares"]+ipo["new_shares"])/ipo["rmb_per_hkd"]
checks=[]
def check(name, passed, evidence):
    checks.append({"check":name,"passed":bool(passed),"evidence":evidence})
for symbol, passed, beta, beta_u in beta_checks:
    check("Independent peer beta: "+symbol,passed,{"levered":beta,"unlevered":beta_u})
check("Independent peer sample cutoff",len(weeks)==105 and weeks[-1]<date(2020,9,8),
      {"first_week":str(weeks[0]),"last_week":str(weeks[-1]),"weekly_returns":len(market)})
check("Independent bottom-up WACC",abs(wacc-float(base["wacc"]))<1e-12,
      {"beta":beta_equity,"wacc":wacc})
check("Independent Python vs R price", abs(price-float(base["price_hkd"]))<1e-9,
      {"python":price,"R":float(base["price_hkd"]),"absolute_difference":abs(price-float(base["price_hkd"]))})
check("Independent enterprise value",abs(ev-float(base["enterprise_value"]))<1e-8,ev)
check("Annual statements reconcile",all(abs(float(r["pretax_profit"])-float(r["income_tax"])-float(r["net_profit"]))<1e-8 for r in rows("data/historical_financials.csv")),"2017-2019")
source = ROOT / "intermediate/source_extracts/nongfu_20200825_prospectus_zh.json"
if source.exists():
    pages=json.loads(source.read_text(encoding="utf-8"))
    text="".join("\n".join(p["text"] for p in pages).split())
    # 以来源中原始的人民币千元金额匹配，避免只把两份模型互相比较。
    for value,label in [("24,021,041","2019 revenue"),("7,471,839","2019 operating net cash"),
                        ("1,083,142","2019 cash equivalents"),("11,188,231,800","IPO shares"),
                        ("7,800","special dividend")]:
        check("Primary PDF: "+label,value in text,value)
else:
    raise RuntimeError("请先运行公开资料下载与提取脚本")
peer_source=ROOT/"intermediate/source_extracts/peer_beta_financials.json"
if peer_source.exists():
    peer_pages=json.loads(peer_source.read_text(encoding="utf-8"))
    for r in peer_financials:
        text="".join("\n".join(p["text"] for p in peer_pages if p["file"]==r["source_file"]).split())
        values=[f"{round(float(r[k])*1000):,}" for k in
                ["borrowings_current_million","leases_current_million","leases_noncurrent_million"]]
        if float(r["borrowings_noncurrent_million"]):
            values.append(f"{round(float(r['borrowings_noncurrent_million'])*1000):,}")
        values.append(f"{int(r['shares']):,}")
        check("Peer PDF debt/shares: "+r["symbol"],all(v in text for v in values),values)
else:
    raise RuntimeError("请先运行同行资料下载与提取脚本 code/08_download_beta_sources.py")
for name in ["enterprise_to_equity_bridge.csv","bridge_robustness.csv","validation_checks.csv"]:
    content=(ROOT/"outputs/tables"/name).read_text(encoding="utf-8")
    check("UTF-8 output "+name,not any(ord(c)<32 and c not in "\n\r\t" for c in content),"no control characters")
out=ROOT/"intermediate/independent_audit.json"
out.write_text(json.dumps({"checks":checks,"all_passed":all(c["passed"] for c in checks)},ensure_ascii=False,indent=2),encoding="utf-8")
if not all(c["passed"] for c in checks):
    raise AssertionError(json.dumps(checks,ensure_ascii=False))
print("Independent audit: all",len(checks),"checks passed; base price HKD",round(price,6))
