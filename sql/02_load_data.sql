SET search_path TO blinkit;

BEGIN;

\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true);
\copy categories FROM 'seed_data/categories.csv' WITH (FORMAT csv, HEADER true);
\copy customers FROM 'seed_data/customers.csv' WITH (FORMAT csv, HEADER true);
\copy dark_stores FROM 'seed_data/dark_stores.csv' WITH (FORMAT csv, HEADER true);
\copy products FROM 'seed_data/products.csv' WITH (FORMAT csv, HEADER true);
\copy riders FROM 'seed_data/riders.csv' WITH (FORMAT csv, HEADER true);
\copy store_inventory FROM 'seed_data/store_inventory.csv' WITH (FORMAT csv, HEADER true);
\copy orders FROM 'seed_data/orders.csv' WITH (FORMAT csv, HEADER true);
\copy order_items FROM 'seed_data/order_items.csv' WITH (FORMAT csv, HEADER true);
\copy inventory_movements FROM 'seed_data/inventory_movements.csv' WITH (FORMAT csv, HEADER true);

ANALYZE;

COMMIT;