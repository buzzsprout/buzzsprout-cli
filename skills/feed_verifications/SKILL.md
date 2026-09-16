---
name: buzzsprout-feed-verifications
description: Manage Buzzsprout RSS feed verification values (podcast verify tags). Create, update, or delete the verify value.
---

# Feed verifications

Manage verification values in the RSS feed (`purpose` is returned but cannot be set through this API). Writable fields: `value` and optional `expires_at`.

POST creates the podcast's generic `verify` value, or replaces the existing one.

## When to use

- Add an owner email / token so a directory can verify the feed.

## Endpoints

- `GET /api/:podcast_id/feed_verifications`
- `POST /api/:podcast_id/feed_verifications`
- `PATCH /api/:podcast_id/feed_verifications/:id`
- `DELETE /api/:podcast_id/feed_verifications/:id` → `204`

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
Content-Type: application/json; charset=utf-8
```

## Example requests

```bash
curl -sS -X POST "https://www.buzzsprout.com/api/PODCAST_ID/feed_verifications" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Accept: application/json" \
  -d '{"value":"owner@example.com","expires_at":"2027-09-01T00:00:00Z"}'
```

Missing `value` → `422` / `param: "value"`.

## CLI

```bash
buzzsprout feed-verifications list 10
buzzsprout feed-verifications create 10 --value owner@example.com
buzzsprout feed-verifications delete 10 7
```
