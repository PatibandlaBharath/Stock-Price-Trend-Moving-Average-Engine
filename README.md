# Stock-Price-Trend-Moving-Average-Engine
# 📈 Stock Market Trends — SQL Analytics 

> A complete **PostgreSQL analytics project** modelling real-world stock market data across companies, sectors, and 365 days of trading history — featuring window functions, moving averages, trading signals, volatility analysis, and performance rankings.

---

## 📁 Project Structure

```
stock-market-trends/
├── schema/
│   ├── sectors.sql            # Sector reference table
│   ├── companies.sql          # Company master data
│   └── stock_prices.sql       # Daily OHLCV price records
├── seed/
│   └── seed_data.sql          # 2,920 synthetic price rows
├── analytics/
│   ├── basic_stats.sql        # AVG / MAX / MIN price queries
│   ├── moving_averages.sql    # 7-day and 30-day MAs
│   ├── yearly_performance.sql # EXTRACT(YEAR) aggregation
│   ├── volatility.sql         # STDDEV-based volatility ranking
│   ├── daily_diff.sql         # LAG-based daily price difference
│   ├── signals.sql            # Golden Cross & Death Cross (CTE)
│   ├── sector_analysis.sql    # Sector-wise average prices
│   ├── top_performers.sql     # Top & bottom closing prices
│   ├── gainers_losers.sql     # Top gainers and top losers
│   ├── rankings.sql           # RANK() window function
│   ├── max_volume_day.sql     # DISTINCT ON max volume per company
│   └── stable_stocks.sql      # Most stable (lowest volatility)
├── views/
│   └── stock_report.sql       # Reporting view
└── indexes/
    └── optimizations.sql      # idx_trade_date performance index
```

---

## 🗄️ Database Schema

### Entity Relationship

```
sectors (sector_id PK, sector_name)
    │
    └──< companies (company_id PK, company_name, stock_symbol UNIQUE,
    │               sector_id FK, market_cap)
              │
              └──< stock_prices (price_id PK, company_id FK, trade_date ← indexed,
                                  open_price, high_price, low_price, close_price, volume)
```

### Table: `sectors`

| Column | Type | Description |
|---|---|---|
| `sector_id` | SERIAL PK | Auto-increment primary key |
| `sector_name` | VARCHAR(100) NOT NULL | Sector label |

### Table: `companies`

| Column | Type | Description |
|---|---|---|
| `company_id` | SERIAL PK | Auto-increment primary key |
| `company_name` | VARCHAR(100) NOT NULL | Full company name |
| `stock_symbol` | VARCHAR(10) UNIQUE | Exchange ticker (e.g. AAPL) |
| `sector_id` | INT FK → sectors | References sectors table |
| `market_cap` | BIGINT | Market capitalisation in USD |

### Table: `stock_prices`

| Column | Type | Description |
|---|---|---|
| `price_id` | SERIAL PK | Auto-increment primary key |
| `company_id` | INT FK → companies | References companies table |
| `trade_date` | DATE | Trading session date (indexed) |
| `open_price` | NUMERIC(10,2) | Opening price |
| `high_price` | NUMERIC(10,2) | Intraday high |
| `low_price` | NUMERIC(10,2) | Intraday low |
| `close_price` | NUMERIC(10,2) | Closing price |
| `volume` | BIGINT | Shares traded |

---

## 🏢 Seed Data

**5 sectors · 8 companies · 2,920 price records** (365 days × 8 companies via `generate_series` + `CROSS JOIN`)

| Company | Symbol | Sector | Market Cap |
|---|---|---|---|
| Apple Inc | AAPL | Technology | $3.0 B |
| Microsoft | MSFT | Technology | $2.8 B |
| Tesla | TSLA | Automobile | $1.2 B |
| JP Morgan | JPM | Banking | $900 M |
| Infosys | INFY | Technology | $700 M |
| Reliance | RELI | Energy | $1.5 B |
| TCS | TCS | Technology | $1.3 B |
| HDFC Bank | HDFC | Banking | $1.0 B |

```sql
INSERT INTO stock_prices (company_id, trade_date, open_price, high_price, low_price, close_price, volume)
SELECT
    c.company_id,
    CURRENT_DATE - gs.day,
    ROUND((100 + random()*50)::numeric, 2),   -- open:  100-150
    ROUND((150 + random()*50)::numeric, 2),   -- high:  150-200
    ROUND((90  + random()*40)::numeric, 2),   -- low:    90-130
    ROUND((100 + random()*60)::numeric, 2),   -- close: 100-160
    (100000 + random()*500000)::BIGINT        -- volume
FROM companies c
CROSS JOIN generate_series(1, 365) AS gs(day);
```

