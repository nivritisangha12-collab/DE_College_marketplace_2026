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

-- @END
ROLLBACK;
