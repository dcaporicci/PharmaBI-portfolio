---
title: "Technical Documentation"
author: "Danilo Caporicci"
date: "2026-11-02"
output: html_document
---

# PharmaBI — Technical documentation

## 1. Purpose and data boundary

PharmaBI combines a private operational ETL with a synthetic portfolio demonstration. Both use the same prepared sales schema and shared downstream functions.

The public generator uses fictional products, manufacturers and transaction settings, plus a public ATC reference. It does not read, rescale or sample operational sales rows. Synthetic results are illustrative software outputs rather than evidence about a real business.

The demo begins with a generated fact table. The original import, cleaning and classification lookup construction remain a separate private workflow.

## 2. Entry points and shared functions

| Entry point | Purpose / input scope |
|---|---|
| `R/pipeline/run_pipeline.R` | Execute the six private ETL/validation scripts |
| `R/pipeline/06_validate_fact_sales.R` | Private wrapper around the shared validator |
| `R/database/01_build_database.R` | Private SQLite build wrapper |
| `R/export/01_export_powerbi.R` | Private Power BI CSV export wrapper |
| `R/demo/01_generate_demo_data.R` | Generate the synthetic fact and reference snapshot |
| `R/demo/02_build_demo_database.R` | Validate the demo fact and build its SQLite database |
| `R/demo/03_export_demo_powerbi.R` | Export the four synthetic Power BI CSVs |
| `R/demo/04_verify_demo.R` | Reconcile demo RDS, SQL outputs and exported CSVs; record local verification reports |
| `dashboard/app.R` | Run Shiny against the selected SQLite path |

Shared interfaces:

```r
pharmabi_data_paths(mode)
validate_fact_sales(fact_file)
build_pharmabi_database(paths, sql_dir = here::here("sql"))
export_pharmabi_powerbi(paths)
```

`pharmabi_data_paths()` accepts exactly `demo` or `private` and has no implicit mode. It returns `mode`, `data_root`, `fact_file`, `reference_file`, `database_dir`, `database_file` and `powerbi_dir`.

The shared validator defines no default dataset: the caller supplies an RDS file. It returns a named list containing the fact table, validation summary and audits. The private wrapper exports the existing diagnostic names into its sourcing environment for compatibility. Demo results are held separately.

The shared database builder receives a path list, checks inputs and required SQL files, and closes its connection on function exit, including failures. It retains the original transformations and numerical reconciliation. It overwrites its selected output tables/view when rebuilt; it is not documented as an atomic file replacement.

The exporter uses a read-only connection and closes it before validation/output. It validates product coverage and reference keys before writing the four CSVs without numeric rounding. Demo mode also requires expected synthetic identifiers and labels.

## 3. Filesystem isolation

| Artifact | Private | Demo |
|---|---|---|
| Fact RDS | `data/facts/fact_sales.rds` | `data/demo/facts/fact_sales.rds` |
| Public ATC snapshot | `data/reference/atc_reference.rds` | `data/demo/reference/atc_reference.rds` |
| SQLite | `data/database/pharmabi.sqlite` | `data/demo/database/pharmabi.sqlite` |
| Power BI CSVs | `data/powerbi/` | `data/demo/powerbi/` |

A missing demo file produces an error; the workflow does not fall back to private inputs.

Generated demo files are ignored through `/data/demo/`. The internal release checklist is also ignored because it contains operational evidence. Source code and reviewed demo images remain versioned.

The portfolio PBIP stays under `powerbi/`. The operational Power BI project is a separate local copy outside the repository. A PBIP entry file references report/model folders, so the complete project directory is copied. Future report-definition changes require intentional transfer between those copies.

## 4. Synthetic generation

The generator sets seed `47031L` and constructs 240 fictional products across 12 GM groups and eight manufacturers.

Base net unit prices are drawn from the configured interval and unit costs from configured price proportions. Forty products receive public human ATC codes across twelve selected level 2 groups; twenty veterinary products receive the explicit scenario codes; 180 have no ATC assignment.

