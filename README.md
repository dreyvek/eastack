# eastack

eastack is [pstack](https://github.com/cursor/plugins/tree/main/pstack) rebuilt for T3 Code, forked from Uzair Ansar's [p3-stack](https://github.com/uzairansaruzi/p3-stack). Same engineering discipline, native T3 orchestration.

pstack is poteto's answer to AI slop code. It turns an agent into an engineering team: one mode skill that routes to playbooks, principles that ground every decision, and verification strict enough that you can parallelize with confidence. eastack keeps that system and rewires the mechanics to T3 Code's primitives:

- **Delegation.** `delegate_task` child agents replace Cursor's Task tool, with per-role providers and models resolved from `orchestrator_capabilities`. Cross-model panels are native.
- **Worktrees.** `t3_thread_launch` binds a worker to its own worktree and branch. One writer per worktree, enforced by the app instead of by advice.
- **Watching.** `watch_pull_request` wakes the thread when checks finish, someone comments, or the branch conflicts. No polling loops.
- **Scheduling.** `schedule_task` runs audits and overnight cadences even when no turn is active. No `/loop`.
- **Memory.** `t3_thread_read` and `t3_thread_search` replace mining Cursor transcript files.
- **Proof.** `preview_*` browser tools and `device_*` simulators replace external control skills. Screenshots and recordings land in the thread.

## Install

```bash
git clone https://github.com/dreyvek/eastack.git
cd eastack
./install.sh
```

`install.sh` links every `skills/*` directory into `~/.agents/skills/`, where T3 Code and Codex read skills, and mirrors each link into `~/.claude/skills/` as `../../.agents/skills/<name>` for Claude Code. Use `./install.sh --project /path/to/repo` to install into a project's `.agents/skills/` and `.claude/skills/` instead. It also registers `hooks/eastack-mode.py` as a `UserPromptSubmit` hook in the matching `.claude/settings.json`. Once you send `/eastack-mode` in a Claude Code thread, that hook keeps the mode on with a one-line reminder on every later message, until you say "eastack-mode off". The links and the hook point into this clone, so keep it where it is.

## Get started

1. Run `/setup-eastack`. It reads `orchestrator_capabilities` and writes `eastack-models.md`, mapping each role (code, judgment, the review panels) to a provider and model you actually have.
2. Use `/eastack-mode` whenever you want rigorous work. It reads the request, picks a playbook, and runs the other skills as the steps need them.
3. Stuck or unsure which skill fits? Type `/eastack-help` with a question. It runs only when typed.

New here? The [guide](docs/guide/README.md) walks you through a first real task, from setup and prompting through verification and overnight runs.

## The mode

`eastack-mode` routes every task. Its playbooks: investigation, bug fix, perf issue, hillclimb, runtime forensics, trace forensics, feature, refactoring, prototype, visual parity, authoring a skill, eval, babysit, shipping, autonomous run, orchestrate, autopilot-full, autopilot-stack, session pickup, pause safely, multi-phase plan, worktree cleanup, opening a PR.

## Skills

architect, arena, automate-me, benchmark-checklist, blast-radius, bro, correct, create-verification-skill, figure-it-out, how, interrogate, maintain-verification-skill, make-bot-ui, no-comments, eastack-help, recall, reflect, setup-eastack, show-me-your-work, swarm, tdd, teach, technical-writing, typescript-best-practices, unslop, why.

## Principles

The twenty-four principle skills are indexed inside `eastack-mode` and referenced by the other skills by name.

## Credit

eastack adapts [pstack](https://github.com/cursor/plugins/tree/main/pstack) by [poteto](https://x.com/poteto), by way of [p3-stack](https://github.com/uzairansaruzi/p3-stack) by Uzair Ansar. The skills, principles, and language are hers; the T3 Code rewiring is p3-stack's and this repo's. MIT, see [LICENSE](LICENSE).
