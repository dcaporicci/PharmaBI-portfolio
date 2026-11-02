-- PharmaBI
-- Define the retail sales view

CREATE VIEW vw_retail_sales AS
SELECT *
FROM fact_sales
WHERE sale_type = 'retail';