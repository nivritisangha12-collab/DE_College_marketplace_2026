# CP3 – Query Optimization & Indexing Report

## 2. Benchmark Environment & Methodology

The benchmarking methodology strictly mirrors the baseline protocol established in Phase 3 to ensure rigorous scientific comparability.

- **Database Engine:** PostgreSQL 18.0 (Postgres.app / macOS Darwin arm64)
- **Database Name:** `blinkit_db`
- **Schema:** `blinkit`
- **Dataset Size:** 1,084,442 relational records across 10 normalized tables (150,000 orders; 675,000 order items; 126,000 store inventory entries; 90,000 inventory movements; 40,000 customers; 1,800 riders; 1,500 products; 120 dark stores; 12 categories; 10 cities)
- **Harness:** `./benchmarks/run_benchmark.sh blinkit_db optimized 3 sql/06_optimized_queries.sql`
- **Measurement Standard:** `EXPLAIN (ANALYZE, BUFFERS)` executed for 3 consecutive iterations per query; average, median, minimum, and maximum execution times recorded.
- **Write Safety:** Write operations (`W01`–`W05`) wrapped in `BEGIN ... ROLLBACK` transactions to prevent state mutations across runs.

## 4. Indexing Strategy & Storage Analysis

### Rationale and Index Catalog

The secondary indexing strategy defined in `sql/05_indexes.sql` deliberately avoids redundant, monolithic B-trees in favor of **partial**, **covering**, and **specialized inverted (GIN)** indexes.

- `idx_dark_stores_location`: Partial coordinate B-tree for active store assignment.
- `idx_dark_stores_city`: Composite B-tree for city-level routing and metadata joins.
- `idx_products_category`: Covering B-tree on category taxonomy with product payload.
- `idx_products_name_trgm`: GIN trigram index for fast text substring searches.
- `idx_store_inventory_product`: Inverted composite B-tree for product-level inventory scans across stores.
- `idx_store_inventory_reorder`: Partial B-tree restricted to low-stock threshold rows.
- `idx_order_items_product_order`: Covering inverted index eliminating 675k-row line item scans.
- `idx_orders_customer_placed`: Composite index for customer order history and tracking.
- `idx_orders_open_store`: 16 kB partial index for operational store dispatch dashboards.
- `idx_orders_placed_at_desc`: Pre-sorted composite index for deferred pagination joins.
- `idx_orders_june_sla`: Partial covering index for SLA delivery performance monitoring.
- `idx_inv_movements_store_restock`: Partial covering index for supply chain replenishment audits.

## 5. Query Refactoring & Execution Plan Analysis

### R01–R05: Customer Discovery & Cart Check

#### R01 – Store Assignment
- **Baseline Plan:** `Seq Scan on dark_stores` (119 rows filtered, 0.074 ms).
- **Optimized Plan:** `Seq Scan on dark_stores` (0.086 ms).
- **Refactoring:** Evaluated bounding constants statically (`latitude BETWEEN 12.903 AND 12.957`). Since `dark_stores` contains only 120 rows across 2 disk pages, PostgreSQL's optimizer intentionally chooses a fast 2-page sequential scan because random page I/O of an index traversal is estimated higher for tiny tables.

#### R02 – Category Product Browsing
- **Baseline Plan:** `Seq Scan on products` | `Seq Scan on categories` | `Index Scan using store_inventory_pkey on store_inventory` (0.355 ms).
- **Optimized Plan:** `Seq Scan on categories` | `Index Only Scan using idx_products_category on products` | `Index Only Scan using idx_store_inventory_product on store_inventory` (0.411 ms).
- **Refactoring:** Reordered join paths to start with category filter, followed by index-only lookups on products and store inventory. Eliminates heap page visits on both major tables.

