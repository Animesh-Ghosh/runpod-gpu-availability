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

The dashboard deliberately runs as **one Fly Machine with one SQLite volume**.
That gives the in-process scheduler and the web server one writer, which is the
simple safe SQLite topology. Do not scale this app horizontally without moving
the scheduler/database design first.

## Local run

```sh
bundle install
RUNPOD_API_KEY=... SNAPSHOT_INTERVAL_SECONDS=60 bundle exec puma -b tcp://127.0.0.1:8080 config.ru
open http://127.0.0.1:8080
```

`RUNPOD_API_KEY` needs read access to the RunPod catalog. The first snapshot is
captured immediately after boot; later snapshots default to every 30 minutes.

For a manual, authenticated snapshot:

```sh
curl -X POST http://127.0.0.1:8080/internal/snapshots \
  -H "Authorization: Bearer $SNAPSHOT_SECRET"
```

## Fly.io deployment

Create a new Fly app from this directory. `fly launch` writes the chosen unique
app name into `fly.toml`; this repository intentionally does not hard-code one.

```sh
fly launch --copy-config --no-deploy
fly volumes create availability_data --size 1 --region bom
fly secrets set RUNPOD_API_KEY=... SNAPSHOT_SECRET="$(openssl rand -hex 32)"
fly deploy
```

The app must keep one Machine running: `auto_stop_machines = "off"` is
intentional, since an in-process scheduler cannot collect data while stopped.
SQLite data lives only on the `availability_data` volume. Back it up before
destroying the Machine or volume.

## Verification

```sh
bundle exec rake test
curl -fsS https://YOUR_APP.fly.dev/healthz
open https://YOUR_APP.fly.dev/
```
