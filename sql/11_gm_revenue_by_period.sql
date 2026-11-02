-- PharmaBI
-- Net revenue by merchandise group for an inclusive date interval
-- Parameters: start date, end date (YYYY-MM-DD)

SELECT
  gm_code,
  gm_desc,
  SUM(revenue) AS revenue
FROM vw_retail_sales
WHERE date >= ?
  AND date <= ?
GROUP BY
  gm_code,
  gm_desc
ORDER BY
  revenue DESC,
  gm_code;