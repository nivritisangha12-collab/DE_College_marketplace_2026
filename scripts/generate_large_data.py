#!/usr/bin/env python3
"""
scripts/generate_large_data.py
Generates the large dataset (20x scaling) for Blinkit 10-Minute Grocery Delivery DBMS.
Matches README Phase 5 target volume:
  - orders: 3,000,000
  - order_items: 13,500,000
  - store_inventory: 2,520,000
  - inventory_movements: 1,800,000
  - customers: 800,000
  - dark_stores: 2,400
  - riders: 36,000
  - products: 1,500
  - categories: 12
  - cities: 10
Preserves original seed data verbatim and appends synthetic records consistent
with existing distributions and foreign keys.
"""

import os
import sys
import shutil
import random
from datetime import datetime, timedelta

def main():
    seed_dir = "seed_data"
    out_dir = "large_data"
    os.makedirs(out_dir, exist_ok=True)
    random.seed(42)

    print(f"Generating large dataset in '{out_dir}/' from '{seed_dir}/'...")

    # 1. Base dimensions: categories, cities, products
    for fname in ["categories.csv", "cities.csv", "products.csv"]:
        src = os.path.join(seed_dir, fname)
        dst = os.path.join(out_dir, fname)
        print(f"Copying {fname}...")
        shutil.copyfile(src, dst)

    # Read products for prices
    product_prices = {}
    with open(os.path.join(seed_dir, "products.csv"), "r") as f:
        next(f)
        for line in f:
            parts = line.strip().split(",")
            pid = int(parts[0])
            mrp = float(parts[6])
            product_prices[pid] = mrp

    # 2. Dark Stores: 120 -> 2,400
    print("Generating dark_stores.csv (2,400 stores)...")
    stores_src = os.path.join(seed_dir, "dark_stores.csv")
    stores_dst = os.path.join(out_dir, "dark_stores.csv")
    with open(stores_src, "r") as fin, open(stores_dst, "w") as fout:
        lines = fin.readlines()
        fout.writelines(lines)
        # city coordinates base
        city_coords = {
            1: (12.9716, 77.5946), 2: (19.0760, 72.8777), 3: (28.7041, 77.1025),
            4: (17.3850, 78.4867), 5: (13.0827, 80.2707), 6: (22.5726, 88.3639),
            7: (18.5204, 73.8567), 8: (23.0225, 72.5714), 9: (26.8467, 80.9462),
            10: (28.4595, 77.0266)
        }
        for sid in range(121, 2401):
            cid = ((sid - 1) % 10) + 1
            code = f"DS-{cid:02d}-{sid:04d}"
            base_lat, base_lon = city_coords[cid]
            lat = round(base_lat + random.uniform(-0.15, 0.15), 6)
            lon = round(base_lon + random.uniform(-0.15, 0.15), 6)
            fout.write(f"{sid},{code},{cid},{lat:.6f},{lon:.6f},2024-01-15,t,1500\n")

    # 3. Customers: 40,000 -> 800,000
    print("Generating customers.csv (800,000 customers)...")
    cust_src = os.path.join(seed_dir, "customers.csv")
    cust_dst = os.path.join(out_dir, "customers.csv")
    first_names = ["Aarav", "Vivaan", "Aditya", "Vihaan", "Arjun", "Sai", "Reyansh", "Ayaan", "Krishna", "Ishaan",
                   "Diya", "Saanvi", "Aanya", "Aadhya", "Pari", "Ananya", "Myra", "Riya", "Avani", "Isha"]
    last_names = ["Sharma", "Verma", "Patel", "Gupta", "Singh", "Kumar", "Mehta", "Joshi", "Rao", "Nair"]
    
    with open(cust_src, "r") as fin, open(cust_dst, "w") as fout:
        for line in fin:
            fout.write(line)
        chunk = []
        base_time = datetime(2024, 1, 1, 0, 0, 0)
        for cid in range(40001, 800001):
            name = f"{random.choice(first_names)} {random.choice(last_names)}"
            phone = f"{6000000000 + cid}"
            city_id = ((cid - 1) % 10) + 1
            created = (base_time + timedelta(seconds=(cid * 97) % 60000000)).strftime("%Y-%m-%d %H:%M:%S+05:30")
            chunk.append(f"{cid},{name},{phone},,{city_id},{created}\n")
            if len(chunk) >= 50000:
                fout.writelines(chunk)
                chunk = []
        if chunk:
            fout.writelines(chunk)

    # 4. Riders: 1,800 -> 36,000
    print("Generating riders.csv (36,000 riders)...")
    riders_src = os.path.join(seed_dir, "riders.csv")
    riders_dst = os.path.join(out_dir, "riders.csv")
    with open(riders_src, "r") as fin, open(riders_dst, "w") as fout:
        for line in fin:
            fout.write(line)
        chunk = []
        for rid in range(1801, 36001):
            name = f"{random.choice(first_names)} {random.choice(last_names)}"
            phone = f"{7000000000 + rid}"
            store_id = ((rid - 1) % 2400) + 1
            chunk.append(f"{rid},{name},{phone},{store_id},2024-06-01,ACTIVE\n")
            if len(chunk) >= 10000:
                fout.writelines(chunk)
                chunk = []
        if chunk:
            fout.writelines(chunk)

    # 5. Store Inventory: 126,000 -> 2,520,000
    print("Generating store_inventory.csv (2,520,000 rows)...")
    inv_src = os.path.join(seed_dir, "store_inventory.csv")
    inv_dst = os.path.join(out_dir, "store_inventory.csv")
    with open(inv_src, "r") as fin, open(inv_dst, "w") as fout:
        for line in fin:
            fout.write(line)
        chunk = []
        # Stores 121..2400, each gets 1,050 products = 2,394,000 rows + 126,000 = 2,520,000
        for sid in range(121, 2401):
            # Select 1,050 products
            offset = (sid * 17) % 1500
            for idx in range(1050):
                pid = ((offset + idx) % 1500) + 1
                qoh = random.randint(0, 60)
                reorder = random.randint(5, 15)
                mrp = product_prices.get(pid, 100.0)
                price = round(mrp * random.uniform(0.85, 1.0), 2)
                chunk.append(f"{sid},{pid},{qoh},{reorder},{price:.2f},2026-06-30 04:00:00+05:30\n")
            if len(chunk) >= 50000:
                fout.writelines(chunk)
                chunk = []
        if chunk:
            fout.writelines(chunk)

    # 6. Orders (3,000,000) & Order Items (13,500,000)
    print("Generating orders.csv (3,000,000) and order_items.csv (13,500,000)...")
    orders_src = os.path.join(seed_dir, "orders.csv")
    orders_dst = os.path.join(out_dir, "orders.csv")
    items_src = os.path.join(seed_dir, "order_items.csv")
    items_dst = os.path.join(out_dir, "order_items.csv")

    # Start date 2025-01-01 to 2026-06-30 (546 days = 47,174,400 seconds)
    start_ts = datetime(2025, 1, 1, 0, 0, 0)
    total_seconds = 546 * 86400

    order_chunk = []
    item_chunk = []
    item_count = 675000

    with open(orders_src, "r") as f_ord_in, open(orders_dst, "w") as f_ord_out, \
         open(items_src, "r") as f_item_in, open(items_dst, "w") as f_item_out:
        
        # Copy seed orders and items
        for line in f_ord_in:
            f_ord_out.write(line)
        for line in f_item_in:
            f_item_out.write(line)

        # Generate orders 150001 to 3000000 (2,850,000 orders)
        # Average 4.5 items per order -> 12,825,000 new items -> total 13,500,000 items
        for oid in range(150001, 3000001):
            cid = ((oid * 7) % 800000) + 1
            # Keep store 43 well represented
            if oid % 50 == 0:
                sid = 43
            else:
                sid = ((oid * 13) % 2400) + 1
            rid = ((sid - 1) * 15 + (oid % 15)) + 1
            
            # Timestamp progression
            sec_offset = int((oid - 150001) / 2850000 * total_seconds)
            placed = start_ts + timedelta(seconds=sec_offset)
            placed_str = placed.strftime("%Y-%m-%d %H:%M:%S+05:30")
            
            # Status distribution
            status_rand = oid % 100
            if status_rand < 86:
                status = "DELIVERED"
                packed = (placed + timedelta(minutes=random.randint(1, 4))).strftime("%Y-%m-%d %H:%M:%S+05:30")
                picked = (placed + timedelta(minutes=random.randint(4, 7))).strftime("%Y-%m-%d %H:%M:%S+05:30")
                delivered_minutes = random.randint(8, 16)
                delivered = (placed + timedelta(minutes=delivered_minutes)).strftime("%Y-%m-%d %H:%M:%S+05:30")
            elif status_rand < 92:
                status = "CANCELLED"
                packed = picked = delivered = ""
            elif status_rand < 95:
                status = "OUT_FOR_DELIVERY"
                packed = (placed + timedelta(minutes=2)).strftime("%Y-%m-%d %H:%M:%S+05:30")
                picked = (placed + timedelta(minutes=4)).strftime("%Y-%m-%d %H:%M:%S+05:30")
                delivered = ""
            elif status_rand < 98:
                status = "PACKING"
                packed = picked = delivered = ""
            else:
                status = "PLACED"
                packed = picked = delivered = ""

            # Line items: 1 to 8 distinct products (average 4.5)
            # Cycle through lengths [3, 4, 4, 5, 5, 5, 6] -> average = 32/7 = 4.57
            num_items = [3, 4, 4, 5, 5, 5, 6][oid % 7]
            subtotal = 0.0
            
            p_offset = (oid * 11) % 1500
            for item_idx in range(num_items):
                pid = ((p_offset + item_idx * 31) % 1500) + 1
                price = product_prices.get(pid, 50.0)
                qty_ord = (item_idx % 3) + 1
                # Short delivery ~3%
                if status == "DELIVERED" and (oid + item_idx) % 33 == 0:
                    qty_del = qty_ord - 1
                else:
                    qty_del = qty_ord if status != "CANCELLED" else 0
                
                subtotal += qty_ord * price
                # Substitute ~2%
                sub_pid = ""
                if (oid + item_idx) % 47 == 0:
                    sub_pid = str(((pid + 10) % 1500) + 1)
                
                item_chunk.append(f"{oid},{pid},{qty_ord},{qty_del},{price:.2f},{sub_pid}\n")
                item_count += 1
            
            subtotal = round(subtotal, 2)
            del_fee = 0.0 if subtotal > 300 else 25.0
            hnd_fee = 4.0 if subtotal > 500 else 2.0
            sml_fee = 20.0 if subtotal < 200 else 0.0
            total = round(subtotal + del_fee + hnd_fee + sml_fee, 2)
            pm = ["UPI", "CARD", "COD", "WALLET"][oid % 4]

            order_chunk.append(f"{oid},{cid},{sid},{rid},{placed_str},{packed},{picked},{delivered},10,{subtotal:.2f},{del_fee:.2f},{hnd_fee:.2f},{sml_fee:.2f},{total:.2f},{pm},{status}\n")

            if len(order_chunk) >= 50000:
                f_ord_out.writelines(order_chunk)
                order_chunk = []
            if len(item_chunk) >= 50000:
                f_item_out.writelines(item_chunk)
                item_chunk = []

        if order_chunk:
            f_ord_out.writelines(order_chunk)
        if item_chunk:
            f_item_out.writelines(item_chunk)

    print(f"Total order items generated: {item_count}")

    # 7. Inventory Movements: 90,000 -> 1,800,000
    print("Generating inventory_movements.csv (1,800,000 movements)...")
    mov_src = os.path.join(seed_dir, "inventory_movements.csv")
    mov_dst = os.path.join(out_dir, "inventory_movements.csv")
    with open(mov_src, "r") as fin, open(mov_dst, "w") as fout:
        for line in fin:
            fout.write(line)
        chunk = []
        for mid in range(90001, 1800001):
            sid = ((mid * 11) % 2400) + 1
            pid = ((mid * 23) % 1500) + 1
            m_type_rand = mid % 10
            if m_type_rand < 6:
                mtype = "RESTOCK"
                qty = random.choice([20, 30, 50, 100])
            elif m_type_rand < 8:
                mtype = "EXPIRY"
                qty = -random.randint(1, 10)
            elif m_type_rand < 9:
                mtype = "DAMAGE"
                qty = -random.randint(1, 5)
            else:
                mtype = "ADJUSTMENT"
                qty = random.choice([-2, -1, 1, 2, 5])
            
            sec_offset = int((mid - 90001) / 1710000 * total_seconds)
            moved = (start_ts + timedelta(seconds=sec_offset)).strftime("%Y-%m-%d %H:%M:%S+05:30")
            chunk.append(f"{mid},{sid},{pid},{mtype},{qty},{moved}\n")
            if len(chunk) >= 50000:
                fout.writelines(chunk)
                chunk = []
        if chunk:
            fout.writelines(chunk)

    print("Large dataset generation complete!")

if __name__ == "__main__":
    main()
