-- =============================================================================
-- Blinkit 10-Minute Grocery Delivery Database: Declarative Partitioning (CP4)
--
-- Schema: blinkit
-- Description:
--   Implements declarative table partitioning across the highest-volume transactional
--   and event tables in the database (inventory_movements, orders, order_items).
--
-- Architectural Strategy & Partition Keys:
--   1. inventory_movements: PARTITION BY RANGE (moved_at)
--      - Rationale: High-frequency audit trail (1.8M rows on large scale, 180M at 100x).
--        Workload queries (R10, R24) filter on specific timeline boundaries (June 2026,
--        last 7 days of June). Data retention policy (W05) purges records older than
--        1 January 2026. Monthly range partitions allow partition pruning to isolate
--        active queries to a single month (e.g. inv_movements_2026_06) while enabling
--        instantaneous bulk purges via DROP/DETACH PARTITION without WAL or vacuum bloat.
--
--   2. orders: PARTITION BY RANGE (placed_at)
--      - Rationale: Core transaction header (3.0M rows on large scale, 300M at 100x).
--        Over 10 workload queries (R08, R11, R13, R14, R15, R17, R18, R19, R20, R21, R25)
--        predicate on placed_at date ranges. Monthly range partitioning prunes 17 of 18
--        partitions for monthly operational reports (June 2026) and 350+ days for daily staffing (R15).
--      - PostgreSQL Primary Key Rule: In PostgreSQL declarative partitioning, any UNIQUE or
--        PRIMARY KEY constraint on a partitioned table MUST contain all partition key columns.
--        Therefore, orders' primary key becomes (order_id, placed_at).
--
--   3. order_items: PARTITION BY HASH (order_id)
--      - Rationale: Largest relational table (13.5M rows on large scale, 1.35B at 100x).
--        Access patterns cluster by order_id (W02 packing line item lookups, order basket queries).
--        Hash partitioning across 16 shards evenly distributes row density and index B-trees,
--        enabling static and run-time partition pruning when queried by order_id.
--      - PostgreSQL Primary Key Rule: PRIMARY KEY (order_id, product_id) naturally satisfies
--        the rule because the partition key (order_id) forms the leading column of the composite key.
--
-- Idempotency:
--   All statements include safe schema checks and idempotent table/index guards.
-- =============================================================================

SET search_path TO blinkit;

