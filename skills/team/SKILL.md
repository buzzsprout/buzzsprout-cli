---
name: buzzsprout-team
description: Manage Buzzsprout team members (login access). Use to list, invite, change role, or remove editors/admins. Not the same as contributors.
---

# Team

People with Buzzsprout **login** access. Not on-show credits (see `contributors`). All team endpoints require **admin or owner**. Editors receive `403` / `code: "forbidden"`.

## When to use

- Invite someone who should log into Buzzsprout.
- Change `editor` ↔ `admin`. `owner` cannot be assigned, changed, or removed. You cannot change or remove yourself.

## Endpoints

- `GET /api/:podcast_id/team`
- `POST /api/:podcast_id/team`
- `PATCH /api/:podcast_id/team/:id` — `:id` is the team entry id, not `user_id`
- `DELETE /api/:podcast_id/team/:id` → `204`

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
Content-Type: application/json; charset=utf-8
```

## Example requests

```bash
curl -sS -X POST "https://www.buzzsprout.com/api/PODCAST_ID/team" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Accept: application/json" \
  -d '{"name":"Pat Editor","email":"pat@example.com","role":"editor"}'
```

Missing `role` on create defaults to `editor`. Duplicate email → `422` / `param: "email"`.

## CLI

```bash
buzzsprout team list 10
buzzsprout team invite 10 --name "Pat Editor" --email pat@example.com --role editor
buzzsprout team update 10 42 --role admin
buzzsprout team delete 10 42
```
