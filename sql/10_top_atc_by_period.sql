-- PharmaBI
-- Top 10 human ATC level 2 categories
-- Parameters: start date, end date, ranking metric
-- Veterinary exclusions refer to codes identified in the current source

SELECT
  SUBSTR(f.atc_code, 1, 3) AS atc_level2,
  a.atc_level2_desc,
  SUM(f.packages) AS packages_sold,
  COUNT(DISTINCT f.sale_id) AS receipts,
  SUM(f.revenue) AS revenue,
  SUM(f.profit) AS profit,
  SUM(f.profit) / NULLIF(SUM(f.revenue), 0)
    AS overall_margin
FROM vw_retail_sales AS f
LEFT JOIN dim_atc_level2 AS a
  ON SUBSTR(f.atc_code, 1, 3) = a.atc_level2
WHERE f.date >= ?
  AND f.date <= ?
  AND f.atc_code IS NOT NULL
  AND f.atc_code NOT IN (
    'P52AC13',
    'P53AX65',
    'P54AB51'
  )
GROUP BY SUBSTR(f.atc_code, 1, 3), a.atc_level2_desc
ORDER BY
  CASE ?
    WHEN 'packages' THEN SUM(f.packages)
    WHEN 'revenue' THEN SUM(f.revenue)
    WHEN 'profit' THEN SUM(f.profit)
  END DESC,
  atc_level2
LIMIT 10;