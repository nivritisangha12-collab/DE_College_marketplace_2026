-- =============================================================================
-- Blinkit 10-Minute Grocery Delivery Database: Relational Schema DDL
--
-- Schema: blinkit
-- Description:
--   Relational schema definition representing the dark-store delivery platform.
--   Enforces entity integrity (PRIMARY KEY), referential integrity (FOREIGN KEY),
--   uniqueness constraints (UNIQUE), and business domain invariants (CHECK).
--
-- Constraints Note:
--   Per Phase 2 specification, only core constraints are defined at this stage.
--   Secondary tuning indexes are deferred to Phase 4 for benchmark comparison.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS blinkit;
SET search_path TO blinkit;

-- -----------------------------------------------------------------------------
-- 1. Master & Dimension Entities
-- -----------------------------------------------------------------------------

-- Cities: Metropolitan regions supported by the delivery network
CREATE TABLE cities (
    city_id INT PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL UNIQUE,
    state VARCHAR(100) NOT NULL
);

-- Categories: Product taxonomy classifying goods by perishability
CREATE TABLE categories (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    is_perishable BOOLEAN NOT NULL
);

-- -----------------------------------------------------------------------------
-- 2. Infrastructure & Operational Fleet
-- -----------------------------------------------------------------------------

-- Dark Stores: Local fulfillment micro-warehouses serving nearby coordinates
CREATE TABLE dark_stores (
    store_id INT PRIMARY KEY,
    store_code VARCHAR(30) NOT NULL UNIQUE,
    city_id INT NOT NULL REFERENCES cities(city_id),
    latitude NUMERIC(9,6) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude NUMERIC(9,6) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    opened_on DATE NOT NULL,
    is_active BOOLEAN NOT NULL,
    max_daily_orders INT NOT NULL CHECK (max_daily_orders > 0)
);

-- -----------------------------------------------------------------------------
-- 3. Customer & Catalogue Management
-- -----------------------------------------------------------------------------

-- Customers: Registered customer accounts linked to operating cities
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(255),
    city_id INT NOT NULL REFERENCES cities(city_id),
    created_at TIMESTAMPTZ NOT NULL
);

-- Products: Master catalogue items with SKU codes, pack sizing, and MRP
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    sku VARCHAR(50) NOT NULL UNIQUE,
    product_name VARCHAR(200) NOT NULL,
    brand VARCHAR(100) NOT NULL,
    category_id INT NOT NULL REFERENCES categories(category_id),
    pack_size VARCHAR(50) NOT NULL,
    mrp NUMERIC(10,2) NOT NULL CHECK (mrp > 0),
    shelf_life_days INT CHECK (shelf_life_days > 0),
    is_active BOOLEAN NOT NULL
);

-- Riders: Delivery personnel attached to specific dark store hubs
CREATE TABLE riders (
    rider_id INT PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20) NOT NULL UNIQUE,
    store_id INT NOT NULL REFERENCES dark_stores(store_id),
    joined_on DATE NOT NULL,
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('ACTIVE','EXITED','ON_LEAVE'))
);

-- -----------------------------------------------------------------------------
-- 4. Store Inventory
-- -----------------------------------------------------------------------------

-- Store Inventory: Localized product stock counts and selling prices per store
CREATE TABLE store_inventory (
    store_id INT NOT NULL REFERENCES dark_stores(store_id),
    product_id INT NOT NULL REFERENCES products(product_id),
    quantity_on_hand INT NOT NULL CHECK (quantity_on_hand >= 0),
    reorder_level INT NOT NULL CHECK (reorder_level >= 0),
    selling_price NUMERIC(10,2) NOT NULL CHECK (selling_price > 0),
    updated_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (store_id, product_id)
);

-- -----------------------------------------------------------------------------
-- 5. Orders & Line Items
-- -----------------------------------------------------------------------------

-- Orders: Header record for customer orders capturing fulfillment timeline and fee breakdown
CREATE TABLE orders (
    order_id BIGINT PRIMARY KEY,
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
    CHECK (total_amount = subtotal + delivery_fee + handling_fee + small_cart_fee)
);

-- Order Items: Line items per order capturing requested vs delivered quantity and substitutions
CREATE TABLE order_items (
    order_id BIGINT NOT NULL REFERENCES orders(order_id),
    product_id INT NOT NULL REFERENCES products(product_id),
    quantity_ordered INT NOT NULL CHECK (quantity_ordered > 0),
    quantity_delivered INT NOT NULL CHECK (
        quantity_delivered >= 0 AND quantity_delivered <= quantity_ordered
    ),
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),
    substitute_product_id INT REFERENCES products(product_id),
    PRIMARY KEY (order_id, product_id)
);

-- -----------------------------------------------------------------------------
-- 6. Inventory Movements
-- -----------------------------------------------------------------------------

-- Inventory Movements: Stock adjustment ledger (restocks, damages, expiries, corrections)
CREATE TABLE inventory_movements (
    movement_id BIGINT PRIMARY KEY,
    store_id INT NOT NULL REFERENCES dark_stores(store_id),
    product_id INT NOT NULL REFERENCES products(product_id),
    movement_type VARCHAR(20) NOT NULL
        CHECK (movement_type IN ('ADJUSTMENT','DAMAGE','EXPIRY','RESTOCK')),
    quantity INT NOT NULL,
    moved_at TIMESTAMPTZ NOT NULL,
    CHECK (movement_type <> 'RESTOCK' OR quantity > 0),
    CHECK (movement_type NOT IN ('DAMAGE','EXPIRY') OR quantity < 0)
);
