# RunPod GPU Availability

A tiny Rack dashboard that records the RunPod GPU catalog's **SERVERLESS**
availability by region and serves the latest snapshot plus a seven-day history.
It is intended to answer a practical question: which RunPod region/pool has
repeatedly had capacity for a Reel Translator endpoint?

## What it records

Every snapshot calls RunPod's documented catalog endpoint with
`include=AVAILABILITY&product=SERVERLESS`. Each row stores the timestamp,
region, GPU, serverless pool, VRAM, availability level, and serverless list
price. Availability is product-specific: Pod stock is not substituted for
Serverless stock.

The dashboard deliberately uses **one always-running Fly Machine with one SQLite
volume**. Rufus Scheduler captures a snapshot shortly after boot and then every
hour. This avoids relying on GitHub Actions cron, while keeping one SQLite writer.
Do not scale this app horizontally without moving the SQLite design first.

Set `SNAPSHOT_INTERVAL_SECONDS` to change the cadence; it defaults to `3600` and the homepage displays the active interval.

## Local run

```sh
bundle install
RUNPOD_API_KEY=... SNAPSHOT_INTERVAL_SECONDS=60 bundle exec puma -b tcp://127.0.0.1:8080 config.ru
open http://127.0.0.1:8080
```

`RUNPOD_API_KEY` needs read access to the RunPod REST v2 catalog. The first
snapshot is captured shortly after boot; later snapshots default to every hour.

## Fly.io deployment

Create a new Fly app from this directory. `fly launch` writes the chosen unique
app name into `fly.toml`; this repository intentionally does not hard-code one.

```sh
fly launch --copy-config --no-deploy
fly volumes create availability_data --size 1 --region sin
fly secrets set RUNPOD_API_KEY=...
fly deploy
```

The Fly Machine intentionally stays running: its in-process scheduler cannot
collect while stopped. SQLite data lives only on the `availability_data` volume.
For this low-cost decision tool, deleting that volume deletes the history; no
separate backup workflow is configured.

## Verification

```sh
bundle exec rake test
curl -fsS https://YOUR_APP.fly.dev/healthz
open https://YOUR_APP.fly.dev/
```
