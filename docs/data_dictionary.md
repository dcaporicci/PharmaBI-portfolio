---
title: "Data Dictionary"
author: "Danilo Caporicci"
date: "2026-11-02"
output: html_document
---

# PharmaBI — Data dictionary

## Scope and grain

This dictionary describes the shared analytical schema. Public numerical examples refer only to the synthetic demonstration.

`fact_sales` contains **one row per product code within a transaction**, including returns and non-retail transactions. Its logical key is `(sale_id, product_code)`. Multiple packages of the same product are stored as one row with a signed quantity.

The private ETL enriches transactional exports with product classifications. The public generator directly constructs the same 20-column fact schema.

## Fact fields

| Column | R type | Meaning and rules |
|---|---|---|
| `date` | Date | Transaction date. A receipt must have one date. |
| `time_slot_quarter` | Character | Recorded/generated 15-minute interval, such as `09:30 - 09:44`. |
| `time_slot_half` | Character | Recorded/generated 30-minute interval. |
| `time_slot_hour` | Character | Recorded/generated hourly interval. |
| `sale_id` | Character | Transaction identifier; part of the logical key. It does not identify a customer. |
| `number_sales` | Integer | Source transaction counter. In the demo, retail numbering restarts each day; non-retail headers use zero. |
| `manufacturer_code` | Character | Manufacturer identifier; fictional in the demo. |
| `manufacturer_desc` | Character | Manufacturer description; fictional in the demo. |
| `product_code` | Character | Product identifier; part of the logical key. Demo codes use a `D` prefix, for example `D00000001`. |
| `product_desc` | Character | Product label. Required, nonblank; demo labels begin with `DEMO `. |
| `gm_code` | Character | Merchandise group identifier. Demo categories use codes such as `D0001`. |
| `gm_desc` | Character | Merchandise group description. Required and nonblank. |
| `atc_code` | Character, nullable | ATC code assigned to a classified product. Missingness must agree with `atc_desc`. |
| `atc_desc` | Character, nullable | ATC description; public reference labels or explicitly fictional veterinary labels in the demo. |
| `revenue` | Numeric | Recorded line net revenue, excluding VAT; signed for returns. It is a line total, not necessarily a unit price. |
| `costs` | Numeric | Recorded product cost attributed to the line; signed for returns. Zero recorded cost is an audit condition, not proof of a free acquisition. |
| `profit` | Numeric | Recorded line profit: `revenue - costs`. Operating expenses are not deducted. |
| `margin` | Numeric | Stored line ratio; checked against `profit / revenue` where revenue is nonzero. Undefined ratio cases require explicit interpretation. |
| `packages` | Integer | Signed package quantity. Negative values represent returns in the synthetic scenario; quantities are not doses or customer counts. |
| `sale_type` | Character | Exactly `retail` or `non_retail`. All rows sharing a receipt identifier must share its type. |

Identifiers are text throughout import, database storage and Power BI. Leading zeros and fictional letter prefixes must be preserved.

SQLite stores `date` as ISO text and quantities as INTEGER; financial fields are stored as numeric values. Power Query converts the date to Date, keeps identifiers as Text and applies explicit numeric types.

## Missing values and validity

The mandatory fact fields checked for NA are `date`, `sale_id`, `product_code`, `product_desc`, `gm_code`, `gm_desc`, `revenue`, `costs`, `profit`, `margin` and `packages`.

Additional checks require a nonmissing integer `number_sales` and an allowed `sale_type`. Required text fields are validated as character and nonblank; all four financial fields must be finite. These rules are implemented in the shared validator.

ATC code and description may both be missing. This is expected for the unclassified portion of the assortment; missing ATC alone is not a reason to discard a retail row.

The demo has no zero-revenue rows. A finite stored margin on a zero-revenue row does not make the mathematical ratio defined; the validator excludes such rows from the ratio comparison.

## Core derived indicators

| Indicator | Definition / denominator |
|---|---|
| Receipts | Distinct `sale_id` within the stated transaction scope and period |
| Products sold | Distinct `product_code` present in the selected fact rows |
| Net packages | Sum of signed `packages` |
| Net revenue / recorded costs / recorded profit | Sums of the corresponding line totals |
| Overall margin | Total recorded profit / total net revenue; not an average of line margins |
| Average net revenue per receipt | Total retail net revenue / distinct retail receipts |
| Average recorded profit per receipt | Total retail recorded profit / distinct retail receipts |
| Active days | Distinct dates with recorded retail transactions |
| Revenue or profit per active day | Period total / period retail active days |
| Product receipt frequency | Receipts containing the product / all retail receipts in scope |
| Human ATC receipt frequency | Receipts containing the category / receipts containing any human ATC product |
| Packages per containing receipt | Category/product net packages / receipts containing that category/product |
| Average category revenue per receipt | Category net revenue / receipts containing that category; not the complete receipt value |
| Average net price per package | Net revenue / signed package quantity, when the denominator is nonzero |

