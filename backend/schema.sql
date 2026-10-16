-- ShopWave store schema + seed data (Managed PostgreSQL)
DROP TABLE IF EXISTS refunds;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL
);

CREATE TABLE orders (
    order_id TEXT PRIMARY KEY,          -- format: SW-1001
    customer_id INT REFERENCES customers(id),
    status TEXT NOT NULL CHECK (status IN ('processing','shipped','delivered','cancelled')),
    total_usd NUMERIC(10,2) NOT NULL,
    items JSONB NOT NULL,
    ordered_at TIMESTAMPTZ NOT NULL,
    delivered_at TIMESTAMPTZ,
    carrier TEXT,
    tracking_number TEXT
);

CREATE TABLE refunds (
    id SERIAL PRIMARY KEY,
    order_id TEXT REFERENCES orders(order_id),
    amount_usd NUMERIC(10,2) NOT NULL,
    reason TEXT,
    status TEXT NOT NULL DEFAULT 'issued',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Customers
INSERT INTO customers (email, full_name) VALUES
('maya@example.com','Maya Chen'),
('derek@example.com','Derek Okafor'),
('priya@example.com','Priya Nair'),
('tom@example.com','Tom Alvarez'),
('lena@example.com','Lena Fischer');

-- Orders: mix of recent (refund-eligible, <14 days) and old (ineligible)
INSERT INTO orders VALUES
('SW-1001',1,'delivered', 89.99,'[{"sku":"HDPH-01","name":"Wireless Headphones","qty":1}]', now()-interval '5 days',  now()-interval '2 days','UPS','1Z999AA10123456784'),
('SW-1002',1,'shipped',  149.50,'[{"sku":"KBRD-02","name":"Mechanical Keyboard","qty":1}]', now()-interval '3 days',  NULL,'FedEx','771234567890'),
('SW-1017',2,'delivered', 42.00,'[{"sku":"MUG-07","name":"Ceramic Mug Set","qty":2}]',      now()-interval '40 days', now()-interval '36 days','USPS','9400110200881234567890'),
('SW-1023',3,'processing',310.00,'[{"sku":"MNTR-11","name":"27in Monitor","qty":1}]',       now()-interval '1 day',   NULL,NULL,NULL),
('SW-1031',4,'delivered', 24.99,'[{"sku":"CBL-19","name":"USB-C Cable 3-pack","qty":1}]',   now()-interval '10 days', now()-interval '7 days','UPS','1Z999AA10123456999'),
('SW-1044',5,'cancelled', 58.00,'[{"sku":"LAMP-03","name":"Desk Lamp","qty":1}]',           now()-interval '20 days', NULL,NULL,NULL),
('SW-1052',2,'delivered',129.00,'[{"sku":"SPKR-05","name":"Bluetooth Speaker","qty":1}]',   now()-interval '12 days', now()-interval '9 days','FedEx','771234567111'),
('SW-1060',3,'shipped',   77.25,'[{"sku":"BAG-08","name":"Laptop Sleeve","qty":1},{"sku":"MOUS-04","name":"Wireless Mouse","qty":1}]', now()-interval '2 days', NULL,'DHL','JD014600003456789012');

-- Prior refund so "already refunded" paths exist
INSERT INTO refunds (order_id, amount_usd, reason) VALUES
('SW-1031', 24.99, 'Damaged on arrival');