The calendar covers 2026. The fictional sales window is 2026-01-05 to 2026-09-20, excluding 2026-04-12 and 2026-04-13. One receipt is allocated to each remaining date before the rest of the 4.800 receipt headers are sampled, producing 257 retail active days.

Receipt counters restart each date. Times are sampled between 09:00 and 19:59 and sorted within dates. Fifteen-, thirty- and sixty-minute labels are derived from minutes after midnight.

Basket sizes range from one to eight distinct product codes. Popularity weights change selection probabilities. Three two-product bundles are proposed in some multi-product baskets; remaining products are sampled without replacement, excluding the chosen bundle.

The product rows join receipt headers and catalogue attributes. Package quantities and line totals are generated, then eight return rows and twelve separate below-cost rows are injected. Three fictional products have zero recorded cost. Dependent profit and margin are recalculated.

Three additional non-retail transactions have six distinct products each. Their headers have unique identifiers, `number_sales = 0L` and explicit `sale_type = "non_retail"`.

The final RDS has the same 20 fact fields as the private analytical schema. Generator helpers such as unit prices and planned basket size are excluded.

Reproduction requires the whole script, unchanged settings, the same public reference snapshot, compatible R/RNG configuration and relevant package versions. The generator currently reads the public snapshot from `data/reference/` before saving its demo copy; retaining that input snapshot matters.

## 5. Private ETL design retained

The original pipeline imports four management-system source roles: transactional time slots, GM classifications, ATC classifications and article information.

It cleans and enriches the fact using latest available product classifications and validates the result. Latest classification is a current-view policy across the period, not historical as-of modelling.

The cleaning rule removes missing product descriptions; shared validation additionally rejects blank required text. Package quantities are measures, not repeated product rows.

Tenant/operator fields and the redundant export-period field are omitted from the fact. Manufacturer attributes are retained but do not establish a supplier/purchasing model.

Private receipt classification is configured in the local, Git-ignored file `config/sales_classification.R`. It must define `non_retail_sale_ids` as a character vector of unique, non-blank receipt identifiers without surrounding whitespace. The fact builder classifies matching receipts as `non_retail` and the remainder as `retail`. An explicitly empty `character(0)` means no exceptions are configured.

The private fact builder stops before constructing or saving the fact if this file is missing or invalid. There is no implicit all-retail fallback. Configure the file separately on each operational computer, using the authorized receipt list. Real identifiers must not be inserted into versioned source or examples. The synthetic generator assigns its own sale types and does not read this private configuration.

The private pipeline wrapper continues to choose private paths explicitly. Existing R analysis scripts and the report/Knit handler still use private inputs. Demo use of that legacy analysis/report route remains pending and is not part of the public launch instructions.

## 6. Validation and SQLite

The shared validator enforces fourteen checks detailed in [Data quality report](data_quality_report.md). Unusual quantities/margins are retained in diagnostic objects rather than automatically deleted.

The SQLite builder:

1. Converts Date values to ISO text.
2. Builds canonical product labels from the latest observed descriptions.
3. Builds full calendar years and ISO weekday attributes.
4. Loads ATC level 2 labels from the selected reference.
5. Writes `fact_sales`, `dim_products`, `dim_date` and `dim_atc_level2`.
6. Recreates `vw_retail_sales` from `sql/04_create_retail_view.sql`.
7. Executes the existing overview, monthly, sales-by-type and minimum-volume product queries.
8. Reconciles row counts, sales-by-type and monthly retail values with R.

Logical key and lookup uniqueness are checked in R. The current build does not declare physical SQL primary/foreign-key constraints.

The minimum-volume query uses `HAVING` to restrict product volume and ranks by recorded profit. It is an exploratory filter, not an inventory recommendation.

## 7. Measures and analytical scope

Revenue is net of VAT. Recorded profit is net revenue minus recorded product costs. Overall margin uses aggregate profit/revenue rather than an average of row margins.

Returns remain signed. Recorded negative profit does not always mean a below-cost sale. Zero recorded cost may reflect source incompleteness and can inflate apparent profitability.