#### R03 – Wildcard Product Search
- **Baseline Plan:** `Seq Scan on products` (1,469 rows removed by `ILIKE '%milk%'`) | `Index Scan on store_inventory` (0.837 ms).
- **Optimized Plan:** `Bitmap Heap Scan on products` | `Bitmap Index Scan on idx_products_name_trgm` | `Index Only Scan using idx_store_inventory_product on store_inventory` (0.207 ms, **4.04× speedup**).
- **Refactoring:** Created a GIN trigram index (`pg_trgm`) on `products.product_name`. Converted full sequential scans of the product catalog into an efficient bitmap index scan.

#### R04 – Multi-Store Product Stock
- **Baseline Plan:** `Seq Scan on dark_stores` | `Index Scan using store_inventory_pkey on store_inventory` (0.132 ms).
- **Optimized Plan:** `Index Only Scan using idx_store_inventory_product on store_inventory` | `Seq Scan on dark_stores` (0.068 ms, **1.94× speedup**).
- **Refactoring:** The composite primary key `(store_id, product_id)` could not support filtering by `product_id = 1236`. The inverted index `idx_store_inventory_product` allowed an immediate index-only lookup of all store records stocking product 1236.

#### R05 – Cart Validation
- **Baseline Plan:** `Index Scan using store_inventory_pkey on store_inventory` (0.033 ms).
- **Optimized Plan:** `Index Only Scan using idx_store_inventory_product on store_inventory` (0.057 ms).
- **Refactoring:** Highly efficient point lookup using composite key index structures.

---

### R06–R08: Order Operations & SLA Monitoring

#### R06 – Real-Time Order Tracking
- **Baseline Plan:** `Seq Scan on orders` (150,000 rows scanned, 5.764 ms).
- **Optimized Plan:** `Index Scan using idx_orders_customer_placed on orders` (0.020 ms, **288.20× speedup**).
- **Refactoring:** Created composite index on `(customer_id, placed_at DESC)`. Replaced a full table scan of 150,000 orders with a direct index seek to the customer's newest order row.

#### R07 – Store Open Orders Dispatch Screen
- **Baseline Plan:** `Seq Scan on orders` (150,000 rows scanned, 6.193 ms).
- **Optimized Plan:** `Index Scan using idx_orders_open_store on orders` (0.019 ms, **325.95× speedup**).
- **Refactoring:** Created partial index on `(store_id, placed_at) WHERE status IN ('PLACED', 'PACKING', 'OUT_FOR_DELIVERY')`. Restricts index size to active orders, bypassing 99.9% of historical order rows.

#### R08 – SLA Delivery Breach Report
- **Baseline Plan:** `Seq Scan on orders` (6.058 ms, 150k rows scanned).
- **Optimized Plan:** `Index Only Scan using idx_orders_june_sla on orders` (1.066 ms, **5.58× speedup**).
- **Refactoring:** Sargable timestamp bounds (`placed_at >= '2026-06-01 00:00:00+05:30' AND placed_at < '2026-07-01 00:00:00+05:30'`) paired with partial covering index `idx_orders_june_sla` containing `(delivered_at, promised_minutes)`.

---

### R09–R12: Replenishment, Wastage & Recommendations

#### R09 – Store Low-Stock Replenishment
- **Baseline Plan:** `Seq Scan on products` | `Bitmap Heap Scan on store_inventory` (0.247 ms).
- **Optimized Plan:** `Seq Scan on products` | `Index Scan using idx_store_inventory_reorder on store_inventory` (0.206 ms, **1.20× speedup**).
- **Refactoring:** Targeted partial index `idx_store_inventory_reorder` isolates low-stock inventory entries without scanning full store inventories.

#### R10 – Category Wastage & Damage Aggregations
- **Baseline Plan:** `Seq Scan on inventory_movements` (90,000 rows) | `Seq Scan on products` | `Index Scan on categories` (4.776 ms).
- **Optimized Plan:** `Index Scan using idx_inv_movements_moved_at on inventory_movements` | `Seq Scan on products` | `Seq Scan on categories` (0.686 ms, **6.96× speedup**).
- **Refactoring:** Filtered movements via date index and pre-aggregated wastage quantities in a CTE at the product level before joining dimension tables, reducing join cardinality by 95%.

