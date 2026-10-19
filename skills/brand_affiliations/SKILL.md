---
name: buzzsprout-brand-affiliations
description: Manage Buzzsprout sponsor or affiliate links and assign them to episodes. Assigned links are appended to the episode description in RSS.
---

# Brand affiliations

Sponsor and affiliate links for a podcast. Create on the show, then assign to episodes.

## When to use

- Add a promo / affiliate headline + URL.
- Attach or remove a link on a single episode.

## Endpoints

- `GET|POST /api/:podcast_id/brand_affiliations`
- `GET|PATCH|DELETE /api/:podcast_id/brand_affiliations/:id`
- `POST /api/:podcast_id/episodes/:episode_id/brand_affiliations` with `{ "brand_affiliation_id": 123 }`
- `DELETE /api/:podcast_id/episodes/:episode_id/brand_affiliations/:id`

Deleting an affiliation removes it from **every** episode. `artwork` is an optional image file on create/update (multipart).

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
Content-Type: application/json; charset=utf-8
```

## Example requests

```bash
curl -sS -X POST "https://www.buzzsprout.com/api/PODCAST_ID/brand_affiliations" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Accept: application/json" \
  -d '{"headline":"Acme","description":"10% off with code PODCAST","url":"https://acme.example"}'
```

Missing `headline` → `422` / `param: "headline"`.

## CLI

```bash
buzzsprout brand-affiliations list 10
buzzsprout brand-affiliations create 10 --headline Acme --url https://acme.example
buzzsprout brand-affiliations assign 10 788881 45
```
