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
