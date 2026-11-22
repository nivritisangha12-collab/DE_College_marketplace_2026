# CP4 – Scalability & Partitioning Report

## 1. System Specifications & Benchmark Environment

- **Database Engine:** PostgreSQL 18.7 (Postgres.app)
- **Host Architecture:** Apple Silicon (macOS Darwin aarch64)
- **Hardware Specs:** 16 GB Unified Memory, High-Throughput NVMe APFS Storage (>230 GB available)
- **Databases:** `blinkit_db` (Standard Seed Dataset) and `blinkit_db_large` (20× Large Dataset)
- **Schema:** `blinkit`
- **Measurement Protocol:** 3 consecutive warm and cold runs using `EXPLAIN (ANALYZE, BUFFERS)` per query; average, median, min, max recorded.

---

## 2. Dataset Scaling Methodology

The large scale benchmark dataset represents a **20× increase in transactional and operational volume**, modeling full production scale for next year. To guarantee experimental integrity and avoid result drift, original seed entities (stores 1–120, customer 1027, product 1236, store 43) were preserved verbatim, with synthetic records generated matching existing relational distributions and foreign keys.

| Table Name | Seed Volume (Rows) | Large Scale Volume (Rows) | Growth Factor | Seed Relational Size | Large Scale Relational Size |
|---|---:|---:|---:|---:|---:|
| `order_items` | 675,000 | 13,703,571 | 20.30× | 42 MB | 1,733 MB (787 MB heap + 946 MB index) |
| `orders` | 150,000 | 3,000,000 | 20.00× | 38 MB | 1,213 MB (359 MB heap + 853 MB index) |
| `store_inventory` | 126,000 | 2,520,000 | 20.00× | 11 MB | 267 MB (141 MB heap + 126 MB index) |
| `inventory_movements` | 90,000 | 1,800,000 | 20.00× | 10 MB | 274 MB (117 MB heap + 157 MB index) |
| `customers` | 40,000 | 800,000 | 20.00× | 4.8 MB | 130 MB (70 MB heap + 60 MB index) |
| `riders` | 1,800 | 36,000 | 20.00× | 184 kB | 6.1 MB (2.5 MB heap + 3.6 MB index) |
| `dark_stores` | 120 | 2,400 | 20.00× | 40 kB | 600 kB (248 kB heap + 352 kB index) |
| `products` | 1,500 | 1,500 | 1.00× | 248 kB | 520 kB (248 kB heap + 272 kB index) |
| `categories` | 12 | 12 | 1.00× | 16 kB | 32 kB |
| `cities` | 10 | 10 | 1.00× | 16 kB | 32 kB |
| **Total Database** | **1,084,442** | **21,863,503** | **20.16×** | **140 MB** | **3,636 MB (~3.64 GB)** |

---

## 3. Declarative Partitioning Strategy & Pruning Architecture

To prevent severe table scan and B-tree degradation under 21.8 million records, declarative table partitioning was applied across the three high-volume tables:

1. **`inventory_movements`: `PARTITION BY RANGE (moved_at)`**
   - **Rationale:** High-throughput event ledger with strict retention policies.
   - **Pruning Target:** Queries R10 and R24 filter on June 2026, while batch job W05 deletes movements older than 1 January 2026.
   - **Partitions:** 12 monthly partitions for 2025, 7 monthly partitions for 2026, plus a `DEFAULT` partition.
   - **Pruning Impact:** Prunes 17 of 18 partitions for monthly queries; retention delete isolates only 2025 partitions.

2. **`orders`: `PARTITION BY RANGE (placed_at)`**
   - **Rationale:** Time-series fulfillment lifecycle. Over 10 workload queries (R08, R11, R13, R14, R15, R17, R18, R19, R20, R21, R25) filter on temporal bounds.
   - **PostgreSQL Primary Key Rule:** Any UNIQUE or PRIMARY KEY constraint on a partitioned table MUST contain all partition key columns. Therefore, the primary key was structured as `(order_id, placed_at)`.
   - **Partitions:** 12 monthly partitions for 2025, 7 monthly partitions for 2026, plus `orders_default`.

3. **`order_items`: `PARTITION BY HASH (order_id)`**
   - **Rationale:** Massive 13.7M-row table. Uniformly distributing rows across 16 hash partitions reduces B-tree height and ensures queries filtering by `order_id` (e.g. W02 packing stock deductions) prune to a single partition.
   - **Primary Key Rule:** `PRIMARY KEY (order_id, product_id)` naturally satisfies the requirement since `order_id` is part of the composite primary key.

---

