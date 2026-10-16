"""
01_shop_pos.py  (Python 3)
Shop point-of-sale and inventory system for a small retail shop / kiosk.
Tracks products, stock, sales and daily profit. Currency: UGX.
Run:  python3 01_shop_pos.py
"""
import sqlite3
from datetime import date

DB = "shop.db"


def connect():
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    with connect() as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            cost REAL NOT NULL,
            price REAL NOT NULL,
            stock INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS sales(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            qty INTEGER NOT NULL,
            total REAL NOT NULL,
            profit REAL NOT NULL,
            sold_on TEXT NOT NULL,
            FOREIGN KEY(product_id) REFERENCES products(id)
        );
        """)


def money(x):
    return f"UGX {x:,.0f}"


def ask_number(prompt, cast=float):
    while True:
        try:
            value = cast(input(prompt).strip())
            if value < 0:
                print("Value cannot be negative.")
                continue
            return value
        except ValueError:
            print("Please enter a valid number.")


def add_product():
    name = input("Product name: ").strip().title()
    if not name:
        print("Name is required.")
        return
    cost = ask_number("Buying cost per unit: ")
    price = ask_number("Selling price per unit: ")
    stock = ask_number("Opening stock: ", int)
    if price < cost:
        print("Warning: selling price is below cost, you will make a loss!")
    try:
        with connect() as c:
            c.execute("INSERT INTO products(name,cost,price,stock) VALUES(?,?,?,?)",
                      (name, cost, price, stock))
        print("Product added.")
    except sqlite3.IntegrityError:
        print("That product already exists. Use restock instead.")


def list_products():
    with connect() as c:
        rows = c.execute("SELECT * FROM products ORDER BY name").fetchall()
    if not rows:
        print("No products yet.")
        return
    print(f"\n{'ID':<4}{'Name':<20}{'Cost':>12}{'Price':>12}{'Stock':>8}")
    for r in rows:
        print(f"{r['id']:<4}{r['name']:<20}{r['cost']:>12,.0f}{r['price']:>12,.0f}{r['stock']:>8}")


def restock():
    list_products()
    pid = ask_number("Product ID to restock: ", int)
    qty = ask_number("Quantity added: ", int)
    with connect() as c:
        cur = c.execute("UPDATE products SET stock = stock + ? WHERE id = ?", (qty, pid))
    print("Stock updated." if cur.rowcount else "Product not found.")


def sell():
    list_products()
    pid = ask_number("Product ID sold: ", int)
    qty = ask_number("Quantity sold: ", int)
    with connect() as c:
        p = c.execute("SELECT * FROM products WHERE id = ?", (pid,)).fetchone()
        if not p:
            print("Product not found.")
            return
        if p["stock"] < qty:
            print(f"Only {p['stock']} left in stock.")
            return
        total = p["price"] * qty
        profit = (p["price"] - p["cost"]) * qty
        c.execute("UPDATE products SET stock = stock - ? WHERE id = ?", (qty, pid))
        c.execute("INSERT INTO sales(product_id,qty,total,profit,sold_on) VALUES(?,?,?,?,?)",
                  (pid, qty, total, profit, date.today().isoformat()))
    print(f"Sale recorded: {money(total)} (profit {money(profit)})")


def low_stock(threshold=5):
    with connect() as c:
        rows = c.execute("SELECT name, stock FROM products WHERE stock <= ?", (threshold,)).fetchall()
    print("\nLow stock items:" if rows else "\nAll items are well stocked.")
    for r in rows:
        print(f" - {r['name']}: {r['stock']} left")


def daily_report():
    day = input("Date (YYYY-MM-DD, blank = today): ").strip() or date.today().isoformat()
    with connect() as c:
        rows = c.execute("""SELECT p.name, SUM(s.qty) qty, SUM(s.total) total, SUM(s.profit) profit
                            FROM sales s JOIN products p ON p.id = s.product_id
                            WHERE s.sold_on = ? GROUP BY p.name ORDER BY total DESC""", (day,)).fetchall()
    if not rows:
        print("No sales on that day.")
        return
    print(f"\nSales report for {day}")
    for r in rows:
        print(f" {r['name']:<20} x{r['qty']:<4} {money(r['total']):>16}  profit {money(r['profit'])}")
    print(f"TOTAL SALES : {money(sum(r['total'] for r in rows))}")
    print(f"TOTAL PROFIT: {money(sum(r['profit'] for r in rows))}")


def menu():
    init_db()
    actions = {"1": add_product, "2": list_products, "3": restock,
               "4": sell, "5": low_stock, "6": daily_report}
    while True:
        print("\n=== SHOP POS ===\n1 Add product\n2 List products\n3 Restock\n"
              "4 Sell\n5 Low stock alert\n6 Daily report\n0 Exit")
        choice = input("Choose: ").strip()
        if choice == "0":
            print("Goodbye!")
            break
        action = actions.get(choice)
        action() if action else print("Invalid choice.")


if __name__ == "__main__":
    menu()