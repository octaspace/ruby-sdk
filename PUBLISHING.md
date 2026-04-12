# Packaging and Publishing Guide

How to validate, build, and publish the `octaspace` gem.

## 1. Pre-release Checklist

```bash
bundle exec rake test          # all tests pass
bundle exec standardrb         # zero linting violations
gem build octaspace.gemspec    # builds without warnings
```

## 2. Local Verification

Install the built gem outside the project and confirm it loads correctly:

```bash
gem install ./octaspace-0.1.0.gem
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
  gem unpack octaspace-0.1.0.gem --target=/tmp/octaspace-check
  find /tmp/octaspace-check -type f | sort
  rm -rf /tmp/octaspace-check
  ```
- **Check metadata that RubyGems.org will display:**
  ```bash
  gem specification octaspace-0.1.0.gem
  ```
- **Install and test in a clean environment:**
  ```bash
  gem install ./octaspace-0.1.0.gem
  ruby -e "require 'octaspace'; p OctaSpace::Client.new; puts OctaSpace::VERSION"
  ```

## 4. Publish to RubyGems.org

```bash
gem push octaspace-0.1.0.gem
```

You will be prompted for credentials on first push. The API key is saved to `~/.gem/credentials`.

## 5. Post-publish

- Verify the gem page at [rubygems.org/gems/octaspace](https://rubygems.org/gems/octaspace).
- Tag the release: `git tag v0.1.0 && git push --tags`.
- Bump `lib/octaspace/version.rb` for the next development cycle.