-- -----------------------------------------------------------------------------
-- 1. Declarative Range Partitioning: inventory_movements
-- -----------------------------------------------------------------------------

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'blinkit' AND tablename = 'inventory_movements'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_partitioned_table pt
        JOIN pg_class c ON c.oid = pt.partrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'blinkit' AND c.relname = 'inventory_movements'
    ) THEN
        RAISE NOTICE 'Migrating inventory_movements to declarative RANGE partitioning...';

        ALTER TABLE inventory_movements RENAME TO inventory_movements_old;

        CREATE TABLE inventory_movements (
            movement_id BIGINT NOT NULL,
            store_id INT NOT NULL REFERENCES dark_stores(store_id),
            product_id INT NOT NULL REFERENCES products(product_id),
            movement_type VARCHAR(20) NOT NULL 
                CHECK (movement_type IN ('ADJUSTMENT','DAMAGE','EXPIRY','RESTOCK')),
            quantity INT NOT NULL,
            moved_at TIMESTAMPTZ NOT NULL,
            CHECK (movement_type <> 'RESTOCK' OR quantity > 0),
            CHECK (movement_type NOT IN ('DAMAGE','EXPIRY') OR quantity < 0),
            PRIMARY KEY (movement_id, moved_at)
        ) PARTITION BY RANGE (moved_at);

        -- Concrete 2025 Monthly Partitions
        CREATE TABLE inv_movements_2025_01 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2025-01-01 00:00:00+05:30') TO ('2025-02-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2025_02 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2025-02-01 00:00:00+05:30') TO ('2025-03-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2025_03 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2025-03-01 00:00:00+05:30') TO ('2025-04-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2025_04 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2025-04-01 00:00:00+05:30') TO ('2025-05-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2025_05 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2025-05-01 00:00:00+05:30') TO ('2025-06-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2025_06 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2025-06-01 00:00:00+05:30') TO ('2025-07-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2025_07 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2025-07-01 00:00:00+05:30') TO ('2025-08-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2025_08 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2025-08-01 00:00:00+05:30') TO ('2025-09-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2025_09 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2025-09-01 00:00:00+05:30') TO ('2025-10-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2025_10 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2025-10-01 00:00:00+05:30') TO ('2025-11-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2025_11 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2025-11-01 00:00:00+05:30') TO ('2025-12-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2025_12 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2025-12-01 00:00:00+05:30') TO ('2026-01-01 00:00:00+05:30');

        -- Concrete 2026 Monthly Partitions
        CREATE TABLE inv_movements_2026_01 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2026-01-01 00:00:00+05:30') TO ('2026-02-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2026_02 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2026-02-01 00:00:00+05:30') TO ('2026-03-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2026_03 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2026-03-01 00:00:00+05:30') TO ('2026-04-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2026_04 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2026-04-01 00:00:00+05:30') TO ('2026-05-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2026_05 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2026-05-01 00:00:00+05:30') TO ('2026-06-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2026_06 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2026-06-01 00:00:00+05:30') TO ('2026-07-01 00:00:00+05:30');
        CREATE TABLE inv_movements_2026_07 PARTITION OF inventory_movements 
            FOR VALUES FROM ('2026-07-01 00:00:00+05:30') TO ('2026-08-01 00:00:00+05:30');

        -- Default Partition for Future / Out-of-Range Records
        CREATE TABLE inv_movements_default PARTITION OF inventory_movements DEFAULT;

        -- Safe Ingestion from Existing Table
        INSERT INTO inventory_movements SELECT * FROM inventory_movements_old;
        DROP TABLE inventory_movements_old CASCADE;

        -- Local Partitioned Indexes
        CREATE INDEX idx_inv_movements_store_restock 
            ON inventory_movements (store_id, moved_at, product_id, quantity) 
            WHERE movement_type = 'RESTOCK';

        CREATE INDEX idx_inv_movements_moved_at 
            ON inventory_movements (moved_at);

        CREATE INDEX idx_inv_movements_wastage 
            ON inventory_movements (moved_at, movement_type, product_id, quantity) 
            WHERE movement_type IN ('EXPIRY', 'DAMAGE');

        RAISE NOTICE 'inventory_movements successfully partitioned by RANGE (moved_at).';
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 2. Declarative Range Partitioning: orders
-- -----------------------------------------------------------------------------

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'blinkit' AND tablename = 'orders'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_partitioned_table pt
        JOIN pg_class c ON c.oid = pt.partrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'blinkit' AND c.relname = 'orders'
    ) THEN
        RAISE NOTICE 'Migrating orders to declarative RANGE partitioning...';

        -- Remove foreign key constraint from unpartitioned order_items if present
        ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_order_id_fkey;
        ALTER TABLE orders RENAME TO orders_old;

        CREATE TABLE orders (
            order_id BIGINT NOT NULL,
            customer_id INT NOT NULL REFERENCES customers(customer_id),
            store_id INT NOT NULL REFERENCES dark_stores(store_id),
            rider_id INT REFERENCES riders(rider_id),
            placed_at TIMESTAMPTZ NOT NULL,
            packed_at TIMESTAMPTZ,
            picked_up_at TIMESTAMPTZ,
            delivered_at TIMESTAMPTZ,
            promised_minutes INT NOT NULL DEFAULT 10 CHECK (promised_minutes > 0),
            subtotal NUMERIC(10,2) NOT NULL CHECK (subtotal >= 0),
            delivery_fee NUMERIC(10,2) NOT NULL CHECK (delivery_fee >= 0),
            handling_fee NUMERIC(10,2) NOT NULL CHECK (handling_fee >= 0),
            small_cart_fee NUMERIC(10,2) NOT NULL CHECK (small_cart_fee >= 0),
            total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
            payment_method VARCHAR(20) NOT NULL 
                CHECK (payment_method IN ('CARD','COD','UPI','WALLET')),
            status VARCHAR(30) NOT NULL 
                CHECK (status IN ('CANCELLED','DELIVERED','OUT_FOR_DELIVERY','PACKING','PLACED')),
            CHECK (total_amount = subtotal + delivery_fee + handling_fee + small_cart_fee),
            PRIMARY KEY (order_id, placed_at)
        ) PARTITION BY RANGE (placed_at);

        -- Concrete 2025 Monthly Partitions
        CREATE TABLE orders_2025_01 PARTITION OF orders FOR VALUES FROM ('2025-01-01 00:00:00+05:30') TO ('2025-02-01 00:00:00+05:30');
        CREATE TABLE orders_2025_02 PARTITION OF orders FOR VALUES FROM ('2025-02-01 00:00:00+05:30') TO ('2025-03-01 00:00:00+05:30');
        CREATE TABLE orders_2025_03 PARTITION OF orders FOR VALUES FROM ('2025-03-01 00:00:00+05:30') TO ('2025-04-01 00:00:00+05:30');
        CREATE TABLE orders_2025_04 PARTITION OF orders FOR VALUES FROM ('2025-04-01 00:00:00+05:30') TO ('2025-05-01 00:00:00+05:30');
        CREATE TABLE orders_2025_05 PARTITION OF orders FOR VALUES FROM ('2025-05-01 00:00:00+05:30') TO ('2025-06-01 00:00:00+05:30');
        CREATE TABLE orders_2025_06 PARTITION OF orders FOR VALUES FROM ('2025-06-01 00:00:00+05:30') TO ('2025-07-01 00:00:00+05:30');
        CREATE TABLE orders_2025_07 PARTITION OF orders FOR VALUES FROM ('2025-07-01 00:00:00+05:30') TO ('2025-08-01 00:00:00+05:30');
        CREATE TABLE orders_2025_08 PARTITION OF orders FOR VALUES FROM ('2025-08-01 00:00:00+05:30') TO ('2025-09-01 00:00:00+05:30');
        CREATE TABLE orders_2025_09 PARTITION OF orders FOR VALUES FROM ('2025-09-01 00:00:00+05:30') TO ('2025-10-01 00:00:00+05:30');
        CREATE TABLE orders_2025_10 PARTITION OF orders FOR VALUES FROM ('2025-10-01 00:00:00+05:30') TO ('2025-11-01 00:00:00+05:30');
        CREATE TABLE orders_2025_11 PARTITION OF orders FOR VALUES FROM ('2025-11-01 00:00:00+05:30') TO ('2025-12-01 00:00:00+05:30');
        CREATE TABLE orders_2025_12 PARTITION OF orders FOR VALUES FROM ('2025-12-01 00:00:00+05:30') TO ('2026-01-01 00:00:00+05:30');

        -- Concrete 2026 Monthly Partitions
        CREATE TABLE orders_2026_01 PARTITION OF orders FOR VALUES FROM ('2026-01-01 00:00:00+05:30') TO ('2026-02-01 00:00:00+05:30');
        CREATE TABLE orders_2026_02 PARTITION OF orders FOR VALUES FROM ('2026-02-01 00:00:00+05:30') TO ('2026-03-01 00:00:00+05:30');
        CREATE TABLE orders_2026_03 PARTITION OF orders FOR VALUES FROM ('2026-03-01 00:00:00+05:30') TO ('2026-04-01 00:00:00+05:30');
        CREATE TABLE orders_2026_04 PARTITION OF orders FOR VALUES FROM ('2026-04-01 00:00:00+05:30') TO ('2026-05-01 00:00:00+05:30');
        CREATE TABLE orders_2026_05 PARTITION OF orders FOR VALUES FROM ('2026-05-01 00:00:00+05:30') TO ('2026-06-01 00:00:00+05:30');
        CREATE TABLE orders_2026_06 PARTITION OF orders FOR VALUES FROM ('2026-06-01 00:00:00+05:30') TO ('2026-07-01 00:00:00+05:30');
        CREATE TABLE orders_2026_07 PARTITION OF orders FOR VALUES FROM ('2026-07-01 00:00:00+05:30') TO ('2026-08-01 00:00:00+05:30');

        -- Default Partition
        CREATE TABLE orders_default PARTITION OF orders DEFAULT;

        -- Safe Ingestion
        INSERT INTO orders SELECT * FROM orders_old;
        DROP TABLE orders_old CASCADE;

        -- Local Partitioned Indexes
        CREATE INDEX idx_orders_customer_placed 
            ON orders (customer_id, placed_at DESC);

        CREATE INDEX idx_orders_open_store 
            ON orders (store_id, placed_at) 
            WHERE status IN ('PLACED', 'PACKING', 'OUT_FOR_DELIVERY');

        CREATE INDEX idx_orders_june_sla 
            ON orders (placed_at, store_id) 
            INCLUDE (delivered_at, promised_minutes) 
            WHERE status = 'DELIVERED';

        CREATE INDEX idx_orders_delivered_june 
            ON orders (store_id, placed_at, rider_id) 
            INCLUDE (delivered_at, picked_up_at) 
            WHERE status = 'DELIVERED';

        CREATE INDEX idx_orders_placed_range 
            ON orders (placed_at) 
            INCLUDE (store_id, total_amount, small_cart_fee, status);

        CREATE INDEX idx_orders_rider_placed 
            ON orders (rider_id, placed_at);

        CREATE INDEX idx_orders_placed_at_desc 
            ON orders (placed_at DESC, order_id);

        CREATE INDEX idx_orders_open_order_id 
            ON orders (store_id, order_id DESC) 
            WHERE status IN ('PLACED', 'PACKING');

        CREATE INDEX idx_orders_packing_min 
            ON orders (order_id) 
            WHERE status = 'PACKING';

        CREATE INDEX idx_orders_order_id 
            ON orders (order_id);

        RAISE NOTICE 'orders successfully partitioned by RANGE (placed_at).';
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 3. Declarative Hash Partitioning: order_items
-- -----------------------------------------------------------------------------

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'blinkit' AND tablename = 'order_items'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_partitioned_table pt
        JOIN pg_class c ON c.oid = pt.partrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'blinkit' AND c.relname = 'order_items'
    ) THEN
        RAISE NOTICE 'Migrating order_items to declarative HASH partitioning...';

        ALTER TABLE order_items RENAME TO order_items_old;

        CREATE TABLE order_items (
            order_id BIGINT NOT NULL,
            product_id INT NOT NULL REFERENCES products(product_id),
            quantity_ordered INT NOT NULL CHECK (quantity_ordered > 0),
            quantity_delivered INT NOT NULL CHECK (
                quantity_delivered >= 0 AND quantity_delivered <= quantity_ordered
            ),
            unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),
            substitute_product_id INT REFERENCES products(product_id),
            PRIMARY KEY (order_id, product_id)
        ) PARTITION BY HASH (order_id);

        -- 16 Hash Partitions for Uniform Sharding
        CREATE TABLE order_items_p0 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 0);
        CREATE TABLE order_items_p1 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 1);
        CREATE TABLE order_items_p2 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 2);
        CREATE TABLE order_items_p3 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 3);
        CREATE TABLE order_items_p4 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 4);
        CREATE TABLE order_items_p5 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 5);
        CREATE TABLE order_items_p6 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 6);
        CREATE TABLE order_items_p7 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 7);
        CREATE TABLE order_items_p8 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 8);
        CREATE TABLE order_items_p9 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 9);
        CREATE TABLE order_items_p10 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 10);
        CREATE TABLE order_items_p11 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 11);
        CREATE TABLE order_items_p12 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 12);
        CREATE TABLE order_items_p13 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 13);
        CREATE TABLE order_items_p14 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 14);
        CREATE TABLE order_items_p15 PARTITION OF order_items FOR VALUES WITH (MODULUS 16, REMAINDER 15);

        -- Safe Ingestion
        INSERT INTO order_items SELECT * FROM order_items_old;
        DROP TABLE order_items_old CASCADE;

        -- Local Partitioned Indexes
        CREATE INDEX idx_order_items_product_order 
            ON order_items (product_id, order_id) 
            INCLUDE (quantity_delivered, quantity_ordered);

        CREATE INDEX idx_order_items_substitute 
            ON order_items (substitute_product_id) 
            WHERE substitute_product_id IS NOT NULL;

        RAISE NOTICE 'order_items successfully partitioned by HASH (order_id).';
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 4. Planner Statistics Refresh
-- -----------------------------------------------------------------------------

ANALYZE;


-- -----------------------------------------------------------------------------
-- Partition Pruning Rationale & Workload Predicate Mapping
-- -----------------------------------------------------------------------------
-- 1. R08, R11, R13, R14, R19, R20: Filter by placed_at >= '2026-06-01' AND < '2026-07-01'
--    -> Prunes 17 of 18 partitions, isolating orders_2026_06.
-- 2. R15: Filter by placed_at >= '2026-06-29' AND < '2026-06-30'
--    -> Prunes all except orders_2026_06.
-- 3. R10, R24: Filter by moved_at in June 2026
--    -> Prunes all except inv_movements_2026_06.
-- 4. W05: Filter by moved_at < '2026-01-01'
--    -> Prunes all 2026 partitions, operating exclusively on 2025 partitions.
