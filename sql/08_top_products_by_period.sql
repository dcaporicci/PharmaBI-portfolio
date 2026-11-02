-- PharmaBI
-- Top 10 retail products by the selected metric
-- Parameters: start date, end date, ranking metric

SELECT
  f.product_code,
  p.product_desc,
  SUM(f.packages) AS packages_sold,
  COUNT(DISTINCT f.sale_id) AS receipts,
  SUM(f.revenue) AS revenue,
  SUM(f.profit) AS profit,
  SUM(f.profit) / NULLIF(SUM(f.revenue), 0)
    AS overall_margin
FROM vw_retail_sales AS f
LEFT JOIN dim_products AS p
  ON f.product_code = p.product_code
WHERE f.date >= ?
  AND f.date <= ?
GROUP BY f.product_code, p.product_desc
ORDER BY
  CASE ?
    WHEN 'profit' THEN SUM(f.profit)
    WHEN 'revenue' THEN SUM(f.revenue)
    WHEN 'packages' THEN SUM(f.packages)
  END DESC,
  f.product_code
LIMIT 10;