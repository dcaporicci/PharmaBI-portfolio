-- PharmaBI
-- Retail KPIs for an inclusive date interval
-- Active days are dates with at least one recorded retail sale
-- Parameters: start date, end date (YYYY-MM-DD)

SELECT
  COUNT(DISTINCT date) AS active_days,
  COUNT(DISTINCT sale_id) AS receipts,
  SUM(revenue) AS revenue,
  SUM(profit) AS profit,
  SUM(profit) / NULLIF(SUM(revenue), 0)
    AS overall_margin,
  SUM(revenue) / NULLIF(COUNT(DISTINCT date), 0)
    AS revenue_per_active_day,
  SUM(profit) / NULLIF(COUNT(DISTINCT date), 0)
    AS profit_per_active_day
FROM vw_retail_sales
WHERE date >= ?
  AND date <= ?;