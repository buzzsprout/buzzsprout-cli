---
name: buzzsprout-stats
description: Buzzsprout download stats for a single podcast-local date. Use for GET /downloads totals and per-episode download details.
---

# Stats

Download activity for **one** podcast-local calendar date (`YYYY-MM-DD`). No date-range filter.

## When to use

- Totals per episode that had downloads that day.
- Paged, normalized download details for one episode.

## Efficient CLI workflow

Use the authenticated CLI with `--json`; do not inspect credentials or rediscover the API with curl.

- For lifetime totals or lifetime rankings, use `buzzsprout episodes list --json` and read `total_downloads`. Do not fetch every day of the podcast's history.
- For totals across all episodes on one date, use `buzzsprout downloads YYYY-MM-DD --json`. This returns totals without requiring individual episode requests.
- For a date range, fetch each required date once and aggregate the results. The API has no date-range endpoint. Respect rate limits and report the dates used; don't count a missing or failed request as zero.
- Only request individual download details when the user wants geography, apps, or devices. Use `--per-page 1000` and follow `pagination.next_page` until `has_more` is false.
- For historical comparisons, use complete days and the podcast's timezone. Prefer explicit dates; `today` and `yesterday` are resolved using the CLI computer's date.

## Endpoints

- `GET /api/:podcast_id/downloads?date=YYYY-MM-DD`
- `GET /api/:podcast_id/:episode_id/downloads?date=YYYY-MM-DD` — note: **not** under `/episodes`

`page` defaults to 1, `per_page` defaults to 100 (max 1000). Invalid/missing `date` → `422` with `param: "date"`. The CLI requires a date: positional `today`, `yesterday`, or `YYYY-MM-DD` (case-insensitive), or `--date` as an alternate. There is no default date.

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
buzzsprout downloads today
buzzsprout downloads yesterday
buzzsprout downloads 2026-09-12
buzzsprout episode 788881 downloads today
buzzsprout episode 788881 downloads yesterday
buzzsprout episode 788881 downloads 2026-09-12
buzzsprout episode 788881 downloads today --page 1 --per-page 100
```

`stats` is an alias for `downloads`. Episode downloads need the episode id **between** `episode` and `downloads` (`buzzsprout episode <id> downloads today`). Do not omit the id.
