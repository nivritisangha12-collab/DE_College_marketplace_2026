-- =============================================================================
-- Blinkit 10-Minute Grocery Delivery Database: Optimization Indexes (CP3)
--
-- Schema: blinkit
-- Description:
--   Targeted secondary, composite, partial, covering, and specialized indexes
--   designed from EXPLAIN ANALYZE execution bottlenecks in the baseline workload.
--   Enforces idempotent syntax (CREATE INDEX IF NOT EXISTS).
-- =============================================================================

SET search_path TO blinkit;

-- Ensure trigram extension is available for wildcard text search
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA blinkit;
EXCEPTION WHEN duplicate_schema OR others THEN
    NULL;
END $$;

-- -----------------------------------------------------------------------------
-- 1. Dark Stores: Spatial & City Infrastructure Indexes
-- -----------------------------------------------------------------------------

-- Target: R01 (Store Assignment)
-- Bottleneck: Sequential scan on dark_stores filtering active stores within bounding coordinates.
-- Design: Partial composite B-tree index on (latitude, longitude) restricted to active stores.
-- Provides fast coordinate range filtering and skips inactive stores entirely.
CREATE INDEX IF NOT EXISTS idx_dark_stores_location
    ON dark_stores (latitude, longitude)
    WHERE is_active;

-- Target: R04, R15, R17 (Store Metadata & City Routing)
-- Bottleneck: Sequential scan on dark_stores when joining or filtering on city_id.
-- Design: Composite B-tree index on (city_id, store_id) enabling index-only joins for city-level routing.
CREATE INDEX IF NOT EXISTS idx_dark_stores_city
    ON dark_stores (city_id, store_id);

-- -----------------------------------------------------------------------------
-- 2. Products: Catalogue Taxonomy & Full-Text Search
-- -----------------------------------------------------------------------------

-- Target: R02, R10, R19 (Category Catalogue Browsing)
-- Bottleneck: Sequential scan on products (1,500 rows) filtering on category_id.
-- Design: Composite covering index on (category_id, product_id) including product_name in payload.
-- Turns category product listings into an Index Only Scan without heap page visits.
CREATE INDEX IF NOT EXISTS idx_products_category
    ON products (category_id, product_id)
    INCLUDE (product_name);

-- Target: R03 (Catalogue Search)
-- Bottleneck: Full sequential scan on products caused by substring search (ILIKE '%milk%').
-- Design: GIN trigram index on product_name using gin_trgm_ops. Deconstructs text into 3-character
-- n-grams, enabling fast Bitmap Index Scans for arbitrary wildcard queries.
CREATE INDEX IF NOT EXISTS idx_products_name_trgm
    ON products USING gin (product_name gin_trgm_ops);

-- -----------------------------------------------------------------------------
-- 3. Store Inventory: Multi-Store Stock Lookups & Replenishment
-- -----------------------------------------------------------------------------

-- Target: R04, R12, R19, W02 (Product Availability Across Stores)
-- Bottleneck: Primary key is (store_id, product_id). Looking up a single product across dark stores
-- could not utilize the leading column of the primary key.
-- Design: Inverted composite B-tree index on (product_id, store_id). Lean key footprint allows
-- Heap-Only Tuple (HOT) updates on stock modifications while accelerating multi-store product scans.
CREATE INDEX IF NOT EXISTS idx_store_inventory_product
    ON store_inventory (product_id, store_id);

-- Target: R09, W04 (Inventory Reorder & Nightly Replenishment)
-- Bottleneck: Table scans across inventory rows to locate products below safety stock.
-- Design: Partial B-tree index on (store_id, quantity_on_hand) restricted to low-stock rows.
-- Keeps index footprint extremely compact (~200 KB) and targets replenishment updates instantly.
CREATE INDEX IF NOT EXISTS idx_store_inventory_reorder
    ON store_inventory (store_id, quantity_on_hand)
    WHERE quantity_on_hand <= reorder_level;

-- -----------------------------------------------------------------------------
-- 4. Order Items: Reverse Lookups & Substitution Tracking
-- -----------------------------------------------------------------------------

