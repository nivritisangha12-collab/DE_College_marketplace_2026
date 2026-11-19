-- =============================================================================
-- Blinkit 10-Minute Grocery Delivery Database: Optimization Indexes (CP3)
--
-- Schema: blinkit
-- Description:
--   Targeted secondary, composite, partial, and covering indexes designed
--   around foreign-key and join bottlenecks in the baseline workload.
-- =============================================================================

SET search_path TO blinkit;

-- -----------------------------------------------------------------------------
-- 1. Infrastructure & Catalogue Dimension Joins
-- -----------------------------------------------------------------------------

-- Target: R04, R15, R17 (Dark store city lookups)
-- Bottleneck: Sequential scan on dark_stores when joining on city_id.
CREATE INDEX idx_dark_stores_city
    ON dark_stores (city_id, store_id);

-- Target: R02, R10, R19 (Product category taxonomy joins)
-- Bottleneck: Sequential scan on products filtering or joining on category_id.
CREATE INDEX idx_products_category
    ON products (category_id, product_id)
    INCLUDE (product_name);

-- Target: R04, R12, R19, W02 (Store inventory multi-store lookups)
-- Bottleneck: Composite PK (store_id, product_id) prevents efficient product_id lookup across stores.
CREATE INDEX idx_store_inventory_product
    ON store_inventory (product_id, store_id);

-- Target: R12, R18, R19 (Order items reverse lookup)
-- Bottleneck: Composite PK (order_id, product_id) prevents product-first lookup.
CREATE INDEX idx_order_items_product_order
    ON order_items (product_id, order_id)
    INCLUDE (quantity_delivered, quantity_ordered);

-- Target: R25 (Customer city filtering)
-- Bottleneck: Sequential scan on customers when filtering by city_id.
CREATE INDEX idx_customers_city
    ON customers (city_id, customer_id);
