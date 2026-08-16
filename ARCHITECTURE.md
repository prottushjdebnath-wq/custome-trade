# APEX FLOW NEURAL MCP — Architecture

Self-hosted, iPad-first crypto market-intelligence and trading-terminal platform.
This document is the system-level spec. See `TASKS.md` for the ordered build plan
and acceptance criteria — that is the file a coding agent should execute against.

## 1. Objective

Build a self-hosted crypto trading intelligence platform (inspired by terminals like
Altrady, fully custom) covering:

- real-time order flow, Level-2 order book, live trades
- Delta, CVD, order-book imbalance
- market structure (BOS/CHoCH/swings), Smart Money Concepts, Order Blocks, Fair Value Gaps
- liquidity and liquidity sweeps
- VWAP, RVOL, approximate volume profile
- open interest, funding, liquidations (where public data permits)
- multi-timeframe analysis and confluence scoring
- AI market reasoning over structured state (not raw prompting)
- custom MCP tools exposing the above to an LLM
- Telegram Mini App + responsive web (PWA) dashboard
- optional future order execution (out of scope for v1)

Primary client: iPad, via Safari/PWA or Telegram. No local dev environment, Docker,
or Python required on the client device — the VPS does all compute.

## 2. Cost constraints (non-negotiable)

Software cost, market-data cost, and AI-inference cost must all be $0. Only the
existing VPS is a paid resource. Concretely:

- No Claude/OpenAI/paid LLM APIs — use a local model via Ollama.
- No TradingView Premium, Altrady, CoinGlass, or other paid SaaS/data subscriptions.
- No paid managed DB/Redis/chart-library/MCP hosting.
- Market data from **public** Binance and Bybit REST/WebSocket endpoints only.
- Exchange trading fees (if the user eventually trades) are not an infra cost and
  are out of scope for this constraint.

## 3. AI architecture principle

The LLM is a reasoning layer, not the data engine. All deterministic calculation
(order flow, structure, SMC, volume, derivatives) happens in Python and is written
into a structured state object called the **Apex Neural Schema**. The AI model
(local, via Ollama) consumes the Neural Schema through MCP tools and produces
interpretation/commentary — it never computes indicators itself and is never the
source of truth for market state.

Do not push this logic into a giant system prompt. Each engine below is a discrete,
testable Python component with its own inputs/outputs.

## 4. Target VPS (inspect before assuming)

Believed current spec — must be verified, not assumed, before provisioning anything:

- Provider: Contabo, Singapore region
- OS: Ubuntu 24.04 LTS
- CPU: 6 vCPU, RAM: 12 GB, Storage: 100 GB NVMe

Rules:
- Do not provision a new VPS or downgrade this one.
- Inspect existing Docker containers, services, ports, firewall rules, Python/Node
  versions, Postgres/Redis/Ollama installs before changing anything.
- Do not delete or stop existing services without first explaining what they are
  and confirming they're unused by this project.

## 5. Data flow

```
Binance public WS + Bybit public WS
        │
   Exchange Adapter (normalizes both feeds to one internal schema)
        │
   Market Data Engine → order book snapshots/deltas, trades, candles
        │
   Order Flow Engine → delta, CVD, imbalance
        │
   Market Structure Engine → BOS, CHoCH, swing points
        │
   SMC Engine → order blocks, FVGs, liquidity pools/sweeps
        │
   Volume Engine → VWAP, RVOL, approximate volume profile
        │
   Derivatives Engine → open interest, funding, liquidations
        │
   Multi-Timeframe Context → aligns all of the above across timeframes
        │
   Apex Neural Schema (structured JSON state graph, persisted + versioned)
        │
   Confluence Engine → weighted scoring across signals
        │
   Decision Engine → LONG / SHORT / WAIT state + rationale
        │
   Custom MCP Server (exposes schema + engines as MCP tools/resources)
        │
   ┌────┴────┐
Local LLM   Web Dashboard (PWA) ──► Telegram Mini App + Safari
(Ollama)
```

## 6. Repository layout

```
apex-flow-neural-mcp/
├── ARCHITECTURE.md          # this file
├── TASKS.md                 # ordered build plan + acceptance criteria
├── docker-compose.yml
├── .env.example
├── services/
│   ├── exchange-adapter/    # Binance/Bybit WS ingestion → normalized events
│   ├── orderflow-engine/    # Delta, CVD, imbalance
│   ├── structure-engine/    # BOS/CHoCH/swings, SMC, FVG, liquidity
│   ├── volume-engine/       # VWAP/RVOL/volume profile
│   ├── derivatives-engine/  # OI/funding/liquidations
│   ├── neural-schema/       # assembles the Apex Neural Schema
│   ├── confluence-engine/
│   ├── decision-engine/
│   └── mcp-server/          # custom MCP tools exposing schema + engines
├── web-dashboard/           # PWA frontend
├── telegram-miniapp/
├── infra/
│   ├── postgres/init.sql
│   └── redis/
└── docs/
```

## 7. Non-functional requirements

- Each service is an independently runnable container in `docker-compose.yml`.
- Postgres for durable state (candles, schema snapshots, decision history);
  Redis for hot/ephemeral state (live order book, pub/sub between engines).
- All inter-service communication either via Redis pub/sub or direct Postgres reads —
  no undocumented in-memory coupling between services.
- Every engine has unit tests against fixture data (recorded WS payloads), independent
  of live exchange connectivity.
- Structured logging; each service must survive exchange WS disconnects and reconnect
  with backoff, without corrupting downstream state.
