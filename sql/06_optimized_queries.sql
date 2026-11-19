SET search_path TO blinkit;
BEGIN;

-- @R01
SELECT store_id, store_code,
       round((6371 * acos(least(1, cos(radians(12.93)) * cos(radians(latitude)) * cos(radians(longitude) - radians(77.62))
                                  + sin(radians(12.93)) * sin(radians(latitude)))))::numeric, 2) AS km
FROM dark_stores
WHERE is_active
  AND latitude BETWEEN 12.903 AND 12.957
  AND longitude BETWEEN 77.592 AND 77.648
ORDER BY km
LIMIT 1;

-- @R02
SELECT p.product_id, p.product_name, si.selling_price, si.quantity_on_hand
FROM categories c
JOIN products p ON p.category_id = c.category_id
JOIN store_inventory si ON si.product_id = p.product_id AND si.store_id = 43
WHERE c.category_name = 'Dairy'
  AND si.quantity_on_hand > 0
ORDER BY si.selling_price;

-- @R03
SELECT p.product_id, p.product_name, si.selling_price
FROM products p
JOIN store_inventory si ON si.product_id = p.product_id AND si.store_id = 43
WHERE p.product_name ILIKE '%milk%'
  AND si.quantity_on_hand > 0
ORDER BY si.selling_price;

-- @R04
SELECT s.store_code, si.quantity_on_hand, si.selling_price
FROM dark_stores s
JOIN store_inventory si ON si.store_id = s.store_id AND si.product_id = 1236
WHERE s.city_id = 1
ORDER BY si.quantity_on_hand DESC;

-- @R05
SELECT product_id, quantity_on_hand, selling_price
FROM store_inventory
WHERE store_id = 43 AND product_id IN (1236, 324, 101, 777);

-- @R06
SELECT order_id, status, placed_at, packed_at, picked_up_at, delivered_at, total_amount
FROM orders
WHERE customer_id = 1027
ORDER BY placed_at DESC
LIMIT 1;

-- @R07
SELECT order_id, status, placed_at, rider_id
FROM orders
WHERE store_id = 43 AND status IN ('PLACED', 'PACKING', 'OUT_FOR_DELIVERY')
ORDER BY placed_at;

-- @R08
SELECT store_id, count(*) AS deliveries,
       round(100.0 * count(*) FILTER (WHERE delivered_at - placed_at > promised_minutes * interval '1 minute') / count(*), 1) AS late_pct
FROM orders
WHERE status = 'DELIVERED'
  AND placed_at >= '2026-06-01 00:00:00+05:30' AND placed_at < '2026-07-01 00:00:00+05:30'
GROUP BY store_id
ORDER BY late_pct DESC;

-- @R09
SELECT p.product_id, p.product_name, si.quantity_on_hand, si.reorder_level
FROM store_inventory si
JOIN products p ON p.product_id = si.product_id
WHERE si.store_id = 43
  AND si.quantity_on_hand <= si.reorder_level
ORDER BY si.quantity_on_hand;

-- @R10
WITH wastage AS (
    SELECT m.product_id, m.movement_type, -sum(m.quantity) AS units_lost
    FROM inventory_movements m
    WHERE m.movement_type IN ('EXPIRY', 'DAMAGE')
      AND m.moved_at >= '2026-06-01 00:00:00+05:30' AND m.moved_at < '2026-07-01 00:00:00+05:30'
    GROUP BY m.product_id, m.movement_type
)
SELECT c.category_name, w.movement_type, sum(w.units_lost) AS units_lost
FROM wastage w
JOIN products p ON p.product_id = w.product_id
JOIN categories c ON c.category_id = p.category_id
GROUP BY c.category_name, w.movement_type
ORDER BY units_lost DESC;

-- @R11
SELECT rider_id, count(*) AS deliveries,
       round(avg(EXTRACT(EPOCH FROM (delivered_at - picked_up_at)) / 60), 1) AS avg_ride_minutes
