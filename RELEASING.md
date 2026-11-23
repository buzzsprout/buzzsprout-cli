# Releasing

Tagged releases publish the gem, a GitHub Release, and a Homebrew formula. Git installations keep updating from `main` with `buzzsprout update`.

`script/release` bumps `lib/buzzsprout/version.rb`, updates the `BuzzsproutCLI/` version in the README and skills, commits, and creates an annotated tag. The tag is `v` plus the version, such as `v0.1.1`.

Pushing that tag runs [`.github/workflows/release.yml`](.github/workflows/release.yml):

1. The test matrix from [`.github/workflows/test.yml`](.github/workflows/test.yml) runs on Ruby 3.0, 3.2, and 3.3.
2. The workflow builds the gem and `script/verify-gem` checks that it contains the `buzzsprout` executable and every bundled skill.
3. A GitHub Release is created with generated notes and the gem attached.
4. Trusted publishing pushes the gem to RubyGems.org. That is what `gem install buzzsprout-cli` and `mise use -g gem:buzzsprout-cli` install.
5. After the gem publish, the workflow builds a Homebrew formula with `script/homebrew-formula` and attaches `buzzsprout-cli.rb` to the same release. It then opens or updates a version-specific PR against the Buzzsprout Homebrew tap.

## One-time RubyGems setup

Do this once, after this workflow is on `main` and before the first tag. No RubyGems API key is stored in GitHub.

1. Create a GitHub Environment named `release` (Settings → Environments). The workflow's publish job uses that name, and the trusted publisher must use the same name.
2. Sign in to RubyGems.org and open [pending trusted publishers](https://rubygems.org/profile/oidc/pending_trusted_publishers). The gem does not exist yet, so the first publish uses a pending publisher.
3. Create a pending publisher:
   - Gem: `buzzsprout-cli`
   - Repository owner: `buzzsprout`
   - Repository name: `buzzsprout-cli`
   - Workflow filename: `release.yml`
   - Environment: `release`
4. Create that publisher when you are ready to tag the first release. If the publish job reports that the publisher is unknown, create the pending publisher again and re-run the workflow.

After the first successful push, RubyGems turns the pending publisher into the gem's trusted publisher and makes that account an owner.

## One-time Homebrew setup

Create the public `buzzsprout/homebrew-tap` repository using `brew tap-new buzzsprout/homebrew-tap` and push its generated workflows. Enable GitHub Actions so the tap tests formula PRs. See [Homebrew’s tap guide](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap).

In the CLI repository, add an Actions secret named `HOMEBREW_TAP_TOKEN`. Use a fine-grained GitHub token scoped to the tap repository with **Contents** and **Pull requests** read/write. The workflow uses it to push the formula branch and open the tap PR.

## Cut a release

From a clean `main` checkout:

```bash
script/release 0.1.1
git push --atomic origin HEAD v0.1.1
```

`script/release 0.1.1 --push` pushes `main` and the tag. The version must be greater than the current `Buzzsprout::VERSION`. The workflow refuses a tag that does not match the gem version.

## Homebrew

The formula is attached after RubyGems publish. It builds from the tag archive, depends on Homebrew Ruby, and installs the `buzzsprout` executable. Review the tap PR and merge it after its install and formula tests pass. Users can then run `brew install buzzsprout/tap/buzzsprout-cli`. If the tap step fails, fix the tap configuration and re-run the failed job for the same tag.

To regenerate the formula for a tag that is already on GitHub:

```bash
curl -fsSL -o source.tar.gz https://github.com/buzzsprout/buzzsprout-cli/archive/refs/tags/v0.1.1.tar.gz
shasum -a 256 source.tar.gz
script/homebrew-formula 0.1.1 <sha256>
```
