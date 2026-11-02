-- PharmaBI
-- Calculate the retail sales baseline
-- Revenue is VAT excluded

SELECT
  MIN(date) AS start_date,
  MAX(date) AS end_date,
  COUNT(DISTINCT sale_id) AS receipts,
  COUNT(DISTINCT product_code) AS unique_products,
  SUM(packages) AS packages_sold,
  SUM(revenue) AS revenue,
  SUM(costs) AS costs,
  SUM(profit) AS profit,
  SUM(profit) / NULLIF(SUM(revenue), 0) AS overall_margin,
  SUM(revenue) / NULLIF(COUNT(DISTINCT sale_id), 0)
    AS average_net_revenue_per_receipt
FROM vw_retail_sales;