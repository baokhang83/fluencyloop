# Releasing FluencyLoop

## Merging to `main` ships to everyone, immediately

`plugins/fluencyloop/hooks/refresh-marketplace.sh` runs on **every** `SessionStart`. It updates the
marketplace and then the plugin, unconditionally and unpinned — `claude plugin update` for Claude
Code, `codex plugin add` for Codex. Neither call names a version, and neither has a rollback path on
the user's side.

Both agents resolve the marketplace at the repository's **default branch**, which is `main`:

- `.claude-plugin/marketplace.json` uses `"source": "."` — the plugin content is whatever that
  checkout holds.
- `.agents/plugins/marketplace.json` uses `{"source": "local", "path": "./plugins/fluencyloop"}` —
  a path *inside* the cloned marketplace repo, with no ref field to pin. Codex takes the clone's
  default branch and there is no per-plugin override.

So `main` is not a development branch. **`main` is the release channel.** A commit that lands there
is running in other people's repositories by their next session. Treat every merge to `main` as a
release, and never merge partial work to it — there is no dual-mode or opt-in path, because the
update is silent and there is nothing for a user to opt into.

## Where work happens

`dev` is the long-lived development branch. Multi-release work — the 0.3 redesign in particular —
is merged there and only promoted to `main` when the whole thing is shippable.

    feature/<slug>  ->  dev  ->  main (= release)

Small, self-contained fixes may still go straight to `main` as their own release, the way 0.2.27
did. Anything that is one step of several does not.

Promoting `dev` is a fast-forward, so `main` stays linear and every release is a commit you can
name:

    git checkout dev && git rebase main   # keep the promotion a fast-forward
    git checkout main && git merge --ff-only dev

## Cutting a release

1. `.github/scripts/bump-version.sh <version>` — `plugins/fluencyloop/VERSION` is the single source
   of truth and the three JSON manifests are generated from it. CI fails on drift, because a
   mismatch breaks the update hook silently for everyone already installed.
2. Add the `CHANGELOG.md` entry.
3. Open the PR and let CI go green. The Windows jobs are not optional: the bash and PowerShell
   runtimes are two implementations of one contract, and a fix applied to only one of them ships a
   version that behaves differently per platform — see 0.2.26, whose `schema_version` marker reached
   no Windows install until 0.2.27.
4. Merge, then tag the merge commit:

       git tag -a v<version> -m "<version> — <summary>" && git push origin v<version>

## Rolling back

Users cannot pin or downgrade — the hook always takes the tip of `main`. A rollback is therefore a
new commit on `main`, not a revert of their install:

    git revert <bad-commit>          # or reset to the last good tag and force-push
    .github/scripts/bump-version.sh <next-patch>

Ship it as its own version. Rolling `main` back to an *earlier* version number leaves anyone who
already updated holding a version the manifest no longer offers, and the update hook has no reason
to move them off it.
