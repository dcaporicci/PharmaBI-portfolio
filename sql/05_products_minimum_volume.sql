-- PharmaBI
-- Top products by recorded profit, with latest observed labels
-- Include products with at least 10 packages sold

SELECT
  f.product_code,
  p.product_desc,
  SUM(f.packages) AS packages_sold,
  COUNT(DISTINCT f.sale_id) AS receipts,
  SUM(f.revenue) AS revenue,
  SUM(f.costs) AS costs,
  SUM(f.profit) AS profit,
  SUM(f.profit) / NULLIF(SUM(f.revenue), 0)
    AS overall_margin
FROM vw_retail_sales AS f
LEFT JOIN dim_products AS p
  ON f.product_code = p.product_code
GROUP BY f.product_code, p.product_desc
HAVING SUM(f.packages) >= 10
ORDER BY profit DESC, f.product_code
LIMIT 20;