-- Declarative Table Partitioning (CP4)
SET search_path TO blinkit;

CREATE TABLE IF NOT EXISTS inventory_movements_partitioned (
    movement_id BIGINT NOT NULL,
    store_id INT NOT NULL REFERENCES dark_stores(store_id),
    product_id INT NOT NULL REFERENCES products(product_id),
    movement_type VARCHAR(20) NOT NULL CHECK (movement_type IN ('ADJUSTMENT','DAMAGE','EXPIRY','RESTOCK')),
    quantity INT NOT NULL,
    moved_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (movement_id, moved_at)
) PARTITION BY RANGE (moved_at);

CREATE TABLE IF NOT EXISTS orders_partitioned (
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
    payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('CARD','COD','UPI','WALLET')),
    status VARCHAR(30) NOT NULL CHECK (status IN ('CANCELLED','DELIVERED','OUT_FOR_DELIVERY','PACKING','PLACED')),
    CHECK (total_amount = subtotal + delivery_fee + handling_fee + small_cart_fee),
    PRIMARY KEY (order_id, placed_at)
) PARTITION BY RANGE (placed_at);

CREATE TABLE IF NOT EXISTS order_items_partitioned (
    order_id BIGINT NOT NULL,
    product_id INT NOT NULL REFERENCES products(product_id),
    quantity_ordered INT NOT NULL CHECK (quantity_ordered > 0),
    quantity_delivered INT NOT NULL CHECK (quantity_delivered >= 0 AND quantity_delivered <= quantity_ordered),
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),
    substitute_product_id INT REFERENCES products(product_id),
    PRIMARY KEY (order_id, product_id)
) PARTITION BY HASH (order_id);

-- Concrete 2025-2026 Monthly Range Partitions for inventory_movements
CREATE TABLE IF NOT EXISTS inv_movements_2025_01 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2025-01-01 00:00:00+05:30') TO ('2025-02-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2025_02 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2025-02-01 00:00:00+05:30') TO ('2025-03-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2025_03 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2025-03-01 00:00:00+05:30') TO ('2025-04-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2025_04 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2025-04-01 00:00:00+05:30') TO ('2025-05-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2025_05 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2025-05-01 00:00:00+05:30') TO ('2025-06-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2025_06 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2025-06-01 00:00:00+05:30') TO ('2025-07-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2025_07 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2025-07-01 00:00:00+05:30') TO ('2025-08-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2025_08 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2025-08-01 00:00:00+05:30') TO ('2025-09-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2025_09 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2025-09-01 00:00:00+05:30') TO ('2025-10-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2025_10 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2025-10-01 00:00:00+05:30') TO ('2025-11-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2025_11 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2025-11-01 00:00:00+05:30') TO ('2025-12-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2025_12 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2025-12-01 00:00:00+05:30') TO ('2026-01-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS inv_movements_2026_01 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2026-01-01 00:00:00+05:30') TO ('2026-02-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2026_02 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2026-02-01 00:00:00+05:30') TO ('2026-03-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2026_03 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2026-03-01 00:00:00+05:30') TO ('2026-04-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2026_04 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2026-04-01 00:00:00+05:30') TO ('2026-05-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2026_05 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2026-05-01 00:00:00+05:30') TO ('2026-06-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2026_06 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2026-06-01 00:00:00+05:30') TO ('2026-07-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_2026_07 PARTITION OF inventory_movements_partitioned FOR VALUES FROM ('2026-07-01 00:00:00+05:30') TO ('2026-08-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS inv_movements_default PARTITION OF inventory_movements_partitioned DEFAULT;

-- Concrete 2025-2026 Monthly Range Partitions for orders
CREATE TABLE IF NOT EXISTS orders_2025_01 PARTITION OF orders_partitioned FOR VALUES FROM ('2025-01-01 00:00:00+05:30') TO ('2025-02-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2025_02 PARTITION OF orders_partitioned FOR VALUES FROM ('2025-02-01 00:00:00+05:30') TO ('2025-03-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2025_03 PARTITION OF orders_partitioned FOR VALUES FROM ('2025-03-01 00:00:00+05:30') TO ('2025-04-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2025_04 PARTITION OF orders_partitioned FOR VALUES FROM ('2025-04-01 00:00:00+05:30') TO ('2025-05-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2025_05 PARTITION OF orders_partitioned FOR VALUES FROM ('2025-05-01 00:00:00+05:30') TO ('2025-06-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2025_06 PARTITION OF orders_partitioned FOR VALUES FROM ('2025-06-01 00:00:00+05:30') TO ('2025-07-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2025_07 PARTITION OF orders_partitioned FOR VALUES FROM ('2025-07-01 00:00:00+05:30') TO ('2025-08-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2025_08 PARTITION OF orders_partitioned FOR VALUES FROM ('2025-08-01 00:00:00+05:30') TO ('2025-09-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2025_09 PARTITION OF orders_partitioned FOR VALUES FROM ('2025-09-01 00:00:00+05:30') TO ('2025-10-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2025_10 PARTITION OF orders_partitioned FOR VALUES FROM ('2025-10-01 00:00:00+05:30') TO ('2025-11-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2025_11 PARTITION OF orders_partitioned FOR VALUES FROM ('2025-11-01 00:00:00+05:30') TO ('2025-12-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2025_12 PARTITION OF orders_partitioned FOR VALUES FROM ('2025-12-01 00:00:00+05:30') TO ('2026-01-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS orders_2026_01 PARTITION OF orders_partitioned FOR VALUES FROM ('2026-01-01 00:00:00+05:30') TO ('2026-02-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2026_02 PARTITION OF orders_partitioned FOR VALUES FROM ('2026-02-01 00:00:00+05:30') TO ('2026-03-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2026_03 PARTITION OF orders_partitioned FOR VALUES FROM ('2026-03-01 00:00:00+05:30') TO ('2026-04-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2026_04 PARTITION OF orders_partitioned FOR VALUES FROM ('2026-04-01 00:00:00+05:30') TO ('2026-05-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2026_05 PARTITION OF orders_partitioned FOR VALUES FROM ('2026-05-01 00:00:00+05:30') TO ('2026-06-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2026_06 PARTITION OF orders_partitioned FOR VALUES FROM ('2026-06-01 00:00:00+05:30') TO ('2026-07-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_2026_07 PARTITION OF orders_partitioned FOR VALUES FROM ('2026-07-01 00:00:00+05:30') TO ('2026-08-01 00:00:00+05:30');
CREATE TABLE IF NOT EXISTS orders_default PARTITION OF orders_partitioned DEFAULT;
