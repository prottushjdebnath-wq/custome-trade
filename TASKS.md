# APEX FLOW NEURAL MCP — Build Tasks

Ordered milestones. Work top to bottom. Do not start a stage until the previous
stage's acceptance criteria are met. Each stage should be its own PR/commit series.
Read `ARCHITECTURE.md` first for full context and constraints.

---

## Stage 0 — Repo & infra skeleton

- [ ] Create repo structure exactly as in `ARCHITECTURE.md` §6.
- [ ] `docker-compose.yml` with services: `postgres`, `redis`, and placeholder
      `exchange-adapter` (empty container that just logs "alive" on an interval).
- [ ] `.env.example` with all expected env vars (DB creds, Redis URL, symbols to
      track, exchange selection, log level).
- [ ] `infra/postgres/init.sql` with initial schema: `candles`, `trades`,
      `orderbook_snapshots` tables (define columns; include exchange, symbol,
      timestamp, and raw JSON payload columns for forward compatibility).

**Done when:** `docker compose up` brings up Postgres + Redis healthy, and the
placeholder adapter container logs successfully. No exchange connectivity yet.

---

## Stage 1 — Exchange adapter + market data engine

- [ ] Binance public WS client: order book diff stream + trade stream for a
      configurable symbol list (start with `BTCUSDT`, `ETHUSDT`).
- [ ] Bybit public WS client: same, for Bybit's equivalent streams.
- [ ] Normalize both feeds into one internal event schema (exchange-agnostic
      order book delta, trade, candle events).
- [ ] Local order book reconstruction (maintain live L2 book in memory/Redis from
      snapshot + diffs, per exchange per symbol).
- [ ] Candle aggregation from trade stream (1m, 5m, 15m, 1h at minimum) written
      to Postgres.
- [ ] Reconnect logic with exponential backoff; must not corrupt the order book
      on reconnect (re-fetch snapshot).
- [ ] Unit tests using recorded/fixture WS payloads (no live network required).

**Done when:** Running the adapter for 10+ minutes against live Binance + Bybit
produces a consistent, non-drifting L2 book in Redis and correct 1m candles in
Postgres for BTCUSDT on both exchanges, verified by a test script.

---

## Stage 2 — Order flow engine

- [ ] Delta calculation (aggressive buy vol − aggressive sell vol) per candle.
- [ ] CVD (cumulative delta) time series, persisted.
- [ ] Order-book imbalance metric (bid vs ask volume within N levels).
- [ ] Expose via Redis pub/sub or a query API consumable by later stages.
- [ ] Unit tests against fixture trade/book data with known expected delta/CVD.

**Done when:** CVD and imbalance values for BTCUSDT match hand-computed values
on a fixture dataset, and update live from Stage 1's data within acceptable
latency (<2s).

---

## Stage 3 — Market structure + SMC engine

- [ ] Swing high/low detection.
- [ ] BOS (break of structure) and CHoCH (change of character) detection.
- [ ] Order block identification.
- [ ] Fair Value Gap (FVG) detection.
- [ ] Liquidity pool identification and sweep detection.
- [ ] Document the exact rule-based definitions used for each (this is inherently
      heuristic — the definitions must be written down, not just implicit in code).
- [ ] Unit tests against fixture candle sequences with hand-labeled expected
      structure events.

**Done when:** Given a fixture candle series with known structure (e.g. a
labeled uptrend-to-downtrend transition), the engine correctly flags the BOS/CHoCH
and at least one order block and FVG at the expected locations.

---

## Stage 4 — Volume engine

- [ ] VWAP (session and rolling).
- [ ] RVOL (relative volume vs historical average for same time-of-day).
- [ ] Approximate volume profile (define the approximation method explicitly —
      e.g. binned volume-by-price over a lookback window — and document it).
- [ ] Unit tests against fixture data.

**Done when:** VWAP/RVOL/profile outputs match hand-computed values on fixture
data within defined tolerance.

---

## Stage 5 — Derivatives engine

- [ ] Open interest polling (Binance/Bybit public futures endpoints).
- [ ] Funding rate polling.
- [ ] Liquidation feed (public liquidation WS streams where available).
- [ ] Graceful degradation: if a symbol/exchange doesn't expose one of these
      publicly, the schema field is explicitly null/absent, not fabricated.

**Done when:** OI, funding, and liquidation data are visible in Redis/Postgres
for BTCUSDT on at least one exchange, refreshing on the correct cadence for
each data type (funding is typically 8h-interval, OI can poll more frequently).

---

## Stage 6 — Multi-timeframe context + Apex Neural Schema

- [ ] Define the Neural Schema as a versioned JSON structure combining outputs
      of Stages 2–5 across multiple timeframes (e.g. 5m/15m/1h/4h) for a symbol.
- [ ] Schema assembly service that queries/subscribes to all prior engines and
      builds the current-state snapshot on demand and on a fixed interval.
- [ ] Persist schema snapshots to Postgres for history/backtesting.
- [ ] JSON schema validation (e.g. via `pydantic`) so downstream consumers get
      a guaranteed shape.

**Done when:** A single API call/query returns a complete, schema-valid Neural
Schema object for BTCUSDT reflecting current live state across all engines.

---

## Stage 7 — Confluence + decision engine

- [ ] Define confluence scoring: how signals from structure/volume/derivatives/
      order flow combine into a weighted score (document the weights/rationale).
- [ ] Decision engine maps confluence score + context into LONG/SHORT/WAIT with
      a human-readable rationale string.
- [ ] This stage is intentionally simple/transparent rule-based logic first —
      no black-box ML — so it's auditable before any AI layer touches it.

**Done when:** Given fixture Neural Schema snapshots with known expected bias,
the decision engine outputs the expected direction and a rationale referencing
the actual contributing signals.

---

## Stage 8 — MCP server

- [ ] Expose Neural Schema, individual engine outputs, and decision engine as
      MCP tools/resources (e.g. `get_neural_schema(symbol)`,
      `get_decision(symbol)`, `get_orderflow(symbol, timeframe)`).
- [ ] Local LLM integration via Ollama: a tool-calling loop where the model
      queries MCP tools and produces natural-language market commentary/reasoning,
      never computing indicators itself.
- [ ] MCP server tests: mock tool calls, verify correct schema is returned.

**Done when:** A local Ollama model, given the MCP tools, can answer "what's the
current bias on BTCUSDT and why" by calling tools and citing real schema fields
in its answer.

---

## Stage 9 — Web dashboard (PWA)

- [ ] Responsive dashboard optimized for iPad Safari: live order book, chart
      with structure/SMC overlays, CVD/delta panel, decision panel with AI
      rationale.
- [ ] PWA manifest + service worker for installability.
- [ ] Read-only in v1 (no order entry).

**Done when:** Dashboard is installable on iPad Safari as a PWA and displays
live-updating data for BTCUSDT end-to-end from the running backend.

---

## Stage 10 — Telegram Mini App

- [ ] Telegram bot + Mini App wrapping the same dashboard/API.
- [ ] Auth via Telegram's WebApp initData validation.

**Done when:** Opening the bot in Telegram on iPad shows the same live data as
the web dashboard.

---

## Out of scope for v1 (do not build unless explicitly requested)

- Order execution / live trading.
- Paid data feeds or AI APIs of any kind.
- Multi-user auth beyond the single owner (Telegram identity is sufficient).
