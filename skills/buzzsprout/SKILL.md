---
name: buzzsprout
description: Buzzsprout API CLI overview. Use for login, token auth headers, first-run, rate limits, ETags, and choosing a resource skill (podcasts, episodes, uploads, stats, team, …).
---

# Buzzsprout CLI

Agent-friendly Ruby CLI for the Buzzsprout API. Prefer the `buzzsprout` executable over raw HTTP unless a flag is missing.

## When to use

- The user mentions Buzzsprout, podcast hosting, RSS, episodes, or their API token.
- You need to list shows, publish an episode, or call a documented API resource.

## Auth

Token auth (not OAuth). The user gets a token under **Profile → API** in Buzzsprout. **You (the agent) must not load that secret into context.**

### Agent rules

- Never read `~/.buzzsprout.json` (or `BUZZSPROUT_CONFIG`) to copy `api_token` into chat, logs, or curl.
- Never print, echo, or interpolate `BUZZSPROUT_API_TOKEN`.
- Authenticate with `buzzsprout login` (TTY prompt, no echo) or assume env/config is already set.
- Prefer the `buzzsprout` CLI over constructing HTTP. If you must show a header shape, keep the placeholder `YOUR_API_TOKEN` — never a real token.
- `buzzsprout status --json` reports `token_set: true` or `false`, not the secret. `--dry-run` prints `Token token=[REDACTED]`.

The CLI sends `Authorization: Token token=…` on API calls (never `?api_token=`). Header shape for docs only:

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
```

Resolution order inside the CLI (not for agents to read): env `BUZZSPROUT_API_TOKEN`, then the file written by `login`. `--token` on argv is login-only and can leak via process list/history — do not recommend it.

```bash
buzzsprout login                  # animation → prompt → GET /podcasts → picker if 2+ shows → save
buzzsprout login --no-animation
buzzsprout login --install-skills # also copy agent skills (no prompt)
buzzsprout login --no-skills      # skip the post-login skills offer
buzzsprout status
buzzsprout podcast use            # picker to change the saved podcast (or pass an id / --podcast / --in)
buzzsprout logout
```

First run with no args and no saved token starts login automatically. Config lives at `~/.buzzsprout.json` (mode `0600` on Unix). Do not open it for the token value. After auth succeeds, login may offer to install these skills into `~/.cursor/skills` (or `BUZZSPROUT_SKILLS_DIR` / `--dir`) unless they are already present.

## Base URL

- Account-level: `https://www.buzzsprout.com/api/podcasts`
- Podcast-scoped: `https://www.buzzsprout.com/api/:podcast_id/...`

Extensionless paths are canonical; `.json` is also accepted by the API.

## Rate limits and caching

- 60 requests per minute per token. `429` is retried with exponential backoff (or `Retry-After`).
- Store `ETag` and send `If-None-Match` on repeat GETs. `304` means use the cached body.
- Retry transient `5xx` on GET. Do not retry validation (`4xx` other than `429`) unchanged.

## Publish workflow

1. `buzzsprout podcasts` — note numeric `id`
2. `buzzsprout episodes create ID --title "…" --private`
3. `buzzsprout uploads start ID EPISODE_ID --file ./episode.m4a` (complete is required)
4. `buzzsprout episodes show ID EPISODE_ID` until `duration` is a positive integer
5. Optional chapters / contributors
6. `buzzsprout episodes publish ID EPISODE_ID`

## CLI map

| Resource | Command prefix | Skill |
| --- | --- | --- |
| Podcasts | `buzzsprout podcasts` | `podcasts` |
| Episodes | `buzzsprout episodes` | `episodes` |
| Uploads | `buzzsprout uploads` | `uploads` |
| Stats | `buzzsprout downloads` | `stats` |
| Team | `buzzsprout team` | `team` |
| Contributors | `buzzsprout contributors` | `contributors` |
| Brand affiliations | `buzzsprout brand-affiliations` | `brand_affiliations` |
| Chapters | `buzzsprout chapters` | `chapters` |
| Transcripts | `buzzsprout transcripts` | `transcripts` |
| Listings | `buzzsprout listings` | `listings` |
| Podrolls | `buzzsprout podrolls` | `podrolls` |
| Feed verifications | `buzzsprout feed-verifications` | `feed_verifications` |
| Fan mail | `buzzsprout fan-mail` | `fan_mail` |
| Insertion points | `buzzsprout insertion-points` | `insertion_points` |
| Soundbites | `buzzsprout soundbites` | `soundbites` |

`--json` prints the API payload. `--dry-run` prints the request without sending it. `--body '{…}'` supplies a JSON body. `--podcast ID` / `--in ID` selects a podcast for this invocation without the interactive picker. A saved `default_podcast_id` is reused until `buzzsprout podcast use`. `--json` and `BUZZSPROUT_NONINTERACTIVE=1` never open the picker.

## Load this skill pack

```bash
buzzsprout skills install --dir ~/.cursor/skills
# or accept the prompt after `buzzsprout login`
```

See `skills/README.md` in the repo for Cursor / Claude Code paths.
