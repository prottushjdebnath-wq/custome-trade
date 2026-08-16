-- Table: candles
CREATE TABLE IF NOT EXISTS candles (
    id BIGSERIAL PRIMARY KEY,
    exchange VARCHAR(50) NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    timeframe VARCHAR(10) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    open NUMERIC,
    high NUMERIC,
    low NUMERIC,
    close NUMERIC,
    volume NUMERIC,
    raw_payload JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(exchange, symbol, timeframe, timestamp)
);

CREATE INDEX idx_candles_lookup ON candles(exchange, symbol, timeframe, timestamp DESC);

-- Table: trades
CREATE TABLE IF NOT EXISTS trades (
    id BIGSERIAL PRIMARY KEY,
    exchange VARCHAR(50) NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    price NUMERIC NOT NULL,
    amount NUMERIC NOT NULL,
    side VARCHAR(10) NOT NULL,
    raw_payload JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_trades_lookup ON trades(exchange, symbol, timestamp DESC);

-- Table: orderbook_snapshots
CREATE TABLE IF NOT EXISTS orderbook_snapshots (
    id BIGSERIAL PRIMARY KEY,
    exchange VARCHAR(50) NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    bids JSONB NOT NULL,
    asks JSONB NOT NULL,
    raw_payload JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_orderbook_snapshots_lookup ON orderbook_snapshots(exchange, symbol, timestamp DESC);
