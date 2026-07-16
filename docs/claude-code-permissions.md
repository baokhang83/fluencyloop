# Claude Code approvals

FluencyLoop deliberately does not edit Claude Code permission settings. A plugin cannot safely
decide which repositories, Git operations, or shell commands you trust. On native Windows, Claude
Code's Bash sandbox is unavailable, so permission rules are the practical way to reduce routine
approval prompts.

For a project you trust, first use `/permissions` and select `acceptEdits`. It accepts ordinary
workspace edits and filesystem operations, but it does not grant unrestricted shell access.

Then add this project-local allow-list to `.claude/settings.local.json` (or add the equivalent
rules with `/permissions`):

```json
{
  "permissions": {
    "allow": [
      "Bash(*.claude/plugins/cache/fluencyloop/fluencyloop/*/bin/fluencyloop *)",
      "Bash(git status *)",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(git branch *)",
      "Bash(git rev-parse *)",
      "Bash(git show *)",
      "Bash(git ls-files *)"
    ]
  }
}
```

The FluencyLoop pattern intentionally matches its versioned plugin-cache launcher, so a plugin
upgrade does not create a new approval rule. Keep it project-local and review the plugin source
before trusting it. If you prefer not to edit settings, choose **Yes, don't ask again** for the
plugin launcher in a Claude Code permission prompt; Claude records the approved command prefix
for that project.

Do not allow `Bash(git *)`: it also permits `git push`, `git reset`, `git merge`, and other
state-changing commands. Leave `git init`, branch switches, Git configuration, staging, commits,
pushes, dependency installs, and network commands as explicit prompts. Use
`bypassPermissions` only inside an isolated container or VM.

See Claude Code's official [permissions guide](https://code.claude.com/docs/en/permissions) and
[settings reference](https://code.claude.com/docs/en/settings) for rule precedence and where to
store shared versus personal settings.
