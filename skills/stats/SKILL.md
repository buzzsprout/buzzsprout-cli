---
name: buzzsprout-stats
description: Buzzsprout download stats for a single podcast-local date. Use for GET /downloads totals and per-episode download details.
---

# Stats

Download activity for **one** podcast-local calendar date (`YYYY-MM-DD`). No date-range filter.

## When to use

- Totals per episode that had downloads that day.
- Paged, normalized download details for one episode.

## Endpoints

- `GET /api/:podcast_id/downloads?date=YYYY-MM-DD`
- `GET /api/:podcast_id/:episode_id/downloads?date=YYYY-MM-DD` — note: **not** under `/episodes`

`page` defaults to 1, `per_page` defaults to 100 (max 1000). Invalid `date` → `422` with `param: "date"`. The CLI sends **today** (local calendar date) when `--date` is omitted.

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
```

## Example requests

```bash
curl -sS "https://www.buzzsprout.com/api/PODCAST_ID/downloads?date=2026-09-12" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Accept: application/json"
```

Podcast response: `[{ "episode_id": 788881, "total": 2 }]`. Empty day: `[]`.

Episode response includes `episodes[].downloads[]` (`app`, `device`, `device_type`, geo, `media_type`) and `pagination`.

## CLI

```bash
buzzsprout stats
buzzsprout stats --date 2026-09-12
buzzsprout stats episode 788881 --date 2026-09-12 --page 1 --per-page 100
```
