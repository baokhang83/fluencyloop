# Releasing FluencyLoop

`main` is development. **`stable` is what installed users run.**

The marketplace entry in `.claude-plugin/marketplace.json` pins the plugin to `ref: "stable"`, so
work can land on `main` without reaching anyone. Before this split, `main` *was* the release
channel and every merge shipped to every install on their next session.

## Cutting a release

1. Bump the version on `main` — one command, never by hand:

   ```bash
   .github/scripts/bump-version.sh 0.2.27
   ```

   `plugins/fluencyloop/VERSION` is the source of truth; the three JSON manifests are generated
   from it. CI fails the build if they drift, because a mismatch breaks the `SessionStart` update
   hook silently for everyone already installed.

2. Add the `CHANGELOG.md` entry, commit, PR, merge to `main`.

3. Promote — this is the step that actually ships:

   ```bash
   git checkout stable && git merge --ff-only main && git push origin stable
   ```

4. Tag the release: `git tag v0.2.27 && git push origin v0.2.27`.

## Why the version bump belongs to the release, not to development

Claude Code reads `marketplace.json` from the repo's **default branch** (`main`), but installs
plugin content from the pinned `ref` (`stable`). If `main` carried a development version, the
marketplace would advertise a version that `stable` does not serve.

So `main` keeps the last released version until you cut the next one. Bump and promote together,
in that order.

## Rolling back

Point `stable` at the last good commit and push it:

```bash
git checkout stable && git reset --hard v0.2.26 && git push --force-with-lease origin stable
```

Users pick it up on their next session. This is the recovery path that did not exist while `main`
was the channel.