-- Target: R12, R18, R19 (Product Affinity & Market Basket Analysis)
-- Bottleneck: Primary key is (order_id, product_id). Finding orders containing a target product
-- (e.g. product 1236) required scanning all 675,000 order items.
-- Design: Reverse composite covering index on (product_id, order_id) including quantities.
-- Replaces 675k-row sequential scan with an instant Index Only Scan.
CREATE INDEX IF NOT EXISTS idx_order_items_product_order
    ON order_items (product_id, order_id)
    INCLUDE (quantity_delivered, quantity_ordered);

-- Target: R13 (Substitution Analysis)
-- Bottleneck: Full scans of order items to check substitute_product_id where >97% of rows are NULL.
-- Design: Highly selective partial index indexing only non-NULL substitute records (~15k rows, 120 KB),
-- eliminating indexing overhead for normal un-substituted order lines.
CREATE INDEX IF NOT EXISTS idx_order_items_substitute
    ON order_items (substitute_product_id)
    WHERE substitute_product_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 5. Orders: Fulfillment Operations, Timeline, and Analytics
-- -----------------------------------------------------------------------------

-- Target: R06, R16, R25 (Customer Order History & Cohort Analysis)
-- Bottleneck: Sequential scan on orders (150,000 rows) filtering by customer_id and sorting placed_at.
-- Design: Composite B-tree index on (customer_id, placed_at DESC) matching filter and sort order.
-- Delivers customer order tracking in <0.04 ms.
CREATE INDEX IF NOT EXISTS idx_orders_customer_placed
    ON orders (customer_id, placed_at DESC);

-- Target: R07 (Store Operational Console)
-- Bottleneck: Sequential scan filtering for unfulfilled orders (PLACED, PACKING, OUT_FOR_DELIVERY).
-- Design: Partial B-tree index on (store_id, placed_at) restricted to open order statuses.
-- Indexes only ~0.1% of orders (16 KB), providing sub-millisecond operational dispatch responsiveness.
CREATE INDEX IF NOT EXISTS idx_orders_open_store
    ON orders (store_id, placed_at)
    WHERE status IN ('PLACED', 'PACKING', 'OUT_FOR_DELIVERY');

-- Target: W02 (Packing Stock Deduction)
-- Bottleneck: Subquery SELECT max(order_id) FROM orders WHERE store_id = 43 AND status IN ('PLACED', 'PACKING')
-- executed a 150,000-row sequential scan taking 18+ ms.
-- Design: Partial B-tree index on (store_id, order_id DESC) for open orders. Transforms table scan
-- into a single index seek taking 0.03 ms (~600x speedup).
CREATE INDEX IF NOT EXISTS idx_orders_open_order_id
    ON orders (store_id, order_id DESC)
    WHERE status IN ('PLACED', 'PACKING');

-- Target: W03 (Rider Dispatch Queue)
-- Bottleneck: Subquery SELECT min(order_id) FROM orders WHERE status = 'PACKING' scanned orders.
-- Design: Partial B-tree index on (order_id) for packing orders. Delivers instant min seek in <0.01 ms.
CREATE INDEX IF NOT EXISTS idx_orders_packing_min
    ON orders (order_id)
    WHERE status = 'PACKING';

-- Target: R22 (Support Console Pagination)
-- Bottleneck: ORDER BY placed_at DESC OFFSET 100000 LIMIT 25 triggered an expensive external merge
-- disk sort spilling 7.3 MB to temporary files.
-- Design: Composite index on (placed_at DESC, order_id). Eliminates sorting entirely, enabling
-- index-only scanning directly into the deferred join.
CREATE INDEX IF NOT EXISTS idx_orders_placed_at_desc
    ON orders (placed_at DESC, order_id);

-- Target: R08, R20 (SLA Reporting & GMV Tracking)
-- Bottleneck: Aggregating SLA metrics across deliveries in June 2026.
-- Design: Partial covering index on (placed_at, store_id) including delivered_at and promised_minutes
-- for DELIVERED orders. Eliminates heap page visits for delivery performance metrics.
CREATE INDEX IF NOT EXISTS idx_orders_june_sla
    ON orders (placed_at, store_id)
    INCLUDE (delivered_at, promised_minutes)
    WHERE status = 'DELIVERED';

