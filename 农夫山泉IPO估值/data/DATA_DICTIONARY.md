# 输入数据字典

金额除明确标注外为人民币亿元，股数为亿股。CSV 保存原数值，百分比以小数存储，空白表示不适用或没有覆盖值，不表示零。

## historical_financials.csv

| 列名 | 含义 |
|---|---|
| year | 历史财务年度 |
| revenue / cost_of_sales | 收入 / 销售成本 |
| selling / administration | 销售及分销 / 行政费用 |
| other_income / other_expense | 其他收入 / 其他费用，分别取正数 |
| finance_cost / pretax_profit / income_tax | 财务费用 / 税前利润 / 所得税 |
| net_profit / parent_profit | 集团净利润 / 归母净利润 |
| operating_cash_generated | 未扣实际税及利息收支的经营所得现金 |
| operating_cash_net | 正式现金流量表经营活动现金净额 |
| capex | 资本开支：购买PPE、使用权资产和无形资产合计 |
| depreciation_ppe / depreciation_rou / amortization | PPE折旧 / 使用权折旧 / 无形资产摊销 |
| int_inventory | 存货，字段名中的int不表示整数或利息 |
| trade_receivables / prepayment_suppliers | 贸易应收及票据 / 供应商预付款 |
| trade_payables / contract_liabilities | 贸易应付及票据 / 合约负债 |
| cash_equivalents / structured_deposits | 现金及等价物 / 结构性存款 |
| interest_debt | 计息借款 |
| lease_current / lease_noncurrent | 流动 / 非流动租赁负债 |
| assets / equity | 总资产 / 总权益 |

## forecast_assumptions.csv

| 列名 | 含义 |
|---|---|
| scenario | bear悲观 / base基准 / bull乐观 |
| year | 预测年度2020—2029 |
| revenue_growth / ebit_margin | 收入增长 / 主营EBIT利润率 |
| da_ratio | 全口径折旧摊销占收入比例 |
| incremental_capital_turnover | 2022年起新增收入/净新增投入资本；计算资本开支 |
| capex_override | 明确资本开支覆盖值；2020与2021采用招股书计划，其余空白 |
| nwc_ratio | 交易性营运资本/收入；不含另加的必要现金 |
| terminal_g / terminal_roic / terminal_margin | 稳定期增长 / 新投资资本回报 / EBIT利润率 |
| wacc_shift | 相对基准WACC的百分点变化，以小数计；0.01为上调1个百分点 |

同一情景的稳定期参数在各年度重复展示以便审阅，计算只读取该情景的首年值。更改稳定期参数时请保持该情景各行一致。终值不使用当前股价决定，权益资本成本也不通过需要求解的内在价值反复迭代。

## ipo_inputs.csv

`key` 为唯一键；`value`为数值；`unit`为单位；`status`区分事实与分析假设；`source_locator`为来源和定位。债务市场权重不同于账面资产负债率，必要经营现金比例同时影响营运投入和股权桥接。人民币/港元的0.8955为报告换算约定。

贝塔不再作为该文件的独立假设输入，由两份同行输入及`code/09_peer_beta.R`计算。

## peer_daily_prices.csv

| 列名 | 含义 |
|---|---|
| symbol | Yahoo证券代码：0322.HK、0220.HK、0345.HK、0506.HK及^HSI |
| date | 香港交易日，2018-09-03至2020-09-04 |
| close | 原始日收盘价；股票单位港元，恒生指数单位点 |
| cash_dividend | 供应商记录的当日每股现金股息；只用于留存公司行动，不计入价格收益率回归 |

原始供应商JSON保存在`data/raw/peer_beta/`；价格使用`indicators.quote.close`，不使用当前概况字段或追溯复权列。样本期无拆合股事件；如以后更改证券或期间，脚本检测到拆合股即报错，须先处理公司行动。每周取共同交易日的最后一天，所有证券同日对齐，不向前填充。105个周价格产生104组简单价格收益率。

## peer_financial_inputs.csv

| 列名 | 含义 |
|---|---|
| symbol / company | 与行情对应的证券代码及公司名称 |
| balance_date / published_date | 财务报表日及本次采用文件的披露日，均早于估值日 |
| currency | 财报币种RMB或HKD |
| borrowings_current_million / borrowings_noncurrent_million | 流动/非流动借款，**财报本币百万元** |
| leases_current_million / leases_noncurrent_million | 流动/非流动租赁负债，**财报本币百万元** |
| shares | 最近披露报表日的已发行股份数量，单位**股**，不是亿股或千股 |
| tax_normalized | 去杠杆统一采用25%的规范化税率，属分析设定，并非各公司实际税率 |
| source_file | 下载后PDF文件名 |
| balance_physical_page / shares_physical_page | PDF物理页码，从1开始 |
| source_locator / comparability | 印刷页码、可比业务与差异 |

债务四项相加，不以总负债代替；RMB项目除以0.8955统一为港元。股权市值为2020-09-04收盘价乘披露股数。未补估报表日至估值日之间的债务及购股权变动。回归结果、标准误、R平方、债务权益比、无杠杆贝塔留存在`outputs/tables/peer_beta_estimates.csv`；均值、中位数、逐一剔除和原0.85假设的估值对照留存在`peer_beta_alternatives.csv`。

## segment_revenue.csv

按水、茶饮、功能饮料、果汁和其他品类记录2017—2019年收入；原披露四舍五入至百万元，转为亿元后有两位小数。仅用于经营结构说明。
