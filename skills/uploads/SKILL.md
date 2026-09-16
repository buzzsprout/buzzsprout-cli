---
name: buzzsprout-uploads
description: Attach audio or video to a Buzzsprout episode. Use for start upload, PUT file bytes, complete, abort, and multipart large files.
---

# Upload audio or video

Preferred way to add or replace episode media. Create the episode first. **Complete is required** — skipping it leaves the episode with no media.

## When to use

- Attach or replace audio/video after `episodes create`.
- Files over 5 GiB (eligible video) need `"multipart": true`.

## Endpoints

- `POST /api/:podcast_id/episodes/:episode_id/uploads` → `201` with `upload.id` + `upload_url` (or `parts`)
- `PUT` the exact bytes to `upload_url` / `parts[].url` — **do not** send Buzzsprout `Authorization`
- `POST /api/:podcast_id/episodes/:episode_id/uploads/:upload_id/complete`
- `DELETE /api/:podcast_id/episodes/:episode_id/uploads/:upload_id/abort`

URL-encode `upload_id` if it contains special characters. After complete, poll the episode until `duration` is not `-1`.

## Auth headers

Buzzsprout calls:

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
Content-Type: application/json; charset=utf-8
```

Storage `PUT`: no Authorization. Match `Content-Length` to the declared `byte_size` (or part `content_length`). Upload URLs expire after 6 hours.

## Example requests

```bash
# 1. Start
curl -sS -X POST "https://www.buzzsprout.com/api/PODCAST_ID/episodes/EPISODE_ID/uploads" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Accept: application/json" \
  -d '{"filename":"episode.m4a","type":"audio/mp4","byte_size":12345678}'

# 2. PUT bytes (no Authorization)
curl -sS -X PUT "UPLOAD_URL" -H "Content-Length: 12345678" --data-binary @episode.m4a

# 3. Complete
curl -sS -X POST "https://www.buzzsprout.com/api/PODCAST_ID/episodes/EPISODE_ID/uploads/UPLOAD_ID/complete" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Accept: application/json"
```

Start JSON fields: `filename`, `byte_size`, media type (`type` preferred; `media_type` / `content_type` aliases). Optional `"multipart": true`.

## CLI

```bash
buzzsprout uploads start 10 788881 --file ./episode.m4a
buzzsprout uploads complete 10 788881 UPLOAD_ID
buzzsprout uploads abort 10 788881 UPLOAD_ID
```

`uploads start --file` performs start → PUT → complete.
