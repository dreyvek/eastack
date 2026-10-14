# eastack contributor guide

eastack adapts [pstack](https://github.com/cursor/plugins/tree/main/pstack) by poteto for T3 Code, forked from [p3-stack](https://github.com/uzairansaruzi/p3-stack). Same skills, same language, rewired to T3's native orchestration.

A skill reads as if it were written for T3 Code first. Keep pstack's sentences verbatim wherever they still apply. Replace every Cursor mechanism with the T3 Code equivalent below.

## Drift from upstream

`drift.md` lists every place eastack differs from upstream pstack beyond its name map, with the reason, the condition that would remove it, and the evidence. Port upstream text verbatim unless a row there explains the difference. A change that adds, removes, or alters a difference updates `drift.md` in the same commit: it adds a row, edits one, or moves one to **Resolved**.

## Delegated workers

If you are a delegated worker, your brief names the files you may write. Write only those, create parent directories as needed, and run git commands only when the brief allows them. Report back the file paths, their line counts, the changes you made to pstack's version, and the drift rows you added or cited.

## Cursor to T3 Code map

| pstack | eastack |
|---|---|
| `Task` tool, `subagent_type`, `run_in_background` | `delegate_task` with a self-contained brief; `mode: "async"` for background work; `task_status` to drain; `task_cancel` to stop |
| Model slugs (`claude-opus-5-5-max`, `grok-4.7-xhigh-fast`, `gpt-5.6-sol-max`) | Named roles resolved from `orchestrator_capabilities` by `setup-eastack` (role names below). Never hardcode a slug. |
| "cloud agent", `environment: "cloud"`, `cloud_base_branch` | A delegated child task. Use `t3_thread_launch` only when the worker needs its own top-level thread, worktree, or branch. |
| "each worker gets its own worktree or branch" | `t3_thread_launch` with `workspaceStrategy`: `{"type":"worktree","baseRef":...,"branch":...}`, `{"type":"existing_worktree","worktreePath":...}`, or `{"type":"root"}`. One writer per worktree. |
| `/loop`, poll loops, `scripts/watch-pr` | `watch_pull_request`: T3 watches the PR and wakes the thread on checks finishing, new comments, or conflicts. Arm it, end the turn, triage on wake. Only a top-level thread can arm it; T3 refuses a delegated child. A merge ends the watch without a wake. For other cadences use `schedule_task`. |
| Hourly audit ticks, recurring runs | `schedule_task` with `{"type":"interval","everyMs":...}` or `{"type":"fixed_time","timeOfDay":...,"weekdays":[...]}`; `run_scheduled_task_now` for an immediate run. |
| Stack bookkeeping, manual PR lists | `link_pull_request` for every layer, immediately; `list_thread_pull_requests` returns the stack bottom to top. |
| `agent-transcripts/*.jsonl` mining | `t3_thread_read`, `t3_thread_search`; `t3_queue_list`/`t3_queue_read`/`t3_queue_edit`/`t3_queue_reorder`/`t3_queue_cancel`/`t3_queue_promote_to_steer` for queued input. |
| `AskQuestion` | Ask plainly in the thread. `t3_pending_request_list`/`t3_pending_request_read`/`t3_pending_request_respond` answer questions in other threads. |
| `control-ui`, `control-cli` (from cursor-team-kit) | `preview_*` browser tools and `device_*` simulator tools; `preview_recording_start`/`preview_recording_stop` and `device_screenshot` for evidence; `html_preview` checks and `html_render` shows an HTML page in the thread. |
| `~/.cursor/rules/pstack-models.mdc`, `/add-plugin` | `setup-eastack` writes `eastack-models.md`; install links `skills/*` into `.agents/skills/` and mirrors each link into `.claude/skills/` (see README). |
| `poteto-mode`, `poteto-agent`, `poteto-help`, `setup-pstack` | `eastack-mode`, `skills/eastack-mode/references/eastack-agent.md`, `eastack-help`, `setup-eastack`. |
| Cursor custom modes ("press option+enter"), the `mode` and `reminder` fields | `hooks/eastack-mode.py`, a Claude Code `UserPromptSubmit` hook that `install.sh` registers. In Claude Code, `/eastack-mode` turns the mode on for the thread, every later prompt carries the reminder, and "eastack-mode off" ends it. eastack ships no persistence hook for other providers. |

Everything else in pstack transfers as written: the principles, the playbook shapes, the brief template, the reply style, the autonomy rules. Adopt it.

## Role names

Code work reads its line in `eastack-models.md`: `feature, refactoring`, `bug-fix`, `perf-issue`, `hillclimb`. Prose and judgment read `judgment and prose`; the hardest changes read `hardest tasks`.

Panels and investigators: `how explorer`, `how explainer`, `why investigators`, `why synthesizer`, `arena runners`, `arena cross-judge pool`, `swarm workers`, `architect runners`, `interrogate reviewers`, `reflect tooling`, `reflect judgment, divergent, synthesizer`.

Keep these names exactly.

## Writing rules

- Thin over complete. Keep the shortest file that still changes behavior. Cut Cursor-only edge-case protocol and forge-specific branches before cutting any rule.
- pstack's voice: terse, declarative, lowercase-friendly, no filler.
- Frontmatter: `name`, one-line `description`, `disable-model-invocation: true` where the source has it, except `unslop`, which other skills load by name. Drop Cursor UI fields (`icon`, `color`, `mode`, `reminder`).
- Use T3 tool names exactly: `delegate_task`, `task_status`, `watch_pull_request`, `link_pull_request`, `schedule_task`, `t3_thread_launch`, `t3_thread_read`, `t3_thread_search`, `preview_*`, `device_*`.
- Delegation briefs are self-contained. T3 child agents get only the brief, never the parent's context. Say this where pstack says "every brief stands alone".
- A child resolves no path relative to a skill. A brief or plan a child reads names skill files as `<skills>/<name>/...`, and the parent fills in the absolute path of the directory that holds the skills.
- Never bullet a Cursor tool into a skill, even as a fallback.

## Layout

- `skills/<name>/SKILL.md` is a skill. `skills/principle-*/SKILL.md` are the short principles.
- `skills/eastack-mode/SKILL.md` is the mode router; its playbooks live in `skills/eastack-mode/playbooks/`.
- A brief for a delegated role lives in the skill that sends it, under `references/`: `skills/eastack-mode/references/eastack-agent.md`, `skills/no-comments/references/comment-sicko.md`. The parent pastes its text into the `delegate_task` brief. It is not a harness agent definition.
- `skills/eastack-mode/scripts/` holds eastack-mode's tools. `worktree-audit.sh` is the audit the Worktree cleanup playbook runs. It reads only, apart from fetching the base ref, and `worktree-audit.test.sh` tests it. `orch/orch.ts` keeps orchestrate bookkeeping in plain files. `watch-pr/` is vendored from upstream and not yet run by a playbook. The Bun tools install their pinned dependencies through `bootstrap.ts` on first run; `node_modules/` stays git-ignored.
- `hooks/eastack-mode.py` keeps eastack-mode on for a Claude Code thread. `install.sh` registers it.
- `drift.md` lists every difference from upstream pstack and the condition that would remove it.

## T3 tool quick reference

- Delegation: `delegate_task`, `task_status`, `task_cancel`, `orchestrator_capabilities`
- Threads: `t3_thread_launch`, `create_threads`, `t3_thread_list`, `t3_thread_read`, `t3_thread_search`, `t3_thread_send`, `t3_thread_wait`, `t3_thread_fork`, `t3_thread_merge_back`, `t3_thread_interrupt`, `t3_thread_organize`, `t3_thread_update`, `t3_thread_configure`
- Worktrees: `t3_worktree_status`, `t3_worktree_list`, `t3_worktree_handoff`
- Pull requests: `link_pull_request`, `list_thread_pull_requests`, `watch_pull_request`, `unwatch_pull_request`, `unlink_pull_request`
- Schedules: `schedule_task`, `list_scheduled_tasks`, `update_scheduled_task`, `delete_scheduled_task`, `run_scheduled_task_now`
- Queue: `t3_queue_list`, `t3_queue_read`, `t3_queue_edit`, `t3_queue_reorder`, `t3_queue_cancel`, `t3_queue_promote_to_steer`
- Preview: `preview_open`, `preview_navigate`, `preview_snapshot`, `preview_click`, `preview_type`, `preview_press`, `preview_hover`, `preview_select`, `preview_drag`, `preview_upload`, `preview_dialog`, `preview_evaluate`, `preview_scroll`, `preview_wait_for`, `preview_status`, `preview_resize`, `preview_set_appearance`, `preview_recording_start`, `preview_recording_stop`, `t3_preview_list`, `t3_preview_close`
- Pages: `html_preview`, `html_render`
- Devices: `device_list`, `device_open`, `device_screenshot`, `device_close`
- Pending requests: `t3_pending_request_list`, `t3_pending_request_read`, `t3_pending_request_respond`

## Definition of done for a skill

1. Every step names a T3 mechanism or a vendor-neutral habit. Grep for `Cursor`, `Task tool`, `subagent_type`, `cloud agent`, `.cursor`, `agent-transcripts`, `AskQuestion`, `icon:`, `claude-`, `grok-`, `gpt-`, `/loop`. None may remain.
2. It is shorter than the pstack source unless the T3 rewrite genuinely needs the lines.
3. Frontmatter matches the rules above, and references to other skills resolve to files in this repo.
4. Every difference from the upstream file beyond the name map has a row in `drift.md`.
