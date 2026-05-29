-- Create sectors Table
CREATE TABLE sectors (
    sector_id SERIAL PRIMARY KEY,
    sector_name VARCHAR(100) NOT NULL
);

-- Create companies Table
CREATE TABLE companies (
    company_id SERIAL PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL,
    stock_symbol VARCHAR(10) UNIQUE,
    sector_id INT REFERENCES sectors(sector_id),
    market_cap BIGINT
);

-- Create stock_prices Table
CREATE TABLE stock_prices (
    price_id SERIAL PRIMARY KEY,
    company_id INT REFERENCES companies(company_id),
    trade_date DATE,
    open_price NUMERIC(10,2),
    high_price NUMERIC(10,2),
    low_price NUMERIC(10,2),
    close_price NUMERIC(10,2),
    volume BIGINT
);

-- Insert values into Sectors Table
INSERT INTO sectors (sector_name)
VALUES
('Technology'),
('Banking'),
('Healthcare'),
('Energy'),
('Automobile');

select * from sectors;

-- Insert values into Company Data
INSERT INTO companies
(company_name, stock_symbol, sector_id, market_cap)
VALUES
('Apple Inc', 'AAPL', 1, 3000000000),
('Microsoft', 'MSFT', 1, 2800000000),
('Tesla', 'TSLA', 5, 1200000000),
('JP Morgan', 'JPM', 2, 900000000),
('Infosys', 'INFY', 1, 700000000),
('Reliance', 'RELI', 4, 1500000000),
('TCS', 'TCS', 1, 1300000000),
('HDFC Bank', 'HDFC', 2, 1000000000);

select * from companies;

-- Insert values into stock_prices
INSERT INTO stock_prices
(company_id, trade_date, open_price,
high_price, low_price, close_price, volume)

SELECT
    c.company_id,

    CURRENT_DATE - gs.day,
    ROUND((100 + random()*50)::numeric,2),
    ROUND((150 + random()*50)::numeric,2),
    ROUND((90 + random()*40)::numeric,2),
    ROUND((100 + random()*60)::numeric,2),
	(100000 + random()*500000)::BIGINT
FROM companies c
CROSS JOIN generate_series(1,365) AS gs(day);

select * from stock_prices;

-- Basic Analytics Queries
-- 1.Average Closing Price
SELECT
company_id,
ROUND(AVG(close_price),2) AS avg_close_price
FROM stock_prices
GROUP BY company_id;

--2.Highest Stock Price
SELECT
company_id,com
MAX(high_price) AS highest_price
FROM stock_prices
GROUP BY company_id;

--3.Lowest Stock Price
SELECT
company_id,
MIN(low_price) AS lowest_price
FROM stock_prices
GROUP BY company_id;

-- Average Analysis over the Trend
--1.7days Moving Average
SELECT
company_id,
trade_date,
close_price,
ROUND(
AVG(close_price)
OVER(
PARTITION BY company_id
ORDER BY trade_date
ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
),2) AS moving_avg_7d
FROM stock_prices;

--2.30-Day Moving Average
SELECT
company_id,
trade_date,
close_price,
ROUND(
AVG(close_price)
OVER(
PARTITION BY company_id
ORDER BY trade_date
ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
),2) AS moving_avg_30d
FROM stock_prices;

-- Yearly Performance
SELECT
company_id,
EXTRACT(YEAR FROM trade_date)
AS year,
ROUND(
AVG(close_price),
2
) AS yearly_avg
FROM stock_prices
GROUP BY company_id, year;

--Volatility Analysis
SELECT
company_id,
ROUND(
STDDEV(close_price)::numeric,
2
) AS volatility
FROM stock_prices
GROUP BY company_id
ORDER BY volatility DESC;

--Daily Price Difference
SELECT
company_id,
trade_date,
close_price,
LAG(close_price)
OVER(
PARTITION BY company_id
ORDER BY trade_date
) AS previous_close,
close_price -
LAG(close_price)
OVER(
PARTITION BY company_id
ORDER BY trade_date
)
AS daily_difference
FROM stock_prices;

