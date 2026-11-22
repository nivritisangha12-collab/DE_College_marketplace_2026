-- =============================================================================
-- Blinkit 10-Minute Grocery Delivery Database: Large Dataset Ingestion Script
--
-- Loads all 10 large CSV files (20x scale) into the 'blinkit' schema using \copy.
-- =============================================================================

SET search_path TO blinkit;

BEGIN;

-- 1. Base Dimension Tables
\copy cities FROM 'large_data/cities.csv' WITH (FORMAT csv, HEADER true);
\copy categories FROM 'large_data/categories.csv' WITH (FORMAT csv, HEADER true);
\copy customers FROM 'large_data/customers.csv' WITH (FORMAT csv, HEADER true);
\copy dark_stores FROM 'large_data/dark_stores.csv' WITH (FORMAT csv, HEADER true);
\copy products FROM 'large_data/products.csv' WITH (FORMAT csv, HEADER true);
\copy riders FROM 'large_data/riders.csv' WITH (FORMAT csv, HEADER true);

-- 2. Store-Level Inventory
\copy store_inventory FROM 'large_data/store_inventory.csv' WITH (FORMAT csv, HEADER true);

-- 3. Orders and Line Items
\copy orders FROM 'large_data/orders.csv' WITH (FORMAT csv, HEADER true);
\copy order_items FROM 'large_data/order_items.csv' WITH (FORMAT csv, HEADER true);

-- 4. Inventory Movement Audit Trail
\copy inventory_movements FROM 'large_data/inventory_movements.csv' WITH (FORMAT csv, HEADER true);

COMMIT;

ANALYZE;