## 4. Empirical Plan Demonstrations: Partition Pruning in Action

### 1. R10 – Category Wastage Report (June 2026)

On the unpartitioned database, R10 had to scan the entire `inventory_movements` table. With range partitioning on `moved_at`, PostgreSQL prunes 18 partitions and accesses **only `inv_movements_2026_06`**:

```
=== R10 Plan on 20× Large Dataset (benchmarks/results/large/R10.txt) ===
Sort  (actual time=3.757..3.758 rows=24.00 loops=1)
  Sort Key: (sum(((- sum(m.quantity))))) DESC
  ->  HashAggregate  (actual time=3.731..3.744 rows=24.00 loops=1)
        Group Key: c.category_name, m.movement_type
        ->  Hash Join  (actual time=3.428..3.624 rows=873.00 loops=1)
              Hash Cond: (p.category_id = c.category_id)
              ->  Hash Join  (actual time=3.418..3.568 rows=873.00 loops=1)
                    Hash Cond: (m.product_id = p.product_id)
                    ->  HashAggregate  (actual time=3.295..3.348 rows=873.00 loops=1)
                          Group Key: m.product_id, m.movement_type
                          ->  Index Only Scan using inv_movements_2026_06_moved_at_movement_type_product_id_qua_idx on inv_movements_2026_06 m
                                (actual time=0.016..1.921 rows=28758.00 loops=1)
                                Index Cond: ((moved_at >= '2026-06-01 00:00:00+05:30') AND (moved_at < '2026-07-01 00:00:00+05:30'))
                                Heap Fetches: 0
Planning Time: 2.809 ms
Execution Time: 3.811 ms (Median: 4.312 ms)
```
> **Pruning Impact:** Zero visits to 2025 or non-June 2026 partitions. 1.77 million rows were pruned at compile time.

---

### 2. R08 – June 2026 SLA Compliance

Query R08 filters for orders placed in June 2026. The query planner automatically isolates `orders_2026_06`:

```
=== R08 Plan on 20× Large Dataset (benchmarks/results/large/R08.txt) ===
Sort  (actual time=19.672..19.723 rows=2034.00 loops=1)
  Sort Key: (round((100.0 * count(*) FILTER ... / count(*)), 1)) DESC
  ->  Finalize HashAggregate  (actual time=19.134..19.457 rows=2034.00 loops=1)
        Group Key: orders.store_id
        ->  Gather  (actual time=18.618..18.840 rows=4050.00 loops=1)
              Workers Planned: 1
              Workers Launched: 1
              ->  Partial HashAggregate  (actual time=16.601..16.691 rows=2025.00 loops=2)
                    Group Key: orders.store_id
                    ->  Parallel Seq Scan on orders_2026_06 orders  (actual time=0.004..8.391 rows=71242.00 loops=2)
                          Filter: ((placed_at >= '2026-06-01 00:00:00+05:30') AND (placed_at < '2026-07-01 00:00:00+05:30') AND (status = 'DELIVERED'))
Planning Time: 1.327 ms
Execution Time: 19.809 ms
```
> **Pruning Impact:** Scans exclusively `orders_2026_06` (142,484 rows analyzed in parallel). All 17 other monthly partitions containing 2.85M rows were completely eliminated.

---

### 3. W05 – Data Retention Purge (< 1 January 2026)

On a non-partitioned table, deleting 1.2 million rows requires scanning the whole table and generating massive write-ahead log (WAL) and table bloat. With range partitioning:

```
=== W05 Plan on 20× Large Dataset (benchmarks/results/large/W05.txt) ===
Delete on inventory_movements  (actual time=775.250..775.255 rows=0.00 loops=1)
  Delete on inv_movements_2025_01 inventory_movements_1
  Delete on inv_movements_2025_02 inventory_movements_2
  ...
  Delete on inv_movements_2025_12 inventory_movements_12
  Delete on inv_movements_default inventory_movements_13
  Buffers: shared hit=1203309 read=10022 dirtied=10022
  ->  Append  (actual time=0.121..775.248 rows=1203297.00 loops=1)
        ->  Seq Scan on inv_movements_2025_01 ...
        ...
        ->  Seq Scan on inv_movements_2025_12 ...
Planning Time: 0.985 ms
Execution Time: 768.196 ms (under 1,000 ms target)
```
> **Pruning Impact:** All 2026 partitions (`inv_movements_2026_01` through `inv_movements_2026_07`) were pruned. In production, this can be further optimized to an instantaneous $O(1)$ DDL command: `ALTER TABLE inventory_movements DETACH PARTITION` followed by `DROP TABLE`.
