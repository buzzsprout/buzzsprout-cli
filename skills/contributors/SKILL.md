---
name: buzzsprout-contributors
description: Manage Buzzsprout on-show credits (Host, Guest, Producer, …) and assign them to episodes. Separate from team login access.
---

# Contributors

On-show credits. They do **not** get a Buzzsprout login. Create on the podcast, then assign to episodes.

## When to use

- Add a guest/host credit.
- Assign or unassign a credit on one episode without deleting the contributor.

## Endpoints

- `GET|POST /api/:podcast_id/contributors`
- `GET|PATCH|DELETE /api/:podcast_id/contributors/:id`
- `POST /api/:podcast_id/episodes/:episode_id/contributors` with `{ "contributor_id": 123 }`
- `DELETE /api/:podcast_id/episodes/:episode_id/contributors/:id` — unassign only

Deleting a contributor removes them from **every** episode. Prefer unassign for a single episode.

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
Content-Type: application/json; charset=utf-8
```

## Example requests

```bash
curl -sS -X POST "https://www.buzzsprout.com/api/PODCAST_ID/contributors" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Accept: application/json" \
  -d '{"name":"Guest Star","role":"Guest","url":"https://example.com"}'
```

Roles: `Host`, `Co-Host`, `Producer`, `Editor`, `Guest` (case-insensitive on write). `bio` is HTML, 1000-character limit including tags.

## CLI

```bash
buzzsprout contributors list 10
buzzsprout contributors create 10 --name "Guest Star" --role Guest
buzzsprout contributors assign 10 788881 123
buzzsprout contributors unassign 10 788881 123
```