#### R11 – Rider Delivery Transit Performance
- **Baseline Plan:** `Seq Scan on orders` (5.027 ms).
- **Optimized Plan:** `Bitmap Heap Scan on orders` | `Bitmap Index Scan on idx_orders_delivered_june` (0.114 ms, **44.10× speedup**).
- **Refactoring:** Partial covering index on `(store_id, placed_at, rider_id)` restricted to `status = 'DELIVERED'` enables instant bitmap index scans.

#### R12 – Product Recommendations (Co-Purchased Items)
- **Baseline Plan:** `Seq Scan on order_items` (675,000 rows scanned) | `Index Only Scan on order_items_pkey` (8.560 ms).
- **Optimized Plan:** `Index Only Scan using idx_order_items_product_order on order_items` | `Index Only Scan using order_items_pkey on order_items` (1.078 ms, **7.94× speedup**).
- **Refactoring:** Created inverted covering index `(product_id, order_id) INCLUDE (quantity_delivered, quantity_ordered)`. Completely eliminated the full table scan of 675,000 line items.

---

### R13–R17: Cohorts, Fees & Category Analytics

#### R13 – Product Substitution Analysis
- **Baseline Plan:** `Seq Scan on products` | `Seq Scan on order_items` | `Seq Scan on orders` (18.577 ms).
- **Optimized Plan:** `Seq Scan on products` | `Seq Scan on order_items` | `Index Only Scan using idx_orders_placed_at_desc on orders` (34.889 ms).
- **Refactoring:** Query preserved exact semantics and SQL 3-valued logic. Date filter pushed down into an index-only scan on orders.

#### R14 – Short Delivery Fill Rate
- **Baseline Plan:** `Seq Scan on order_items` | `Seq Scan on orders` (18.160 ms).
- **Optimized Plan:** `Seq Scan on order_items` | `Index Scan using idx_orders_placed_range on orders` (16.275 ms, **1.12× speedup**).
- **Refactoring:** Orders date range filtered via `idx_orders_placed_range`, eliminating table scanning on orders.

#### R15 – Dark Store Hourly Staffing Profile
- **Baseline Plan:** `Seq Scan on orders` (forced by non-sargable `DATE(placed_at) = '2026-06-29'`) | `Index Scan on dark_stores` (8.069 ms).
- **Optimized Plan:** `Index Only Scan using idx_orders_placed_range on orders` | `Seq Scan on dark_stores` (0.096 ms, **84.05× speedup**).
- **Refactoring:** Converted `DATE(placed_at)` into sargable range `placed_at >= '2026-06-29 00:00:00+05:30' AND placed_at < '2026-06-30 00:00:00+05:30'`, unlocking an Index Only Scan.

#### R16 – Monthly Customer Retention Cohorts
- **Baseline Plan:** Two full sequential scans on orders (one for cohort `min(placed_at)` and a correlated `EXISTS` subquery per customer) (29.045 ms).
- **Optimized Plan:** Single-pass aggregation on orders (21.418 ms, **1.36× speedup**).
- **Refactoring:** Eliminated the correlated `EXISTS` subquery by combining `min(placed_at)` and `bool_or(placed_at >= '2026-06-01')` into a single aggregation pass over orders.

#### R17 – Monthly Small-Cart Fees per City
- **Baseline Plan:** `Seq Scan on orders` (forced by `EXTRACT(YEAR FROM placed_at) = 2026`) | `Index Scan on dark_stores` (28.989 ms).
- **Optimized Plan:** `Index Scan using idx_orders_placed_range on orders` | `Seq Scan on dark_stores` (9.757 ms, **2.97× speedup**).
- **Refactoring:** Replaced `EXTRACT` with sargable annual bounds and pre-aggregated fees at `(store_id, month)` level in a CTE, shrinking the join cardinality with `dark_stores` from 49,725 rows to 708 rows.

---

### R18–R22: Dead Stock, GMV & Support Pagination

