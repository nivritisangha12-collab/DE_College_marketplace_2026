# CP2 – Baseline Query Timings

## 1. Objective

The objective of Phase 3 is to measure the execution performance of the 30 given SQL queries before applying additional indexing or query optimization.

Each query was executed three times using `EXPLAIN (ANALYZE, BUFFERS)`. The execution times were recorded in milliseconds, and the average was calculated for each query.

Write queries (W01–W05) were executed inside transactions using `BEGIN` and `ROLLBACK` to prevent permanent changes to the database.

## 2. Benchmark Environment

- Database: PostgreSQL
- Database name: blinkit_db
- Schema: blinkit
- Dataset: Blinkit grocery delivery dataset
- Total records: 1,084,442
- Read queries: 25 (R01–R25)
- Write queries: 5 (W01–W05)
- Number of executions per query: 3
- Indexes: Primary key and UNIQUE constraint indexes only

## 3. Baseline Timing Table

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Store assignment: the nearest active dark store within ~3 km of a customer at (12.93, 77.62) | READ | 0.099 | 0.050 | 0.074 | 0.074 |
| R02: Category page: Dairy products in stock at store 43, cheapest first | READ | 0.329 | 0.428 | 0.308 | 0.355 |
| R03: Search: products with "milk" in the name that are in stock at store 43 | READ | 0.930 | 0.781 | 0.800 | 0.837 |
| R04: Product page: stock of product 1236 in every Bengaluru dark store | READ | 0.185 | 0.108 | 0.104 | 0.132 |
| R05: Cart check: current stock and price of 4 cart items at store 43 | READ | 0.033 | 0.035 | 0.032 | 0.033 |
| R06: Order tracking: customer 1027's latest order with its timeline | READ | 6.929 | 5.311 | 5.053 | 5.764 |
| R07: Store screen: open orders at store 43 (not yet delivered or cancelled) | READ | 6.624 | 6.205 | 5.750 | 6.193 |
| R08: SLA report: share of June 2026 deliveries that took longer than promised, per store | READ | 6.058 | 5.955 | 5.844 | 5.952 |
| R09: Replenishment: products at store 43 at or below their reorder level | READ | 0.249 | 0.248 | 0.245 | 0.247 |
| R10: Wastage: units lost to expiry or damage per category in June 2026 | READ | 5.082 | 4.765 | 4.481 | 4.776 |
| R11: Rider performance: average minutes from pickup to delivery per rider at store 43 (June 2026) | READ | 5.091 | 5.000 | 4.989 | 5.027 |
| R12: Recommendations: products most often bought together with product 1236 | READ | 9.712 | 7.989 | 7.980 | 8.560 |
| R13: Category team: active products that were never given as a substitute in June 2026 | READ | 18.939 | 18.482 | 18.311 | 18.577 |
| R14: Fill rate: share of order lines delivered short, per store, June 2026 | READ | 18.514 | 17.944 | 18.023 | 18.160 |
| R15: Staffing: orders per hour at Bengaluru stores on 29 June 2026 | READ | 8.144 | 8.003 | 8.061 | 8.069 |
| R16: Growth: monthly cohorts—customers by month of first order, and how many ordered again in June 2026 | READ | 29.070 | 28.644 | 29.422 | 29.045 |
| R17: Finance: small-cart fee collected per city per month in 2026 | READ | 29.226 | 28.668 | 29.072 | 28.989 |
| R18: Dead stock: products in stock at store 43 that did not sell there in June 2026 | READ | 5.575 | 5.480 | 5.426 | 5.494 |
| R19: Category report: June 2026 units sold of every Fruits & Vegetables product | READ | 1815.103 | 1852.001 | 1865.762 | 1844.289 |
| R20: Finance: daily GMV and running total for June 2026 | READ | 9.073 | 8.807 | 8.335 | 8.738 |
| R21: Store manager: active riders of store 43 with no delivery on 30 June 2026 | READ | 5.047 | 4.783 | 4.755 | 4.862 |
| R22: Support console: all orders, newest first, page 4,001 (25 per page) | READ | 33.069 | 32.647 | 32.530 | 32.749 |
| R23: Warehouse scanner: look up a product by SKU | READ | 0.023 | 0.022 | 0.022 | 0.022 |
| R24: Supply chain: units restocked per product at store 43 in the last 7 days of June 2026 | READ | 2.971 | 2.808 | 2.748 | 2.842 |
| R25: Loyalty: 20 Mumbai customers with the most delivered orders in 2026 | READ | 13.485 | 13.061 | 12.999 | 13.182 |
| W01: Checkout: place a new order at store 43 | WRITE | 0.521 | 0.483 | 0.501 | 0.502 |
| W02: Packing done: reduce store 43's stock for every line of its most recent PLACED or PACKING order | WRITE | 9.962 | 10.463 | 9.657 | 10.027 |
| W03: Dispatch: give the oldest PACKING order (anywhere) to its store's first active rider | WRITE | 11.109 | 11.125 | 11.157 | 11.130 |
| W04: Nightly replenishment at store 43: top up everything at or below reorder level | WRITE | 1.071 | 0.736 | 0.547 | 0.785 |
| W05: Data retention: delete inventory movements older than 1 January 2026 | WRITE | 21.706 | 179.711 | 11.580 | 70.999 |

