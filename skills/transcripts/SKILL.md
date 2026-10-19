---
name: buzzsprout-transcripts
description: Manage Buzzsprout public transcripts and high-fidelity segment transcripts for an episode.
---

# Transcripts

Two separate resources:

1. **High-fidelity** — Buzzsprout-generated segments (word-level). GET/PUT only; cannot create or delete.
2. **Custom public** — a file you upload to replace what is shown publicly.

Uploading a custom transcript does not start Buzzsprout transcription. Deleting custom does not remove high-fidelity.

## When to use

- Fetch the public transcript download URL.
- Replace the editable high-fidelity segment array.
- Upload an `.srt` or JSON transcript file.

## Endpoints

- `GET /api/:podcast_id/episodes/:episode_id/transcript`
- `POST /api/:podcast_id/episodes/:episode_id/transcript` (multipart `transcript_file` + `transcript_format` = `srt`|`json`)
- `DELETE /api/:podcast_id/episodes/:episode_id/transcript`
- `GET /api/:podcast_id/episodes/:episode_id/high_fidelity_transcript`
- `PUT|PATCH /api/:podcast_id/episodes/:episode_id/high_fidelity_transcript` — raw segment array, not wrapped

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
```

JSON writes for high-fidelity: `Content-Type: application/json; charset=utf-8`. Custom upload is multipart.

## Example requests

```bash
curl -sS -X POST "https://www.buzzsprout.com/api/PODCAST_ID/episodes/EPISODE_ID/transcript" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Accept: application/json" \
  -F "transcript_file=@episode.srt" \
  -F "transcript_format=srt"
```

Segments: required `start_time` (seconds) and `body`; optional `end_time`, `speaker`, `type` (`text`|`punc`).

## CLI

```bash
buzzsprout transcripts show 10 788881
buzzsprout transcripts upload 10 788881 --file episode.srt --transcript-format srt
buzzsprout transcripts high-fidelity 10 788881
buzzsprout transcripts replace-high-fidelity 10 788881 --body '[{"start_time":0,"end_time":1.2,"body":"Hello"}]'
buzzsprout transcripts delete 10 788881
```
