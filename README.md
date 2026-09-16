# Buzzsprout CLI

A fun, agent-friendly command-line interface for the [Buzzsprout API](https://github.com/buzzsprout/buzzsprout-api). List podcasts, manage episodes, upload audio, and call the rest of the public API — with a first-run that actually feels like a first run.

Modeled on [basecamp-cli](https://github.com/robzolkos/ruby-basecamp-cli): Ruby gem, `bin/` + `lib/` + `skills/`, stdlib `Net::HTTP` (no Thor; that CLI uses a small custom dispatcher, and this one matches it).

## Features

- **First run** — braille startup animation of the Buzzsprout mark + wordmark (embedded in the CLI source), token prompt, live `GET /api/podcasts`, celebration, token saved to `~/.buzzsprout.json`
- **Token auth** — `Authorization: Token token=…` from **Profile → API** (not OAuth)
- **Identifiable User-Agent** — `BuzzsproutCLI/0.1.0` on every request
- **Rate limits** — 60 req/min; retries `429` with backoff
- **ETags** — sends `If-None-Match` on repeat GETs
- **Agent skills** — `skills/` with one skill per API resource, plus `buzzsprout skills install`

## Installation

Ruby 3.0+ is required. This GitHub repo is **private**: unauthenticated `raw.githubusercontent.com` (and the public API) **404**. Clone with your existing GitHub credentials, then run the installer.

```bash
git clone --depth 1 https://github.com/higher-pixels/buzzsprout-cli.git ~/.buzzsprout-cli
~/.buzzsprout-cli/script/install
buzzsprout login
```

SSH:

```bash
git clone --depth 1 git@github.com:higher-pixels/buzzsprout-cli.git ~/.buzzsprout-cli
~/.buzzsprout-cli/script/install
buzzsprout login
```

If you already have a checkout: `./script/install` from the repo root. The script checks for Ruby 3.0+ and symlinks `bin/buzzsprout` to `~/.local/bin` (or `~/bin` if that directory is already on PATH). It does not `sudo`. If `~/.buzzsprout-cli` already exists and is this repo, run the install script from that clone instead of cloning again.

A specific branch (until this lands on `main`, use the PR branch):

```bash
git clone --depth 1 -b cursor/buzzsprout-cli-3c1e https://github.com/higher-pixels/buzzsprout-cli.git ~/.buzzsprout-cli
~/.buzzsprout-cli/script/install
buzzsprout login
```

Authenticated one-liner if you have [`gh`](https://cli.github.com/) logged in (`gh auth status`). Quote the path so `?ref=` is not eaten by the shell. The piped script still `git clone`s, so GitHub git credentials (HTTPS or SSH) are required too:

```bash
gh api "repos/higher-pixels/buzzsprout-cli/contents/script/install?ref=main" --jq .content | base64 --decode | bash
```

Match `ref=` with `BUZZSPROUT_CLI_REF` when installing a non-default branch. Use `BUZZSPROUT_CLI_REPO=git@github.com:higher-pixels/buzzsprout-cli.git` if your `gh` is authenticated but `git clone` over HTTPS is not.

If this repo is ever public, unauthenticated raw curl would work. **While it is private, that URL 404s:**

```bash
# 404 while the repo is private — do not use this as the primary install
curl -fsSL https://raw.githubusercontent.com/higher-pixels/buzzsprout-cli/main/script/install | bash
```

Optional overrides: `BUZZSPROUT_CLI_HOME` (clone dir), `BUZZSPROUT_CLI_BIN` (where the executable goes), `BUZZSPROUT_CLI_REPO` (git remote), `BUZZSPROUT_CLI_REF` (branch or tag, default `main`).

### From source

```bash
git clone https://github.com/higher-pixels/buzzsprout-cli.git
cd buzzsprout-cli
bundle install
```

Then either:

- Run directly: `./bin/buzzsprout`
- Add to PATH: `export PATH="$PATH:/path/to/buzzsprout-cli/bin"`
- Install as a gem: `rake install` or `./script/install`

## First run

With no config yet, `buzzsprout` (or `buzzsprout login`) will:

1. Play a short braille animation of the Buzzsprout logo (sprout/bolt grows, then the “Buzzsprout” wordmark wipes in). The art is a constant in the Ruby source — no image files in the repo. On dark terminals the bolt and wordmark use bright green `#61D752`; on light terminals the wordmark stays dark `#214538`. Override with `BUZZSPROUT_THEME=dark` or `light` (`NO_COLOR` still disables color).
2. Prompt for your API token (**Profile → API** in Buzzsprout)
3. Test the connection:

   ```http
   GET https://www.buzzsprout.com/api/podcasts
   Authorization: Token token=YOUR_API_TOKEN
   User-Agent: BuzzsproutCLI/0.1.0
   Accept: application/json
   ```

4. On success: celebrate, list your podcasts, save the token to `~/.buzzsprout.json` (mode `0600`)
5. On failure: print a clear error and offer to retry / re-enter the token

```bash
buzzsprout login
buzzsprout login --no-animation
buzzsprout login --token "$BUZZSPROUT_API_TOKEN" --no-animation
```

Skip the animation with `--no-animation` or `BUZZSPROUT_NO_ANIMATION=1`.

## Authentication

| Source | Notes |
| --- | --- |
| `BUZZSPROUT_API_TOKEN` | Highest priority after a successful `login --token` save; never commit this |
| `~/.buzzsprout.json` | Written by `buzzsprout login` |
| `--token` | Login only, for non-interactive setup |

```json
{
  "api_token": "YOUR_API_TOKEN",
  "default_podcast_id": 10
}
```

```bash
buzzsprout status
buzzsprout use 10
buzzsprout logout
```

## Commands

Global flags: `--json`, `--body '{…}'`, `--file PATH`, `--dry-run`, `--podcast ID`, `--no-animation`.

### Podcasts

```bash
buzzsprout podcasts
buzzsprout podcasts show 10
buzzsprout podcasts update 10 --title "Life Empowerment"
```

### Episodes

```bash
buzzsprout episodes list 10
buzzsprout episodes show 10 788881
buzzsprout episodes create 10 --title "My episode" --private
buzzsprout episodes publish 10 788881
buzzsprout episodes unpublish 10 788881
```

### Uploads

Create the episode first. Complete is required or the episode has no media.

```bash
buzzsprout uploads start 10 788881 --file ./episode.m4a
```

That runs start → PUT bytes (no API token on the storage URL) → complete.

### Everything else

```bash
buzzsprout stats 10 --date 2026-09-12
buzzsprout team list 10
buzzsprout contributors list 10
buzzsprout brand-affiliations list 10
buzzsprout chapters list 10 788881
buzzsprout transcripts show 10 788881
buzzsprout listings list 10
buzzsprout podrolls list 10
buzzsprout feed-verifications list 10
buzzsprout fan-mail list 10
buzzsprout insertion-points list 10 788881
buzzsprout soundbites show 10 788881
```

`buzzsprout help` prints the full map. `--dry-run` prints the HTTP request without sending it (useful without live credentials).

## Skills for agents

Each major API resource has a skill under [`skills/`](skills/README.md): when to use it, endpoints, auth headers, example requests, and CLI mapping.

```bash
buzzsprout skills
buzzsprout skills path
buzzsprout skills install --dir ~/.cursor/skills
```

Copy or symlink into whatever directory your agent already loads (`~/.cursor/skills`, `~/.claude/skills`, `.cursor/skills` in a project). Details: [skills/README.md](skills/README.md).

## Environment

| Variable | Purpose |
| --- | --- |
| `BUZZSPROUT_API_TOKEN` | Token override |
| `BUZZSPROUT_PODCAST_ID` | Default podcast id |
| `BUZZSPROUT_CONFIG` | Config path (default `~/.buzzsprout.json`) |
| `BUZZSPROUT_API_BASE` | API base (default `https://www.buzzsprout.com/api`) |
| `BUZZSPROUT_NO_ANIMATION=1` | Skip the intro |
| `BUZZSPROUT_THEME` | `dark` or `light` for the intro. If unset: `COLORFGBG`, then OSC 11 on a TTY, otherwise **dark** (bright green `#61D752` for bolt + wordmark). Light terminals use `#214538` for the wordmark. |
| `NO_COLOR` / `BUZZSPROUT_NO_COLOR` | Disable ANSI color |

## Development

```bash
bundle install
bundle exec rake test
```

Tests use a local fake API (no real tokens). Do not put API tokens in this repo.

Endpoint shapes follow [buzzsprout/buzzsprout-api#56](https://github.com/buzzsprout/buzzsprout-api/pull/56).

## License

MIT
