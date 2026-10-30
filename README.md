# Buzzsprout CLI

A fun, agent-friendly command-line interface for the [Buzzsprout API](https://github.com/buzzsprout/buzzsprout-api). List podcasts, manage episodes, upload audio, and call the rest of the public API — with a first-run that actually feels like a first run.

Modeled on [basecamp-cli](https://github.com/robzolkos/ruby-basecamp-cli): Ruby gem, `bin/` + `lib/` + `skills/`, stdlib `Net::HTTP` (no Thor; that CLI uses a small custom dispatcher, and this one matches it).

## Features

- **First run** — braille startup animation of the Buzzsprout mark + wordmark (embedded in the CLI source), token prompt, live `GET /api/podcasts`, celebration, token saved to `~/.buzzsprout.json`
- **Browser login** — OAuth with automatic refresh; API tokens remain supported for scripts
- **Identifiable User-Agent** — `BuzzsproutCLI/0.1.0` on every request
- **Rate limits** — 60 req/min; retries `429` with backoff
- **ETags** — sends `If-None-Match` on repeat GETs
- **Agent skills** — `skills/` with one skill per API resource, plus `buzzsprout skills install`

## Installation

On macOS or Linux, install Ruby 3.0+ and Git, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/higher-pixels/buzzsprout-cli/main/script/install | bash
buzzsprout login
```

The repository is public; no GitHub account is required. The installer clones into `~/.buzzsprout-cli` and links `buzzsprout` into `~/.local/bin` (or `~/bin` if already on PATH). Follow any PATH instructions it prints. It does not use `sudo`. On Windows, use WSL with Ruby and Git installed.

To inspect the code before installing:

```bash
git clone https://github.com/higher-pixels/buzzsprout-cli.git ~/.buzzsprout-cli
~/.buzzsprout-cli/script/install
buzzsprout login
```

If you already have a checkout, run `./script/install` from its root.

### Updating

```bash
buzzsprout update                  # update CLI and refresh agent skills
buzzsprout update --check          # check without installing
buzzsprout update --check --json   # machine-readable check for AI assistants
```

Updates follow `main`, so changes to commands, the public OAuth client ID, and skills are detected even when the version number hasn't changed. The updater only fast-forwards clean installations of the official repository on `main`; it refuses local edits, other branches, and divergent history. Your login and saved podcast are preserved. Gem installations should use `gem update buzzsprout-cli` instead.

Skills refresh in detected Claude Code and Cursor directories, or the destination selected by `BUZZSPROUT_SKILLS_DIR` / `--dir`. For a custom location, run `buzzsprout update --dir PATH`. Previous skill copies are backed up. Start a new AI session after refreshing skills. If the skill refresh fails, the CLI update remains installed and the command reports how to retry.

Normal commands check GitHub at most once a day and print update notices on stderr, preserving JSON stdout. Checks have a three-second network timeout; offline or rate-limited checks do not fail the command. Automatic checks are skipped in CI, for development/dirty checkouts, and when `BUZZSPROUT_NO_UPDATE_CHECK=1`. Explicit `update --check` always requests a fresh result. Nothing updates automatically.

Older installations without the update command can be updated from a clean `main` checkout with `git pull --ff-only`, then `./script/install` and `buzzsprout skills install`.

Installer overrides: `BUZZSPROUT_CLI_HOME` (clone directory), `BUZZSPROUT_CLI_BIN` (executable directory), `BUZZSPROUT_CLI_REPO` (Git remote), and `BUZZSPROUT_CLI_REF` (branch or tag, default `main`).

### From source

```bash
git clone https://github.com/higher-pixels/buzzsprout-cli.git
cd buzzsprout-cli
bundle install
```

Then either:

- Run directly: `./bin/buzzsprout`
- Add to PATH: `export PATH="$PATH:/path/to/buzzsprout-cli/bin"`
- Install as a gem: `rake install`
- Link this checkout onto PATH: `./script/install`

## First run

Run `buzzsprout login` to connect your account:

1. The CLI prints an authorization link and opens it in your browser.
2. Sign in to Buzzsprout and approve access. Use a browser on the same computer as the CLI.
3. Return to the terminal. The CLI checks the connection, saves your credentials privately, and helps you choose a default podcast.
4. If agent skills are not installed, the CLI offers to install them. Use `--install-skills` to install without prompting or `--no-skills` to skip.

Use `buzzsprout login --no-browser` to open the printed link yourself. Authorization times out after five minutes; rerun login if needed.

## Authentication

OAuth access tokens refresh automatically. If the connection has been revoked or cannot be refreshed, run `buzzsprout login` again. Failed login attempts leave existing saved credentials intact.

Existing API-token configurations continue to work. For token login, run `buzzsprout login --api-token` and enter your token from **Profile → API** at the hidden prompt. `BUZZSPROUT_API_TOKEN` takes precedence over saved credentials, including OAuth. It also selects token authentication when running login. This remains useful for scripts or remote sessions where browser callbacks cannot reach the CLI.

Credentials are saved in `~/.buzzsprout.json` with mode `0600` on Unix. Never copy this file into a chat or commit it. Tokens are redacted from status, dry-run output, and API errors. `status` shows the active authentication method.

`buzzsprout logout` revokes the saved OAuth connection and removes local credentials and the default podcast. `--local-only` removes only the local copy; you can disconnect the app from your Buzzsprout profile. API-token logout only removes the saved token; an environment variable remains active until you unset it.

**Agents:** do not read the credential file or print `BUZZSPROUT_API_TOKEN`. Use the authenticated CLI instead of constructing requests with real tokens.

```bash
buzzsprout status                 # token_set: true — never the secret
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

Global flags: `--json`, `--body '{…}'`, `--file PATH`, `--dry-run`, `--podcast ID` (alias `--in`), `--no-animation`, `--install-skills`, `--no-skills`.

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
buzzsprout listings
buzzsprout listings Apple url
buzzsprout listings Apple status
buzzsprout listings submit-all
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

`buzzsprout skills install` installs or refreshes skills for detected Cursor and Claude Code installations (`~/.cursor` and `~/.claude`). Login offers the same installation when skills are missing or outdated. `BUZZSPROUT_SKILLS_DIR` or `--dir` selects a single destination instead. Resource folders use names such as `buzzsprout-stats`; previous Buzzsprout folders are archived beside the skills directory, and unrelated skills are preserved. Details: [skills/README.md](skills/README.md).

## Environment

| Variable | Purpose |
| --- | --- |
| `BUZZSPROUT_API_TOKEN` | Token override (never print) |
| `BUZZSPROUT_PODCAST_ID` | Explicit podcast id for this process (skips the picker) |
| `BUZZSPROUT_NONINTERACTIVE=1` | Never open the podcast picker or the post-login skills prompt |
| `BUZZSPROUT_CONFIG` | Config path (default `~/.buzzsprout.json`) |
| `BUZZSPROUT_SKILLS_DIR` | Override detected agent skills directories |
| `BUZZSPROUT_API_BASE` | API base (default `https://www.buzzsprout.com/api`) |
| `BUZZSPROUT_NO_ANIMATION=1` | Skip the intro |
| `BUZZSPROUT_NO_UPDATE_CHECK=1` | Disable automatic update checks |
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