FROM orders
WHERE store_id = 43 AND status = 'DELIVERED'
  AND placed_at >= '2026-06-01 00:00:00+05:30' AND placed_at < '2026-07-01 00:00:00+05:30'
GROUP BY rider_id
ORDER BY avg_ride_minutes;

-- @R12
SELECT b.product_id, count(*) AS together
FROM order_items a
JOIN order_items b ON b.order_id = a.order_id AND b.product_id <> a.product_id
WHERE a.product_id = 1236
GROUP BY b.product_id
ORDER BY together DESC
LIMIT 10;

-- @R13
SELECT p.product_id, p.product_name
FROM products p
WHERE p.is_active
  AND p.product_id NOT IN (
      SELECT oi.substitute_product_id
      FROM orders o
      JOIN order_items oi ON oi.order_id = o.order_id
      WHERE o.placed_at >= '2026-06-01 00:00:00+05:30' AND o.placed_at < '2026-07-01 00:00:00+05:30'
  );

-- @R14
SELECT o.store_id, count(*) AS lines,
       round(100.0 * count(*) FILTER (WHERE oi.quantity_delivered < oi.quantity_ordered) / count(*), 2) AS short_pct
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.placed_at >= '2026-06-01 00:00:00+05:30' AND o.placed_at < '2026-07-01 00:00:00+05:30'
GROUP BY o.store_id
ORDER BY short_pct DESC;

-- @R15
SELECT o.store_id, EXTRACT(HOUR FROM o.placed_at) AS hour, count(*) AS orders
FROM orders o
JOIN dark_stores s ON s.store_id = o.store_id
WHERE s.city_id = 1
  AND o.placed_at >= '2026-06-29 00:00:00+05:30' AND o.placed_at < '2026-06-30 00:00:00+05:30'
GROUP BY 1, 2
ORDER BY 1, 2;

-- @R16
WITH customer_activity AS (
    SELECT customer_id,
           date_trunc('month', min(placed_at)) AS cohort,
           bool_or(placed_at >= '2026-06-01 00:00:00+05:30') AS active_in_june
    FROM orders
    GROUP BY customer_id
)
SELECT cohort,
       count(*) AS customers,
       count(*) FILTER (WHERE active_in_june) AS active_in_june
FROM customer_activity
GROUP BY cohort
ORDER BY cohort;

-- @R17
WITH store_monthly_fees AS (
    SELECT o.store_id,
           date_trunc('month', o.placed_at) AS month,
           sum(o.small_cart_fee) AS fees
    FROM orders o
    WHERE o.placed_at >= '2026-01-01 00:00:00+05:30' AND o.placed_at < '2027-01-01 00:00:00+05:30'
    GROUP BY o.store_id, 2
)
SELECT s.city_id, sm.month, sum(sm.fees) AS small_cart_fees
FROM store_monthly_fees sm
JOIN dark_stores s ON s.store_id = sm.store_id
GROUP BY 1, 2
ORDER BY 1, 2;

-- @R18
SELECT p.product_id, p.product_name, si.quantity_on_hand
FROM store_inventory si
JOIN products p ON p.product_id = si.product_id
WHERE si.store_id = 43 AND si.quantity_on_hand > 0
  AND NOT EXISTS (SELECT 1 FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
                  WHERE oi.product_id = si.product_id AND o.store_id = 43
                    AND o.placed_at >= '2026-06-01 00:00:00+05:30')
ORDER BY si.quantity_on_hand DESC;

-- @R19
SELECT p.product_id, p.product_name, coalesce(sum(oi.quantity_delivered), 0) AS units_sold
FROM categories c
JOIN products p ON p.category_id = c.category_id
LEFT JOIN (
    orders o
    JOIN order_items oi ON oi.order_id = o.order_id
) ON oi.product_id = p.product_id
  AND o.placed_at >= '2026-06-01 00:00:00+05:30' AND o.placed_at < '2026-07-01 00:00:00+05:30'
