# PharmaBI — Demonstration findings

**Synthetic demonstration data.** Every numerical example below concerns fictional transactions generated for the portfolio. These are worked analytical examples, not findings about a real parafarmacia.

The demo window is **2026-01-05 to 2026-09-20**. Monetary tables use a decimal comma and a dot for thousands. Values retain three decimal places for reconciliation.

## 1. Establish the retail baseline

**Question:** What activity does the selected sales dataset represent?

| Retail indicator | Verified demo result |
|---|---:|
| Receipt-product rows | 7.817 |
| Receipts | 4.800 |
| Distinct products | 240 |
| Net packages | 9.607 |
| Net revenue | EUR 185.853,967 |
| Recorded costs | EUR 118.563,536 |
| Recorded profit | EUR 67.290,431 |
| Overall margin | 36,21% |

The full fact table includes another 18 rows belonging to three non-retail transactions. Those are excluded from retail receipt and economic indicators.

**Analytical use:** the baseline makes transaction scope explicit before evaluating products, categories or changes.

**Limit:** recorded profit subtracts recorded product costs, not operating expenses. The fixture deliberately includes zero recorded costs, below-cost sales and returns.

**Evidence:** the shared fact validator passed 14 checks; sales-by-type and monthly SQLite aggregations reconciled with R. Overview KPIs also matched Shiny and Power BI in local Windows checks.

![Synthetic retail baseline in Power BI](images/powerbi-sales-overview-demo.png)

## 2. Separate period length, receipt activity and profitability

**Question:** Does higher monthly revenue reflect more active days, a higher daily average, or both?

The reference period is **2026-02-01 to 2026-02-28**; the current period is
**2026-03-01 to 2026-03-31**. Both contain only synthetic retail transactions.

| Indicator | February: reference | March: current | Change |
|---|---:|---:|---:|
| Active days | 28 | 31 | +10,71% |
| Receipts | 500 | 595 | +19,00% |
| Net revenue (EUR) | 19.602,177 | 23.150,605 | +18,10% |
| Recorded profit (EUR) | 7.175,940 | 8.404,020 | +17,11% |
| Net revenue per active day (EUR) | 700,078 | 746,794 | +6,67% |
| Recorded profit per active day (EUR) | 256,284 | 271,097 | +5,78% |
| Receipts per active day | 17,857 | 19,194 | +7,48% |
| Average net revenue per receipt (EUR) | 39,204 | 38,909 | -0,75% |
| Overall margin | 36,61% | 36,30% | -0,31 percentage points |

Changes are calculated from unrounded values against February. The net-revenue
increase is **EUR 3.548,428** and the recorded-profit increase is **EUR 1.228,080**.
The margin change is measured in percentage points, not percentage change.

**Interpretation:** March has three more active days, and its net revenue per
active day is also 6,67% higher. The larger monthly total therefore accompanies
an increase in the daily average. These are separate descriptions of activity.

The daily revenue average can be decomposed arithmetically:

`revenue per active day = receipts per active day × average net revenue per receipt`

Receipts per active day increase by 7,48%, while average net revenue per receipt
falls by 0,75%. In this synthetic comparison, the higher daily revenue accompanies
more receipts per day, rather than a larger average receipt value. Receipts count
transactions, not distinct customers.

Recorded profit grows by 17,11%, while overall margin decreases from 36,61% to
36,30%. Total profit contribution and margin percentage answer different questions;
they should be read together.

**Analytical use:** show the monthly total, normalize by active days, then inspect
receipts per active day, average receipt value and margin before explaining the change.
The arithmetic identity describes the observed components; it does not identify
causal drivers.

**Evidence:** the February and March RDS summaries were calculated separately in R.
Both periods are also covered by the automated verifier's R/SQL reconciliations,
which passed on Linux and Windows. Reproduce the worked example with:

```r
source(here::here("R", "demo", "05_period_comparison_case.R"))

print(demo_period_example$comparison, digits = 10, row.names = FALSE)
print(demo_period_example$margin_change, digits = 10, row.names = FALSE)
```

The script writes three unrounded CSV outputs under the ignored
`data/demo/case_studies/` directory.

**Limit:** daily averages do not control for weekday composition, category mix,
prices, promotions or other influences. The figures describe fictional transactions,
not a business improvement or a causal effect. For other intervals, inspect partial
calendar coverage: January starts on 2026-01-05, September ends on 2026-09-20,
and the scenario excludes 2026-04-12 and 2026-04-13.

## 3. Explore product and merchandise group rankings

**Question:** Which products and categories contribute most to recorded profit?

In the full-period Power BI screenshots, with **Recorded profit** selected:

| Displayed synthetic ranking leader | Recorded profit |
|---|---:|
| Product `DEMO Supplements 042 [D00000042]` | EUR 2.555,283 |
| Merchandise group `Supplements [D0003]` | EUR 7.660,114 |

