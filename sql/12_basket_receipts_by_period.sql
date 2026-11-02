-- PharmaBI
-- One row per retail receipt within an inclusive date interval
-- Parameters: start date, end date (YYYY-MM-DD)

SELECT
  sale_id,
  date,
  COUNT(DISTINCT product_code) AS unique_products,
  SUM(packages) AS packages_sold,
  SUM(revenue) AS revenue,
  SUM(costs) AS costs,
  SUM(profit) AS profit
FROM vw_retail_sales
WHERE date >= ?
  AND date <= ?
GROUP BY sale_id, date
ORDER BY date, sale_id;