WHERE c.category_name = 'Fruits & Vegetables'
GROUP BY p.product_id, p.product_name
ORDER BY units_sold DESC;

-- @R20
SELECT day, gmv, sum(gmv) OVER (ORDER BY day) AS running_gmv
FROM (
    SELECT placed_at::date AS day, sum(total_amount) AS gmv
    FROM orders
    WHERE status = 'DELIVERED'
      AND placed_at >= '2026-06-01 00:00:00+05:30' AND placed_at < '2026-07-01 00:00:00+05:30'
    GROUP BY 1
) d
ORDER BY day;

-- @R21
SELECT r.rider_id, r.full_name
FROM riders r
WHERE r.store_id = 43 AND r.status = 'ACTIVE'
  AND NOT EXISTS (SELECT 1 FROM orders o WHERE o.rider_id = r.rider_id AND o.placed_at >= '2026-06-30 00:00:00+05:30')
ORDER BY r.rider_id;

-- @R22
SELECT o.order_id, o.customer_id, o.store_id, o.status, o.total_amount, o.placed_at
FROM (
    SELECT order_id
    FROM orders
    ORDER BY placed_at DESC
    OFFSET 100000
    LIMIT 25
) sub
JOIN orders o ON o.order_id = sub.order_id
ORDER BY o.placed_at DESC;

-- @R23
SELECT product_id, product_name, pack_size, mrp
FROM products
WHERE sku = 'BK19787884';

-- @R24
SELECT m.product_id, count(*) AS restocks, sum(m.quantity) AS units
FROM inventory_movements m
WHERE m.store_id = 43 AND m.movement_type = 'RESTOCK'
  AND m.moved_at >= '2026-06-24 00:00:00+05:30'
GROUP BY m.product_id
ORDER BY units DESC;

-- @R25
SELECT c.customer_id, count(*) AS orders, sum(o.total_amount) AS spend
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE c.city_id = 2 AND o.status = 'DELIVERED' AND o.placed_at >= '2026-01-01 00:00:00+05:30'
GROUP BY c.customer_id
ORDER BY orders DESC, spend DESC
LIMIT 20;

-- @W01
INSERT INTO orders (order_id, customer_id, store_id, placed_at, subtotal, delivery_fee, handling_fee, small_cart_fee,
                    total_amount, payment_method, status)
VALUES (90000001, 1027, 43, '2026-07-01 08:00:00+05:30', 245.00, 0, 6, 0, 251.00, 'UPI', 'PLACED');

-- @W02
UPDATE store_inventory si
SET quantity_on_hand = greatest(0, si.quantity_on_hand - oi.quantity_ordered),
    updated_at = '2026-07-01 08:05:00+05:30'
FROM order_items oi
WHERE oi.order_id = (SELECT max(order_id) FROM orders WHERE store_id = 43 AND status IN ('PLACED', 'PACKING'))
  AND si.store_id = 43
  AND si.product_id = oi.product_id;

-- @W03
UPDATE orders o
SET rider_id = (SELECT min(r.rider_id) FROM riders r WHERE r.store_id = o.store_id AND r.status = 'ACTIVE'),
    status = 'OUT_FOR_DELIVERY',
    picked_up_at = coalesce(o.packed_at, o.placed_at) + interval '1 minute',
    packed_at = coalesce(o.packed_at, o.placed_at + interval '30 seconds')
WHERE o.order_id = (SELECT min(order_id) FROM orders WHERE status = 'PACKING');

-- @W04
UPDATE store_inventory
SET quantity_on_hand = reorder_level * 4, updated_at = '2026-07-01 05:00:00+05:30'
WHERE store_id = 43 AND quantity_on_hand <= reorder_level;

-- @W05
DELETE FROM inventory_movements
WHERE moved_at < '2026-01-01 00:00:00+05:30';

-- @END
ROLLBACK;