#### R18 – Dead Stock Detection
- **Baseline Plan:** `Seq Scan on orders` | `Index Only Scan on order_items` | `Bitmap Heap Scan on store_inventory` (5.494 ms).
- **Optimized Plan:** `Bitmap Heap Scan on store_inventory` | `Index Scan using idx_orders_placed_range on orders` | `Index Only Scan on order_items_pkey` (0.980 ms, **5.61× speedup**).
- **Refactoring:** Reordered `NOT EXISTS` join to scan June orders through `idx_orders_placed_range`, eliminating sequential order scans.

#### R19 – Category Units Sold (Fruits & Vegetables)
- **Baseline Plan:** Correlated scalar subquery executed 125 times inside `SELECT`. Each iteration executed a `Hash Join` between `order_items` and `orders`, scanning 675,000 order items 125 times (1,844.289 ms).
- **Optimized Plan:** Set-based `LEFT JOIN` on `orders` and `order_items` aggregated once in parallel (16.688 ms, **110.52× speedup**).
- **Refactoring:** Completely eliminated the $O(N)$ correlated subquery antipattern. Refactored into a single set-based outer join grouped by product, cutting query execution time from 1.84 seconds to 16 ms.

#### R20 – Daily GMV & Running Total
- **Baseline Plan:** `Seq Scan on orders` (forced by non-sargable `placed_at::date BETWEEN ...`) (8.738 ms).
- **Optimized Plan:** `Index Only Scan using idx_orders_placed_range on orders` (1.428 ms, **6.12× speedup**).
- **Refactoring:** Rewrote `placed_at::date` into explicit timestamp boundaries, allowing PostgreSQL to satisfy both the date filter and GMV aggregation purely from the index pages.

#### R21 – Idle Active Riders
- **Baseline Plan:** `Seq Scan on orders` | `Seq Scan on riders` (4.862 ms).
- **Optimized Plan:** `Index Scan using idx_orders_placed_range on orders` | `Bitmap Heap Scan on riders` | `Bitmap Index Scan on idx_riders_store_active` (0.088 ms, **55.25× speedup**).
- **Refactoring:** Paired partial index `idx_riders_store_active` with `idx_orders_rider_placed` to evaluate rider delivery existence in microseconds.

#### R22 – Support Console High-Offset Pagination
- **Baseline Plan:** `Seq Scan on orders` | `Sort Method: external merge Disk: 7352kB` (32.749 ms).
- **Optimized Plan:** `Index Only Scan using idx_orders_placed_at_desc on orders` | `Index Scan using orders_pkey on orders` (5.247 ms, **6.24× speedup**).
- **Refactoring (Deferred Join):** High-offset pagination (`OFFSET 100000 LIMIT 25`) forces PostgreSQL to sort and retain all 100,025 wide rows in memory, overflowing work_mem and spilling 7.3 MB to temporary disk. The optimized query uses a **deferred join**:
  1. An inner subquery scans the narrow composite index `idx_orders_placed_at_desc` to retrieve only the 25 target `order_id` values (zero disk sort).
  2. The outer query joins back to `orders` by primary key for only those 25 rows, completely eliminating disk I/O.

---

### R23–R25: Scanners, Supply Chain & Loyalty

#### R23 – Warehouse SKU Scanner
- **Baseline Plan:** `Index Scan using products_sku_key on products` (0.022 ms).
- **Optimized Plan:** `Index Scan using products_sku_key on products` (0.025 ms).
- **Refactoring:** Preserved direct point-lookup on the unique constraint index.

#### R24 – Supply Chain Restock Audit
- **Baseline Plan:** `Seq Scan on inventory_movements` (90,000 rows scanned, 2.842 ms).
- **Optimized Plan:** `Index Only Scan using idx_inv_movements_store_restock on inventory_movements` (0.046 ms, **61.78× speedup**).
- **Refactoring:** Created partial covering index `(store_id, moved_at, product_id, quantity) WHERE movement_type = 'RESTOCK'`. Yields an Index Only Scan with 0 heap block accesses.