Active days are dates with retail transactions. A full calendar date table does not prove that a store was open or that a missing observation means zero sales.

Product segmentation in the legacy analysis uses upper-quartile thresholds for package volume and total recorded profit. Sales volume is a proxy for activity, not stock turnover.

Concentration is calculated from cumulative shares after sorting. Profit-ranked category sets must not be described as the minimum category sets for revenue or packages unless those metrics have been sorted independently.

Human ATC indicators use only the classified human scope; their shares and receipt frequencies have different denominators from whole-assortment retail indicators. Receipts can overlap between categories.

## 8. Public ATC reference

The AIFA builder reads a semicolon-separated source with `CODICE_ATC` and `DESCRIZIONE`. It trims values, standardizes codes, converts empty strings to NA, derives levels from code lengths, removes identical rows and validates required values, code structure and uniqueness.

The recorded source correction `JO5AR13` → `J05AR13` remains explicit in the builder. The downloaded CSV is retained unchanged. References: [AIFA medicine lists](https://www.aifa.gov.it/liste-dei-farmaci) and the [WHO ATC index](https://atcddd.fhi.no/atc_ddd_index/).

Level 2 labels are joined by three-character code. The tested snapshot contains 94 such reference rows, while the demo assigns human products across twelve selected groups.

The implemented human rule excludes missing/blank ATC and the three codes `P52AC13`, `P53AX65` and `P54AB51`. It does not exclude all P-prefixed codes and is not a complete classifier for arbitrary new veterinary codes.

## 9. Shiny implementation

`PHARMABI_DATA_MODE` is read at application startup; its default is `demo`. The path resolver rejects invalid modes. The title and sidebar identify synthetic or private scope.

For the public demonstration:

```r
Sys.setenv(PHARMABI_DATA_MODE = "demo")
shiny::runApp(here::here("dashboard"), launch.browser = TRUE)
```

Every query opens the selected SQLite database read-only and closes it on exit. SQL comes from version-controlled files, with bound parameters for date intervals and supported ranking selectors. Date bounds are loaded at startup; restart the application after rebuilding its database.

Date validation covers incomplete/inverted selections and intervals without retail transactions. Dependent outputs display a validation message and recover when valid dates are restored.

### Period comparisons

Both endpoints are inclusive. The overview query is reused for Current and Reference periods. Daily values divide the full period total by its retail active-day count, not by an average of monthly averages.

Absolute change is current minus reference; relative change divides by the reference, with N/A for zero or missing reference. Margin changes use percentage points.

With comparison enabled, the overview chart shows one bar per period; otherwise it shows monthly values. Partial calendar months are marked. Product and ATC rankings and the merchandise group profit chart follow the Current period.

GM comparisons use `sql/11_gm_revenue_by_period.sql` and retain categories appearing in either interval. Missing category-period revenue is zero. Total and daily comparisons use the same whole-period active-day denominators. Sorting precedes display formatting; scoped CSS keeps table headers visible.

### Basket structure

`sql/12_basket_receipts_by_period.sql` returns receipt-level counts and amounts. `summarise_basket_receipts()` applies the same summary logic to both periods.

The interface shows receipt count, multi-product share, mean distinct products and mean net receipt revenue. The distribution chart labels bar counts. Comparison displays changes in multi-product share (percentage points), mean distinct products and mean net revenue.

Reference-period validation does not prevent Current-period outputs from being shown.

### Product pairs

`sql/13_basket_pair_frequency_by_period.sql` first selects distinct receipt-product combinations. A self-join on receipt with `product_code_a < product_code_b` produces each unordered pair once per containing receipt. Labels are joined after aggregation.

For all retail receipts `N`, individual counts `n_A`/`n_B` and co-occurrences `n_AB`:

| Metric | Formula |
|---|---|
| Receipts together | `n_AB` |
| Support | `n_AB / N` |
| Confidence A to B | `n_AB / n_A` |
| Confidence B to A | `n_AB / n_B` |
| Expected receipts together | `n_A * n_B / N` |
| Lift | `n_AB * N / (n_A * n_B)` |

Real-number SQL arithmetic preserves fractional results. Metric denominators are calculated before the minimum-count display filter. The interface shows up to twenty qualifying pairs; the default minimum is five.

Code ordering does not express purchase sequence. Current-period pair results retain return rows and do not identify customers. A collapsible guide explains the indicators.

## 10. Power BI implementation

The portfolio copy imports four CSVs from `data/demo/powerbi/`. Required text parameter `DataFolder` supplies the absolute directory with its trailing separator.

`File.Contents(DataFolder & "fact_sales_retail.csv")` illustrates the path construction. Product, date and ATC queries use the same parameter. GM references the retail query.

CSV export uses comma delimiters and decimal points. Headers are promoted before types; codes remain Text. Numeric parsing uses the export's decimal-point locale, independently of European display formatting.

Active one-to-many relationships connect the calendar, canonical products, GM and level 2 ATC to retail sales with single-direction dimension-to-fact filtering. Automatic date/time is disabled and the explicit calendar is marked as the date table.

### Measures and rankings

`Net Revenue`, `Recorded Profit`, `Packages Sold`, `Receipts`, `Overall Margin` and `Distinct Products Sold` aggregate fact rows in the current filter context.

The disconnected `Ranking Metric` selector has recorded profit, net revenue and packages. `Selected Ranking Metric` uses `SELECTEDVALUE()` and `SWITCH()`, defaulting to recorded profit when no single selection exists.

The selected measure controls horizontal values, Top 10 filtering and descending sort. Dynamic format strings preserve numeric types while switching euro amounts and integer quantities. Data labels use no automatic scaling and inherit precision after removal of fixed overrides.

Month selections are synchronized on all four pages; metric selections on the three ranking pages. Product/category labels combine descriptions and codes.

### Category scope and tooltips

`dim_gm` is a Power Query reference retaining unique code-description combinations. Its unique code assumption must be checked if a new source provides conflicting category descriptions.

Power Query derives `atc_level2` and `is_human_atc`. The Human ATC page filters the flag; all other pages retain the complete retail scope.

Product tooltips include profit, revenue, packages, receipts and overall margin. GM/ATC tooltips also include distinct products sold. These use measures rather than a raw product code aggregated as First.

Automatic subtitles listing technical fields were removed from ranking charts. Every portfolio page displays the synthetic-data label. The overview note identifies the fictional sales window and partial January/September coverage.

### Separate operational copy

The local operational project uses its own report/model folders and points to private CSVs. It is kept outside the public repository. Changes to measures and visuals do not propagate automatically between the copies.

## 11. Reporting, reproducibility and release boundaries

The legacy custom Knit handler generates HTML and an A4 landscape PDF before optional email delivery. The verified operational setup uses local configuration and OS keyring credentials. A render/PDF failure prevents sending; SMTP acceptance is not proof of inbox receipt.

The current report still sources private R analyses. It has not been converted or verified for the synthetic demo. Public demo instructions therefore launch Shiny/Power BI, not that report.

Use the same reference snapshot, scenario settings, R/RNG configuration and relevant package versions for exact reproduction. Generated datasets, databases, caches and credentials are excluded from Git.

Windows demo validation and smoke checks are recorded in [Data quality report](data_quality_report.md). On 2026-11-03 the separate Linux portfolio checkout completed reference preparation, demo generation, validation/build, CSV export and manual Shiny checks. The new [automated verifier](demo_verification.md) passed all 70 checks on Linux, including independent receipt-pair enumeration in R and comparison with SQL. It opens SQLite read-only and writes per-run reports under the ignored `data/demo/validation/` directory. Its Windows execution, macOS and a clean setup remain unverified.

Updating current files does not remove operational values from earlier commits or cached copies. Repository/history and remaining public-asset review remain separate release tasks.

## Document revision

2026-11-02 — Consolidated the public technical description around the synthetic demo, retained analytical definitions and implementation decisions, corrected stale model/roadmap statements and removed operational numerical evidence.

2026-11-03 — Added the standalone demo verifier and recorded successful Linux data and Shiny checks.
