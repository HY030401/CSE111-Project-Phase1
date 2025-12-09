--yhz030401

-- Drop tables if they already exist (for re-run convenience)
DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS invoice_line CASCADE;
DROP TABLE IF EXISTS invoice CASCADE;
DROP TABLE IF EXISTS product_category CASCADE;
DROP TABLE IF EXISTS product CASCADE;
DROP TABLE IF EXISTS category CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS country CASCADE;

-- 1. Core Entities

CREATE TABLE country (
  country_id     SERIAL PRIMARY KEY,
  name           VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE customer (
  customer_id    SERIAL PRIMARY KEY,
  full_name      VARCHAR(150) NOT NULL,
  email          VARCHAR(200) UNIQUE,
  phone          VARCHAR(50),
  country_id     INT REFERENCES country(country_id),
  created_at     TIMESTAMP DEFAULT NOW()
);

CREATE TABLE category (
  category_id    SERIAL PRIMARY KEY,
  name           VARCHAR(100) UNIQUE NOT NULL,
  description    TEXT
);

CREATE TABLE product (
  product_id     SERIAL PRIMARY KEY,
  sku            VARCHAR(50) UNIQUE NOT NULL,
  name           VARCHAR(200) NOT NULL,
  description    TEXT,
  unit_price     NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMP DEFAULT NOW()
);

-- Many-to-many: Product - Category
CREATE TABLE product_category (
  product_id     INT NOT NULL REFERENCES product(product_id) ON DELETE CASCADE,
  category_id    INT NOT NULL REFERENCES category(category_id) ON DELETE CASCADE,
  PRIMARY KEY (product_id, category_id)
);

CREATE TABLE invoice (
  invoice_id     SERIAL PRIMARY KEY,
  customer_id    INT NOT NULL REFERENCES customer(customer_id),
  invoice_date   TIMESTAMP NOT NULL DEFAULT NOW(),
  status         VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  currency       CHAR(3) NOT NULL DEFAULT 'GBP',
  ship_to_country VARCHAR(100)
);

-- Invoice line items
CREATE TABLE invoice_line (
  invoice_line_id  SERIAL PRIMARY KEY,
  invoice_id       INT NOT NULL REFERENCES invoice(invoice_id) ON DELETE CASCADE,
  product_id       INT NOT NULL REFERENCES product(product_id),

  quantity         INT NOT NULL CHECK (quantity > 0),
  unit_price       NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),

  -- Automatically calculated as quantity * unit_price
  line_total       NUMERIC(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);

CREATE TABLE payment (
  payment_id     SERIAL PRIMARY KEY,
  invoice_id     INT NOT NULL REFERENCES invoice(invoice_id) ON DELETE CASCADE,
  method         VARCHAR(30) NOT NULL,
  amount         NUMERIC(12,2) NOT NULL,
  paid_at        TIMESTAMP DEFAULT NOW(),
  external_ref   VARCHAR(100)
);

-- 2. Useful Indexes

CREATE INDEX idx_customer_country      ON customer(country_id);
CREATE INDEX idx_product_name          ON product(name);
CREATE INDEX idx_invoice_date          ON invoice(invoice_date);
CREATE INDEX idx_invoice_status        ON invoice(status);
CREATE INDEX idx_invoice_line_invoice  ON invoice_line(invoice_id);
CREATE INDEX idx_payment_invoice       ON payment(invoice_id);
