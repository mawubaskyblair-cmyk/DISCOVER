-- 09_business_bookkeeping.sql  (SQL - SQLite compatible)
-- Complete bookkeeping database for any small business: income, expenses,
-- customers who owe you (debtors), suppliers you owe, and monthly profit.
-- Run: sqlite3 books.db < 09_business_bookkeeping.sql

PRAGMA foreign_keys = ON;

-- ---------- TABLES ----------
CREATE TABLE IF NOT EXISTS categories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL UNIQUE,
    kind        TEXT NOT NULL CHECK (kind IN ('INCOME', 'EXPENSE'))
);

CREATE TABLE IF NOT EXISTS customers (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    name    TEXT NOT NULL,
    phone   TEXT,
    place   TEXT
);

CREATE TABLE IF NOT EXISTS suppliers (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    name    TEXT NOT NULL,
    phone   TEXT
);

CREATE TABLE IF NOT EXISTS transactions (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    trans_date   TEXT NOT NULL DEFAULT (date('now')),
    category_id  INTEGER NOT NULL REFERENCES categories(id),
    amount       REAL NOT NULL CHECK (amount > 0),
    method       TEXT NOT NULL DEFAULT 'CASH' CHECK (method IN ('CASH','MOBILE_MONEY','BANK')),
    note         TEXT
);

CREATE TABLE IF NOT EXISTS credit_sales (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id  INTEGER NOT NULL REFERENCES customers(id),
    sale_date    TEXT NOT NULL DEFAULT (date('now')),
    amount       REAL NOT NULL CHECK (amount > 0),
    due_date     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS credit_payments (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    credit_sale_id  INTEGER NOT NULL REFERENCES credit_sales(id),
    paid_on         TEXT NOT NULL DEFAULT (date('now')),
    amount          REAL NOT NULL CHECK (amount > 0)
);

CREATE TABLE IF NOT EXISTS supplier_bills (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    supplier_id  INTEGER NOT NULL REFERENCES suppliers(id),
    bill_date    TEXT NOT NULL DEFAULT (date('now')),
    amount       REAL NOT NULL CHECK (amount > 0),
    paid         INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_trans_date ON transactions(trans_date);
CREATE INDEX IF NOT EXISTS idx_credit_customer ON credit_sales(customer_id);

-- ---------- STARTER DATA ----------
INSERT OR IGNORE INTO categories (name, kind) VALUES
    ('Sales', 'INCOME'), ('Services', 'INCOME'), ('Other income', 'INCOME'),
    ('Stock purchase', 'EXPENSE'), ('Rent', 'EXPENSE'), ('Transport', 'EXPENSE'),
    ('Salaries', 'EXPENSE'), ('Electricity & water', 'EXPENSE'),
    ('Airtime & data', 'EXPENSE'), ('Taxes & licences', 'EXPENSE');

INSERT INTO customers (name, phone, place) VALUES
    ('Namukasa Sarah', '0700000001', 'Mukono'),
    ('Okello James',   '0700000002', 'Seeta');

INSERT INTO suppliers (name, phone) VALUES ('Kampala Wholesalers', '0700000009');

INSERT INTO transactions (trans_date, category_id, amount, method, note) VALUES
    (date('now','start of month'), 1, 850000, 'CASH', 'Week 1 sales'),
    (date('now','start of month','+7 days'), 1, 920000, 'MOBILE_MONEY', 'Week 2 sales'),
    (date('now','start of month','+3 days'), 4, 600000, 'BANK', 'Restock'),
    (date('now','start of month','+1 days'), 5, 250000, 'CASH', 'Shop rent'),
    (date('now','start of month','+9 days'), 6, 45000, 'CASH', 'Boda to market'),
    (date('now','start of month','+10 days'), 2, 120000, 'MOBILE_MONEY', 'Repair service');

INSERT INTO credit_sales (customer_id, sale_date, amount, due_date) VALUES
    (1, date('now','-40 days'), 300000, date('now','-10 days')),
    (2, date('now','-5 days'),  150000, date('now','+25 days'));
INSERT INTO credit_payments (credit_sale_id, paid_on, amount) VALUES (1, date('now','-20 days'), 100000);

-- ---------- REPORTS (VIEWS) ----------
DROP VIEW IF EXISTS v_monthly_profit;
CREATE VIEW v_monthly_profit AS
SELECT substr(t.trans_date, 1, 7) AS month,
       SUM(CASE WHEN c.kind = 'INCOME'  THEN t.amount ELSE 0 END) AS income,
       SUM(CASE WHEN c.kind = 'EXPENSE' THEN t.amount ELSE 0 END) AS expenses,
       SUM(CASE WHEN c.kind = 'INCOME' THEN t.amount ELSE -t.amount END) AS profit
FROM transactions t JOIN categories c ON c.id = t.category_id
GROUP BY month
ORDER BY month DESC;

DROP VIEW IF EXISTS v_expense_breakdown;
CREATE VIEW v_expense_breakdown AS
SELECT substr(t.trans_date, 1, 7) AS month, c.name AS category,
       SUM(t.amount) AS total,
       ROUND(100.0 * SUM(t.amount) /
             (SELECT SUM(t2.amount) FROM transactions t2
                JOIN categories c2 ON c2.id = t2.category_id
              WHERE c2.kind = 'EXPENSE' AND substr(t2.trans_date,1,7) = substr(t.trans_date,1,7)), 1) AS pct
FROM transactions t JOIN categories c ON c.id = t.category_id
WHERE c.kind = 'EXPENSE'
GROUP BY month, c.name
ORDER BY month DESC, total DESC;

DROP VIEW IF EXISTS v_debtors;
CREATE VIEW v_debtors AS
SELECT cu.name, cu.phone, cs.id AS sale_id, cs.amount AS sold,
       IFNULL(SUM(cp.amount), 0) AS paid,
       cs.amount - IFNULL(SUM(cp.amount), 0) AS balance,
       cs.due_date,
       CASE WHEN cs.due_date < date('now') THEN 'OVERDUE' ELSE 'OK' END AS status
FROM credit_sales cs
JOIN customers cu ON cu.id = cs.customer_id
LEFT JOIN credit_payments cp ON cp.credit_sale_id = cs.id
GROUP BY cs.id
HAVING balance > 0
ORDER BY cs.due_date;

DROP VIEW IF EXISTS v_cash_position;
CREATE VIEW v_cash_position AS
SELECT t.method,
       SUM(CASE WHEN c.kind = 'INCOME' THEN t.amount ELSE -t.amount END) AS balance
FROM transactions t JOIN categories c ON c.id = t.category_id
GROUP BY t.method;

-- ---------- RUN THE REPORTS ----------
.headers on
.mode column
SELECT '--- MONTHLY PROFIT ---' AS report;
SELECT * FROM v_monthly_profit;
SELECT '--- EXPENSE BREAKDOWN ---' AS report;
SELECT * FROM v_expense_breakdown;
SELECT '--- CUSTOMERS WHO OWE YOU ---' AS report;
SELECT * FROM v_debtors;
SELECT '--- MONEY BY CHANNEL ---' AS report;
SELECT * FROM v_cash_position;
SELECT '--- TOTAL OWED TO YOU ---' AS report;
SELECT IFNULL(SUM(balance), 0) AS total_debtors FROM v_debtors;