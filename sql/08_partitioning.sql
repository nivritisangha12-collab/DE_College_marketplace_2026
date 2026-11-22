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
