---
name: buzzsprout-episodes
description: Create, inspect, update, schedule, publish, and unpublish Buzzsprout episodes. Use for titles, private flag, published_at, and episode metadata.
---

# Episodes

Create, inspect, update, schedule, and unpublish episodes for a podcast.

## When to use

- Draft a private episode, then attach media with the `uploads` skill.
- Publish with `"private": false` (optionally schedule `published_at`).
- Unpublish with `"private": true`.

Typical workflow: create private → upload (complete!) → wait for `duration` > 0 → optional chapters/contributors → publish.

## Endpoints

- `GET /api/:podcast_id/episodes`
- `GET /api/:podcast_id/episodes/:id`
- `POST /api/:podcast_id/episodes` → `201 Created`
- `PATCH /api/:podcast_id/episodes/:id` (also `PUT`)

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
Content-Type: application/json; charset=utf-8
```

## Example requests

```bash
curl -sS -X POST "https://www.buzzsprout.com/api/PODCAST_ID/episodes" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Accept: application/json" \
  -d '{"title":"Too many or too few?","private":true,"episode_number":6}'
```

Write fields: `title`, `description`, `artist`, `tags` (comma-separated string), `published_at` (include timezone offset), `season_number`, `episode_number`, `episode_type` (`full`|`trailer`|`bonus`), `explicit`, `private`, `custom_url`. Artwork: `artwork_url` or multipart `artwork_file`.

Legacy `audio_url` / `audio_file` still work; new work should use the upload endpoints.

Create/update use a **legacy error format** (field hashes, HTTP 400). Other resources use `{ "error": { "code", "message", "param" } }`.

## CLI

```bash
buzzsprout episodes list 10
buzzsprout episodes show 10 788881
buzzsprout episodes create 10 --title "My episode" --private
buzzsprout episodes update 10 788881 --body '{"description":"…"}'
buzzsprout episodes publish 10 788881
buzzsprout episodes unpublish 10 788881
```
