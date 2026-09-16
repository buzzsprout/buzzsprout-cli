---
name: buzzsprout-listings
description: Inspect Buzzsprout directory listing status and submit remaining one-click directories. Submit requires admin or owner.
---

# Listings

Directory listings for a podcast. There is no directory search. GET every directory, inspect `status`, then submit remaining one-click directories in one request.

## When to use

- See Apple / Spotify / etc. listing state (`listed`, `submitted`, `unlisted`, `failed`).
- Submit all remaining one-click directories (admin/owner only).

Pandora is omitted. Unlisted directories that have never been submitted have `id: null`.

## Endpoints

- `GET /api/:podcast_id/listings`
- `POST /api/:podcast_id/listings/submit_all` → `202 Accepted`

Submit requires a verified email and a podcast with a published episode, artwork, description, author, and category — otherwise `422` / `code: "ineligible"`. Editors → `403` / `forbidden`.

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
```

## Example requests

```bash
curl -sS -X POST "https://www.buzzsprout.com/api/PODCAST_ID/listings/submit_all" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Accept: application/json"
```

## CLI

```bash
buzzsprout listings list 10
buzzsprout listings submit-all 10
```
