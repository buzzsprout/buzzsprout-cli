---
name: buzzsprout-podcasts
description: List, show, and update Buzzsprout podcasts. Use for show metadata, RSS URL, categories, default podcast id, or GET /api/podcasts.
---

# Podcasts

List, inspect, and update podcasts available to the authenticated user. Any member can list and show. Updates require **admin or owner**.

## When to use

- Discover the numeric podcast id (needed by almost every other endpoint).
- Read or change title, description, categories, language, timezone, artwork URL.

## Endpoints

These routes do **not** put a podcast id before `podcasts`.

- `GET /api/podcasts`
- `GET /api/podcasts/:id`
- `PATCH /api/podcasts/:id` (also `PUT`)

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
Content-Type: application/json; charset=utf-8   # writes only
```

## Example requests

```bash
curl -sS "https://www.buzzsprout.com/api/podcasts" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Accept: application/json"

curl -sS -X PATCH "https://www.buzzsprout.com/api/podcasts/PODCAST_ID" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Accept: application/json" \
  -d '{"title":"Life Empowerment","category":"Arts :: Books"}'
```

Writable fields: `title`, `description`, `keywords`, `author`, `explicit`, `language`, `timezone`, `website_address`, `contact_email`, `category`, `category2`, `category3`. Write a category as `"Main :: Sub"`. `rss_url` and `website_url` are read-only.

## CLI

```bash
buzzsprout podcasts
buzzsprout podcasts show 10
buzzsprout podcasts update 10 --title "Life Empowerment"
buzzsprout use 10
```
