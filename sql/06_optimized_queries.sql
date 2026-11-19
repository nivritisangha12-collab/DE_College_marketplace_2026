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

-- @END
ROLLBACK;
