---
name: buzzsprout-podrolls
description: Manage recommended podcasts in a Buzzsprout RSS feed (podroll). Send guid and feed_url; there is no search endpoint.
---

# Podrolls

Recommended podcasts in the RSS feed. They can be any podcast, not only Buzzsprout. No search — send `guid` and `feed_url` yourself (for example from Podcast Index).

## When to use

- Add, reorder, or remove recommended shows.

## Endpoints

- `GET|POST /api/:podcast_id/podrolls`
- `PATCH /api/:podcast_id/podrolls/:id`
- `DELETE /api/:podcast_id/podrolls/:id` → `204`

On update, send `{ "position": 1 }` (1-based; `0` is treated as `1`) and optionally `feed_url` / `guid`.

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
Content-Type: application/json; charset=utf-8
```

## Example requests

```bash
curl -sS -X POST "https://www.buzzsprout.com/api/PODCAST_ID/podrolls" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Accept: application/json" \
  -d '{"guid":"29cdca4a-32d8-56ba-b48b-09a011c5daa9","feed_url":"https://feeds.example.com/show.rss"}'
```

## CLI

```bash
buzzsprout podrolls list 10
buzzsprout podrolls create 10 --guid 29cdca4a-32d8-56ba-b48b-09a011c5daa9 --feed-url https://feeds.example.com/show.rss
buzzsprout podrolls update 10 12 --position 1
buzzsprout podrolls delete 10 12
```
