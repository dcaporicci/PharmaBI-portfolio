-- PharmaBI
-- Summarise recorded sales by type

SELECT
  sale_type,
  COUNT(*) AS sales_rows,
  COUNT(DISTINCT sale_id) AS transactions,
  SUM(packages) AS packages_sold,
  SUM(revenue) AS revenue,
  SUM(costs) AS costs,
  SUM(profit) AS profit
FROM fact_sales
GROUP BY sale_type
ORDER BY sale_type;
