-- PharmaBI
-- Count receipts containing each unordered product pair
-- Add product descriptions from the product dimension
-- Parameters: start date, end date (YYYY-MM-DD)

WITH basket_products AS (
  SELECT DISTINCT
    sale_id,
    product_code
  FROM vw_retail_sales
  WHERE date >= ?
    AND date <= ?
),

receipt_total AS (
  SELECT
    COUNT(DISTINCT sale_id) AS receipts
  FROM basket_products
),

product_frequency AS (
  SELECT
    product_code,
    COUNT(*) AS receipts
  FROM basket_products
  GROUP BY product_code
),

pair_frequency AS (
  SELECT
    a.product_code AS product_code_a,
    b.product_code AS product_code_b,
    COUNT(*) AS receipts_together
  FROM basket_products AS a
  INNER JOIN basket_products AS b
    ON a.sale_id = b.sale_id
    AND a.product_code < b.product_code
  GROUP BY a.product_code, b.product_code
)

SELECT
  pairs.product_code_a,
  product_a.product_desc AS product_desc_a,
  pairs.product_code_b,
  product_b.product_desc AS product_desc_b,
      pairs.receipts_together,
  frequency_a.receipts AS receipts_a,
  frequency_b.receipts AS receipts_b,
  1.0 * pairs.receipts_together /
    frequency_a.receipts AS confidence_a_to_b,
  1.0 * pairs.receipts_together /
    frequency_b.receipts AS confidence_b_to_a,
  1.0 * pairs.receipts_together /
    totals.receipts AS support,
  1.0 * frequency_a.receipts * frequency_b.receipts /
    totals.receipts AS expected_receipts_together,
  1.0 * pairs.receipts_together * totals.receipts /
    (1.0 * frequency_a.receipts * frequency_b.receipts) AS lift
FROM pair_frequency AS pairs
CROSS JOIN receipt_total AS totals
INNER JOIN product_frequency AS frequency_a
  ON pairs.product_code_a = frequency_a.product_code
INNER JOIN product_frequency AS frequency_b
  ON pairs.product_code_b = frequency_b.product_code
LEFT JOIN dim_products AS product_a
  ON pairs.product_code_a = product_a.product_code
LEFT JOIN dim_products AS product_b
  ON pairs.product_code_b = product_b.product_code
ORDER BY
  pairs.receipts_together DESC,
  pairs.product_code_a,
  pairs.product_code_b;