## 4. Scan Types and Reasons

The following observations are based on the scan nodes recorded in the PostgreSQL execution plans.

### R01 – Store assignment
- Scan type: Sequential Scan on dark_stores.
- Reason: PostgreSQL scans the dark_stores table to evaluate active status and the latitude and longitude range conditions. The query does not have a suitable index for these location conditions.

### R02 – Category page
- Scan type: Sequential Scans on products and categories; Index Scan on store_inventory.
- Reason: The existing composite primary key on store_inventory helps locate inventory by store and product. The product and category tables are scanned to identify the required category and products.

### R03 – Product search
- Scan type: Sequential Scan on products; Index Scan on store_inventory.
- Reason: The name search uses ILIKE with a leading wildcard, which is not efficiently supported by a normal B-tree index. The inventory lookup uses the existing primary key index.

### R04 – Product page
- Scan type: Sequential Scan on dark_stores; Index Scan on store_inventory.
- Reason: The store inventory primary key supports product inventory lookups. The city condition is evaluated while scanning dark_stores.

### R05 – Cart check
- Scan type: Index Scan using store_inventory_pkey.
- Reason: The composite primary key on store_inventory supports lookups using store_id and product_id, making this query very efficient.

### R06 – Order tracking
- Scan type: Sequential Scan on orders.
- Reason: The customer_id filter and placed_at sorting are not supported by a suitable additional index, so PostgreSQL scans the orders table.

### R07 – Store screen
- Scan type: Sequential Scan on orders.
- Reason: The query filters orders by store_id and status and sorts by placed_at. No additional index supports this combination.

### R08 – SLA report
- Scan type: Sequential Scan on orders.
- Reason: PostgreSQL scans orders to identify June 2026 deliveries and calculate delivery delays for each store.

### R09 – Replenishment
- Scan type: Sequential Scan on products; Bitmap Heap Scan and Bitmap Index Scan on store_inventory.
- Reason: PostgreSQL uses the inventory primary key index to identify relevant inventory records and then checks the product details.

### R10 – Wastage report
- Scan type: Sequential Scans on inventory_movements and products; Index Scan on categories.
- Reason: The movement date and movement type conditions require scanning inventory_movements. Product information is also scanned, while the category primary key supports category lookups.

### R11 – Rider performance
- Scan type: Sequential Scan on orders.
- Reason: The query filters orders by store, delivery status and date before grouping by rider. No suitable additional index covers these filtering conditions.

### R12 – Product recommendations
- Scan type: Sequential Scan on order_items; Index Only Scan using order_items_pkey.
- Reason: PostgreSQL scans order_items to find orders containing the selected product and uses the composite primary key index while matching other items in those orders.

### R13 – Substitute analysis
- Scan type: Sequential Scans on products, order_items and orders.
- Reason: The query checks active products against a subquery involving order_items and orders. The existing indexes do not avoid the broad scans required by these conditions.

### R14 – Fill rate
- Scan type: Sequential Scans on order_items and orders.
- Reason: The query processes order lines and joins them with orders to calculate short-delivery percentages. PostgreSQL scans both tables to evaluate the date and grouping conditions.

### R15 – Staffing report
- Scan type: Sequential Scan on orders; Index Scan on dark_stores.
- Reason: The orders table is scanned for the requested date and city. The primary key on dark_stores supports store lookups.

### R16 – Customer cohorts
- Scan type: Sequential Scan on orders.
- Reason: The query calculates each customer's first order and checks June activity. These operations require processing a large portion of the orders table.

### R17 – Small-cart fee report
- Scan type: Sequential Scan on orders; Index Scan on dark_stores.
- Reason: The query processes orders from 2026 and groups fees by city and month. The existing store primary key supports the join to dark_stores.