--Golden Cross Detection
WITH ma_data AS (
SELECT
company_id,
trade_date,
AVG(close_price)
OVER(
PARTITION BY company_id
ORDER BY trade_date
ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
) AS ma_50,
AVG(close_price)
OVER(
PARTITION BY company_id
ORDER BY trade_date
ROWS BETWEEN 199 PRECEDING AND CURRENT ROW
) AS ma_200
FROM stock_prices
)
SELECT *
FROM ma_data
WHERE ma_50 > ma_200;

--Death Cross Detection
WITH ma_data AS (
SELECT
company_id,
trade_date,
AVG(close_price)
OVER(
PARTITION BY company_id
ORDER BY trade_date
ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
) AS ma_50,

AVG(close_price)
OVER(
PARTITION BY company_id
ORDER BY trade_date
ROWS BETWEEN 199 PRECEDING AND CURRENT ROW
) AS ma_200
FROM stock_prices
)
SELECT *
FROM ma_data
WHERE ma_50 < ma_200;

--Top Performing Stocks
SELECT
c.company_name,
ROUND(
AVG(sp.close_price),
2
) AS average_price
FROM stock_prices sp
JOIN companies c
ON sp.company_id = c.company_id
GROUP BY c.company_name
ORDER BY average_price DESC;

-- Sector Wise Analysis
SELECT
s.sector_name,
ROUND(
AVG(sp.close_price),
2
) AS avg_sector_price
FROM stock_prices sp
JOIN companies c
ON sp.company_id = c.company_id
JOIN sectors s
ON c.sector_id = s.sector_id
GROUP BY s.sector_name;

--Highest Trading Volume
SELECT
c.company_name,
MAX(sp.volume) AS highest_volume
FROM stock_prices sp
JOIN companies c
ON sp.company_id = c.company_id
GROUP BY c.company_name
ORDER BY highest_volume DESC;

-- Top 5 Highest Closing Prices
SELECT
c.company_name,
sp.trade_date,
sp.close_price
FROM stock_prices sp
JOIN companies c
ON sp.company_id = c.company_id
ORDER BY sp.close_price DESC
LIMIT 5;

-- Lowest Closing Prices
SELECT
c.company_name,
sp.trade_date,
sp.close_price
FROM stock_prices sp
JOIN companies c
ON sp.company_id = c.company_id
ORDER BY sp.close_price ASC
LIMIT 5;

--  Top Gainers
SELECT
company_id,
trade_date,
close_price -
LAG(close_price)
OVER(
PARTITION BY company_id
ORDER BY trade_date
)
AS gain
FROM stock_prices
ORDER BY gain DESC
LIMIT 10;

-- Top Losers
SELECT
company_id,
trade_date,
close_price -
LAG(close_price)
OVER(
PARTITION BY company_id
ORDER BY trade_date
)
AS loss
FROM stock_prices
ORDER BY loss ASC
LIMIT 10;

--Rank Stocks by Average Price
SELECT
c.company_name,
ROUND(
AVG(sp.close_price),
2
) AS avg_price,
RANK()
OVER(
ORDER BY AVG(sp.close_price) DESC
) AS stock_rank
FROM stock_prices sp
JOIN companies c
ON sp.company_id = c.company_id
GROUP BY c.company_name;


--Company-wise Maximum Volume Day
SELECT DISTINCT ON (company_id)
company_id,
trade_date,
volume
FROM stock_prices
ORDER BY company_id, volume DESC;

-- Most Stable Stocks
SELECT
c.company_name,
ROUND(
STDDEV(sp.close_price)::numeric,
2
) AS volatility
FROM stock_prices sp
JOIN companies c
ON sp.company_id = c.company_id
GROUP BY c.company_name
ORDER BY volatility ASC;

--Create View for Reporting
CREATE VIEW stock_report AS
SELECT
c.company_name,
c.stock_symbol,
sp.trade_date,
sp.close_price,
sp.volume
FROM stock_prices sp
JOIN companies c
ON sp.company_id = c.company_id;

SELECT * FROM stock_report;

-- Index Optimization
CREATE INDEX idx_trade_date
ON stock_prices(trade_date);

SELECT *
FROM pg_indexes
WHERE tablename = 'stock_prices';