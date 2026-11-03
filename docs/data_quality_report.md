---
title: "Data Quality Report"
author: "Danilo Caporicci"
date: "2026-11-02"
output: html_document
---

# PharmaBI — Data quality report

## Scope and evidence

This public report documents the **synthetic demonstration fixture**, the shared validation rules and the checks reported during local execution. This edition omits operational quality counts and product identifiers.

The demo was generated independently of operational sales rows. It uses a public ATC reference snapshot. It begins at the prepared fact-table level, so passing its checks does not validate the original management-system CSV import or cleaning process.

## Verified demo structure

| Item | Result |
|---|---:|
| Complete fact rows | 7.835 |
| Fact columns | 20 |
| Retail rows | 7.817 |
| Retail receipts | 4.800 |
| Non-retail rows | 18 |
| Non-retail transactions | 3 |
| Distinct products sold in retail | 240 |
| Retail active dates | 257 |

Demo sales span 2026-01-05 to 2026-09-20. The SQLite calendar covers the complete year 2026 with 365 rows. It is not an opening-day calendar.

## Shared fact validator

`validate_fact_sales(fact_file)` reads the explicitly supplied RDS. It prints the final summary and returns the fact table, summaries and audits in a named list.

All 14 checks passed for the tested synthetic fixture:

| Check | Enforced rule |
|---|---|
| Column types | Expected Date, character, integer and numeric classes |
| Mandatory missing values | No NA in the mandatory fact fields |
| Logical-key uniqueness | Unique `(sale_id, product_code)` |
| Count-variable integrity | Nonmissing integer quantities and counters |
| Profit formula | `abs(revenue - costs - profit) < 1e-10` |
| Margin formula | Agreement with `profit / revenue` for nonzero revenue |
| GM classification coverage | Nonmissing GM code and description |
| Non-empty input | Nonempty data frame |
| Required columns | All 20 required names exist; extra columns are permitted |
| Mandatory text values | Required character fields are not missing, empty or whitespace-only |
| Finite financial values | Revenue, costs, profit and stored margin are finite |
| ATC code-description consistency | ATC code and description are missing together |
| Sale type values | Only `retail` and `non_retail` |
| Receipt metadata consistency | Each receipt has one date and one sale type |

The maximum displayed profit-formula difference was **5.684342e-14**; the margin-formula difference was **0**. These are computational checks on the fixture, not evidence that recorded costs are commercially correct.

The required text check covers `sale_id`, `product_code`, `product_desc`, `gm_code`, `gm_desc` and `sale_type`. The validator does not prove the substantive accuracy of classifications or validate every descriptive field against a master-data registry.

Zero-revenue rows are excluded from the ratio-formula check because their margin is undefined. The current demo contains no such rows, so zero-revenue behaviour needs a separate fixture before claiming test coverage.

## Controlled diagnostic cases

| Scenario | Fixture definition / observed result |
|---|---|
| Returns | Eight retail rows with negative packages, revenue and costs |
| Below-cost sales | Twelve separate rows with revenue reduced below recorded cost |
| Zero recorded costs | Three fictional products, across their generated transaction rows |
| Missing ATC | Deliberately unassigned for 180 catalogue products |
| Veterinary scope | Twenty catalogue products using the explicit veterinary code list |
| Non-retail scope | Three transactions with six products each |

Return and below-cost rows are selected separately and exclude the zero-cost products. After the changes, profit and margin are recalculated.

The validator retains these rows and builds audits; it does not treat every unusual sign or margin as a structural failure. In particular, a return may have negative profit with a positive ratio margin. A numeric receipt-loss audit must be interpreted in that context.

The number of zero-cost rows depends on how frequently the selected products occur. It is distinct from the number of zero-cost products.

## Database and export checks

The SQLite builder checks:

- product-dimension completeness and unique codes;
- calendar uniqueness, complete attributes and coverage of sales dates;
- nonempty ATC level 2 labels with complete, unique codes;
- the stored fact row count;
- sales-by-type and monthly retail results against R, using a numerical tolerance.

All existing SQL/R reconciliation checks passed for the demo. The builder also executes the overview and minimum-volume product query; the current script does not assert an independent reconciliation of every returned product-ranking column.

The Power BI exporter checks product coverage and ATC reference structure before CSV writes. Demo mode additionally checks the expected synthetic receipt/product identifiers and product labels. This guard catches obvious source mix-ups; it is not a general disclosure-risk assessment.

The four exports contain 7.817 retail rows, 365 calendar rows, 240 product labels and 94 ATC level 2 reference rows in the tested snapshot. All four output files were confirmed present.

## Automated demo reconciliation on Linux and Windows — 2026-11-03

`R/demo/04_verify_demo.R` completed successfully with **70 checks passed** on both Linux and Windows.
It reused the shared structural validator, compared the stored fact and dimensions
with their R sources, and reconciled SQL monthly values and seven inclusive date
intervals with independent R calculations. Those intervals include partial months,
a single day, the fictional closure and a period outside coverage.

The verifier independently enumerated unordered product pairs within receipts in R.
Pair counts, both confidence directions, support, expected co-occurrences and lift
matched SQL for every checked interval. The recorded Linux full-period synthetic result contained
4071 distinct pairs, 4995 pair occurrences, 3573 pairs seen once, and a maximum of
133 containing receipts for one pair. These are fictional demonstration results.

All four CSV exports matched SQLite, and the checked input file fingerprints were
unchanged by verification. Results and verification-session metadata are saved
locally under `data/demo/validation/`; see [Demo verification](demo_verification.md).
Numerical reconciliation uses absolute tolerance `1e-7`, while the shared fact
validator retains its own financial tolerance.

## Isolation and interface verification

On 2026-10-30, the private SQLite file's MD5 fingerprint was compared before and after building the demo. It was unchanged. This confirms file-content isolation for that execution; it is not a complete security or privacy guarantee.

The local Windows session used R 4.6.1 for the recorded fact validation. Demo Shiny displayed the expected overview totals and handled the selected empty interval. On 2026-11-02 the four Power BI pages were checked with the synthetic CSVs, including month/metric switching and recovery from a month without observations.

On 2026-11-03 Shiny was also checked in the separate Linux portfolio checkout, including the initial KPIs, all five tabs, the empty interval and recovery.

Power BI overview values matched the synthetic baseline. Public screenshots identify the data as synthetic. Product/category screenshot leaders are visual reference values, not substitutes for independent group-level reconciliation.

## Remaining release checks

- Test a clean installation on a new machine; macOS remains unverified.
- Retain the reference snapshot and generation-environment details for reproducibility; the verifier records input fingerprints and its own session versions, rather than pinning dependencies.
- Complete the final public repository and asset review before the release tag. The public portfolio starts with a separate reviewed snapshot; the original history remains private.
- Complete demo integration of the legacy R analysis/report path before using it for public report generation.

Passing the checks above establishes specific structural and numerical properties. It does not establish business profitability, clinical meaning, customer behaviour or complete confidentiality of all repository history.
