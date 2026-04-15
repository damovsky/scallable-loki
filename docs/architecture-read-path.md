# Log Read Path: Grafana → Loki → S3

How a Grafana query fetches logs from Loki.

```
👤 you (browser)
      │
      ▼
┌─────────────────────┐
│       Grafana       │
│                     │
│  datasource: Loki   │
│  url: loki-gateway  │
│                     │
│  Explore /          │
│  Logs Drilldown     │
└──────────┬──────────┘
           │ HTTP GET /loki/api/v1/query_range
           │ query: {app="poc-app"}
           │ range: last 1h
           ▼
┌──────────────────────┐
│    loki-gateway      │  nginx reverse proxy
│       (:80)          │  routes /loki/api/* → loki-read
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────────┐
│         loki-read x3             │
│                                  │
│  query-frontend: parse LogQL,    │
│  split by time range, fan out    │
│                                  │
│  querier: fetch from ingesters   │
│  + object store, merge results   │
└───────────┬──────────────────────┘
            │
            ├──────────────────────────────────────┐
            │ recent logs                          │ older logs
            │ (still in memory, not yet flushed)   │ (flushed to S3)
            ▼                                      ▼
┌───────────────────────┐             ┌────────────────────────┐
│    loki-write x3      │             │    loki-backend x3     │
│    (ingesters)        │             │                        │
│                       │             │  index-gateway:        │
│  in-memory WAL        │             │  looks up TSDB index   │
│  hot chunks           │             │  → finds chunk refs    │
│                       │             │    in S3               │
└───────────────────────┘             └───────────┬────────────┘
            │                                     │ chunk refs
            │                                     ▼
            │                          ┌──────────────────────┐
            │                          │  loki-chunks-cache   │  cache hit?
            │                          │    (memcached)       │──────────────▶ chunk data
            │                          └──────────┬───────────┘
            │                                     │ cache miss
            │                                     ▼
            │                          ┌──────────────────────┐
            │                          │      S3 Bucket       │
            │                          │  loki-prod-storage   │
            │                          │                      │
            │                          │  chunks/ ← raw logs  │
            │                          │  index/  ← TSDB      │
            │                          └──────────┬───────────┘
            │                                     │ raw chunk
            │                                     │ (stored in cache)
            │                                     ▼
            └──────────────────────────▶ results merged by loki-read
                                                  │
                                                  ▼
                                         back to Grafana
                                         rendered as log lines
```

## Key concepts

- **loki-gateway** is a dumb router — all query logic lives in `loki-read`
- **loki-read** always fans out to both ingesters (hot) and object store (cold) and merges
- **loki-chunks-cache** avoids hitting S3 for recently flushed chunks (big latency win)
- **loki-backend** does not serve logs directly — it only maintains the index that tells the querier *where* chunks are in S3

## LogQL quick reference

```logql
# all poc-app logs
{app="poc-app"}

# errors only
{app="poc-app"} |= "ERROR"

# parse structured fields
{app="poc-app"} | logfmt | msg != ""
```
