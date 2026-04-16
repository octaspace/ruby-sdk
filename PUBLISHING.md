# Packaging and Publishing Guide

How to validate, build, and publish the `octaspace` gem.

Important release policy for this repository:

- there is no GitHub Actions workflow that publishes to RubyGems automatically
- publish only after the feature PR is reviewed, polished, and merged into `main`
- publish from a clean local checkout of `main`
- do not use `rake release` in this repository; build, push, tag, and release explicitly as separate manual steps

## 0. Release Sequence

1. Finish the feature branch work and merge the PR into `main`.
2. Switch to `main` locally and pull the merged commit.
3. Update `CHANGELOG.md` and bump `lib/octaspace/version.rb` if that was not already done in the merged branch.
4. Run verification locally.
5. Build the gem.
6. Push the gem to RubyGems manually.
7. Tag the exact published commit and push the tag.
8. Create the GitHub Release manually from that tag.

## 1. Pre-release Checklist

```bash
git switch main
git pull --ff-only
bundle exec rake test          # all tests pass
bundle exec standardrb         # zero linting violations
gem build octaspace.gemspec    # builds without warnings
```

## 2. Local Verification

Install the built gem outside the project and confirm it loads correctly:

```bash
gem install ./octaspace-0.2.0.gem
ruby -e "require 'octaspace'; p OctaSpace::Client.new"
```

Or interactively:

```bash
irb
> require 'octaspace'
> OctaSpace::Client.new                    # public endpoints (no key)
> OctaSpace::Client.new(api_key: "token")  # authenticated client
```

## 3. Pre-publish Dry Run

There is no public staging server for RubyGems (test.rubygems.org was shut down).
Use these alternatives to verify the gem before publishing:

- **Inspect gem contents:**
  ```bash
  gem unpack octaspace-0.2.0.gem --target=/tmp/octaspace-check
  find /tmp/octaspace-check -type f | sort
  rm -rf /tmp/octaspace-check
  ```
- **Check metadata that RubyGems.org will display:**
  ```bash
  gem specification octaspace-0.2.0.gem
  ```
- **Install and test in a clean environment:**
  ```bash
  gem install ./octaspace-0.2.0.gem
  ruby -e "require 'octaspace'; p OctaSpace::Client.new; puts OctaSpace::VERSION"
  ```

## 4. Publish to RubyGems.org

```bash
gem push octaspace-0.2.0.gem
```

You will be prompted for credentials on first push. The API key is saved to `~/.gem/credentials`.

## 5. Post-publish

- Verify the gem page at [rubygems.org/gems/octaspace](https://rubygems.org/gems/octaspace).
- Tag the exact published commit: `git tag v0.2.0 && git push origin v0.2.0`.
- Create the GitHub Release manually from tag `v0.2.0`.
- Bump `lib/octaspace/version.rb` for the next development cycle in a follow-up commit.
