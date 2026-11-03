# Working with the `next` branch

`next` is the branch that moves the SDK to the new OctaSpace API (test stand `https://api-dev.octa.space`).
All changes for the new API go to `next` as pull requests; merging `next → main` is a separate decision,
made when the new API reaches production. `main` stays the branch of the current (legacy) SDK and its hotfixes.
Cube, go-sdk, js-sdk and octa-cli work the same way.

The default branch on GitHub is **`main`**. A PR opened without an explicit base therefore targets `main`,
not `next`.

## `main` and `next`, step by step

| Step | Working with `main` | Working with `next` |
|---|---|---|
| Update branches | `git fetch origin` | `git fetch origin` (same) |
| Switch to the base branch | `git switch main` | `git switch next` |
| Pull the latest code | `git pull` | `git pull` (same; `next` tracks `origin/next`) |
| New task branch | `git switch -c feat/x` (from `main`) | `git switch -c feat/x origin/next` ← **the key difference** |
| Commit | `git add …` → `git commit` | same |
| First push of the branch | `git push -u origin feat/x` | same (push the task branch, not `next`) |
| Catch up with the base | `git rebase origin/main` | `git rebase origin/next` |
| PR with `gh` | `gh pr create` | `gh pr create --base next` ← **required** |
| PR on the website | base `main` is preselected | change **base: main → next** by hand |
| Branch diff against the base | `git diff main...HEAD` | `git diff origin/next...HEAD` |
| After the PR is merged | `git switch main && git pull` | `git switch next && git pull` |

`git switch -c feat/x origin/next` creates the task branch straight from the remote `next`,
even if you are on `main` and have no local `next`. The branch tracks `origin/next` at first;
the first `git push -u origin feat/x` switches it to its own remote branch.

## Typical task cycle

```bash
git fetch origin
git switch -c feat/my-task origin/next   # from a fresh next, even when you are on main
# ... changes ...
bundle exec rake test && bundle exec standardrb
git add -A && git commit -m "…"
git push -u origin feat/my-task
gh pr create --base next                 # without --base the PR opens against main
```

If something was merged into `next` while you were working, update the branch before the PR:

```bash
git fetch origin
git rebase origin/next
git push --force-with-lease              # a plain push is refused after a rebase
```

## Dependent PRs (a stack)

When task B builds on task A that is not merged yet, create branch B from A and open the PR
with base A: `gh pr create --base feat/a`. The PR then shows only B's changes.

⚠️ **Do not delete branch A when merging it** (`gh pr merge --delete-branch` or the
"Delete branch" button) while PR B points at it: GitHub **closes** PR B instead of retargeting it.
Merge the stack one PR at a time, in this order:

```bash
gh pr merge <A> --merge                 # without --delete-branch
gh pr edit <B> --base next              # retarget the next PR
git push origin --delete feat/a         # now branch A can be deleted
```

If PR B was closed anyway: restore branch A at its last commit
(`git push origin <sha>:refs/heads/feat/a`), then `gh pr reopen <B>` and
`gh pr edit <B> --base next`.

## Easy mistakes

1. **The PR opened against `main`.** `--base next` was forgotten or the base was not changed on the
   website, so the PR shows the whole difference between `next` and `main`.
   Fix: `gh pr edit <N> --base next`.
2. **The branch was created from `main`.** `git switch -c feat/x` while on `main` branches off `main`,
   and a PR into `next` drags in extra commits. Always name the base explicitly (`origin/next`)
   instead of relying on the current branch.
   Fix: `git rebase --onto origin/next origin/main feat/x`.
3. **Pushing straight to `next`.** Push only task branches; changes reach `next` through PRs,
   just like `main`.
4. **Hotfixes on `main` never reach `next`.** Urgent fixes to the legacy SDK go in a branch from
   `main` with a PR into `main`. So that they are not lost, merge `main` into `next` from time to time
   in a separate PR:

   ```bash
   git switch -c chore/sync-main-into-next origin/next
   git merge origin/main
   git push -u origin chore/sync-main-into-next
   gh pr create --base next
   ```

5. **A stale local `next`.** It only moves on `git pull`. For new branches and rebases it is safer
   to use `origin/next` right after `git fetch`.

## CI and releases

- CI (`.github/workflows/ci.yml`) runs on pushes to `main` and `next` and on every PR, stacked ones included.
- Dependabot opens update PRs against `next` (`target-branch` in `.github/dependabot.yml`).
  After `next` is merged into `main`, set `target-branch: main` again.
- The gem is not published to RubyGems from `next` until the new API reaches production.

## If `next` lives for a long time

The default branch on GitHub (Settings → Branches) can be switched to `next`: PRs then target it
by default and mistake 1 goes away. This changes the default base for the whole team, so it is a
team decision, not one developer's.
