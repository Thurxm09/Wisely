# Skill sources & licenses

These skills are vendored (copied) directly into this repo's `.claude/skills/`
so they load on every session, on any device, with no network dependency and
no reliance on a SessionStart hook. Update by re-copying from upstream; there
is no build step for any of them.

| Skill(s) | Upstream | License |
|---|---|---|
| `task-observer` | [rebelytics/one-skill-to-rule-them-all](https://github.com/rebelytics/one-skill-to-rule-them-all) | CC BY 4.0 |
| `brainstorming`, `dispatching-parallel-agents`, `executing-plans`, `finishing-a-development-branch`, `receiving-code-review`, `requesting-code-review`, `subagent-driven-development`, `systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `using-superpowers`, `verification-before-completion`, `writing-plans`, `writing-skills` | [obra/superpowers](https://github.com/obra/superpowers) `skills/` | MIT |
| `caveman` | [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) `skills/caveman/` | MIT |
| `explain-diff-html`, `explain-diff-notion` | [Geoffrey Litt's gist](https://gist.github.com/geoffreylitt/a29df1b5f9865506e8952488eac3d524) | None stated (unlicensed public gist) |

`impeccable` and `claude-mem` are **not** included here — they are plugins/tools
installed at runtime (not static skill files), see `.claude/hooks/session-start.sh`.
Unlike the skills above, they are best-effort and not guaranteed to persist.
