-- PharmaBI
-- Top 8 merchandise groups by recorded profit
-- Parameters: start date, end date (YYYY-MM-DD)

SELECT
  gm_code,
  gm_desc,
  SUM(profit) AS profit
FROM vw_retail_sales
WHERE date >= ?
  AND date <= ?
GROUP BY gm_code, gm_desc
ORDER BY profit DESC, gm_code, gm_desc
LIMIT 8;