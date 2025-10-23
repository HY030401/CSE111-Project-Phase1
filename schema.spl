-- 1 Core Entities (UC1 3)
CREATE TABLE country (
  country_id   SERIAL PRIMARY KEY,
  name         VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE customer (
  customer_id  SERIAL PRIMARY KEY,
  full_name    VARCHAR(150) NOT NULL,
  email        VARCHAR(200) UNIQUE,
  phone        VARCHAR(50),
  country_id   INT REFERENCES country(country_id),
  created_at   TIMESTAMP DEFAULT NOW()
);

CREATE TABLE category (
  category_id  SERIAL PRIMARY KEY,
  name         VARCHAR(120) UNIQUE NOT NULL,
  description  TEXT
);

CREATE TABLE product (
  product_id   SERIAL PRIMARY KEY,
  sku          VARCHAR(60) UNIQUE NOT NULL,
  name         VARCHAR(200) NOT NULL,
  description  TEXT,
  unit_price   NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMP DEFAULT NOW()
);

-- 2 Relationship Tables(Intermediate table for many-to-many relationships(M:N))
CREATE TABLE product_category (
  product_id   INT NOT NULL REFERENCES product(product_id) ON DELETE CASCADE,
  category_id  INT NOT NULL REFERENCES category(category_id) ON DELETE CASCADE,
  PRIMARY KEY (product_id, category_id)
);

-- 3 Sales: Invoice, Lines, Payments(UC2 4 5)
CREATE TABLE invoice (
  invoice_id     SERIAL PRIMARY KEY,
  customer_id    INT NOT NULL REFERENCES customer(customer_id),
  invoice_date   TIMESTAMP NOT NULL,
  status         VARCHAR(20) NOT NULL CHECK (status IN ('DRAFT','PAID','SHIPPED','REFUNDED','CANCELLED')),
  currency       CHAR(3) NOT NULL DEFAULT 'GBP',
  ship_to_country VARCHAR(100)
);

CREATE TABLE invoice_line (
  invoice_line_id SERIAL PRIMARY KEY,
  invoice_id    INT NOT NULL REFERENCES invoice(invoice_id) ON DELETE CASCADE,
  product_id    INT NOT NULL REFERENCES product(product_id),
  quantity      INT NOT NULL CHECK (quantity > 0),
  unit_price    NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
  line_total    NUMERIC(14,2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);

CREATE TABLE payment (
  payment_id    SERIAL PRIMARY KEY,
  invoice_id    INT NOT NULL REFERENCES invoice(invoice_id) ON DELETE CASCADE,
  method        VARCHAR(30) NOT NULL, -- e.g., CARD, PAYPAL
  amount        NUMERIC(12,2) NOT NULL, -- refunds can be negative
  paid_at       TIMESTAMP NOT NULL,
  external_ref  VARCHAR(120)
);


-- 4 Indexes(UC 6)
CREATE INDEX idx_customer_country ON customer(country_id);
CREATE INDEX idx_product_name ON product(name);
CREATE INDEX idx_invoice_date ON invoice(invoice_date);
CREATE INDEX idx_invoice_status ON invoice(status);
CREATE INDEX idx_invoice_line_invoice ON invoice_line(invoice_id);
CREATE INDEX idx_payment_invoice ON payment(invoice_id);


-- 5 Main Use Cases
-- UC1 Browse Products       -> product, category, product_category
-- UC2 Place Order & Pay     -> customer, invoice, invoice_line, payment, product
-- UC3 Manage Catalog        -> product, category, product_category
-- UC4 Fulfill Order         -> invoice (status transitions), customer
-- UC5 Process Refund        -> payment (negative amount), invoice
-- UC6 View Sales Reports    -> invoice, invoice_line, product, country
