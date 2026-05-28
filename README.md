# Stock-Price-Trend-Moving-Average-Engine
# 📈 Stock Market Trends — SQL Analytics Project

A complete **PostgreSQL analytics project** that models real-world stock market data across companies, sectors, and trading history — with advanced SQL techniques including window functions, moving averages, volatility analysis, and signal detection.

---

## 📁 Project Structure

```
stock-market-trends/
├── schema/
│   ├── sectors.sql          # Sector reference table
│   ├── companies.sql        # Company master data
│   └── stock_prices.sql     # Daily OHLCV price records
├── seed/
│   └── seed_data.sql        # 365 days × 8 companies synthetic data
├── analytics/
│   ├── basic_stats.sql      # Avg / High / Low price queries
│   ├── moving_averages.sql  # 7-day and 30-day MAs
│   ├── volatility.sql       # STDDEV-based volatility ranking
│   ├── daily_diff.sql       # LAG-based daily price difference
│   ├── signals.sql          # Golden Cross & Death Cross detection
│   └── sector_analysis.sql  # Sector-wise aggregations
├── views/
│   └── stock_report.sql     # Reporting view
└── indexes/
    └── optimizations.sql    # Performance index on trade_date
```

---

## 🗄️ Database Schema

### Entity Relationship Overview

```
sectors (sector_id PK, sector_name)
    │
    └──< companies (company_id PK, company_name, stock_symbol, sector_id FK, market_cap)
              │
              └──< stock_prices (price_id PK, company_id FK, trade_date,
                                  open_price, high_price, low_price, close_price, volume)
```

### Tables

#### `sectors`
| Column | Type | Description |
|---|---|---|
| `sector_id` | SERIAL PK | Auto-increment primary key |
| `sector_name` | VARCHAR(100) | Sector label (e.g. Technology, Banking) |

#### `companies`
| Column | Type | Description |
|---|---|---|
| `company_id` | SERIAL PK | Auto-increment primary key |
| `company_name` | VARCHAR(100) | Full company name |
| `stock_symbol` | VARCHAR(10) UNIQUE | Ticker (e.g. AAPL, TSLA) |
| `sector_id` | INT FK | References `sectors` |
| `market_cap` | BIGINT | Market capitalisation in USD |

#### `stock_prices`
| Column | Type | Description |
|---|---|---|
| `price_id` | SERIAL PK | Auto-increment primary key |
| `company_id` | INT FK | References `companies` |
| `trade_date` | DATE | Date of trading session |
| `open_price` | NUMERIC(10,2) | Opening price |
| `high_price` | NUMERIC(10,2) | Intraday high |
| `low_price` | NUMERIC(10,2) | Intraday low |
| `close_price` | NUMERIC(10,2) | Closing price |
| `volume` | BIGINT | Number of shares traded |

---

## 🏢 Seed Data

**5 Sectors** and **8 Companies** are seeded, with **365 days × 8 companies = 2,920 price records** generated using `generate_series` and `random()`.

| Company | Symbol | Sector | Market Cap |
|---|---|---|---|
| Apple Inc | AAPL | Technology | $3.0B |
| Microsoft | MSFT | Technology | $2.8B |
| Tesla | TSLA | Automobile | $1.2B |
| JP Morgan | JPM | Banking | $900M |
| Infosys | INFY | Technology | $700M |
| Reliance | RELI | Energy | $1.5B |
| TCS | TCS | Technology | $1.3B |
| HDFC Bank | HDFC | Banking | $1.0B |

---

## 🔍 Analytics Queries

### 1. Basic Statistics

```sql
-- Average closing price per company
SELECT company_id, ROUND(AVG(close_price), 2) AS avg_close_price
FROM stock_prices
GROUP BY company_id;

-- Highest intraday price
SELECT company_id, MAX(high_price) AS highest_price
FROM stock_prices
GROUP BY company_id;

-- Lowest intraday price
SELECT company_id, MIN(low_price) AS lowest_price
FROM stock_prices
GROUP BY company_id;
```

---

### 2. Moving Averages (Window Functions)

```sql
-- 7-Day Moving Average
SELECT company_id, trade_date, close_price,
  ROUND(AVG(close_price) OVER (
    PARTITION BY company_id
    ORDER BY trade_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ), 2) AS moving_avg_7d
FROM stock_prices;

-- 30-Day Moving Average
SELECT company_id, trade_date, close_price,
  ROUND(AVG(close_price) OVER (
    PARTITION BY company_id
    ORDER BY trade_date
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ), 2) AS moving_avg_30d
FROM stock_prices;
```

---

### 3. Volatility Analysis

```sql
-- Rank companies by price volatility (higher STDDEV = more volatile)
SELECT company_id,
  ROUND(STDDEV(close_price)::numeric, 2) AS volatility
FROM stock_prices
GROUP BY company_id
ORDER BY volatility DESC;
```

---

### 4. Daily Price Difference (LAG)

```sql
-- Compare today's close to yesterday's close
SELECT company_id, trade_date, close_price,
  LAG(close_price) OVER (PARTITION BY company_id ORDER BY trade_date) AS previous_close,
  close_price - LAG(close_price) OVER (PARTITION BY company_id ORDER BY trade_date) AS daily_difference
FROM stock_prices;
```

---

