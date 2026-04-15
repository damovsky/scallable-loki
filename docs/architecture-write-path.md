# Log Write Path: poc-app → Loki → S3

How a log line travels from the application to long-term storage.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  POD: poc-app (namespace: default)                                          │
│                                                                             │
│  ┌─────────────────────┐   /tmp/app.log    ┌────────────────────────────┐  │
│  │  app container      │ ───(shared vol)──▶ │  fluent-bit sidecar        │  │
│  │                     │                   │                            │  │
│  │  2026-04-15 [INFO]  │                   │  tail /tmp/app.log         │  │
│  │  msg="User login"   │                   │  output: loki              │  │
│  │  msg="New order"    │                   │  host: loki-gateway:80     │  │
│  └─────────────────────┘                   └────────────┬───────────────┘  │
│                                                         │                  │
└─────────────────────────────────────────────────────────┼──────────────────┘
                                                          │ HTTP POST /loki/api/v1/push
                                                          │ labels: app=poc-app
                                                          │         env=production
                                                          ▼
                                             ┌────────────────────┐
                                             │   loki-gateway     │
                                             │   (nginx :80)      │
                                             │                    │
                                             │  routes /push →    │
                                             │  loki-write        │
                                             └────────┬───────────┘
                                                      │
                                        ┌─────────────▼──────────────┐
                                        │      loki-write x3         │
                                        │  (StatefulSet, Spot nodes) │
                                        │                            │
                                        │  1. write to WAL           │
                                        │  2. buffer in memory       │
                                        │  3. flush chunk to S3      │
                                        └──────────┬─────────────────┘
                                                   │
                              ┌────────────────────┼──────────────────────┐
                              │                    │                      │
                              ▼                    ▼                      ▼
                   ┌──────────────────┐  ┌─────────────────┐  ┌──────────────────────┐
                   │  loki-backend x3 │  │  S3 Bucket      │  │  loki-chunks-cache   │
                   │                 │  │  loki-prod-      │  │  (memcached)         │
                   │  - compactor     │  │  storage-ematiq  │  │                      │
                   │  - index-gateway │  │                 │  │  warm cache of       │
                   │  - query-sched.  │  │  chunks/  ← raw │  │  recently flushed    │
                   │                 │  │  index/   ← TSDB │  │  chunks              │
                   │  builds & stores │  │                 │  └──────────────────────┘
                   │  TSDB index      │  └─────────────────┘
                   └──────────────────┘
```

## Component roles

| Component | Role |
|---|---|
| `fluent-bit` | Tails `/tmp/app.log`, ships to Loki via HTTP |
| `loki-gateway` | nginx reverse proxy, routes push → write, query → read |
| `loki-write` | Ingester: WAL → in-memory chunks → flush to S3 |
| `loki-backend` | Compactor + index-gateway: maintains TSDB index in S3 |
| `loki-chunks-cache` | Memcached: hot cache of recently flushed chunks |
| `S3` | Long-term storage for raw chunks and TSDB index |
