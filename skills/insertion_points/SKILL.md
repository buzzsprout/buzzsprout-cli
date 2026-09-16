---
name: buzzsprout-insertion-points
description: Manage Buzzsprout mid-roll insertion timestamps on processed episode audio.
---

# Insertion points

Mid-roll timestamps on **processed** episode audio. Returns `422` / `code: "unprocessable"` if audio is not processed yet.

## When to use

- Place or adjust mid-roll markers.
- Manual placements must sit after the first 20% of the episode, before the last 20%, and at least six minutes apart.

## Endpoints

- `GET /api/:podcast_id/episodes/:episode_id/insertion_points`
- `POST /api/:podcast_id/episodes/:episode_id/insertion_points` with `{ "timestamp": "00:15:00" }` or `{ "seconds": 900 }`
- `PATCH /api/:podcast_id/episodes/:episode_id/insertion_points/:id`
- `DELETE /api/:podcast_id/episodes/:episode_id/insertion_points/:id` → `204`

Omitting both `timestamp` and `seconds` on create → `422` / `param: "seconds"`. New points default to `eligible: true`.

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
Content-Type: application/json; charset=utf-8
```

## Example requests

```bash
curl -sS -X POST "https://www.buzzsprout.com/api/PODCAST_ID/episodes/EPISODE_ID/insertion_points" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Accept: application/json" \
  -d '{"timestamp":"00:15:00"}'
```

## CLI

```bash
buzzsprout insertion-points list 10 788881
buzzsprout insertion-points create 10 788881 --timestamp 00:15:00
buzzsprout insertion-points delete 10 788881 3
```
