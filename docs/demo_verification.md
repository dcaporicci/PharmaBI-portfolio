# Synthetic demo verification

This check belongs to the public **PharmaBI-portfolio** project.

## Run

Open this project's `PharmaBI.Rproj` in RStudio. Prepare the demo with scripts
`01_generate_demo_data.R`, `02_build_demo_database.R` and
`03_export_demo_powerbi.R` before running:

```r
source(here::here("R", "demo", "04_verify_demo.R"))

table(demo_checks$summary$status)
print(demo_checks$baseline, digits = 12, row.names = FALSE)
print(demo_checks$pair_summary, row.names = FALSE)
```

The script explicitly selects demo paths, independently of
`PHARMABI_DATA_MODE`. SQLite is opened read-only. No private input is required.
The script does not generate data, rebuild databases or replace CSV exports.

## Checks

- Reuse the shared fact validator, including its structural, key, text, quantity
  and financial consistency checks.
- Check synthetic prefixes as a guard against accidentally selecting operational
  records. This is not a proof of anonymity.
- Compare sale-type totals with the documented fixture below.
- Reconcile every SQLite fact row with the demo RDS, the retail view with the
  retail source rows, product labels with the source, the complete 2026 calendar
  with dates calculated in R, and ATC level 2 labels with the demo reference RDS.
- Recalculate monthly totals and active-day averages in R and compare with SQL.
- Check inclusive intervals for the full sales window, February, March, a partial
  multi-month window, a single day, the fictional closure and an October interval
  outside coverage.
- Reconcile period overviews, monthly values and receipt-level baskets.
- Enumerate all unordered product pairs independently in R using combinations
  within each receipt. Compare their frequencies, containing-receipt counts,
  descriptions, support, both confidence directions, expected frequency and lift
  with SQL. For each interval, total pair occurrences must equal the sum of
  `k * (k - 1) / 2` over its receipt baskets.
- Parse and compare the four Power BI CSV files with the corresponding database
  tables/view. Identifiers are parsed as text; numeric values use decimal points.
- Confirm that the input RDS files, SQLite database and four CSVs have identical
  file fingerprints before and after verification.

Numerical reconciliations use an **absolute tolerance of `1e-7`**. The shared
validator retains its own financial tolerance. No input values are rounded by
the verification script.

Returns remain product presences for pair analysis, consistently with the
implemented basket scope. Negative quantities remain signed in economic totals.

SQL intervals with no retail records must return zero counts and missing
monetary aggregates, with no monthly, receipt or pair rows. Zero total revenue
produces a missing overall margin rather than a division error.

## Documented fixture

| Sale type | Rows | Transactions | Net packages | Revenue | Costs | Profit |
|---|---:|---:|---:|---:|---:|---:|
| non_retail | 18 | 3 | 291 | 5606.562 | 3745.954 | 1860.608 |
| retail | 7817 | 4800 | 9607 | 185853.967 | 118563.536 | 67290.431 |

Retail coverage is `2026-01-05` to `2026-09-20`, with 240 sold products.
Decimal points in this table represent stored numeric values.

This baseline is an intentional regression check for the documented demo, not a
universal expectation for other datasets. A changed generator, RNG configuration
or ATC reference can require investigation. Update the expected fixture and its
public documentation only after reviewing an intentional scenario change.

## Verified Linux execution — 2026-11-03

The corrected verifier completed successfully on Linux with **70 checks passed**.
The documented sale-type baseline reconciled, including retail revenue of
185853.967 and recorded profit of 67290.431.

The full-period synthetic pair summary was:

| Indicator | Verified value |
|---|---:|
| Distinct unordered product pairs | 4071 |
| Total pair occurrences across receipts | 4995 |
| Pairs seen in exactly one receipt | 3573 |
| Receipts containing the most frequent pair | 133 |

Pair occurrences count each pair in each containing receipt. They are not a
count of receipts: one receipt with multiple products contributes several pairs.
The scenario deliberately injects recurring fictional product pairs.

Shiny was also checked in the separate Linux portfolio checkout: the initial KPIs,
all five tabs, the empty interval and recovery worked as expected. On 2026-11-03
the corrected verifier was also executed on Windows, with all **70 checks passed**.
Earlier Windows checks covered demo generation, database construction, CSV export
and manual dashboard use.

## Local reports

Every execution creates its own `run-*` subdirectory under
`data/demo/validation/`. This directory is already excluded from Git by the
`/data/demo/` rule.

| File | Content |
|---|---|
| `verification_summary.csv` | Named checks and final run status; also written on failure |
| `verification_session.txt` | Verification time, R/RNG details and session information; also written on failure |
| `input_fingerprints.csv` | Fingerprints of the checked demo inputs, after successful checks |
| `package_versions.csv` | Installed data-check and dashboard package versions, after successful checks |
| `top_demo_pairs.csv` | Up to 20 pair rows in the SQL ranking order, after successful checks |

The successful call assigns `demo_checks`, including its check summary,
sale-type baseline, pair summary, top pairs, export row counts and report path.
The previous `demo_checks` result is cleared before each execution; a failed run
does not leave an older successful result in that object.

Session metadata describe the **verification session**, not proof of the original
generator's execution environment. MD5 fingerprints are change-detection aids;
they are not privacy certificates or a requirement for identical binary files
across operating systems or R serialization/compression versions.

## Scope limits

This script checks prepared data and selected analytical SQL outputs. It does
not automate Shiny browser interactions or plot rendering, execute Power BI DAX,
or validate every product/category ranking query. Those checks remain separate.
It also does not convert the legacy private R Markdown reporting workflow.

Downloading the same public reference and using the same seed still requires
compatible reference content, generator code, R/RNG settings and package versions
for exact reproduction. Recording fingerprints and versions supports diagnosis;
it does not by itself pin or redistribute an ATC snapshot.
