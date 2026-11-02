-- PharmaBI
-- Monthly retail revenue totals and active-day averages
-- Parameters: start date, end date (YYYY-MM-DD)

SELECT
  SUBSTR(date, 1, 7) AS month,
  COUNT(DISTINCT date) AS active_days,
  SUM(revenue) AS revenue,
  SUM(revenue) / NULLIF(COUNT(DISTINCT date), 0)
    AS revenue_per_day
FROM vw_retail_sales
WHERE date >= ?
  AND date <= ?
GROUP BY SUBSTR(date, 1, 7)
ORDER BY month;