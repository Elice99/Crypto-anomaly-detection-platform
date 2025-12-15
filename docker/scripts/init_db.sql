-- ===============================
-- CRYPTO ANOMALY DETECTION DATABASE SCHEMA
-- ===============================

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ===============================
-- CUSTOM FUNCTIONS
-- ===============================

-- Calculate percentage price change
CREATE OR REPLACE FUNCTION calculate_price_change(
    old_price NUMERIC,
    new_price NUMERIC
)
RETURNS NUMERIC AS $$
BEGIN
    IF old_price = 0 THEN
        RETURN 0;
    END IF;
    RETURN ((new_price - old_price) / old_price) * 100;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ===============================
-- TABLES
-- ===============================

-- Coin metadata table (stores basic coin information)
CREATE TABLE IF NOT EXISTS coin_metadata (
    id SERIAL PRIMARY KEY,
    coin_id VARCHAR(50) UNIQUE NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    name VARCHAR(100) NOT NULL,
    image_url TEXT,
    market_cap_rank INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Coin prices table (time-series data)
CREATE TABLE IF NOT EXISTS coin_prices (
    coin_id VARCHAR(50) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    price NUMERIC(20, 8) NOT NULL,
    market_cap NUMERIC(20, 2),
    total_volume NUMERIC(20, 2),
    circulating_supply NUMERIC(20, 2),
    total_supply NUMERIC(20, 2),
    price_change_24h NUMERIC(10, 4),
    price_change_percentage_24h NUMERIC(10, 4),
    volume_change_24h NUMERIC(10, 4),
    timestamp TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (coin_id, timestamp)
);

-- Historical prices table (daily aggregated data)
CREATE TABLE IF NOT EXISTS historical_prices (
    id SERIAL PRIMARY KEY,
    coin_id VARCHAR(50) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    date DATE NOT NULL,
    open_price NUMERIC(20, 8),
    high_price NUMERIC(20, 8),
    low_price NUMERIC(20, 8),
    close_price NUMERIC(20, 8),
    volume NUMERIC(20, 2),
    market_cap NUMERIC(20, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(coin_id, date)
);

-- Anomalies table (stores detected anomalies)
CREATE TABLE IF NOT EXISTS anomalies (
    coin_id VARCHAR(50) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    anomaly_type VARCHAR(50) NOT NULL, -- 'price_spike', 'volume_spike', 'price_drop', 'ml_detected'
    severity VARCHAR(20) DEFAULT 'medium', -- 'low', 'medium', 'high', 'critical'
    price_at_detection NUMERIC(20, 8),
    volume_at_detection NUMERIC(20, 2),
    detection_method VARCHAR(50), -- 'z_score', 'isolation_forest', 'threshold'
    confidence_score NUMERIC(5, 4), -- 0.0000 to 1.0000
    details JSONB, -- Store additional metadata
    detected_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (coin_id, detected_at)
);

-- Alerts table (user-defined alert rules)
CREATE TABLE IF NOT EXISTS alerts (
    id SERIAL PRIMARY KEY,
    alert_name VARCHAR(100) NOT NULL,
    coin_id VARCHAR(50) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    alert_type VARCHAR(50) NOT NULL, -- 'price_above', 'price_below', 'volume_spike', 'custom'
    threshold_value NUMERIC(20, 8),
    is_active BOOLEAN DEFAULT true,
    last_triggered_at TIMESTAMP,
    trigger_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Technical indicators table (calculated features)
CREATE TABLE IF NOT EXISTS technical_indicators (
    coin_id VARCHAR(50) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    rsi NUMERIC(10, 4), -- Relative Strength Index
    macd NUMERIC(10, 4), -- MACD
    macd_signal NUMERIC(10, 4),
    macd_histogram NUMERIC(10, 4),
    bollinger_upper NUMERIC(20, 8),
    bollinger_middle NUMERIC(20, 8),
    bollinger_lower NUMERIC(20, 8),
    ma_7 NUMERIC(20, 8), -- 7-day moving average
    ma_30 NUMERIC(20, 8), -- 30-day moving average
    volume_ma_7 NUMERIC(20, 2),
    volatility NUMERIC(10, 4),
    timestamp TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (coin_id, timestamp)
);

-- Backtesting results table
CREATE TABLE IF NOT EXISTS backtest_results (
    id SERIAL PRIMARY KEY,
    strategy_name VARCHAR(100) NOT NULL,
    coin_id VARCHAR(50) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    initial_capital NUMERIC(20, 2),
    final_capital NUMERIC(20, 2),
    total_return NUMERIC(10, 4), -- Percentage
    sharpe_ratio NUMERIC(10, 4),
    max_drawdown NUMERIC(10, 4),
    win_rate NUMERIC(5, 4),
    total_trades INTEGER,
    winning_trades INTEGER,
    losing_trades INTEGER,
    parameters JSONB, -- Store strategy parameters
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Data collection logs table (track pipeline runs)
CREATE TABLE IF NOT EXISTS data_collection_logs (
    id SERIAL PRIMARY KEY,
    source VARCHAR(50) NOT NULL, -- 'coingecko', 'binance', 'cryptocompare'
    collection_type VARCHAR(50) NOT NULL, -- 'live', 'historical', 'minute'
    coins_collected INTEGER,
    status VARCHAR(20) NOT NULL, -- 'success', 'failed', 'partial'
    error_message TEXT,
    execution_time_seconds NUMERIC(10, 2),
    started_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================
-- CONVERT TO TIMESCALEDB HYPERTABLES
-- ===============================

-- Convert coin_prices to hypertable
SELECT create_hypertable('coin_prices', 'timestamp', 
    if_not_exists => TRUE,
    chunk_time_interval => INTERVAL '1 day'
);

-- Convert anomalies to hypertable
SELECT create_hypertable('anomalies', 'detected_at', 
    if_not_exists => TRUE,
    chunk_time_interval => INTERVAL '7 days'
);

-- Convert technical_indicators to hypertable
SELECT create_hypertable('technical_indicators', 'timestamp', 
    if_not_exists => TRUE,
    chunk_time_interval => INTERVAL '1 day'
);

-- ===============================
-- INDEXES FOR PERFORMANCE
-- ===============================

-- Indexes on coin_metadata
CREATE INDEX IF NOT EXISTS idx_coin_metadata_coin_id ON coin_metadata(coin_id);
CREATE INDEX IF NOT EXISTS idx_coin_metadata_symbol ON coin_metadata(symbol);

-- Indexes on coin_prices
CREATE INDEX IF NOT EXISTS idx_coin_prices_coin_id ON coin_prices(coin_id);
CREATE INDEX IF NOT EXISTS idx_coin_prices_symbol ON coin_prices(symbol);
CREATE INDEX IF NOT EXISTS idx_coin_prices_timestamp ON coin_prices(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_coin_prices_coin_timestamp ON coin_prices(coin_id, timestamp DESC);

-- Indexes on historical_prices
CREATE INDEX IF NOT EXISTS idx_historical_prices_coin_id ON historical_prices(coin_id);
CREATE INDEX IF NOT EXISTS idx_historical_prices_date ON historical_prices(date DESC);

-- Indexes on anomalies
CREATE INDEX IF NOT EXISTS idx_anomalies_coin_id ON anomalies(coin_id);
CREATE INDEX IF NOT EXISTS idx_anomalies_type ON anomalies(anomaly_type);
CREATE INDEX IF NOT EXISTS idx_anomalies_severity ON anomalies(severity);
CREATE INDEX IF NOT EXISTS idx_anomalies_detected_at ON anomalies(detected_at DESC);

-- Indexes on technical_indicators
CREATE INDEX IF NOT EXISTS idx_technical_indicators_coin_id ON technical_indicators(coin_id);
CREATE INDEX IF NOT EXISTS idx_technical_indicators_timestamp ON technical_indicators(timestamp DESC);

-- Indexes on alerts
CREATE INDEX IF NOT EXISTS idx_alerts_coin_id ON alerts(coin_id);
CREATE INDEX IF NOT EXISTS idx_alerts_active ON alerts(is_active);

-- ===============================
-- COMPRESSION POLICIES (Optional - saves disk space)
-- ===============================

-- Enable compression on coin_prices after 7 days
SELECT add_compression_policy('coin_prices', INTERVAL '7 days', if_not_exists => TRUE);

-- Enable compression on technical_indicators after 30 days
SELECT add_compression_policy('technical_indicators', INTERVAL '30 days', if_not_exists => TRUE);

-- ===============================
-- RETENTION POLICIES (Optional - auto-delete old data)
-- ===============================

-- Keep coin_prices for 1 year (uncomment if you want auto-cleanup)
-- SELECT add_retention_policy('coin_prices', INTERVAL '365 days', if_not_exists => TRUE);

-- ===============================
-- INITIAL SEED DATA (Optional)
-- ===============================

-- Insert popular coins metadata
INSERT INTO coin_metadata (coin_id, symbol, name, market_cap_rank) VALUES
    ('bitcoin', 'BTC', 'Bitcoin', 1),
    ('ethereum', 'ETH', 'Ethereum', 2),
    ('binancecoin', 'BNB', 'BNB', 3),
    ('solana', 'SOL', 'Solana', 4),
    ('ripple', 'XRP', 'XRP', 5),
    ('cardano', 'ADA', 'Cardano', 6),
    ('avalanche-2', 'AVAX', 'Avalanche', 7),
    ('dogecoin', 'DOGE', 'Dogecoin', 8),
    ('polkadot', 'DOT', 'Polkadot', 9),
    ('chainlink', 'LINK', 'Chainlink', 10)
ON CONFLICT (coin_id) DO NOTHING;

-- ===============================
-- VIEWS (Helpful query shortcuts)
-- ===============================

-- Latest prices view
CREATE OR REPLACE VIEW latest_prices AS
SELECT DISTINCT ON (coin_id)
    coin_id,
    symbol,
    price,
    market_cap,
    total_volume,
    price_change_percentage_24h,
    timestamp
FROM coin_prices
ORDER BY coin_id, timestamp DESC;

-- Recent anomalies view
CREATE OR REPLACE VIEW recent_anomalies AS
SELECT 
    a.coin_id,
    a.symbol,
    a.anomaly_type,
    a.severity,
    a.price_at_detection,
    a.detection_method,
    a.confidence_score,
    a.detected_at,
    cm.name as coin_name
FROM anomalies a
LEFT JOIN coin_metadata cm ON a.coin_id = cm.coin_id
WHERE a.detected_at > NOW() - INTERVAL '7 days'
ORDER BY a.detected_at DESC;

-- ===============================
-- SUCCESS MESSAGE
-- ===============================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TimescaleDB initialized successfully!';
    RAISE NOTICE 'Database: crypto_data';
    RAISE NOTICE 'User: crypto_user';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Tables created:';
    RAISE NOTICE '  ✓ coin_metadata';
    RAISE NOTICE '  ✓ coin_prices (hypertable)';
    RAISE NOTICE '  ✓ historical_prices';
    RAISE NOTICE '  ✓ anomalies (hypertable)';
    RAISE NOTICE '  ✓ alerts';
    RAISE NOTICE '  ✓ technical_indicators (hypertable)';
    RAISE NOTICE '  ✓ backtest_results';
    RAISE NOTICE '  ✓ data_collection_logs';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Views created:';
    RAISE NOTICE '  ✓ latest_prices';
    RAISE NOTICE '  ✓ recent_anomalies';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Initial seed data: 10 popular coins';
    RAISE NOTICE '========================================';
END;
$$;