Legacy analytical names such as `average_receipt_value` refer to net revenue in this model. Labels should state the net basis. An observed sales-volume measure is not a stock-turnover measure.

## VAT and returns

Operational interpretation of the revenue field was established through like-for-like source-price checks. Public examples do not reproduce those operational checks or values. The generator creates net prices directly; it does not calculate VAT.

The schema has no VAT-rate field. It cannot reconstruct gross collections by applying one assumed rate to the entire assortment.

A return reverses quantity, revenue and cost in the demo. Negative profit with a positive ratio margin is therefore possible. Period totals include signed returns.

## Lookup and dimension tables

| Object | Grain / purpose |
|---|---|
| ETL `dim_products_gm` | One product per latest retained merchandise classification |
| ETL `dim_products_atc` | One classified product per latest retained ATC classification |
| SQLite `dim_products` | One product code and latest observed description from the complete fact table |
| SQLite `dim_date` | One date across complete calendar years spanning the fact data |
| SQLite `dim_atc_level2` | One public level 2 reference code, whether or not transactions exist |
| SQLite `vw_retail_sales` | View selecting `sale_type = 'retail'` from the fact table |
| Power BI `dim_gm` | Distinct GM code/description pairs derived from retail sales |
| Power BI `Ranking Metric` | Disconnected selector for recorded profit, net revenue or packages |

The ETL product lookup tables are not the same objects as the SQLite product dimension. Power BI's GM table is not a physical SQLite table.

## Date dimension

| Column | SQLite type | Meaning |
|---|---|---|
| `date` | TEXT | Unique ISO date `YYYY-MM-DD` |
| `year` | INTEGER | Calendar year |
| `month_number` | INTEGER | Month from 1 to 12 |
| `year_month` | TEXT | Calendar month `YYYY-MM` |
| `weekday_number` | INTEGER | ISO weekday, Monday = 1 through Sunday = 7 |

The tested demo calendar contains 365 dates in 2026. Its range is rebuilt from the full years covering the fact dates.

Calendar membership does not establish opening or data availability. The demo's observed sales window is shorter than its calendar.

## ATC reference and derived fields

The public RDS has `atc_code`, `atc_desc` and integer `atc_level`. Code lengths 1, 3, 4, 5 and 7 identify levels 1 through 5.

The SQLite/CSV level 2 table has:

| Column | Meaning |
|---|---|
| `atc_level2` | Unique three-character reference code |
| `atc_level2_desc` | Description from the validated public reference |

Power Query adds two columns to the 20-column retail CSV:

| Field | Type | Rule |
|---|---|---|
| `atc_level2` | Text, nullable | First three characters of `atc_code`; preserve nulls |
| `is_human_atc` | Logical | False for null/blank codes and `P52AC13`, `P53AX65`, `P54AB51`; true for other nonblank codes |

The Human ATC page filters the flag to true. It is an explicit scenario/source rule, not a complete veterinary classifier. Human group P must not be removed wholesale. New operational classifications require review.

Public reference codes assigned to fictional products are software examples, not real product registrations.

## Basket indicators

Receipt-level SQL returns `sale_id`, `date`, `unique_products`, `packages_sold`, `revenue`, `costs` and `profit`.

- `unique_products` counts distinct product codes; package quantity does not multiply presence.
- `multi_product_receipt_share` is the proportion of retail receipts with at least two distinct codes.
- Averages and medians are calculated from receipt-level values.
- Current presence-based basket queries retain return rows; they describe recorded transactions, including returns.

## Pair indicators

Each unordered product pair appears once per containing receipt. Let `N` be all retail receipts, `n_A` and `n_B` the individual product receipt counts, and `n_AB` the co-occurrence count.

| Field | Definition |
|---|---|
| `receipts_together` | `n_AB` |
| `receipts_a` / `receipts_b` | `n_A` / `n_B` |
| `support` | `n_AB / N` |
| `confidence_a_to_b` | `n_AB / n_A` |
| `confidence_b_to_a` | `n_AB / n_B` |
| `expected_receipts_together` | `n_A * n_B / N` under independence |
| `lift` | `n_AB * N / (n_A * n_B)` |

Support includes single-product receipts in its denominator. Confidence is directional; lift is symmetric. A/B code ordering is not purchase order. The minimum receipt threshold filters display rows after metric calculation.

## Period comparisons and display

Changes are current minus reference. Relative change is `(current - reference) / reference × 100`; a zero or missing reference gives N/A.

Margin changes and changes in multi-product receipt share are expressed in percentage points. Category daily revenue divides by the active days of the whole retail period, rather than category-specific active dates.

Analytical values retain precision until display. Shiny money uses two decimal places; the Power BI validation views use three, with integer quantities and percentage margins. Rounding conventions can affect the last displayed decimal without changing the underlying definition.
