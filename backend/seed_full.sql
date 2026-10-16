-- ShopWave FULL seed: 25 customers, 60 orders, refund history
-- Idempotent: drops and recreates tables.
DROP TABLE IF EXISTS refunds; DROP TABLE IF EXISTS orders; DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL
);

CREATE TABLE orders (
    order_id TEXT PRIMARY KEY,
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

INSERT INTO customers (email, full_name) VALUES
('maya.chen@example.com','Maya Chen'),
('derek.okafor@example.com','Derek Okafor'),
('priya.nair@example.com','Priya Nair'),
('tom.alvarez@example.com','Tom Alvarez'),
('lena.fischer@example.com','Lena Fischer'),
('aisha.khan@example.com','Aisha Khan'),
('carlos.mendez@example.com','Carlos Mendez'),
('emma.larsson@example.com','Emma Larsson'),
('raj.patel@example.com','Raj Patel'),
('sofia.rossi@example.com','Sofia Rossi'),
('liam.walsh@example.com','Liam Walsh'),
('nina.petrov@example.com','Nina Petrov'),
('oscar.dubois@example.com','Oscar Dubois'),
('hana.sato@example.com','Hana Sato'),
('ben.carter@example.com','Ben Carter'),
('zoe.nguyen@example.com','Zoe Nguyen'),
('marcus.hall@example.com','Marcus Hall'),
('ivy.kim@example.com','Ivy Kim'),
('diego.vargas@example.com','Diego Vargas'),
('tara.singh@example.com','Tara Singh'),
('felix.weber@example.com','Felix Weber'),
('amara.diallo@example.com','Amara Diallo'),
('jonas.berg@example.com','Jonas Berg'),
('keiko.tanaka@example.com','Keiko Tanaka'),
('sam.reed@example.com','Sam Reed');

INSERT INTO orders (order_id, customer_id, status, total_usd, items, ordered_at, delivered_at, carrier, tracking_number) VALUES
('SW-1001',1,'delivered',89.99,'[{"sku": "HDPH-01", "name": "Wireless Headphones", "qty": 1}]'::jsonb,now()-interval '5 days',now()-interval '2 days','UPS','1Z999AA13746317213'),
('SW-1002',1,'shipped',149.5,'[{"sku": "KBRD-02", "name": "Mechanical Keyboard", "qty": 1}]'::jsonb,now()-interval '3 days',NULL,'FedEx','214832269481'),
('SW-1017',2,'delivered',42.0,'[{"sku": "MUG-07", "name": "Ceramic Mug Set", "qty": 2}]'::jsonb,now()-interval '40 days',now()-interval '36 days','USPS','9400110200881222575562'),
('SW-1023',3,'processing',310.0,'[{"sku": "MNTR-11", "name": "27in Monitor", "qty": 1}]'::jsonb,now()-interval '1 days',NULL,NULL,NULL),
('SW-1031',4,'delivered',24.99,'[{"sku": "CBL-19", "name": "USB-C Cable 3-pack", "qty": 1}]'::jsonb,now()-interval '10 days',now()-interval '7 days','UPS','1Z999AA13585650756'),
('SW-1044',5,'cancelled',58.0,'[{"sku": "LAMP-03", "name": "Desk Lamp", "qty": 1}]'::jsonb,now()-interval '20 days',NULL,NULL,NULL),
('SW-1052',2,'delivered',129.0,'[{"sku": "SPKR-05", "name": "Bluetooth Speaker", "qty": 1}]'::jsonb,now()-interval '12 days',now()-interval '9 days','FedEx','746174432554'),
('SW-1060',3,'shipped',77.25,'[{"sku": "BAG-08", "name": "Laptop Sleeve", "qty": 1}, {"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 1}]'::jsonb,now()-interval '2 days',NULL,'DHL','JD014600003455176955'),
('SW-1061',3,'delivered',87.98,'[{"sku": "NTBK-22", "name": "Dotted Notebook 2-pack", "qty": 2}, {"sku": "LAMP-03", "name": "Desk Lamp", "qty": 1}]'::jsonb,now()-interval '61 days',now()-interval '59 days','DHL','JD014600003487490893'),
('SW-1062',23,'delivered',353.74,'[{"sku": "MNTR-11", "name": "27in Monitor", "qty": 1}, {"sku": "PLNT-21", "name": "Desk Planter", "qty": 1}, {"sku": "CBL-19", "name": "USB-C Cable 3-pack", "qty": 1}]'::jsonb,now()-interval '51 days',now()-interval '47 days','DHL','JD014600003499949389'),
('SW-1063',23,'cancelled',243.99,'[{"sku": "KBRD-02", "name": "Mechanical Keyboard", "qty": 1}, {"sku": "CHRG-12", "name": "65W GaN Charger", "qty": 1}, {"sku": "STND-09", "name": "Laptop Stand", "qty": 1}]'::jsonb,now()-interval '34 days',NULL,NULL,NULL),
('SW-1065',9,'cancelled',740.0,'[{"sku": "WTCH-15", "name": "Fitness Watch", "qty": 2}, {"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 1}, {"sku": "MNTR-11", "name": "27in Monitor", "qty": 1}]'::jsonb,now()-interval '57 days',NULL,NULL,NULL),
('SW-1067',11,'delivered',620.0,'[{"sku": "MNTR-11", "name": "27in Monitor", "qty": 2}]'::jsonb,now()-interval '30 days',now()-interval '25 days','DHL','JD014600003443101783'),
('SW-1068',18,'shipped',406.98,'[{"sku": "CHRG-12", "name": "65W GaN Charger", "qty": 2}, {"sku": "SPKR-05", "name": "Bluetooth Speaker", "qty": 2}, {"sku": "CAM-30", "name": "Webcam 1080p", "qty": 1}]'::jsonb,now()-interval '2 days',NULL,'DHL','JD014600003490048665'),
('SW-1071',13,'delivered',56.99,'[{"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 1}, {"sku": "CBL-19", "name": "USB-C Cable 3-pack", "qty": 1}]'::jsonb,now()-interval '90 days',now()-interval '86 days','USPS','9400110200881270897765'),
('SW-1072',24,'delivered',92.75,'[{"sku": "PLNT-21", "name": "Desk Planter", "qty": 1}, {"sku": "MUG-07", "name": "Ceramic Mug Set", "qty": 2}, {"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 1}]'::jsonb,now()-interval '22 days',now()-interval '18 days','FedEx','638263151675'),
('SW-1075',10,'delivered',69.0,'[{"sku": "CAM-30", "name": "Webcam 1080p", "qty": 1}]'::jsonb,now()-interval '13 days',now()-interval '8 days','UPS','1Z999AA11540137296'),
('SW-1077',17,'processing',374.0,'[{"sku": "MNTR-11", "name": "27in Monitor", "qty": 1}, {"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 2}]'::jsonb,now()-interval '1 days',NULL,NULL,NULL),
('SW-1079',21,'delivered',814.75,'[{"sku": "BAG-08", "name": "Laptop Sleeve", "qty": 1}, {"sku": "KBRD-02", "name": "Mechanical Keyboard", "qty": 1}, {"sku": "MNTR-11", "name": "27in Monitor", "qty": 2}]'::jsonb,now()-interval '5 days',now()-interval '2 days','FedEx','794529888366'),
('SW-1082',2,'processing',32.0,'[{"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 1}]'::jsonb,now()-interval '1 days',NULL,NULL,NULL),
('SW-1083',16,'delivered',398.0,'[{"sku": "WTCH-15", "name": "Fitness Watch", "qty": 2}]'::jsonb,now()-interval '34 days',now()-interval '29 days','DHL','JD014600003457553014'),
('SW-1086',14,'delivered',174.47,'[{"sku": "HDPH-01", "name": "Wireless Headphones", "qty": 1}, {"sku": "STND-09", "name": "Laptop Stand", "qty": 1}, {"sku": "NTBK-22", "name": "Dotted Notebook 2-pack", "qty": 2}]'::jsonb,now()-interval '46 days',now()-interval '44 days','FedEx','591929601508'),
('SW-1088',9,'delivered',45.25,'[{"sku": "BAG-08", "name": "Laptop Sleeve", "qty": 1}]'::jsonb,now()-interval '9 days',now()-interval '7 days','UPS','1Z999AA14645120421'),
('SW-1089',13,'processing',129.0,'[{"sku": "SPKR-05", "name": "Bluetooth Speaker", "qty": 1}]'::jsonb,now()-interval '1 days',NULL,NULL,NULL),
('SW-1090',15,'delivered',448.75,'[{"sku": "WTCH-15", "name": "Fitness Watch", "qty": 2}, {"sku": "PLNT-21", "name": "Desk Planter", "qty": 1}, {"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 1}]'::jsonb,now()-interval '40 days',now()-interval '37 days','UPS','1Z999AA13328710672'),
('SW-1092',16,'shipped',142.99,'[{"sku": "MUG-07", "name": "Ceramic Mug Set", "qty": 1}, {"sku": "HDPH-01", "name": "Wireless Headphones", "qty": 1}, {"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 1}]'::jsonb,now()-interval '5 days',NULL,'UPS','1Z999AA16305160342'),
('SW-1095',2,'shipped',188.98,'[{"sku": "STND-09", "name": "Laptop Stand", "qty": 2}, {"sku": "CHRG-12", "name": "65W GaN Charger", "qty": 2}]'::jsonb,now()-interval '2 days',NULL,'USPS','9400110200881296637649'),
('SW-1098',11,'cancelled',179.98,'[{"sku": "HDPH-01", "name": "Wireless Headphones", "qty": 2}]'::jsonb,now()-interval '44 days',NULL,NULL,NULL),
('SW-1100',4,'delivered',64.0,'[{"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 2}]'::jsonb,now()-interval '19 days',now()-interval '15 days','UPS','1Z999AA14776436931'),
('SW-1103',23,'delivered',208.49,'[{"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 2}, {"sku": "HDPH-01", "name": "Wireless Headphones", "qty": 1}, {"sku": "STND-09", "name": "Laptop Stand", "qty": 1}]'::jsonb,now()-interval '36 days',now()-interval '34 days','UPS','1Z999AA15962610986'),
('SW-1106',22,'shipped',109.25,'[{"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 2}, {"sku": "BAG-08", "name": "Laptop Sleeve", "qty": 1}]'::jsonb,now()-interval '1 days',NULL,'DHL','JD014600003427558317'),
('SW-1107',9,'delivered',263.0,'[{"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 2}, {"sku": "WTCH-15", "name": "Fitness Watch", "qty": 1}]'::jsonb,now()-interval '17 days',now()-interval '15 days','FedEx','507311484139'),
('SW-1110',14,'delivered',95.5,'[{"sku": "LAMP-03", "name": "Desk Lamp", "qty": 1}, {"sku": "PLNT-21", "name": "Desk Planter", "qty": 2}]'::jsonb,now()-interval '29 days',now()-interval '26 days','UPS','1Z999AA19051829827'),
('SW-1111',6,'processing',42.0,'[{"sku": "MUG-07", "name": "Ceramic Mug Set", "qty": 2}]'::jsonb,now()-interval '1 days',NULL,NULL,NULL),
('SW-1112',24,'processing',58.5,'[{"sku": "MUG-07", "name": "Ceramic Mug Set", "qty": 1}, {"sku": "PLNT-21", "name": "Desk Planter", "qty": 2}]'::jsonb,now()-interval '0 days',NULL,NULL,NULL),
('SW-1115',8,'delivered',82.99,'[{"sku": "LAMP-03", "name": "Desk Lamp", "qty": 1}, {"sku": "CBL-19", "name": "USB-C Cable 3-pack", "qty": 1}]'::jsonb,now()-interval '6 days',now()-interval '3 days','DHL','JD014600003457130035'),
('SW-1117',17,'delivered',504.99,'[{"sku": "LAMP-03", "name": "Desk Lamp", "qty": 2}, {"sku": "HDPH-01", "name": "Wireless Headphones", "qty": 1}, {"sku": "KBRD-02", "name": "Mechanical Keyboard", "qty": 2}]'::jsonb,now()-interval '7 days',now()-interval '5 days','DHL','JD014600003425521714'),
('SW-1120',19,'delivered',398.0,'[{"sku": "WTCH-15", "name": "Fitness Watch", "qty": 2}]'::jsonb,now()-interval '3 days',now()-interval '0 days','USPS','9400110200881254318698'),
('SW-1122',22,'processing',251.98,'[{"sku": "CAM-30", "name": "Webcam 1080p", "qty": 2}, {"sku": "CBL-19", "name": "USB-C Cable 3-pack", "qty": 2}, {"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 2}]'::jsonb,now()-interval '1 days',NULL,NULL,NULL),
('SW-1124',10,'shipped',258.0,'[{"sku": "SPKR-05", "name": "Bluetooth Speaker", "qty": 2}]'::jsonb,now()-interval '6 days',NULL,'FedEx','430714225291'),
('SW-1127',19,'shipped',159.5,'[{"sku": "BAG-08", "name": "Laptop Sleeve", "qty": 2}, {"sku": "CAM-30", "name": "Webcam 1080p", "qty": 1}]'::jsonb,now()-interval '5 days',NULL,'DHL','JD014600003479182797'),
('SW-1129',21,'shipped',14.99,'[{"sku": "NTBK-22", "name": "Dotted Notebook 2-pack", "qty": 1}]'::jsonb,now()-interval '6 days',NULL,'USPS','9400110200881242862209'),
('SW-1132',25,'delivered',178.0,'[{"sku": "CAM-30", "name": "Webcam 1080p", "qty": 1}, {"sku": "STND-09", "name": "Laptop Stand", "qty": 2}]'::jsonb,now()-interval '66 days',now()-interval '61 days','FedEx','928467665569'),
('SW-1135',6,'processing',257.23,'[{"sku": "MOUS-04", "name": "Wireless Mouse", "qty": 1}, {"sku": "BAG-08", "name": "Laptop Sleeve", "qty": 1}, {"sku": "HDPH-01", "name": "Wireless Headphones", "qty": 2}]'::jsonb,now()-interval '0 days',NULL,NULL,NULL),
('SW-1136',22,'shipped',233.48,'[{"sku": "CHRG-12", "name": "65W GaN Charger", "qty": 2}, {"sku": "LAMP-03", "name": "Desk Lamp", "qty": 2}, {"sku": "PLNT-21", "name": "Desk Planter", "qty": 2}]'::jsonb,now()-interval '2 days',NULL,'DHL','JD014600003447220099'),
('SW-1138',16,'shipped',240.0,'[{"sku": "BAG-08", "name": "Laptop Sleeve", "qty": 2}, {"sku": "KBRD-02", "name": "Mechanical Keyboard", "qty": 1}]'::jsonb,now()-interval '3 days',NULL,'USPS','9400110200881241039390'),
('SW-1141',5,'shipped',258.0,'[{"sku": "SPKR-05", "name": "Bluetooth Speaker", "qty": 2}]'::jsonb,now()-interval '3 days',NULL,'DHL','JD014600003412621534'),
('SW-1144',13,'delivered',87.48,'[{"sku": "CBL-19", "name": "USB-C Cable 3-pack", "qty": 2}, {"sku": "PLNT-21", "name": "Desk Planter", "qty": 2}]'::jsonb,now()-interval '71 days',now()-interval '68 days','DHL','JD014600003462191530'),
('SW-1147',22,'shipped',419.0,'[{"sku": "WTCH-15", "name": "Fitness Watch", "qty": 2}, {"sku": "MUG-07", "name": "Ceramic Mug Set", "qty": 1}]'::jsonb,now()-interval '5 days',NULL,'UPS','1Z999AA19190197115'),
('SW-1149',21,'delivered',221.98,'[{"sku": "MUG-07", "name": "Ceramic Mug Set", "qty": 2}, {"sku": "HDPH-01", "name": "Wireless Headphones", "qty": 2}]'::jsonb,now()-interval '44 days',now()-interval '41 days','DHL','JD014600003443859311'),
('SW-1150',16,'delivered',457.99,'[{"sku": "HDPH-01", "name": "Wireless Headphones", "qty": 1}, {"sku": "LAMP-03", "name": "Desk Lamp", "qty": 1}, {"sku": "MNTR-11", "name": "27in Monitor", "qty": 1}]'::jsonb,now()-interval '34 days',now()-interval '31 days','UPS','1Z999AA13668616333'),
('SW-1151',19,'cancelled',422.99,'[{"sku": "WTCH-15", "name": "Fitness Watch", "qty": 2}, {"sku": "CBL-19", "name": "USB-C Cable 3-pack", "qty": 1}]'::jsonb,now()-interval '43 days',NULL,NULL,NULL),
('SW-1152',24,'shipped',24.99,'[{"sku": "CBL-19", "name": "USB-C Cable 3-pack", "qty": 1}]'::jsonb,now()-interval '5 days',NULL,'UPS','1Z999AA19284507318'),
('SW-1155',7,'delivered',433.99,'[{"sku": "NTBK-22", "name": "Dotted Notebook 2-pack", "qty": 1}, {"sku": "STND-09", "name": "Laptop Stand", "qty": 2}, {"sku": "MNTR-11", "name": "27in Monitor", "qty": 1}]'::jsonb,now()-interval '75 days',now()-interval '73 days','USPS','9400110200881219255216'),
('SW-1158',11,'delivered',105.49,'[{"sku": "NTBK-22", "name": "Dotted Notebook 2-pack", "qty": 1}, {"sku": "BAG-08", "name": "Laptop Sleeve", "qty": 2}]'::jsonb,now()-interval '49 days',now()-interval '44 days','FedEx','674382277186'),
('SW-1161',18,'processing',287.98,'[{"sku": "SPKR-05", "name": "Bluetooth Speaker", "qty": 2}, {"sku": "NTBK-22", "name": "Dotted Notebook 2-pack", "qty": 2}]'::jsonb,now()-interval '0 days',NULL,NULL,NULL),
('SW-1164',9,'processing',37.5,'[{"sku": "PLNT-21", "name": "Desk Planter", "qty": 2}]'::jsonb,now()-interval '2 days',NULL,NULL,NULL),
('SW-1165',22,'delivered',90.5,'[{"sku": "BAG-08", "name": "Laptop Sleeve", "qty": 2}]'::jsonb,now()-interval '26 days',now()-interval '21 days','FedEx','871359612234'),
('SW-1168',17,'cancelled',620.0,'[{"sku": "MNTR-11", "name": "27in Monitor", "qty": 2}]'::jsonb,now()-interval '36 days',NULL,NULL,NULL),
('SW-1169',25,'delivered',507.0,'[{"sku": "STND-09", "name": "Laptop Stand", "qty": 2}, {"sku": "WTCH-15", "name": "Fitness Watch", "qty": 2}]'::jsonb,now()-interval '5 days',now()-interval '3 days','USPS','9400110200881251098277');

INSERT INTO refunds (order_id, amount_usd, reason, created_at) VALUES
('SW-1031',(SELECT total_usd FROM orders WHERE order_id='SW-1031'),'Damaged on arrival',now()-interval '9 days'),
('SW-1165',90.5,'Changed my mind',now()-interval '20 days'),
('SW-1110',95.5,'Item defective',now()-interval '24 days'),
('SW-1150',457.99,'Changed my mind',now()-interval '29 days'),
('SW-1158',105.49,'Wrong item received',now()-interval '47 days'),
('SW-1086',174.47,'Wrong item received',now()-interval '40 days'),
('SW-1155',433.99,'Damaged on arrival',now()-interval '66 days'),
('SW-1100',64.0,'Wrong item received',now()-interval '15 days');

-- sanity checks
SELECT 'customers' t, count(*) FROM customers
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'refunds', count(*) FROM refunds;