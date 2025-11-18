-- 1) Countries
INSERT INTO country(name) VALUES
('United Kingdom'), ('Germany'), ('France'), ('Spain'), ('USA');

-- 2) Customers
INSERT INTO customer(full_name, email, phone, country_id, created_at) VALUES
('Alice Brown','alice@example.com','+44-1000', 1, NOW() - INTERVAL '120 days'),
('Bob Smith','bob@example.com','+49-2000',    2, NOW() - INTERVAL '90 days'),
('Chris Lee','chris@example.com','+33-3000',  3, NOW() - INTERVAL '30 days'),
('Diana Wu','diana@example.com','+34-4000',  4, NOW() - INTERVAL '10 days'),
('Evan Kim','evan@example.com','+1-555',     5, NOW() - INTERVAL '5 days');

-- 3) Categories
INSERT INTO category(name, description) VALUES
('Stationery','Pens, pencils, notebooks'),
('Home','Home & kitchen accessories'),
('Toys','Kids toys and games'),
('Seasonal','Holiday / seasonal items');

-- 4) Products
INSERT INTO product(sku, name, description, unit_price, is_active, created_at) VALUES
('ST001','Pencil Set','HB pencils (pack of 10)', 3.50, TRUE, NOW() - INTERVAL '100 days'),
('ST002','Notebook A5','A5 lined notebook',      4.20, TRUE, NOW() - INTERVAL '100 days'),
('HM001','Ceramic Mug','350ml mug',              6.90, TRUE, NOW() - INTERVAL '80 days'),
('HM002','Tea Towel','Cotton kitchen towel',     2.80, TRUE, NOW() - INTERVAL '80 days'),
('TY001','Building Blocks','24-piece blocks',    9.99, TRUE, NOW() - INTERVAL '60 days'),
('SE001','Xmas Ornament','Glass ornament',       7.50, TRUE, NOW() - INTERVAL '40 days');

-- 5) Product-Category mapping (M:N)
INSERT INTO product_category(product_id, category_id) VALUES
(1,1), (2,1),     -- Stationery
(3,2), (4,2),     -- Home
(5,3),            -- Toys
(6,4), (3,4);     -- Seasonal + Mug in Seasonal too

-- 6) Invoices
INSERT INTO invoice(customer_id, invoice_date, status, currency, ship_to_country) VALUES
(1, NOW() - INTERVAL '25 days', 'PAID',    'GBP','United Kingdom'),  -- id 1
(2, NOW() - INTERVAL '20 days', 'PAID',    'EUR','Germany'),         -- id 2
(3, NOW() - INTERVAL '15 days', 'PAID',    'EUR','France'),          -- id 3
(3, NOW() - INTERVAL '10 days', 'SHIPPED', 'EUR','France'),          -- id 4
(4, NOW() - INTERVAL '7 days',  'PAID',    'EUR','Spain'),           -- id 5
(5, NOW() - INTERVAL '3 days',  'PAID',    'USD','USA');             -- id 6

-- 7) Invoice lines (M:N between invoice and product)
-- invoice 1
INSERT INTO invoice_line(invoice_id, product_id, quantity, unit_price) VALUES
(1,1, 2, 3.50),
(1,3, 1, 6.90),
(1,2, 3, 4.20);
-- invoice 2
INSERT INTO invoice_line(invoice_id, product_id, quantity, unit_price) VALUES
(2,3, 2, 6.90),
(2,4, 1, 2.80);
-- invoice 3
INSERT INTO invoice_line(invoice_id, product_id, quantity, unit_price) VALUES
(3,6, 2, 7.50),
(3,1, 5, 3.50);
-- invoice 4
INSERT INTO invoice_line(invoice_id, product_id, quantity, unit_price) VALUES
(4,5, 1, 9.99),
(4,3, 2, 6.90);
-- invoice 5
INSERT INTO invoice_line(invoice_id, product_id, quantity, unit_price) VALUES
(5,2, 4, 4.20);
-- invoice 6
INSERT INTO invoice_line(invoice_id, product_id, quantity, unit_price) VALUES
(6,1, 1, 3.50),
(6,6, 1, 7.50);

-- 8) Payments (include a refund example)
-- Assume payments equal invoice totals except invoice 3 gets a partial refund later
INSERT INTO payment(invoice_id, method, amount, paid_at, external_ref) VALUES
(1,'CARD', (SELECT SUM(line_total) FROM invoice_line WHERE invoice_id=1), NOW() - INTERVAL '24 days','PAY-1'),
(2,'CARD', (SELECT SUM(line_total) FROM invoice_line WHERE invoice_id=2), NOW() - INTERVAL '19 days','PAY-2'),
(3,'CARD', (SELECT SUM(line_total) FROM invoice_line WHERE invoice_id=3), NOW() - INTERVAL '14 days','PAY-3'),
(4,'CARD', (SELECT SUM(line_total) FROM invoice_line WHERE invoice_id=4), NOW() - INTERVAL '9 days','PAY-4'),
(5,'PAYPAL',(SELECT SUM(line_total) FROM invoice_line WHERE invoice_id=5), NOW() - INTERVAL '6 days','PAY-5'),
(6,'CARD', (SELECT SUM(line_total) FROM invoice_line WHERE invoice_id=6), NOW() - INTERVAL '2 days','PAY-6');

-- Partial refund on invoice 3 (-5.00)
INSERT INTO payment(invoice_id, method, amount, paid_at, external_ref) VALUES
(3,'CARD', -5.00, NOW() - INTERVAL '12 days','REF-3-1');
