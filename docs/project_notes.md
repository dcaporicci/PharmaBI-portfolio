---
title: "Project notes"
author: "Danilo Caporicci"
date: "2026-11-02"
output: html_document
---

# PharmaBI — Public development notes

These notes retain the development decisions relevant to the public portfolio. Operational observations, business-specific identifiers and confidential numerical results have been removed from this edition; the original working documents are retained privately.

All numerical fixture values below refer to synthetic demonstration data. Development dates describe the project's history, not a business's sales calendar.

## Foundations — July to August 2026

Defined the analytical grain as one product code within one transaction, with package quantity stored separately.

Built the R pipeline for importing management-system exports, assessing quality, cleaning records, constructing product-classification lookup tables, building the fact table and validating it.

Selected the latest available product classification for the current analytical view. Kept missing ATC values where no classification is assigned. Removed records without product descriptions rather than relying on a list of particular product identifiers.

Separated retail and non-retail transaction scope. Explored product performance, concentration and segmentation while documenting the effects of recorded costs.

## Public ATC reference — 2026-10-05

Added `R/reference/01_build_atc_reference.R` using public AIFA data.

The builder standardizes code/description fields, derives hierarchy levels, validates code structure and uniqueness, and retains a dated source snapshot. A documented `JO5AR13` to `J05AR13` source correction and identical-row deduplication are applied in code.

Replaced blanket removal of P-prefixed codes with an explicit veterinary exclusion list. Human antiparasitic groups must not be excluded merely because their code begins with P.

## Retail reporting and indicator definitions — 2026-10-09 to 2026-10-13

Clarified that analytical revenue is net of VAT and that recorded profit precedes operating expenses. Revenue comparisons require matching product, quantity and transaction period; current catalogue prices are not substitutes for historical transaction prices.

Used numeric weekday codes and explicit labels for portability. Renamed category-specific revenue-per-receipt indicators to avoid implying complete receipt value.

Created the R Markdown report and custom Knit handler for HTML/PDF generation and local email delivery. The operational workflow was verified on Windows 11 with Infomaniak. Credentials and generated reports remain local.

Resolved a custom Knit invocation problem using `knit: |-`. A later PDF timeout succeeded on retry; the cause was not established.

Added receipt composition and unordered product-pair analysis, including support, directional confidence, expected counts under independence and lift. The public notes do not reproduce operational pair statistics.

## SQLite and cross-platform dashboard — October 2026

Added SQLite, the retail view, product/date/ATC dimensions and reusable SQL queries. Reconciled stored row counts, sales-by-type aggregates and monthly retail results with R.

Used DB Browser for SQLite to inspect the model independently. Built Shiny as the primary interface for development across operating systems, later adding Power BI as a complementary Windows implementation.

Added interactive dates, retail KPIs, monthly totals and per-active-day values; product and ATC rankings; merchandise group comparisons; and validation for incomplete, inverted or empty intervals.

Period comparisons use inclusive boundaries, current-minus-reference changes and percentage-point changes for margins. Category comparisons retain groups present in either interval and use whole-period retail active days.

Added readable date controls, ISO dates, European numeric formatting, wrapped category labels and sticky comparison-table headings.

## Reproducibility and first Power BI pages — 2026-10-27

Corrected the pipeline timer and verified the complete private workflow in a fresh R session on Windows with the existing local packages and source files. This was not a clean-installation test.

Documented the setup in English and Italian. Added CSV exports for Power BI and preserved identifiers as text. Promoted CSV headers before converting types; used the CSV's decimal-point locale for numeric parsing while retaining European display formatting.

Created the Power BI sales overview with four measures and a monthly chart. Disabled automatic date/time tables and used the explicit date dimension.

## Shiny baskets and Power BI model expansion — 2026-10-28 to 2026-10-29

Extended Shiny with receipt-level indicators, a labelled basket-size chart, pair metrics, a minimum co-occurrence control and an in-context indicator guide.

Added a shared basket-summary helper for current/reference comparisons. Differences in multi-product receipt share use percentage points. Pair outputs continue to follow the Current period only.

