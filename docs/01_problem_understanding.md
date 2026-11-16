# Problem Understanding — Blinkit

## Project Overview
Blinkit is a 10-minute grocery delivery platform connecting customers with nearby dark stores. Its database supports product discovery, order placement, inventory management, rider operations and business analytics.

## P1. Store Assignment and Product Discovery
- Business need: Find the nearest active dark store and display available products through category browsing and search.
- Stakeholders: Customers and customer app team.
- Workload: Customer-facing, real-time.
- Queries: R01–R05.
- Assumptions: Only active stores are eligible; product availability depends on store inventory.

## P2. Order Placement and Tracking
- Business need: Provide quick checkout, stock validation and access to customers' latest order status.
- Stakeholders: Customers and checkout team.
- Workload: Customer-facing, real-time.
- Queries: R06, W01.
- Assumptions: Each order belongs to one customer and one dark store; rider assignment may happen later.

## P3. Dark Store Operations
- Business need: Help store staff view open orders, pack orders, dispatch riders and update inventory.
- Stakeholders: Dark-store staff and delivery operations.
- Workload: Operational, real-time.
- Queries: R07, R21, W02, W03.
- Assumptions: Riders belong to a home store; dispatch happens after packing.

## P4. Inventory Replenishment
- Business need: Identify low-stock products, dead stock and recent restocking activity.
- Stakeholders: Supply chain and inventory teams.
- Workload: Operational reporting.
- Queries: R09, R18, R24, W04.
- Assumptions: Reorder level is maintained for every store-product pair; inventory movements record stock changes.

## P5. Product Substitution Analysis
- Business need: Identify active products that have not been used as substitutes during a particular month.
- Stakeholders: Category management team.
- Workload: Reporting and analytics.
- Query: R13.
- Assumptions: Substitute products are recorded against order items; missing substitute values are stored as NULL.

## P6. Service Quality and Delivery Performance
- Business need: Monitor delivery SLA, fill rate, wastage and rider performance across stores.
- Stakeholders: Operations and city managers.
- Workload: Reporting and analytics.
- Queries: R08, R10, R11, R14, R15.
- Assumptions: Delivery time is calculated using pickup and delivery timestamps; completed-delivery metrics exclude cancelled orders.

## P7. Growth and Finance Analytics
- Business need: Analyse customer cohorts, fees, GMV, loyalty, recommendations and category sales.
- Stakeholders: Growth, marketing and finance teams.
- Workload: Reporting and analytics.
- Queries: R12, R16, R17, R19, R20, R22, R23, R25, W05.
- Assumptions: GMV is calculated using order totals; cohort analysis uses customer creation and order activity dates.

## Conclusion
The database must support fast transactional operations and reliable analytical reporting while maintaining data integrity as order volumes grow.
