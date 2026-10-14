# Drift from upstream pstack

eastack tracks [pstack](https://github.com/cursor/plugins/tree/main/pstack). This file lists every place where eastack differs from upstream beyond the name map below, why it differs, and what would let us remove the difference. Add a row in the same change that introduces a drift. Move a row to **Resolved** in the change that removes it.

**Upstream baseline:** pstack 0.15.24, `cursor/plugins@1e5c90a` (2026-10-14). Previous baseline: pstack #509, `1e56b29`.

**Name map (not drift):** `poteto-mode` is `eastack-mode`. `poteto-agent` is `skills/eastack-mode/references/eastack-agent.md`. `poteto-help` is `eastack-help`. `setup-pstack` is `setup-eastack`. `~/.cursor/rules/pstack-models.mdc` is `eastack-models.md`. The Comment Sicko agent is `skills/no-comments/references/comment-sicko.md`.

**Columns.** *Upstream* is what pstack does. *eastack* is what we do instead. *Why* gives the reason and its evidence. *Removable when* names the condition that would let us return to upstream behavior, or `never` when the difference is the T3 runtime itself. *Verified* says how the eastack behavior was checked (a probe, a test, a source citation), or `not yet`.

## Runtime: T3 Code instead of Cursor

| ID | Upstream | eastack | Why | Removable when | Verified |
|---|---|---|---|---|---|
| G1 | Task tool subagents (`subagent_type`, `run_in_background`, a model slug) | `delegate_task` with a self-contained brief and `target: {providerInstanceId, model, options}`, `mode: "async"`; the child's result wakes the parent | T3 has no Task tool, and its children get only the brief | never | T3 tool description; wakes measured 2026-10-14 |
| G2 | Cloud agents (`environment: "cloud"`) for isolated workers and verification lanes | `t3_thread_launch` top-level threads, each with its own worktree | T3 children shared the parent's checkout before T3 #19102 | Now: `delegate_task` `isolation: "worktree"` (T3 #19102, Nightly 0.0.46-nightly.20261014.3093 and later). Scheduled for Phase 2.4 | Probes on Claude and Codex, 2026-10-14 |
| G3 | `/loop` with `scripts/watch-pr` wakes the chat on PR events | `watch_pull_request` arms T3's watcher, and the thread ends its turn | T3 has no `/loop` | Partly in Phase 3.3 (watch-pr inside the turn for merge waits). T3's watch never wakes on a merge | T3 source, `PullRequestWatchReactor.ts` |
| G4 | `/loop 1h` audit tick inside the chat | `schedule_task` interval bound to the thread | T3's only timer, and it is persistent app state | Phase 3.2 adds dedupe, retirement and model sync. Never fully: T3 has no in-chat timer | T3 source, `ScheduledTaskService.ts` |
| G5 | `AskQuestion` structured questions | Ask plainly in the thread | No equivalent T3 tool | never | n/a |
| G6 | Mining `agent-transcripts/*.jsonl` | `t3_thread_read`, `t3_thread_search` | T3 stores threads, not JSONL transcripts | never | n/a |
| G7 | `control-ui` and `control-cli` from cursor-team-kit drive and record UIs and CLIs | `preview_*` and `device_*` tools; CLIs use the repo's own driver | T3 ships browser and simulator tools; cursor-team-kit is not installed | `control-cli` vendored in Phase 4.4 | not yet |
| G8 | `/poteto-mode` picked from the slash menu, no toggle (upstream dropped the `mode` and `reminder` keys in #597) | `/eastack-mode` stays on for the thread through `hooks/eastack-mode.py`, until "eastack-mode off" | Claude Code needs a hook to keep a mode on across prompts | never, for Claude Code | Hook in daily use |
| G9 | Leaf skills found through the plugin's install path (#577) | The parent fills `<skills>` with the absolute skills path in every brief | T3 children resolve nothing relative to the parent's skill | never | Used in the signing program's briefs |
| G10 | Plugin manifests (`.cursor-plugin/plugin.json`, Agent Plugins v1 `plugin.json`) | `install.sh` symlinks every skill into `.agents/skills` and `.claude/skills` | T3, Codex and Claude Code read skill folders | never | `install.sh` |

## Forge and tooling

| ID | Upstream | eastack | Why | Removable when | Verified |
|---|---|---|---|---|---|
| F1 | Graphite (`gt`) and the Origin forge are supported where installed | `gh` only | The repos eastack runs on use GitHub | When Origin or `gt` is adopted | n/a |
| F2 | `deslop` (cursor-team-kit) strips code slop before commit | `unslop` over the diff, which is a prose skill | cursor-team-kit was not ported | Phase 4.1 vendors `deslop` | not yet |
| F3 | Cursor's built-in `create-skill` drafts and evaluates skills | The authoring-a-skill playbook | A Cursor built-in | Phase 4.4 points at `skill-creator` | not yet |
| F4 | `automations/benny` triages Slack issue reports and reproduces bugs | Not ported | Built on Cursor Automations; Tangent has no users yet | After launch, as T3 webhook `schedule_task`s | n/a |

## Models

| ID | Upstream | eastack | Why | Removable when | Verified |
|---|---|---|---|---|---|
| M1 | `pstack-models.mdc` holds slugs; each routed skill names default slugs and same-family fallbacks | `eastack-models.md` role lines, resolved through `orchestrator_capabilities`; no per-skill defaults | T3 model ids belong to provider instances; eastack never hardcodes a slug | Phase 2.1 adds family defaults and a checker | Known failure: a provider-only target resolves to that provider's first catalog model, so Ship ran on gpt-6.1-sol |

## eastack-mode and playbooks

| ID | Upstream | eastack | Why | Removable when | Verified |
|---|---|---|---|---|---|

## Routed skills

| ID | Upstream | eastack | Why | Removable when | Verified |
|---|---|---|---|---|---|

## Principles and other skills

| ID | Upstream | eastack | Why | Removable when | Verified |
|---|---|---|---|---|---|

## New skills, help and docs

| ID | Upstream | eastack | Why | Removable when | Verified |
|---|---|---|---|---|---|

## Scripts

| ID | Upstream | eastack | Why | Removable when | Verified |
|---|---|---|---|---|---|

## Resolved

| ID | Drift | Resolved by | Date |
|---|---|---|---|
