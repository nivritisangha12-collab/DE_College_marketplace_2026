-- =============================================================================
-- Blinkit 10-Minute Grocery Delivery Database: Bulk Ingestion Script
--
-- Loads all 10 seed CSV files into the 'blinkit' schema using PostgreSQL \copy.
-- Tables are loaded in dependency order to satisfy foreign key constraints:
--   1. Dimension / Base tables (cities, categories, customers, dark_stores, products, riders)
--   2. Inventory mapping (store_inventory)
--   3. Transactional data (orders, order_items, inventory_movements)
-- Ingestion is executed within a single transaction and finalized with ANALYZE
-- to update planner statistics.
-- =============================================================================

SET search_path TO blinkit;

BEGIN;

-- 1. Base Dimension Tables
\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true);
\copy categories FROM 'seed_data/categories.csv' WITH (FORMAT csv, HEADER true);
\copy customers FROM 'seed_data/customers.csv' WITH (FORMAT csv, HEADER true);
\copy dark_stores FROM 'seed_data/dark_stores.csv' WITH (FORMAT csv, HEADER true);
\copy products FROM 'seed_data/products.csv' WITH (FORMAT csv, HEADER true);
\copy riders FROM 'seed_data/riders.csv' WITH (FORMAT csv, HEADER true);

-- 2. Store-Level Inventory
\copy store_inventory FROM 'seed_data/store_inventory.csv' WITH (FORMAT csv, HEADER true);

-- 3. Orders and Line Items
\copy orders FROM 'seed_data/orders.csv' WITH (FORMAT csv, HEADER true);
\copy order_items FROM 'seed_data/order_items.csv' WITH (FORMAT csv, HEADER true);

-- 4. Inventory Movement Audit Trail
\copy inventory_movements FROM 'seed_data/inventory_movements.csv' WITH (FORMAT csv, HEADER true);

-- Refresh planner statistics across all populated tables
ANALYZE;

COMMIT;