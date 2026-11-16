# Schema Design — Blinkit

## 1. Database Overview
The Blinkit database is designed using PostgreSQL. It contains 10 relational tables that manage cities, dark stores, customers, products, inventory, riders, orders and inventory movements.

## 2. Data Dictionary

| Table | Primary Key | Purpose |
|---|---|---|
| cities | city_id | Stores city and state details |
| categories | category_id | Stores product categories |
| dark_stores | store_id | Stores dark-store locations |
| customers | customer_id | Stores customer details |
| products | product_id | Stores product catalogue |
| riders | rider_id | Stores delivery partner details |
| store_inventory | store_id, product_id | Tracks inventory at each store |
| orders | order_id | Stores customer orders |
| order_items | order_id, product_id | Stores products within orders |
| inventory_movements | movement_id | Records inventory changes |

## 3. Relationships
- One city can have multiple customers and dark stores.
- One category can contain multiple products.
- One dark store can have multiple riders.
- Store inventory connects dark stores and products.
- One customer can place multiple orders.
- One dark store can process multiple orders.
- One rider can deliver multiple orders.
- One order can contain multiple order items.
- Products can reference other products as substitutes.
- Inventory movements record stock changes for a store-product pair.

## 4. Functional Dependencies
- cities: city_id → city_name, state
- categories: category_id → category_name, is_perishable
- dark_stores: store_id → store_code, city_id, latitude, longitude, opened_on, is_active, max_daily_orders
- customers: customer_id → full_name, phone, email, city_id, created_at
- products: product_id → sku, product_name, brand, category_id, pack_size, mrp, shelf_life_days, is_active
- riders: rider_id → full_name, phone, store_id, joined_on, status
- store_inventory: (store_id, product_id) → quantity_on_hand, reorder_level, selling_price, updated_at
- orders: order_id → customer_id, store_id, rider_id, placed_at, packed_at, picked_up_at, delivered_at, promised_minutes, subtotal, delivery_fee, handling_fee, small_cart_fee, total_amount, payment_method, status
- order_items: (order_id, product_id) → quantity_ordered, quantity_delivered, unit_price, substitute_product_id
- inventory_movements: movement_id → store_id, product_id, movement_type, quantity, moved_at

## 5. Normalization
The schema is designed to satisfy Third Normal Form (3NF):
- Each table has a primary key.
- Every non-key attribute depends on the whole candidate key.
- No transitive dependencies are intentionally stored.
- Many-to-many relationships are resolved through store_inventory and order_items.

## 6. Integrity Constraints
The database uses:
- Primary keys to uniquely identify records.
- Foreign keys to maintain valid relationships.
- UNIQUE constraints on city names, category names, store codes, phone numbers and product SKUs.
- NOT NULL constraints for mandatory attributes.
- CHECK constraints for positive prices, valid coordinates, order statuses, payment methods, quantities and inventory movement signs.

## 7. Data Integrity Validation
Initial CSV validation reported:
- No orphan records across the 14 foreign-key relationships.
- No duplicate composite keys in store_inventory and order_items.
- No duplicate values in the checked unique columns.
- No order-total mismatches in the initial validation.
- No invalid RESTOCK, DAMAGE or EXPIRY movement signs.

## 8. Data Quality Observations
- Customer email is NULL for 18,023 records.
- Rider assignment is NULL for 5,822 orders.
- Some order timestamps are NULL because orders may not have reached those stages.
- Product shelf_life_days is NULL for 875 products.
- Substitute product is NULL for 660,000 order items.

These NULL values represent optional or stage-dependent information and are not automatically invalid records.
