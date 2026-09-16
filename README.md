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

1. Play a short braille animation of the Buzzsprout logo (sprout/bolt grows, then the “Buzzsprout” wordmark wipes in). The finale stays on screen while auth continues below it. The art is a constant in the Ruby source — no image files in the repo. On dark terminals the bolt and wordmark use bright green `#61D752`; on light terminals the wordmark stays dark `#214538`. Override with `BUZZSPROUT_THEME=dark` or `light` (`NO_COLOR` still disables color).
2. Prompt for your API token (**Profile → API** in Buzzsprout)
3. Test the connection:

   ```http
   GET https://www.buzzsprout.com/api/podcasts
   Authorization: Token token=YOUR_API_TOKEN
   User-Agent: BuzzsproutCLI/0.1.0
   Accept: application/json
   ```

4. On success: a blank line, then **Authentication Successful** in the logo green `#61D752` (`NO_COLOR` / non-TTY: plain text), then **pick a podcast** if you have more than one (arrow keys, type to search, Enter), and save the token to `~/.buzzsprout.json` (mode `0600`)
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
buzzsprout podcast use            # interactive picker, then save as default
buzzsprout podcast use 10         # or pass the id / --podcast / --in
buzzsprout logout
```

## Podcast selection

Any command that needs a podcast id goes through the same resolver:

1. **Explicit** — positional id, `--podcast ID`, `--in ID`, or `BUZZSPROUT_PODCAST_ID` (this invocation only)
2. **Saved** — `default_podcast_id` in `~/.buzzsprout.json` is reused with no picker
3. **TTY, none saved** — vertical list (`GET /api/podcasts`, ↑/↓, type to search, Enter). The choice is saved. A single podcast auto-selects and is saved. The list redraws in place (no stacked frames).
4. **Noninteractive, none saved** — `--json`, `BUZZSPROUT_NONINTERACTIVE=1`, or no TTY: error with “pass `--podcast ID` or run `buzzsprout podcast use`”

Change the saved podcast with `buzzsprout podcast use` (picker) or `buzzsprout podcast use 10`. Esc / Ctrl-C cancels the picker. Agents never block on it.

```bash
buzzsprout episodes list --podcast 10
buzzsprout episodes list --in 10
buzzsprout episodes list              # saved podcast, or picker if none is set
buzzsprout podcast use                # pick a different saved podcast
```

## Commands

Global flags: `--json`, `--body '{…}'`, `--file PATH`, `--dry-run`, `--podcast ID` (alias `--in`), `--no-animation`.

### Podcasts

```bash
buzzsprout podcasts
buzzsprout podcast use
buzzsprout podcast use 10
buzzsprout podcasts show 10
buzzsprout podcasts update 10 --title "Life Empowerment"
```

### Episodes

```bash
buzzsprout episodes list 10
buzzsprout episodes list              # saved podcast, or picker if none is set
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

### Downloads

Date is required (no default). `today` and `yesterday` are local calendar dates; `stats` is an alias.

```bash
buzzsprout downloads today
buzzsprout downloads yesterday
buzzsprout downloads 2026-09-01
buzzsprout episode 788881 downloads today
buzzsprout episode 788881 downloads yesterday
buzzsprout episode 788881 downloads 2026-09-01
```

### Everything else

```bash
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
| `BUZZSPROUT_PODCAST_ID` | Explicit podcast id for this process (skips the picker) |
| `BUZZSPROUT_NONINTERACTIVE=1` | Never open the podcast picker |
| `BUZZSPROUT_CONFIG` | Config path (default `~/.buzzsprout.json`) |
| `BUZZSPROUT_API_BASE` | API base (default `https://www.buzzsprout.com/api`) |
| `BUZZSPROUT_NO_ANIMATION=1` | Skip the intro |
| `BUZZSPROUT_THEME` | `dark` or `light` for the intro. If unset: `COLORFGBG`, then a best-effort OSC 11 query **only** on a raw TTY (skipped if that would leak). Otherwise **dark** (bright green `#61D752` for bolt + wordmark). Light terminals use `#214538` for the wordmark. |
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