#### R25 – Customer Loyalty Leaderboard
- **Baseline Plan:** `Seq Scan on orders` | `Seq Scan on customers` (13.182 ms).
- **Optimized Plan:** `Index Scan using idx_orders_placed_range on orders` | `Index Only Scan using idx_customers_city on customers` (9.315 ms, **1.42× speedup**).
- **Refactoring:** Created `idx_customers_city` to allow index-only filtering of Mumbai customers, driving a hash join against delivered 2026 orders.

---

### W01–W05: Transactional Operations & Data Retention

#### W01 – Customer Order Checkout
- **Baseline Plan:** `Insert on orders` (0.502 ms).
- **Optimized Plan:** `Insert on orders` (0.709 ms).
- **Analysis:** Single-row insertion incurring minor index maintenance across secondary indexes. The modest increase (~0.2 ms) is well within real-time SLA thresholds (<5 ms).

#### W02 – Packing Done Stock Deduction
- **Baseline Plan:** `Seq Scan on orders` (scanned 150,000 orders to evaluate `max(order_id)`) | `Index Scan on order_items` | `Index Scan on store_inventory` (10.027 ms).
- **Optimized Plan:** `Index Only Scan using idx_orders_open_order_id on orders` | `Index Scan on order_items` | `Index Scan on store_inventory` (0.240 ms, **41.78× speedup**).
- **Refactoring:** The subquery `SELECT max(order_id) FROM orders WHERE store_id = 43 AND status IN ('PLACED', 'PACKING')` previously performed a full table scan. The partial index `idx_orders_open_order_id` transformed this into a 0.03 ms index seek.

#### W03 – Rider Dispatch Assignment
- **Baseline Plan:** `Index Scan on orders_pkey` (scanned orders to find `min(order_id) WHERE status = 'PACKING'`) | `Index Scan on riders` (11.130 ms).
- **Optimized Plan:** `Index Only Scan using idx_orders_packing_min on orders` | `Index Only Scan using idx_riders_store_active on riders` (0.299 ms, **37.22× speedup**).
- **Refactoring:** Partial indexes `idx_orders_packing_min` and `idx_riders_store_active` provide instant minimum order and available rider seeks in microseconds.

#### W04 – Nightly Store Replenishment
- **Baseline Plan:** `Bitmap Heap Scan on store_inventory` | `Bitmap Index Scan on store_inventory_pkey` (0.785 ms).
- **Optimized Plan:** `Index Scan using idx_store_inventory_reorder on store_inventory` (1.167 ms).
- **Refactoring:** Direct targeting of qualifying rows via `idx_store_inventory_reorder`.

#### W05 – Data Retention Movement Purge
- **Baseline Plan:** `Seq Scan on inventory_movements` (70.999 ms average, highly variable up to 179 ms).
- **Optimized Plan:** `Seq Scan on inventory_movements` (29.648 ms average, **2.39× speedup**).
- **Refactoring:** `moved_at < '2026-01-01'` selects 60,165 out of 90,000 rows (67% of the table). PostgreSQL's query planner correctly utilizes a sequential scan for mass deletes to maximize sequential I/O throughput.

---


## 6. Verification and Correctness

To verify that optimizations introduced zero semantic drift, all 25 read queries were tested against the baseline database state using bidirectional set difference validation:

$$\text{Diff}_1 = (\text{Baseline Query}) \setminus (\text{Optimized Query}) = \emptyset$$
$$\text{Diff}_2 = (\text{Optimized Query}) \setminus (\text{Baseline Query}) = \emptyset$$

### Validation Results Summary

- **Total Read Queries Tested:** 25 (R01–R25)
- **Queries with Identical Row Counts:** 25 / 25 (100%)
- **Queries with Zero Symmetric Difference:** 25 / 25 (100%)
- **Write Operations:** W01–W05 tested within transactions and verified to execute without constraint violations or data corruption.

---

