---
name: buzzsprout-chapters
description: Get or replace a Buzzsprout episode chapter list in one request. No single-chapter CRUD.
---

# Chapters

Replace an episode's chapter list in one request. There is no single-chapter create/update/delete.

## When to use

- Read current chapters, edit locally, PUT the replacement.
- Empty array deletes every non-ad chapter.

## Endpoints

- `GET /api/:podcast_id/episodes/:episode_id/chapters`
- `PUT /api/:podcast_id/episodes/:episode_id/chapters`

Send `{ "chapters": [...] }` or a raw array. Omitting the array or sending another type → `422` without changing existing chapters.

`start_time` may be `HH:MM:SS`, `MM:SS`, or seconds. `url` and `link` are both accepted on write; the response always uses `url`.

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
Content-Type: application/json; charset=utf-8
```

## Example requests

```bash
curl -sS -X PUT "https://www.buzzsprout.com/api/PODCAST_ID/episodes/EPISODE_ID/chapters" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Accept: application/json" \
  -d '{"chapters":[{"title":"Intro","start_time":"00:00:00"},{"title":"Main","start_time":"00:01:30"}]}'
```

## CLI

```bash
buzzsprout chapters list 10 788881
buzzsprout chapters replace 10 788881 --body '[{"title":"Intro","start_time":"00:00:00"}]'
```
