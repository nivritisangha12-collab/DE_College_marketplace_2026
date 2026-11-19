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

-- -----------------------------------------------------------------------------
-- 2. Multi-Column Composite Filtering and Sorting Indexes
-- -----------------------------------------------------------------------------

-- Target: R01 (Store Assignment)
-- Bottleneck: Coordinate boundary filtering on dark_stores.
CREATE INDEX idx_dark_stores_location
    ON dark_stores (latitude, longitude);

-- Target: R06, R16 (Customer Order Tracking and Cohort Grouping)
-- Bottleneck: Filtering orders by customer_id and sorting placed_at descending.
CREATE INDEX idx_orders_customer_placed
    ON orders (customer_id, placed_at DESC);

-- Target: R22 (Support Console Pagination)
-- Bottleneck: Sorting orders by placed_at descending with high offset.
CREATE INDEX idx_orders_placed_at_desc
    ON orders (placed_at DESC, order_id);

-- Target: R21 (Rider Delivery Activity)
-- Bottleneck: Checking order deliveries per rider timestamp.
CREATE INDEX idx_orders_rider_placed
    ON orders (rider_id, placed_at);

-- Target: R13, R14, R15, R17, R20 (Analytical Date Range Scans)
-- Bottleneck: Broad table scans on placed_at date windows.
CREATE INDEX idx_orders_placed_range
    ON orders (placed_at)
    INCLUDE (store_id, total_amount, small_cart_fee, status);

-- Target: W05 (Movement Retention Purges)
-- Bottleneck: Identifying movements prior to retention cutoff timestamp.
CREATE INDEX idx_inv_movements_moved_at
    ON inventory_movements (moved_at);
