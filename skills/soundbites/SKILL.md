---
name: buzzsprout-soundbites
description: Create, inspect, or delete a Buzzsprout soundbite (short video clip) from processed episode audio.
---

# Soundbites

Create a short video clip from processed episode audio. Artwork is `episode` or `podcast` — no custom image. The API does not return a rendered video file; when `creating_video` is `false`, the clip is ready in Buzzsprout.

## When to use

- Kick off a square/portrait/landscape clip from a time range.
- Poll GET until `creating_video` is false.

`POST` returns `202 Accepted`. GET before a soundbite exists returns `404`. Audio not processed → `422` / `unprocessable`.

## Endpoints

- `POST /api/:podcast_id/episodes/:episode_id/soundbite`
- `GET /api/:podcast_id/episodes/:episode_id/soundbite`
- `DELETE /api/:podcast_id/episodes/:episode_id/soundbite` → `204`

Defaults: `start_time` 0, `duration` 30, `aspect_ratio` `square`, podcast artwork (anything other than `"episode"`). Optional styling: `background_color`, `text_color`, `wave_color`, `text_line_1`, `text_line_2`.

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
Content-Type: application/json; charset=utf-8
```

## Example requests

```bash
curl -sS -X POST "https://www.buzzsprout.com/api/PODCAST_ID/episodes/EPISODE_ID/soundbite" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Accept: application/json" \
  -d '{"start_time":10,"duration":15,"aspect_ratio":"square","artwork":"episode"}'
```

## CLI

```bash
buzzsprout soundbites create 10 788881 --start-time 10 --duration 15 --aspect-ratio square --artwork episode
buzzsprout soundbites show 10 788881
buzzsprout soundbites delete 10 788881
```
