# moda-mcp

Identify cryptocurrency breakout signals, run paper trading simulations, and visualize portfolio performance.

This monorepo contains multiple FastAPI-based microservices for data ingestion, feature computation, signal generation (rule-based and ML), simulation/paper trading, and a Next.js + Tailwind frontend for dashboards and visualization. Deployment targets Google Cloud Run using Docker containers.

## Services
- ingestion: Multiple source-specific services (Coinbase, CoinGecko, Polygon, CoinAPI, yfinance) with shared utilities.
- features: Computes derived features for signals.
- signals: Hosts rule-based and ML-driven breakout signals.
- paper_trading: Simulates strategies and risk controls.
- prompt_engine: Misc utility/prompt orchestration (future use).
- frontend: Next.js + Tailwind UI.

## Local development (Docker Compose)
Optional example for bringing up selected services:

- Each service exposes /health returning {"status":"ok"} on port 8000 inside the container.
- See each service's Dockerfile and requirements for details.

## Deploying to Google Cloud Run
- See `deployment/cloud_run/deploy.sh` for a simple template using gcloud CLI.
- See `deployment/terraform/main.tf` for a starting Terraform file.

## Structure (high level)
See repository directories for more details:
- ingestion/* (per-source collectors)
- features/* (derived features)
- signals/* (rule-based and ML)
- paper_trading/* (simulator)
- frontend/* (Next.js + Tailwind UI)
- prompt_engine/* (utility service)
- deployment/* (Cloud Run and Terraform scaffolding)