**Evidence:** these values are displayed in the checked synthetic Power BI screenshots. They are presented as visual reference examples, rather than an independent product-level SQL/R reconciliation.

**Analytical use:** switch between profit, revenue and package volume, then inspect costs, quantities and receipt counts through tooltips.

**Limit:** the generator assigns fictional popularity weights and recurring pairs. Three fictional products have zero recorded costs. Rankings cannot support real assortment, margin or stock decisions.

![Synthetic product profit ranking](images/powerbi-products-demo.png)

![Synthetic merchandise group profit ranking](images/powerbi-merchandise-groups-demo.png)

### Worked example: volume, profit and margin

The full-period synthetic retail data produce three different ranking leaders:

| Ranking leader | Product code | Net packages | Recorded profit (EUR) | Overall margin |
|---|---|---:|---:|---:|
| Package volume | D00000061 | 220 | 422,180 | 21,22% |
| Total recorded profit | D00000042 | 180 | 2.555,283 | 50,47% |
| Eligible overall margin | D00000024 | 20 | 42,900 | 54,75% |

D00000042 combines higher average net revenue per package with a higher
margin than D00000061. Its recorded profit per package is EUR 14,196,
compared with EUR 1,919. D00000024 has the highest eligible margin,
but its lower revenue and volume produce a smaller total contribution.

The margin ranking includes products with at least 10 net packages,
positive revenue and nonzero total recorded costs. The volume and
profit rankings include all retail products.

Reproduce this example with `R/demo/06_product_performance_case.R`.
The comparison CSV is generated under `data/demo/case_studies/`.

These fictional results illustrate different analytical questions.
Recorded profit excludes operating expenses, and package volume alone
does not establish inventory turnover or justify assortment decisions.

## 4. Read the human ATC scope correctly

**Question:** Which classified categories lead the synthetic human ATC view?

The displayed full-period profit ranking is led by `A02` at **EUR 2.077,876**.

**Evidence:** the checked Power BI Human ATC screenshot, filtered using `is_human_atc` and ranked by recorded profit.

The synthetic catalogue assigns human ATC codes to 40 products across 12 chosen level 2 groups. Twenty fictional veterinary products use the three explicitly excluded codes; 180 catalogue products have no ATC assignment.

**Analytical use:** demonstrate hierarchy labels, category filtering and the distinction between the complete retail assortment and classified products.

**Limit:** official reference metadata are assigned to fictional products for software testing. This is not a list of actual medicinal products, an assessment of regulatory status, or evidence of disease prevalence.

![Synthetic human ATC profit ranking](images/powerbi-human-atc-demo.png)

## 5. Interpret receipt associations cautiously

**Question:** Which products occur together, and how should an association be interpreted?

The fixture contains **7.817 product presences across 4.800 retail receipts**. Each product code is represented once per containing receipt; package quantities are recorded separately.

Three recurring product pairs are deliberately injected into some multi-product baskets. The SQL/Shiny analysis can explore their receipt counts, support, directional confidence and lift.

**Analytical use:** demonstrate the distinction between frequency, conditional probability and relative co-occurrence under independence.

**Limit:** injected pairs are simulation settings, not empirical purchase recommendations. Receipts do not identify customers or separate visits. The eight return rows also remain in the current receipt-presence analysis, so the table represents recorded transactions, including returns.

The independent R/SQL reconciliation recorded the following full-period Linux
summary, with all 70 verifier checks subsequently also passing on Windows:

| Synthetic pair indicator | Verified value |
|---|---:|
| Distinct unordered pairs | 4.071 |
| Pair occurrences across receipts | 4.995 |
| Pairs seen in exactly one receipt | 3.573 |
| Receipts containing the most frequent pair | 133 |

A receipt with multiple products contributes several pair occurrences. These
counts are not customer counts. Detailed pair-level interpretation must also
consider support, confidence, lift and the scenario's injected associations.
See [Demo verification](demo_verification.md) for the recorded scope and limits.

## Traceability

- `R/demo/01_generate_demo_data.R` defines the scenario.
- `R/demo/04_verify_demo.R` reconciles the demo data across R, SQL and CSVs.
- `R/demo/05_period_comparison_case.R` reproduces the February-March worked example.
- `R/validation/validate_fact_sales.R` validates the fact table.
- `R/database/build_database.R` reconciles sales-by-type and monthly totals.
- `sql/06_retail_overview_by_period.sql` provides period KPIs.
- `sql/11_gm_revenue_by_period.sql` supports category comparisons.
- `sql/12_basket_receipts_by_period.sql` and `sql/13_basket_pair_frequency_by_period.sql` support basket analysis.
- `dashboard/app.R` and the portfolio PBIP expose the demo interactively.

The observations above illustrate the analytical process and its limitations. They are not business claims derived from confidential operational data.