### 5. Trading Signals — Golden Cross & Death Cross

> A **Golden Cross** occurs when the 50-day MA crosses above the 200-day MA — a bullish signal.  
> A **Death Cross** occurs when the 50-day MA drops below the 200-day MA — a bearish signal.

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
-- Golden Cross: bullish
SELECT * FROM ma_data WHERE ma_50 > ma_200;

-- Death Cross: bearish
SELECT * FROM ma_data WHERE ma_50 < ma_200;
```

---

### 6. Sector-Wise Analysis

```sql
SELECT s.sector_name,
  ROUND(AVG(sp.close_price), 2) AS avg_sector_price
FROM stock_prices sp
JOIN companies c ON sp.company_id = c.company_id
JOIN sectors s ON c.sector_id = s.sector_id
GROUP BY s.sector_name;
```

---

### 7. Top Performing Stocks

```sql
SELECT c.company_name,
  ROUND(AVG(sp.close_price), 2) AS average_price
FROM stock_prices sp
JOIN companies c ON sp.company_id = c.company_id
GROUP BY c.company_name
ORDER BY average_price DESC;
```

---

### 8. Highest Trading Volume

```sql
SELECT c.company_name, MAX(sp.volume) AS highest_volume
FROM stock_prices sp
JOIN companies c ON sp.company_id = c.company_id
GROUP BY c.company_name
ORDER BY highest_volume DESC;
```

---

## 👁️ Reporting View

```sql
CREATE VIEW stock_report AS
SELECT c.company_name, c.stock_symbol,
  sp.trade_date, sp.close_price, sp.volume
FROM stock_prices sp
JOIN companies c ON sp.company_id = c.company_id;

SELECT * FROM stock_report;
```

Use this view in dashboards, reports, or BI tools without re-writing joins.

---

## ⚡ Index Optimization

```sql
-- Speed up date-range queries significantly
CREATE INDEX idx_trade_date ON stock_prices(trade_date);

-- Verify index was created
SELECT * FROM pg_indexes WHERE tablename = 'stock_prices';
```

The index on `trade_date` is critical for time-series queries, moving average windows, and any `WHERE trade_date BETWEEN ...` filters.

---

## 🛠️ Setup & Usage

### Prerequisites
- PostgreSQL 13+
- `psql` CLI or any SQL client (DBeaver, pgAdmin, TablePlus)

### Run the Project

```bash
# 1. Connect to your PostgreSQL instance
psql -U your_username -d your_database

# 2. Create schema
\i schema/sectors.sql
\i schema/companies.sql
\i schema/stock_prices.sql

# 3. Seed data
\i seed/seed_data.sql

# 4. Run analytics
\i analytics/basic_stats.sql
\i analytics/moving_averages.sql
\i analytics/signals.sql

# 5. Create view and index
\i views/stock_report.sql
\i indexes/optimizations.sql
```

---

## 💡 SQL Concepts Demonstrated

| Concept | Used In |
|---|---|
| `SERIAL PRIMARY KEY` | All three tables |
| `FOREIGN KEY` references | companies → sectors, stock_prices → companies |
| `generate_series` + `CROSS JOIN` | Bulk seed data generation |
| `AVG() OVER (ROWS BETWEEN ...)` | Moving averages (7-day, 30-day, 50-day, 200-day) |
| `LAG()` window function | Daily price difference |
| `STDDEV()` aggregate | Volatility analysis |
| `CTE (WITH ...)` | Golden Cross / Death Cross |
| Multi-table `JOIN` | Sector analysis, top stocks, volume |
| `CREATE VIEW` | Reusable reporting layer |
| `CREATE INDEX` | Query performance optimization |
| `pg_indexes` system catalog | Index introspection |

---

## 📊 Sample Output Snapshots

**Volatility Ranking (sample)**
```
company_id | volatility
-----------+-----------
         3 |      17.43   ← Tesla (most volatile)
         1 |      17.31
         7 |      17.28
         2 |      17.24
         5 |      17.18
         8 |      17.07
         6 |      17.02
         4 |      16.89   ← JP Morgan (least volatile)
```

**Moving Average (sample)**
```
company_id | trade_date | close_price | moving_avg_7d | moving_avg_30d
-----------+------------+-------------+---------------+---------------
         1 | 2024-01-01 |      134.50 |        128.40 |         125.20
         1 | 2024-01-02 |      141.20 |        130.10 |         126.80
```

---

## 🐛 Known Issues / Fixes

One syntax error exists in the original `basic_stats.sql`:

```sql
-- ❌ Bug (extra comma and typo)
SELECT company_id, com
MAX(high_price) AS highest_price

-- ✅ Fix
SELECT company_id,
MAX(high_price) AS highest_price
```

---

## 🚀 Future Enhancements

- [ ] Add RSI (Relative Strength Index) calculation
- [ ] Add Bollinger Bands using STDDEV window
- [ ] Parameterize moving average windows via functions
- [ ] Add a `dividends` table and yield analysis
- [ ] Connect to a live data source (e.g. Alpha Vantage API → PostgreSQL)
- [ ] Build a Grafana or Metabase dashboard on top of `stock_report` view

---

## 📄 License

MIT License — free to use, fork, and extend.

---

> Built with PostgreSQL · Window Functions · CTEs · Time-Series Analysis
