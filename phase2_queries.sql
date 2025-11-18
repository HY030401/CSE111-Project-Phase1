-- 1) Total revenue by country (None)
SELECT c.name AS country, SUM(il.line_total) AS revenue
FROM invoice i
JOIN customer cu ON cu.customer_id = i.customer_id
JOIN country c ON c.country_id = cu.country_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
GROUP BY c.name
ORDER BY revenue DESC;

-- 2) Best-selling products by units (1:N)
SELECT p.sku, p.name, SUM(il.quantity) AS units, SUM(il.line_total) AS sales
FROM product p
JOIN invoice_line il ON il.product_id = p.product_id
GROUP BY p.sku, p.name
ORDER BY units DESC, sales DESC;

-- 3) Revenue by category (N:M)
SELECT cat.name AS category, SUM(il.line_total) AS revenue
FROM category cat
JOIN product_category pc ON pc.category_id = cat.category_id
JOIN invoice_line il ON il.product_id = pc.product_id
GROUP BY cat.name
ORDER BY revenue DESC;

-- 4) Orders per customer (1:N)
SELECT cu.full_name, COUNT(*) AS orders
FROM customer cu
JOIN invoice i ON i.customer_id = cu.customer_id
GROUP BY cu.full_name
ORDER BY orders DESC;

-- 5) Average order value per customer (None)
SELECT cu.full_name, ROUND(AVG(t.total),2) AS avg_order_value
FROM customer cu
JOIN (
  SELECT i.invoice_id, i.customer_id, SUM(il.line_total) AS total
  FROM invoice i JOIN invoice_line il ON il.invoice_id = i.invoice_id
  GROUP BY i.invoice_id
) t ON t.customer_id = cu.customer_id
GROUP BY cu.full_name
ORDER BY avg_order_value DESC;

-- 6) Monthly revenue trend (None)
SELECT DATE_TRUNC('month', i.invoice_date) AS month, SUM(il.line_total) AS revenue
FROM invoice i
JOIN invoice_line il ON il.invoice_id = i.invoice_id
GROUP BY DATE_TRUNC('month', i.invoice_date)
ORDER BY month;

-- 7) Customers with no orders (None)
SELECT cu.full_name, cu.email
FROM customer cu
LEFT JOIN invoice i ON i.customer_id = cu.customer_id
WHERE i.invoice_id IS NULL;

-- 8) Products never ordered (None)
SELECT p.sku, p.name
FROM product p
LEFT JOIN invoice_line il ON il.product_id = p.product_id
WHERE il.invoice_id IS NULL;

-- 9) Top 3 customers by revenue (window function)
WITH cust_rev AS (
  SELECT cu.customer_id, cu.full_name, SUM(il.line_total) AS revenue
  FROM customer cu
  JOIN invoice i ON i.customer_id = cu.customer_id
  JOIN invoice_line il ON il.invoice_id = i.invoice_id
  GROUP BY cu.customer_id, cu.full_name
)
SELECT full_name, revenue, RANK() OVER (ORDER BY revenue DESC) AS rnk
FROM cust_rev
ORDER BY rnk
LIMIT 3;

-- 10) Invoices with partial refunds (payments < invoice lines)  (1:N)
SELECT i.invoice_id,
       SUM(il.line_total) AS billed,
       SUM(p.amount)      AS paid
FROM invoice i
JOIN invoice_line il ON il.invoice_id = i.invoice_id
JOIN payment p ON p.invoice_id = i.invoice_id
GROUP BY i.invoice_id
HAVING SUM(p.amount) < SUM(il.line_total);

-- 11) Update: mark PAID invoices as SHIPPED if older than 7 days (None)
UPDATE invoice
SET status = 'SHIPPED'
WHERE status = 'PAID' AND invoice_date < NOW() - INTERVAL '7 days'
RETURNING invoice_id, status;

-- 12) Insert: add a new category and map an existing product (N:M)
INSERT INTO category(name, description) VALUES ('Gifts','Giftable items')
RETURNING category_id;

INSERT INTO product_category(product_id, category_id)
SELECT p.product_id, (SELECT category_id FROM category WHERE name='Gifts')
FROM product p WHERE p.sku = 'HM001';

-- 13) Delete: unmap a product from a category (N:M)
DELETE FROM product_category
WHERE product_id = (SELECT product_id FROM product WHERE sku='HM001')
  AND category_id = (SELECT category_id FROM category WHERE name='Seasonal');

-- 14) Update: increase price by 10% for all products in 'Stationery' (1:N)
UPDATE product SET unit_price = ROUND(unit_price * 1.10, 2)
WHERE product_id IN (
  SELECT product_id FROM product_category pc
  JOIN category c ON c.category_id = pc.category_id
  WHERE c.name = 'Stationery'
)
RETURNING product_id, unit_price;

-- 15) Select: customers and their last order date (1:N)
SELECT cu.full_name, MAX(i.invoice_date) AS last_order
FROM customer cu
LEFT JOIN invoice i ON i.customer_id = cu.customer_id
GROUP BY cu.full_name
ORDER BY last_order NULLS LAST;

-- 16) Exists: customers who bought any Seasonal product (N:M)
SELECT DISTINCT cu.full_name
FROM customer cu
WHERE EXISTS (
  SELECT 1
  FROM invoice i
  JOIN invoice_line il ON il.invoice_id = i.invoice_id
  JOIN product_category pc ON pc.product_id = il.product_id
  JOIN category c ON c.category_id = pc.category_id
  WHERE i.customer_id = cu.customer_id AND c.name = 'Seasonal'
);

-- 17) Subquery: invoices above overall average value (1:N)
WITH inv_tot AS (
  SELECT i.invoice_id, SUM(il.line_total) AS total
  FROM invoice i JOIN invoice_line il ON il.invoice_id = i.invoice_id
  GROUP BY i.invoice_id
)
SELECT invoice_id, total
FROM inv_tot
WHERE total > (SELECT AVG(total) FROM inv_tot)
ORDER BY total DESC;

-- 18) Delete: remove a refund smaller than 1 currency unit (cleanup example) (None)
DELETE FROM payment
WHERE amount < 0 AND ABS(amount) < 1
RETURNING payment_id, amount;

-- 19) Parameter-like example: find products by keyword (None)
SELECT p.sku, p.name FROM product p WHERE LOWER(p.name) LIKE '%' || LOWER('mug') || '%';

-- 20) HAVING: customers with total revenue >= 20  (1:N)
SELECT cu.full_name, SUM(il.line_total) AS revenue
FROM customer cu
JOIN invoice i ON i.customer_id = cu.customer_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
GROUP BY cu.full_name
HAVING SUM(il.line_total) >= 20
ORDER BY revenue DESC;

-- 21) Bonus: Revenue share by category (percentage of total) (N:M)
WITH cat_rev AS (
  SELECT cat.name AS category, SUM(il.line_total) AS revenue
  FROM category cat
  JOIN product_category pc ON pc.category_id = cat.category_id
  JOIN invoice_line il ON il.product_id = pc.product_id
  GROUP BY cat.name
), total AS (
  SELECT SUM(revenue) AS grand_total FROM cat_rev
)
SELECT c.category,
       c.revenue,
       ROUND(100.0 * c.revenue / t.grand_total, 2) AS pct_of_total
FROM cat_rev c CROSS JOIN total t
ORDER BY c.revenue DESC;