Added the Power BI product, merchandise group and Human ATC pages. Product labels combine canonical descriptions and codes. A disconnected `Ranking Metric` table and `Selected Ranking Metric` measure control values, Top 10 selection and sorting.

Dynamic format strings retain numeric measures while switching monetary and quantity displays. Resetting a formatting block also resets its nested settings, so display units must be checked afterwards.

Completed the four-page report and synchronized the relevant slicers. Added the `DataFolder` parameter for all four CSV queries. Empty observed-data selections produce blanks, not an assertion of zero sales.

## Portfolio isolation and synthetic scenario — 2026-10-30

Established a synthetic portfolio path separate from the operational data.

The generator uses seed `47031L`, a fictional catalogue of 240 products in 12 GM categories, eight fictional manufacturers and public ATC metadata. It does not read operational sales records.

Forty catalogue products receive human ATC codes, twenty receive the explicit veterinary codes, and 180 remain unclassified. These are scenario settings rather than business findings.

Generated 4.800 retail receipt headers over 257 dates between 2026-01-05 and 2026-09-20. Chose two fictional dates without sales and inserted recurring pairs into some multi-product baskets.

The tested fixture has 7.817 retail product presences. Added eight returns, twelve below-cost rows, zero recorded costs for three products, and three non-retail transactions comprising eighteen rows.

Created `R/config/data_paths.R`. The resolver requires an explicit mode and returns separate fact, reference, database and export paths.

## Shared validation, database build and Shiny demo — 2026-10-30

Expanded the fact validator to 14 structural and consistency checks, then extracted it into `R/validation/validate_fact_sales.R`. The private pipeline wrapper retains its original role and exposes existing diagnostics; demo validation returns a separate result list.

Extracted the SQLite builder while retaining its transformations and reconciliations. The demo command validates the synthetic RDS and builds `data/demo/database/pharmabi.sqlite`.

All 14 demo checks and the existing SQL/R reconciliation checks passed. A before/after fingerprint comparison confirmed that building the demo left the private SQLite file unchanged.

Updated Shiny to default to demo mode through `PHARMABI_DATA_MODE`, with visible synthetic/private scope labels. The demo overview matched the synthetic database and recovered from an empty date selection on Windows.

## Synthetic exports and Power BI portfolio copy — 2026-11-02

Extracted `R/export/export_powerbi.R` and added `R/demo/03_export_demo_powerbi.R`. Exports use a read-only database connection, preserve numeric values, and validate the expected demo prefixes before writes.

The tested CSVs contain 7.817 retail rows, 365 calendar dates, 240 product labels and 94 ATC level 2 reference labels.

Preserved a complete operational Power BI copy outside the repository. The tracked portfolio copy now reads `data/demo/powerbi/` through `DataFolder`. Report and semantic-model folders are copied together with the PBIP entry file.

Checked the four pages, synchronized month/metric controls, empty-month handling and recovery. Updated the coverage note and labelled every page as synthetic.

Reviewed ranking tooltips and removed automatic subtitles listing technical fields. Prepared four `-demo.png` screenshots for public documentation.

## Public documentation review — 2026-11-02

Reworked the two READMEs and six supporting documents to describe the synthetic public path accurately.

Corrected the dictionary's old gross-revenue description, added `sale_type` to the fact schema and distinguished ETL lookup tables, SQLite dimensions and Power BI relationships.

Removed operational aggregates, detailed product observations and old screenshot references from these documents. Retained design decisions and verification boundaries rather than reinterpreting operational findings as synthetic ones.

The legacy R analysis/report path still selects operational inputs and is not part of the public demo commands.

## Remaining release work

- Review the remaining repository files and Git history; replacing current documents does not remove earlier versions.
- Remove operational screenshots from the public working tree after retaining private copies, then update any remaining links.
- Capture and review replacement Shiny screenshots using demo mode.
- Record reproducibility inputs and verify the complete demo sequence on Linux / in a clean setup.
- Independently reconcile detailed synthetic basket/pair outputs before publishing numerical pair findings.
- Prepare a short presentation and a local demonstration fallback.
- Complete the release review and choose a version tag.

The full educational guide, historical data and inventory integration remain later work.