-- Target: R11 (Rider Performance Metrics)
-- Bottleneck: Rider delivery performance aggregation for a specific store.
-- Design: Composite partial covering index on (store_id, placed_at, rider_id) including timestamps.
-- Eliminates table scans for store delivery reviews.
CREATE INDEX IF NOT EXISTS idx_orders_delivered_june
    ON orders (store_id, placed_at, rider_id)
    INCLUDE (delivered_at, picked_up_at)
    WHERE status = 'DELIVERED';

-- Target: R13, R14, R15, R17, R20 (Order Date Range Scans)
-- Bottleneck: Broad date range queries on orders in 2026 requiring full table scans.
-- Design: Covering B-tree index on placed_at with store_id, total_amount, small_cart_fee, and status.
-- Allows high-throughput index range scans and index-only scans.
CREATE INDEX IF NOT EXISTS idx_orders_placed_range
    ON orders (placed_at)
    INCLUDE (store_id, total_amount, small_cart_fee, status);

-- Target: R21 (Rider Availability Verification)
-- Bottleneck: Checking NOT EXISTS for recent rider deliveries scanned orders for every candidate rider.
-- Design: Composite index on (rider_id, placed_at). Evaluates existence check in a single index seek.
CREATE INDEX IF NOT EXISTS idx_orders_rider_placed
    ON orders (rider_id, placed_at);

-- -----------------------------------------------------------------------------
-- 6. Inventory Movements: Audit Ledger & Retention Purges
-- -----------------------------------------------------------------------------

-- Target: W05 (Data Retention Purge)
-- Bottleneck: Filtering inventory movements older than 1 Jan 2026 for deletion.
-- Design: B-tree index on moved_at facilitating date filtering and retention cleanup.
CREATE INDEX IF NOT EXISTS idx_inv_movements_moved_at
    ON inventory_movements (moved_at);

-- Target: R24 (Supply Chain Restock Ingestion)
-- Bottleneck: Supply chain restock tracking for a specific store over recent days.
-- Design: Partial covering index on (store_id, moved_at, product_id, quantity) for RESTOCK events.
-- Yields an Index Only Scan with 0 heap fetches.
CREATE INDEX IF NOT EXISTS idx_inv_movements_store_restock
    ON inventory_movements (store_id, moved_at, product_id, quantity)
    WHERE movement_type = 'RESTOCK';

-- Target: R10 (Wastage & Damage Aggregations)
-- Bottleneck: Wastage aggregation by category across expiry and damage movement types.
-- Design: Partial covering index on (moved_at, movement_type, product_id, quantity) for loss events.
-- Eliminates sequential scans on inventory movements.
CREATE INDEX IF NOT EXISTS idx_inv_movements_wastage
    ON inventory_movements (moved_at, movement_type, product_id, quantity)
    WHERE movement_type IN ('EXPIRY', 'DAMAGE');

-- -----------------------------------------------------------------------------
-- 7. Customers & Riders: Operational Dimensions
-- -----------------------------------------------------------------------------

-- Target: R25 (City Loyalty Aggregations)
-- Bottleneck: Filtering customers by city sequentially scanned 40,000 customer records.
-- Design: Composite B-tree index on (city_id, customer_id). Transforms customer filter into an Index Only Scan.
CREATE INDEX IF NOT EXISTS idx_customers_city
    ON customers (city_id, customer_id);

-- Target: R21, W03 (Active Rider Dispatch)
-- Bottleneck: Finding active riders assigned to a dark store.
-- Design: Partial covering index on (store_id, rider_id) including full_name where status = 'ACTIVE'.
-- Provides instant index access for rider dispatch and availability queries.
CREATE INDEX IF NOT EXISTS idx_riders_store_active
    ON riders (store_id, rider_id)
    INCLUDE (full_name)
    WHERE status = 'ACTIVE';

-- Refresh planner statistics to reflect new index selectivity
ANALYZE;
