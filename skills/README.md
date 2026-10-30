# Skills for agents

This directory contains agent skills for the Buzzsprout API. Each folder is a skill an agent can load: when to use it, the HTTP endpoints, required headers, example requests, and the matching `buzzsprout` CLI command.

Layout matches [basecamp-cli](https://github.com/robzolkos/ruby-basecamp-cli) (`skills/<name>/SKILL.md`), with **one skill per major resource** plus an overview skill.

| Skill | Use it for |
| --- | --- |
| [`buzzsprout`](buzzsprout/SKILL.md) | Auth, first run, headers, rate limits, CLI map |
| [`podcasts`](podcasts/SKILL.md) | List / show / update shows |
| [`episodes`](episodes/SKILL.md) | Create, inspect, publish episodes |
| [`uploads`](uploads/SKILL.md) | Attach audio or video (start → PUT → complete) |
| [`stats`](stats/SKILL.md) | Download totals for one date (`buzzsprout downloads`) |
| [`team`](team/SKILL.md) | People with Buzzsprout login access |
| [`contributors`](contributors/SKILL.md) | On-show credits (Host, Guest, …) |
| [`brand_affiliations`](brand_affiliations/SKILL.md) | Sponsor / affiliate links |
| [`chapters`](chapters/SKILL.md) | Replace an episode chapter list |
| [`transcripts`](transcripts/SKILL.md) | Public and high-fidelity transcripts |
| [`listings`](listings/SKILL.md) | Directory status (`listings Apple url`) and one-click submit |
| [`podrolls`](podrolls/SKILL.md) | Recommended podcasts in RSS |
| [`feed_verifications`](feed_verifications/SKILL.md) | RSS feed verification values |
| [`fan_mail`](fan_mail/SKILL.md) | Listener messages |
| [`insertion_points`](insertion_points/SKILL.md) | Mid-roll timestamps |
| [`soundbites`](soundbites/SKILL.md) | Short video clips from episode audio |

API shapes follow [buzzsprout/buzzsprout-api#56](https://github.com/buzzsprout/buzzsprout-api/pull/56).

## Install or refresh

```bash
buzzsprout skills install
```

Installs into `~/.cursor/skills` and `~/.claude/skills` when the corresponding agent directory exists. If neither exists, choose a directory explicitly. Local Claude Code reads these skills; Cowork and cloud sessions need skills configured separately in Claude.

```bash
buzzsprout skills install --dir ~/.claude/skills
buzzsprout skills install --dir .claude/skills
```

`--dir` takes precedence over `BUZZSPROUT_SKILLS_DIR`; either overrides automatic detection. Login offers installation when any detected destination is missing skills or has outdated content. `--install-skills` refreshes without prompting; `--no-skills` skips the offer. Noninteractive and JSON login skip the prompt.

Resource directories are namespaced, for example `buzzsprout-stats`. The overview remains `buzzsprout`. Previous owned folders, including old unprefixed installations, are archived in `buzzsprout-skill-backups` alongside the destination skills directory. Unrelated skills are preserved; conflicts in namespaced directories are reported instead of overwritten.

Load the `buzzsprout` overview first, followed by the resource skill needed for the task. `buzzsprout skills path` prints the bundled source location.

## Conventions every skill assumes

Prefer `buzzsprout …` over raw HTTP. **Never** read `~/.buzzsprout.json` for the token, **never** echo `BUZZSPROUT_API_TOKEN`, and **never** paste a real token into curl or chat. Header shape for documentation only (`YOUR_API_TOKEN` is a placeholder):

```text
Authorization: Token token=YOUR_API_TOKEN
User-Agent: BuzzsproutCLI/0.1.0
Accept: application/json
```

- Base URL: `https://www.buzzsprout.com/api`
- Token from **Profile → API**, stored by `buzzsprout login` or the env var — never commit tokens.
- Identifiable `User-Agent` on every request (generic library defaults may be blocked).
- JSON writes: `Content-Type: application/json; charset=utf-8`
- Rate limit: 60 requests / minute; retry `429` with backoff.
- When a response has `ETag`, send it back as `If-None-Match`.