---

## 🔍 Analytics Queries

### 1. Basic Statistics

```sql
-- Average closing price
SELECT company_id, ROUND(AVG(close_price), 2) AS avg_close_price
FROM stock_prices GROUP BY company_id;

-- Highest intraday price
SELECT company_id, MAX(high_price) AS highest_price
FROM stock_prices GROUP BY company_id;

-- Lowest intraday price
SELECT company_id, MIN(low_price) AS lowest_price
FROM stock_prices GROUP BY company_id;
```

---

### 2. Moving Averages (Window Functions)

```sql
-- 7-Day Moving Average
SELECT company_id, trade_date, close_price,
  ROUND(AVG(close_price) OVER (
    PARTITION BY company_id ORDER BY trade_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ), 2) AS moving_avg_7d
FROM stock_prices;

-- 30-Day Moving Average
SELECT company_id, trade_date, close_price,
  ROUND(AVG(close_price) OVER (
    PARTITION BY company_id ORDER BY trade_date
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ), 2) AS moving_avg_30d
FROM stock_prices;
```

---

### 3. Yearly Performance

```sql
SELECT company_id,
  EXTRACT(YEAR FROM trade_date) AS year,
  ROUND(AVG(close_price), 2) AS yearly_avg
FROM stock_prices
GROUP BY company_id, year;
```

---

### 4. Volatility Analysis

```sql
SELECT company_id,
  ROUND(STDDEV(close_price)::numeric, 2) AS volatility
FROM stock_prices
GROUP BY company_id
ORDER BY volatility DESC;
```

---

### 5. Daily Price Difference (LAG)

```sql
SELECT company_id, trade_date, close_price,
  LAG(close_price) OVER (PARTITION BY company_id ORDER BY trade_date) AS previous_close,
  close_price - LAG(close_price) OVER (PARTITION BY company_id ORDER BY trade_date) AS daily_difference
FROM stock_prices;
```

---

### 6. Trading Signals — Golden Cross & Death Cross

> **Golden Cross**: MA-50 > MA-200 → Bullish signal
> **Death Cross**: MA-50 < MA-200 → Bearish signal

```sql
WITH ma_data AS (
  SELECT company_id, trade_date,
    AVG(close_price) OVER (
      PARTITION BY company_id ORDER BY trade_date
      ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
    ) AS ma_50,
    AVG(close_price) OVER (
      PARTITION BY company_id ORDER BY trade_date
      ROWS BETWEEN 199 PRECEDING AND CURRENT ROW
    ) AS ma_200
  FROM stock_prices
)
SELECT * FROM ma_data WHERE ma_50 > ma_200;  -- Golden Cross (bullish)
SELECT * FROM ma_data WHERE ma_50 < ma_200;  -- Death Cross  (bearish)
```

---

### 7. Sector-Wise Analysis

```sql
SELECT s.sector_name,
  ROUND(AVG(sp.close_price), 2) AS avg_sector_price
FROM stock_prices sp
JOIN companies c ON sp.company_id = c.company_id
JOIN sectors s   ON c.sector_id   = s.sector_id
GROUP BY s.sector_name;
```

---

### 8. Top Performing Stocks

```sql
SELECT c.company_name,
  ROUND(AVG(sp.close_price), 2) AS average_price
FROM stock_prices sp
JOIN companies c ON sp.company_id = c.company_id
GROUP BY c.company_name
ORDER BY average_price DESC;
```

---

### 9. Highest Trading Volume

```sql
SELECT c.company_name, MAX(sp.volume) AS highest_volume
FROM stock_prices sp
JOIN companies c ON sp.company_id = c.company_id
GROUP BY c.company_name
ORDER BY highest_volume DESC;
```

---

### 10. Top 5 Highest & Lowest Closing Prices

```sql
-- Top 5 highest
SELECT c.company_name, sp.trade_date, sp.close_price
FROM stock_prices sp JOIN companies c ON sp.company_id = c.company_id
ORDER BY sp.close_price DESC LIMIT 5;

-- Bottom 5 lowest
SELECT c.company_name, sp.trade_date, sp.close_price
FROM stock_prices sp JOIN companies c ON sp.company_id = c.company_id
ORDER BY sp.close_price ASC LIMIT 5;
```

---

### 11. Top Gainers & Top Losers

