---
name: buzzsprout-fan-mail
description: List, publish, mark read, and block Buzzsprout fan mail (listener messages). Cannot create mail or send SMS replies.
---

# Fan mail

Inbound listener messages. You cannot create fan mail or send an SMS reply through this API.

## When to use

- Triage unread listener texts/voice transcripts.
- Publish a message, mark it read, or block a sender (no unblock endpoint).

## Endpoints

- `GET /api/:podcast_id/fan_mail` — unblocked messages, newest first
- `GET /api/:podcast_id/fan_mail/:id` — also marks the thread as read
- `PATCH /api/:podcast_id/fan_mail/:id` with `{ "published": true|false }`
- `POST /api/:podcast_id/fan_mail/:id/read`
- `POST /api/:podcast_id/fan_mail/:id/block`

## Auth headers

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
Content-Type: application/json; charset=utf-8
```

## Example requests

```bash
curl -sS -X PATCH "https://www.buzzsprout.com/api/PODCAST_ID/fan_mail/FAN_MAIL_ID" \
  -H "Authorization: Token token=YOUR_API_TOKEN" \
  -H "User-Agent: BuzzsproutCLI/0.1.0" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Accept: application/json" \
  -d '{"published":true}'
```

Fields: `status` (`unread`|`read`), `published`, `blocked`, `text`, `sender_info`, geo, `message_type` (`TextMessage`|`VoiceMessage`). Missing ids → `404`.

## CLI

```bash
buzzsprout fan-mail list 10
buzzsprout fan-mail show 10 501
buzzsprout fan-mail publish 10 501
buzzsprout fan-mail read 10 501
buzzsprout fan-mail block 10 501
```
