# Drift from upstream pstack

eastack tracks [pstack](https://github.com/cursor/plugins/tree/main/pstack). This file lists every place where eastack differs from upstream beyond the name map below, why it differs, and what would let us remove the difference. Add a row in the same change that introduces a drift. Move a row to **Resolved** in the change that removes it.

**Upstream baseline:** pstack 0.15.24, `cursor/plugins@1e5c90a` (2026-10-14). Previous baseline: pstack 0.15.14 at #509, `1e56b29`.

**Name map (not drift):** `poteto-mode` is `eastack-mode`. `poteto-agent` is `skills/eastack-mode/references/eastack-agent.md`. `poteto-help` is `eastack-help`. `setup-pstack` is `setup-eastack`. `~/.cursor/rules/pstack-models.mdc` is `eastack-models.md`. The Comment Sicko agent is `skills/no-comments/references/comment-sicko.md`.

**Columns.** *Upstream* is what pstack does. *eastack* is what we do instead. *Why* gives the reason. *Removable when* names the condition that would let us return to upstream behavior, or `never` when the difference is the T3 runtime itself. *Verified* names the evidence: a file and line, a probe with its date, or `not yet`. Upstream paths are under `pstack/` at the baseline. T3 paths are in the T3 Code repo at `ce6f8ce` (2026-10-14).

## Runtime: T3 Code instead of Cursor

| ID | Upstream | eastack | Why | Removable when | Verified |
|---|---|---|---|---|---|
| G1 | Task tool subagents (`subagent_type`, `run_in_background`, a model slug) | `delegate_task` with a self-contained brief, `target: {providerInstanceId, model, options}` and `mode: "async"`; the child's completion wakes the parent. eastack never uses a provider's native subagent tool | Cursor's Task tool does not exist under T3. A native subagent runs only its own provider's models, while `delegate_task` runs any model in the T3 catalog, which the role lines need. The child gets only the brief | never | T3 `apps/server/src/mcp/toolkits/orchestrator/tools.ts:68` (child runs on the task prompt alone; an async completion wakes the parent), `packages/contracts/src/orchestratorMcp.ts:100-129` (target); wakes measured 2026-10-14 |
| G2 | Cloud agents (`environment: "cloud"`) for workers and verification lanes, unless the task needs this machine | `t3_thread_launch` top-level threads, each with its own worktree, for a worker that needs its own checkout | `delegate_task` children shared the parent's checkout before T3 #19102 | Now: `delegate_task` `isolation: "worktree"` (T3 #19102, Nightly 0.0.46-nightly.20261014.3093 and later). Scheduled for Phase 2.4 | Upstream `skills/poteto-mode/playbooks/orchestrate.md:17`. T3 `packages/contracts/src/orchestratorMcp.ts:177-182` (`isolation`, default `shared`). Probes on Claude and Codex, 2026-10-14 |
| G3 | `scripts/watch-pr/watch-pr` polls a PR or a queued stack to a verdict under `/loop`, and its output wakes the chat | `watch_pull_request` arms T3's watcher, and the thread ends its turn. Only a top-level thread can arm it | `/loop` is not a T3 mechanism, and Codex has nothing like it. T3 refuses a watch from a subagent | Partly in Phase 3.3 (watch-pr inside the turn for merge waits). Never fully: T3's watch ends silently on a merge | Upstream `skills/poteto-mode/playbooks/babysit.md:12`, `shipping.md:9`. T3 `apps/server/src/orchestration-v2/PullRequestWatchReactor.ts:524-529` (a merge ends the watch with no wake), `apps/server/src/mcp/toolkits/pullRequests/handlers.ts:280` (subagent refused) |
| G4 | `/loop 1h` audit tick inside the chat | `schedule_task` interval bound to the thread | The only timer T3 gives every provider. It is persistent app state and fires with no turn active | Phase 3.2 adds dedupe, retirement and model sync. Never fully: T3 has no in-chat timer | Upstream `skills/poteto-mode/playbooks/multi-phase-plan.md:41`, `autopilot-full.md:22`. T3 `apps/server/src/mcp/toolkits/orchestrator/tools.ts:117-119`, `apps/server/src/scheduledTasks/ScheduledTaskService.ts` |
| G5 | `AskQuestion` structured questions | Ask plainly in the thread | T3 has no question tool of its own. Each provider brings a different one (Claude Code's `AskUserQuestion`, Codex's `request_user_input` only when listed), so a skill that names one breaks on the others | When T3 offers one question tool to every provider | Upstream `skills/poteto-mode/SKILL.md:20`, `skills/setup-pstack/SKILL.md:22`. T3 `apps/server/src/mcp/toolkits/*/tools.ts` (no question tool), `apps/server/src/provider/CodexDeveloperInstructions.ts:177-179` |
| G6 | Mining `agent-transcripts/*.jsonl` under `~/.cursor/projects/` | `t3_thread_read`, `t3_thread_search` | Cursor transcripts do not exist under T3. Each provider logs in its own format, and the thread tools read every provider's threads the same way. Search is bounded and promises no complete result | never | Upstream `skills/recall/SKILL.md:15`, `skills/reflect/SKILL.md:15`. T3 `apps/server/src/mcp/toolkits/orchestrator/tools.ts:207`, `apps/server/src/mcp/toolkits/thread/tools.ts:243-246` |
| G7 | `control-ui` and `control-cli` from cursor-team-kit drive and record UIs and CLIs | `preview_*` and `device_*` tools; CLIs and TUIs use the repo's own driver skill | T3 ships browser and simulator tools; cursor-team-kit is not installed | `control-cli` vendored in Phase 4.4 | Upstream `README.md:247`. T3 `apps/server/src/mcp/toolkits/preview/tools.ts`, `device/tools.ts`. eastack `skills/eastack-mode/SKILL.md:28`, `playbooks/multi-phase-plan.md:15`. CLI driving: not yet |
| G8 | A Cursor custom mode: `/poteto-mode` sent with option+enter stays on across turns. The skill's `mode` and `reminder` keys were dropped after #509 | In Claude Code, `/eastack-mode` stays on for the thread through `hooks/eastack-mode.py` until "eastack-mode off". On other providers it applies to the message that sends it | Claude Code needs a `UserPromptSubmit` hook to keep a mode on across prompts. eastack ships no hook for other providers | never, for Claude Code | Upstream `README.md:93`; the keys sit at `skills/poteto-mode/SKILL.md:5,8` at #509 and are gone at the baseline. Probe 2026-10-14: the hook adds the reminder to a `/eastack-mode` prompt and to a later prompt on that branch, adds the off notice to "eastack-mode off", and adds nothing after it |
| G9 | poteto-mode tells the parent to put its absolute path in every `poteto-agent` prompt, and bundled skills resolve as `../<name>/SKILL.md` from it. With no path, `poteto-agent` searches `~/.cursor/plugins/` (#577) | The parent fills `<skills>` with the absolute skills path in every brief and plan a child reads | A T3 child gets only the brief and has no plugin install to search | never | Upstream `skills/poteto-mode/SKILL.md:11`, `agents/poteto-agent.md:9`. eastack `skills/eastack-mode/SKILL.md:91`, `references/eastack-agent.md:3`. Used in the signing program's briefs |
| G10 | Plugin manifests (`.cursor-plugin/plugin.json`, plus an Agent Plugins v1 `plugin.json` added after #509), installed with `/add-plugin pstack` | `install.sh` links every skill into `.agents/skills` and mirrors each link into `.claude/skills` | Codex reads `.agents/skills` and Claude Code reads `.claude/skills`; the hook in G8 also needs registering | If eastack ships its own Claude Code and Codex plugins | Upstream `README.md:18`, `plugin.json`. T3 `apps/server/src/provider/Drivers/ClaudeSkills.ts:4-7`. Probe 2026-10-14: `install.sh --project` into an empty directory linked 51 skills, every `.claude/skills` link resolved, and the hook was registered |
| G11 | Delegate roles are harness agents in `agents/` (`poteto-agent` with `is_background: true`, `comment-sicko`), registered through the plugin manifest's `agents` key | Each role's text lives under the sending skill's `references/`, and the parent pastes it into the `delegate_task` brief | `delegate_task` takes no agent definition; its `role` is a fixed label | never | Upstream `.cursor-plugin/plugin.json` (`"agents": "./agents/"`), `agents/poteto-agent.md:1-5`. T3 `packages/contracts/src/orchestratorMcp.ts:139-146`, `:170-201` |
| G12 | Display names in `name` (`Poteto Mode`, `Make Bot UI`) and Cursor UI fields (`icon`, `color`, and at #509 `mode` and `reminder`) | `name` matches the skill's folder; Cursor UI fields are dropped | Claude Code names a skill by its folder, whatever `name` says. T3 and the providers read no Cursor UI field | never | Upstream `skills/poteto-mode/SKILL.md:2-6`, `skills/make-bot-ui/SKILL.md:2`. T3 `apps/server/src/provider/Drivers/ClaudeSkills.ts:363-368` |
| G13 | `unslop` sets `disable-model-invocation: true` | `unslop` drops the flag, so an agent can load it | Other skills tell the agent to apply **unslop**, and in Claude Code the flag hides a skill from the agent | When every provider lets an agent load a skill the user alone invokes | Upstream `skills/unslop/SKILL.md:4`. T3 `apps/server/src/provider/Drivers/ClaudeSkills.ts:109`. eastack commit `f622df6` |
| G14 | A first-person README: Cursor install, default models, "not shipped here", plan mode, automations | eastack's own README: what the T3 rewiring does, install, getting started, credit to pstack and p3-stack | The README describes this port, not upstream; G7, G8, G10, F2, F3, F4 and M1 cover its runtime differences | never | `README.md` against upstream `README.md` |

## Forge and tooling

| ID | Upstream | eastack | Why | Removable when | Verified |
|---|---|---|---|---|---|
| F1 | `gh` by default, and the Origin forge (`origin pr …`) when `command -v origin` succeeds and Origin resolves the repo. Never requires Graphite (`gt`) | `gh` only | The repos eastack runs on use GitHub | When a repo eastack runs on adopts Origin | Upstream `skills/poteto-mode/playbooks/opening-a-pr.md:24`, `babysit.md:7`. eastack `skills/eastack-mode/playbooks/opening-a-pr.md:26` |
| F2 | `deslop` (cursor-team-kit) strips code slop from the diff before commit | The **unslop** skill over the diff. unslop is a prose skill | cursor-team-kit was not ported | Phase 4.1 vendors `deslop` | Upstream `skills/poteto-mode/SKILL.md:28`. eastack `skills/eastack-mode/SKILL.md:26`. Whether unslop catches code slop: not yet |
| F3 | Cursor's built-in `create-skill` drafts and tunes skills | The authoring-a-skill playbook | A Cursor built-in | Phase 4.4 points at `skill-creator` | Upstream `skills/reflect/SKILL.md:54-56`. eastack `skills/reflect/SKILL.md:54-56` |
| F4 | `automations/benny` triages Slack issue reports and reproduces bugs | Not ported | Built on Cursor Automations; Tangent has no users yet | After launch, as T3 webhook `schedule_task`s | Upstream `automations/benny/FOR_AGENTS.md:5`. T3 webhook trigger: `apps/server/src/mcp/toolkits/orchestrator/tools.ts:119` |

## Models

| ID | Upstream | eastack | Why | Removable when | Verified |
|---|---|---|---|---|---|
| M1 | `pstack-models.mdc` holds slugs; each routed skill names default slugs and same-family fallbacks | `eastack-models.md` role lines, resolved through `orchestrator_capabilities`; no per-skill defaults | T3 model ids belong to provider instances; eastack never hardcodes a slug | Phase 2.1 adds family defaults and a checker | Upstream `skills/swarm/SKILL.md:25`, `skills/interrogate/SKILL.md:36`. Known failure: a target that names only a provider gets that provider's first catalog model (T3 `apps/server/src/mcp/OrchestratorMcpService.ts:1275-1279`), so Ship ran on gpt-6.1-sol |
| M2 | Reasoning level and speed are part of the slug (`grok-4.7-xhigh-fast`) | A role line's `(<effort>, fast)` becomes `target.options`: the model's reasoning option at `<effort>`, plus its fast option, both named by `orchestrator_capabilities` | T3 keeps model, reasoning and speed apart, and each provider names its options differently | never | eastack `skills/eastack-mode/SKILL.md:93`. T3 `packages/contracts/src/orchestratorMcp.ts:94`, `:123` |
| M3 | `setup-pstack` writes one global always-applied rule, `~/.cursor/rules/pstack-models.mdc`, so every chat has it in context | `setup-eastack` writes `eastack-models.md` at the project root or `~/.agents/`; the project file wins, and skills read it before their first delegation | No provider applies a file to every chat for us, and a project can need its own models | never | Upstream `skills/setup-pstack/SKILL.md:8`, `:39-44`. eastack `skills/setup-eastack/SKILL.md:8`, `skills/eastack-mode/SKILL.md:93` |

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