```sql
-- Top 10 single-day gainers
SELECT company_id, trade_date,
  close_price - LAG(close_price) OVER (PARTITION BY company_id ORDER BY trade_date) AS gain
FROM stock_prices ORDER BY gain DESC LIMIT 10;

-- Top 10 single-day losers
SELECT company_id, trade_date,
  close_price - LAG(close_price) OVER (PARTITION BY company_id ORDER BY trade_date) AS loss
FROM stock_prices ORDER BY loss ASC LIMIT 10;
```

---

### 12. Stock Rankings (RANK Window Function)

```sql
SELECT c.company_name,
  ROUND(AVG(sp.close_price), 2) AS avg_price,
  RANK() OVER (ORDER BY AVG(sp.close_price) DESC) AS stock_rank
FROM stock_prices sp
JOIN companies c ON sp.company_id = c.company_id
GROUP BY c.company_name;
```

---

### 13. Company-wise Maximum Volume Day

```sql
SELECT DISTINCT ON (company_id)
  company_id, trade_date, volume
FROM stock_prices
ORDER BY company_id, volume DESC;
```

---

### 14. Most Stable Stocks (Lowest Volatility)

```sql
SELECT c.company_name,
  ROUND(STDDEV(sp.close_price)::numeric, 2) AS volatility
FROM stock_prices sp
JOIN companies c ON sp.company_id = c.company_id
GROUP BY c.company_name
ORDER BY volatility ASC;
```

---

## 👁️ Reporting View

```sql
CREATE VIEW stock_report AS
SELECT c.company_name, c.stock_symbol,
       sp.trade_date, sp.close_price, sp.volume
FROM stock_prices sp
JOIN companies c ON sp.company_id = c.company_id;

SELECT * FROM stock_report WHERE stock_symbol = 'AAPL' ORDER BY trade_date DESC;
```

---

## ⚡ Index Optimization

```sql
CREATE INDEX idx_trade_date ON stock_prices(trade_date);

-- Verify
SELECT * FROM pg_indexes WHERE tablename = 'stock_prices';
```

> An index on `trade_date` is critical for time-series queries and `OVER (ORDER BY trade_date)` window frames.

---

## 💡 SQL Concepts Demonstrated

| Concept | Used In |
|---|---|
| `SERIAL PRIMARY KEY` | All three tables |
| `FOREIGN KEY` references | companies → sectors, stock_prices → companies |
| `UNIQUE` constraint | stock_symbol |
| `generate_series` + `CROSS JOIN` | Bulk seed data generation |
| `AVG() OVER (ROWS BETWEEN …)` | 7-day, 30-day, 50-day, 200-day moving averages |
| `LAG()` window function | Daily difference, gainers/losers |
| `RANK() OVER (ORDER BY …)` | Stock price rankings |
| `STDDEV()` aggregate | Volatility, most stable stocks |
| `EXTRACT(YEAR FROM …)` | Yearly performance |
| `CTE (WITH … AS)` | Golden Cross / Death Cross detection |
| `DISTINCT ON` | Max volume day per company |
| Multi-table `JOIN` | Sector analysis, top stocks, volume |
| `LIMIT` | Top 5 prices, top 10 gainers/losers |
| `CREATE VIEW` | Reusable reporting layer |
| `CREATE INDEX` | Query performance on trade_date |
| `pg_indexes` system catalog | Index introspection |

---

## 🛠️ Setup & Usage

### Prerequisites
- PostgreSQL 13+
- `psql` CLI or GUI client (DBeaver, pgAdmin, TablePlus)

### Run the Project

```bash
# 1. Create and connect to database
psql -U your_username
CREATE DATABASE stock_market;
\c stock_market

# 2. Create schema
\i schema/create_tables.sql

# 3. Seed data
\i seed/seed_data.sql

# 4. Run analytics
\i analytics/moving_averages.sql
\i analytics/signals.sql
\i analytics/rankings.sql

# 5. Create view and index
\i views/stock_report.sql
\i indexes/optimizations.sql
```

---

## 🐛 Known Issue

One syntax error in the original `basic_stats.sql`:

```sql
-- WRONG (stray token 'com' and missing comma)
SELECT company_id, com
MAX(high_price) AS highest_price
FROM stock_prices GROUP BY company_id;

-- CORRECT
SELECT company_id,
MAX(high_price) AS highest_price
FROM stock_prices GROUP BY company_id;
```

---


> Built with **PostgreSQL** · Window Functions · CTEs · Time-Series Analytics · Trading Signal Detection