### R18 – Dead stock
- Scan type: Sequential Scan on orders and products; Index Only Scan on order_items; Bitmap Heap Scan and Bitmap Index Scan on store_inventory.
- Reason: The inventory primary key supports the store inventory lookup. The query also checks sales history using order_items and orders, requiring additional scans.

### R19 – Category sales report
- Scan type: Sequential Scans on categories, products and order_items; Index Scan using orders_pkey.
- Reason: The correlated subquery calculates delivered quantities for each product and checks the relevant orders. It repeatedly performs product-level sales lookups, resulting in substantial work across order_items and orders.

### R20 – Daily GMV
- Scan type: Sequential Scan on orders.
- Reason: PostgreSQL scans orders to filter delivered transactions in June 2026, group them by day and calculate the running total.

### R21 – Rider availability
- Scan type: Sequential Scans on orders and riders.
- Reason: The query checks active riders and uses a NOT EXISTS condition to find riders without recent deliveries. Both tables are scanned to evaluate these conditions.

### R22 – Support console
- Scan type: Sequential Scan on orders.
- Reason: The query sorts orders by placed_at and skips the first 100,000 rows. Without a suitable index for the ordering, PostgreSQL scans and sorts the orders table.

### R23 – Warehouse scanner
- Scan type: Index Scan using products_sku_key.
- Reason: The unique constraint on SKU automatically creates an index, allowing PostgreSQL to locate the product directly.

### R24 – Supply chain
- Scan type: Sequential Scan on inventory_movements.
- Reason: PostgreSQL scans inventory movements to filter by store, movement type and date before grouping restock quantities by product.

### R25 – Loyalty report
- Scan type: Sequential Scans on orders and customers.
- Reason: The query filters customers by city and orders by delivery status and date. The existing primary key indexes do not directly support these combined conditions.

### W01 – Checkout
- Scan type: No Scan.
- Reason: The query inserts a new order using supplied values. It does not need to scan existing table rows for its main operation. Constraint checks and related triggers are still executed.

### W02 – Stock deduction
- Scan type: Sequential Scan on orders; Index Scans on order_items and store_inventory.
- Reason: PostgreSQL scans orders to identify the latest eligible order. The primary key indexes support locating the order items and matching inventory records.

### W03 – Rider dispatch
- Scan type: Index Scans on orders and riders.
- Reason: The orders primary key supports locating the selected order, while the riders primary key supports rider lookups. The query also evaluates the rider's store and active status.

### W04 – Nightly replenishment
- Scan type: Bitmap Heap Scan and Bitmap Index Scan on store_inventory.
- Reason: PostgreSQL uses the existing inventory primary key index to identify matching inventory rows and then accesses the corresponding table pages for updating them.

### W05 – Data retention
- Scan type: Sequential Scan on inventory_movements.
- Reason: The query deletes records based on moved_at. No suitable additional index exists for this date condition, so PostgreSQL scans the table to identify qualifying rows.

## 5. Baseline Performance Observations

- R23 is the fastest read query, with an average execution time of 0.022 ms. Its SKU lookup benefits from the existing unique index.
- R19 is the slowest read query, with an average execution time of 1844.289 ms (approximately 1.84 seconds).
- R22 takes 32.749 ms on average, partly due to sorting and skipping a large number of rows.
- R16 and R17 also show relatively high execution times because they process a large portion of the orders table.
- W05 has the highest average write execution time at 70.999 ms.
- W05 has considerable variation across its three runs: 21.706 ms, 179.711 ms and 11.580 ms. Its median is 21.706 ms, indicating that the second run was unusually slow.

## 6. Conclusion

The baseline benchmark was successfully completed for all 30 SQL workload queries, with each query executed three times.

The execution plans show frequent sequential scans on large tables such as orders, order_items and inventory_movements. Existing primary key and unique indexes help several targeted lookups, but many filtering, grouping and sorting operations still require substantial table scans.

R19 and W05 are the most expensive read and write queries respectively, based on their average execution times.

These baseline measurements and execution plans will be used to evaluate the impact of indexing and query optimization in Phase 4.

## 7. Benchmark Files

The benchmark script generated the following files:

- `benchmarks/results/baseline/summary.csv` – average, median, minimum, maximum execution times and scan nodes for all 30 queries.
- `benchmarks/results/baseline/R01.txt` to `R25.txt` – raw execution plans for read queries.
- `benchmarks/results/baseline/W01.txt` to `W05.txt` – raw execution plans for write queries.
