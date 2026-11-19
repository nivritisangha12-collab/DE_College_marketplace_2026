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
