# eastack

eastack is [pstack](https://github.com/cursor/plugins/tree/main/pstack) rebuilt for T3 Code, forked from Uzair Ansar's [p3-stack](https://github.com/uzairansaruzi/p3-stack). Same engineering discipline, native T3 orchestration.

pstack is poteto's answer to AI slop code. It turns an agent into an engineering team: one mode skill that routes to playbooks, principles that ground every decision, and verification strict enough that you can parallelize with confidence. eastack keeps that system and rewires the mechanics to T3 Code's primitives:

- **Delegation.** `delegate_task` child agents replace Cursor's Task tool, with per-role providers and models resolved from `orchestrator_capabilities`. Cross-model panels are native.
- **Worktrees.** A worker that needs its own checkout is a `delegate_task` child with `isolation: "worktree"`, in its own worktree and branch, and its completion wakes the parent. Other workers share the parent's checkout. One writer per worktree.
- **Watching.** Babysit and Shipping run pstack's `watch-pr` in the turn, reading every record, until the playbook's stop condition. When the thread has other work, a watcher subagent runs it, and its completion wakes the parent.
- **Timers.** Where a pstack playbook needs a timer that watching cannot replace, `schedule_task` runs it even when no turn is active, and the playbook deletes it when the work ends.
- **Memory.** `t3_thread_read` and `t3_thread_search` replace mining Cursor transcript files.
- **Proof.** `preview_*` browser tools and `device_*` simulators replace external control skills for web UIs and simulators. Screenshots and recordings land in the thread.

[`drift.md`](drift.md) lists every place eastack differs from pstack, and why.

Fork it. Improve it. Make it yours. PRs are welcome!

## Install

```bash
git clone https://github.com/dreyvek/eastack.git
cd eastack
./install.sh
```

`install.sh` links every `skills/*` directory into `~/.agents/skills/`, where T3 Code and Codex read skills, and mirrors each link into `~/.claude/skills/` as `../../.agents/skills/<name>` for Claude Code. Use `./install.sh --project /path/to/repo` to install into a project's `.agents/skills/` and `.claude/skills/` instead. It also registers `hooks/eastack-mode.py` as a `UserPromptSubmit` hook in the matching `.claude/settings.json`. Once you send `/eastack-mode` in a Claude Code thread, that hook keeps the mode on with a one-line reminder on every later message, until you say "eastack-mode off". The links and the hook point into this clone, so keep it where it is.

## Get started

1. Run [`/setup-eastack`](./skills/setup-eastack/SKILL.md), pick a reasoning budget, and choose which models you want.
2. Use [`/eastack-mode`](./skills/eastack-mode/SKILL.md) whenever you're doing anything that requires rigor.

New here? The [eastack guide](./docs/guide/README.md) walks you through a first real task, from setup and prompting through verification and overnight runs. Stuck, or unsure which skill fits? Ask [`/eastack-help`](./skills/eastack-help/SKILL.md).

That's it. The other skills are situational; the mode skill uses them for you as needed. Out of the box, code delegates (feature, refactoring, bug fix, perf, hillclimb) and swarm workers go to Opus 5.5 at high reasoning, while the hardest changes, prose, and judgment go to Opus 5.5 at xhigh. Explorers, investigators and reflect's tooling reviewer go to Grok. The default panels pair Opus 5.5 with GPT-6.1 Sol and GPT-6 Astra, and Shipping's verifiers run on GPT-6 Astra. [`/setup-eastack`](./skills/setup-eastack/SKILL.md) changes any of it.

## Usage

Use [`/eastack-mode`](./skills/eastack-mode/SKILL.md) at the start of a task. It reads your request, picks from a set of playbooks, and runs the other skills as the steps need them.

Pick `/eastack-mode` from the `/` menu before you type your task, so T3 attaches the skill to the message.

### Just use [`/eastack-mode`](./skills/eastack-mode/SKILL.md)

This skill is the main shortcut. Use it whenever you need the agent to do rigorous engineering work. It comes with twenty-three playbooks:

```
/eastack-mode this pr has a subtle bug where the scroll drifts every 750ms even when idle. repro
first, then fix and verify.
```

```
/eastack-mode i'm going to bed. land the stack even if ci flakes. i want everything merged by
morning.
```

<details>
<summary>The twenty-three playbooks</summary>

| playbook | for |
|---|---|
| [investigation](./skills/eastack-mode/playbooks/investigation.md) | a read-only question. how does x work, why was y built this way, are we sure. |
| [bug fix](./skills/eastack-mode/playbooks/bug-fix.md) | reproduce a defect, root-cause it, and fix with runtime evidence. |
| [perf](./skills/eastack-mode/playbooks/perf-issue.md) | trace a measured slowness and improve it against a baseline. |
| [hillclimb](./skills/eastack-mode/playbooks/hillclimb.md) | sustained, scientific improvement of one metric against a target, looping hypotheses with before/after measurement and one commit per accepted win. |
| [runtime forensics](./skills/eastack-mode/playbooks/runtime-forensics.md) | diagnose a live symptom (leak, idle-cpu spin, glitch) from instrumentation. |
| [trace forensics](./skills/eastack-mode/playbooks/trace-forensics.md) | diagnose a captured profiling artifact (cpuprofile, trace, spindump, heap snapshot). |
| [feature](./skills/eastack-mode/playbooks/feature.md) | new or changed behavior, built from a named data shape. |
| [refactoring](./skills/eastack-mode/playbooks/refactoring.md) | a behavior-preserving change to structure or shape. |
| [prototype](./skills/eastack-mode/playbooks/prototype.md) | a throwaway sketch to make a design or behavioral decision cheaply, or to settle an empirical fork by observing it. |
| [visual parity](./skills/eastack-mode/playbooks/visual-parity.md) | pixel-exact ui equivalence between two implementations. |
| [authoring a skill](./skills/eastack-mode/playbooks/authoring-a-skill.md) | writing or editing a SKILL.md. |
| [eval](./skills/eastack-mode/playbooks/eval.md) | test how a skill or prompt change affects agent behavior, blinded. |
| [babysit](./skills/eastack-mode/playbooks/babysit.md) | drive a pr or a stack to merge-ready: conflicts, review threads, ci. |
| [shipping](./skills/eastack-mode/playbooks/shipping.md) | independently verify a green stack, then land the contiguous verified run bottom-up through github by default or origin when available. |
| [autonomous run](./skills/eastack-mode/playbooks/autonomous-run.md) | drive a long task to completion without stopping. |
| [orchestrate](./skills/eastack-mode/playbooks/orchestrate.md) | a standing project handed to one coordinator thread: multi-day, many stacked prs, fleets of subagents. |
| [autopilot-full](./skills/eastack-mode/playbooks/autopilot-full.md) | run independent prs to merged with one owner per pr and a root swarm verdict on each round, from the code-ready head on. |
| [autopilot-stack](./skills/eastack-mode/playbooks/autopilot-stack.md) | build and verify one linear base-branch stack for the operator to review and land. |
| [session pickup](./skills/eastack-mode/playbooks/session-pickup.md) | resume or take over a prior agent's in-flight work. |
| [pause safely](./skills/eastack-mode/playbooks/pause-safely.md) | suspend in-flight work cleanly so it can be resumed later. |
| [multi-phase plan](./skills/eastack-mode/playbooks/multi-phase-plan.md) | work that spans phases or stacked PRs. |
| [worktree cleanup](./skills/eastack-mode/playbooks/worktree-cleanup.md) | reclaim disk by pruning merged or abandoned worktrees and stale ios simulators, safety-gated. |
| [opening a pr](./skills/eastack-mode/playbooks/opening-a-pr.md) | open a ready pr from small ordered commits with a conventional commits title and a briefing-style body. invoked at the end of every other playbook. |

</details>

When invoked it:

1. matches your task to a [playbook](./skills/eastack-mode/playbooks/) and opens a todo list whose first items are its steps, copied in verbatim.
2. routes to the other skills as the steps fire.
3. writes unslopped replies framed for the consumer and the maintainer.

The full rules and playbooks live in [`skills/eastack-mode/SKILL.md`](./skills/eastack-mode/SKILL.md).

In Claude Code, `/eastack-mode` stays on across turns through the hook `install.sh` registers (see Install). It applies itself when a playbook matches or the task needs rigor, and stays out of the way otherwise. Other providers have no such hook, so send `/eastack-mode` again on the message that needs it.

For long runs, tell [`/eastack-mode`](./skills/eastack-mode/SKILL.md) to run until done, with a check that can pass or fail. The Autonomous run playbook drives to it, woken by a watcher subagent's completion or by a `schedule_task` heartbeat it deletes when the run ends. You can make the agent work for many hours without sacrificing rigor.

## Skills

[`/eastack-mode`](./skills/eastack-mode/SKILL.md) runs most of these for you when a step needs them (`how`, `why`, `architect`, `arena`, `swarm`, `interrogate`, `deslop`, `unslop`, `no-comments`, `technical-writing`, `tdd`, and the principles). The table below is for when you want one directly:

```
/how do we cancel runs? do we have an n+1 when we look up every run to cancel?
```

```
/interrogate review this pr.
```

<details>
<summary>All skills</summary>

| skill | use it when |
|---|---|
| [`/eastack-mode`](./skills/eastack-mode/SKILL.md) | default entry point for any non-trivial task. |
| [`/eastack-help`](./skills/eastack-help/SKILL.md) | you're new to eastack, or unsure which skill, playbook, or principle fits. finds out what you're trying to do, answers that part, and hands you a prompt to type. runs only when you type `/eastack-help`. |
| [`/in-your-own-words`](./skills/in-your-own-words/SKILL.md) | you want the agent to play back your goal and the problem before it starts. runs only when you type `/in-your-own-words`. |
| [`/sharpen`](./skills/sharpen/SKILL.md) | you want a task approached the way a top expert would, aimed at what you're really after, without overspecifying it or deciding your choices for you. |
| [`/how`](./skills/how/SKILL.md) | you want a walkthrough of how a subsystem works. |
| [`/why`](./skills/why/SKILL.md) | you want to know why something was built this way. discovers available MCPs at run time and queries each evidence category in parallel (source control, issue tracker, long-form docs, real-time chat, infra observability, error tracking, analytics warehouse). |
| [`/recall`](./skills/recall/SKILL.md) | you're starting or resuming work and want your recent context on a topic rebuilt from your own thread history and the shared record, handed back as a tight current-state brief. |
| [`/ketchup`](./skills/ketchup/SKILL.md) | you want what changed in this thread since your last message, in a few plain sentences and small visuals, with just enough context on each action item to make the call. |
| [`/blast-radius`](./skills/blast-radius/SKILL.md) | you have a small-looking change and want to know what else it could break, with the one fact it's safe because of proven by running code, not asserted. |
| [`/architect`](./skills/architect/SKILL.md) | you're about to write code that crosses a function boundary and want the caller's usage, types, and module shape settled first. |
| [`/arena`](./skills/arena/SKILL.md) | you want N parallel attempts at the same thing, then to grab the best parts of each. |
| [`/swarm`](./skills/swarm/SKILL.md) | you want N parallel workers across different slices or races, then one aggregated report. |
| [`/interrogate`](./skills/interrogate/SKILL.md) | you have a diff and want different models to try to break it, including a strict code-quality lens. |
| [`/automate-me`](./skills/automate-me/SKILL.md) | you want your own `-mode` skill, drafted from how you've actually worked. |
| [`/make-bot-ui`](./skills/make-bot-ui/SKILL.md) | you want a page or dashboard whose buttons wake the agent over a webhook, including the webhook secret and Tailscale. |
| [`/setup-eastack`](./skills/setup-eastack/SKILL.md) | you want to pick which models eastack uses per role. detects your models and writes `eastack-models.md`. |
| [`/reflect`](./skills/reflect/SKILL.md) | a long task landed and you want the recipe captured as a skill edit. |
| [`/correct`](./skills/correct/SKILL.md) | you keep correcting agents for the same mistakes. mines history for mistake classes, fixes each at the highest level that works (architecture, then types, lint, and ci, then tests, with docs last), and keeps a table pairing each rule with what enforces it. |
| [`/teach`](./skills/teach/SKILL.md) | you want to actually understand a change or subsystem, not just have it summarized. runs how + why and weaves one plain explanation, built up diagram by diagram. |
| [`/tdd`](./skills/tdd/SKILL.md) | you're fixing a bug and there's a cheap local test path. write the failing test first, then the fix. |
| [`/benchmark-checklist`](./skills/benchmark-checklist/SKILL.md) | you ran a benchmark or measured a speedup or regression. vets the number (limiter, tuning, errors, repeat runs, end-to-end relevance) before you report or act on it. |
| [`/no-comments`](./skills/no-comments/SKILL.md) | strip comments before review; spawns Comment Sicko, fixes accepted findings, offers encodings for claimed constraints. |
| [`/typescript-best-practices`](./skills/typescript-best-practices/SKILL.md) | you're reading or editing typescript. grounds the type-system-discipline principle in syntax. |
| [`/figure-it-out`](./skills/figure-it-out/SKILL.md) | no bundled playbook fits. designs a rigorous, auditable playbook for the task. |
| [`/show-me-your-work`](./skills/show-me-your-work/SKILL.md) | you want a reviewable decision trail. logs decisions to a tsv you can commit. |
| [`/create-verification-skill`](./skills/create-verification-skill/SKILL.md) | your project has no scripted way to prove app behavior. generates a project-local verify skill with a feature map, for any language or platform. |
| [`/maintain-verification-skill`](./skills/maintain-verification-skill/SKILL.md) | your verify skill's feature map has drifted from the app. source wave + one live pass, at most one PR of proven corrections. |
| [`/deslop`](./skills/deslop/SKILL.md) | you're about to commit. removes AI code slop from the branch's diff. |
| [`/unslop`](./skills/unslop/SKILL.md) | you're cleaning up writing. removes AI tells. |
| [`/bro`](./skills/bro/SKILL.md) | you want the last message restated in plain human language, no jargon. |
| [`/technical-writing`](./skills/technical-writing/SKILL.md) | layered doc standard (Diátaxis + Google developer style + STE + Global English) for docs, RFCs, readmes, PR descriptions, commit messages. |

</details>

### Examples

Mostly you type [`/eastack-mode`](./skills/eastack-mode/SKILL.md) at the start of a task and let it route to a playbook. The other skills fire as the steps need them. A few you reach for directly.

<details>
<summary>All the examples</summary>

```
bug fix:           /eastack-mode this pr has a subtle bug where the scroll drifts every 750ms even
                   when idle. repro first, then fix and verify.
perf:              /eastack-mode a big list takes a second or two to load even though we virtualize.
                   run a cpu trace and tell me why.
feature:           /eastack-mode build a small feature behind a feature flag. verify it really works.
prototype:         /eastack-mode build two prototypes of the markdown renderer so we can compare.
                   spawn an agent for each.
multi-phase:       /eastack-mode open source these skills as a plugin. nothing internal leaks, work
                   in a temp dir, show me the dependency graph first.
overnight run:     /eastack-mode i'm going to bed. land the stack even if ci flakes. i want
                   everything merged by morning.
babysit:           /eastack-mode check on pr 123. anything outstanding?
visual parity:     /eastack-mode the row spacing is too tall when this flag is on. the second image
                   is correct. repro and fix until it matches.
figure it out:     /eastack-mode i'm stepping away. migrate every caller from the synchronous store
                   to the new async one, keeping behavior identical. i want to trust it was done
                   right when i'm back.
how:               /how do we cancel runs? do we have an n+1 when we look up every run to cancel?
why:               /why is this feature flag not on yet?
architect:         design this instrumentation to be high signal with no false positives. /architect
                   this first.
arena:             /arena take my prompt to the arena verbatim. i want to compare their proposals
                   with yours.
swarm:             /swarm check every package under packages/ against its check.sh. one worker per
                   package. one report.
interrogate:       /interrogate review this pr.
tdd:               /tdd implement
unslop:            can we unslop and tighten the new changes?
reflect:           /reflect that took too long. capture what we learned so the next run doesn't
                   repeat it.
correct:           /correct
show-me-your-work: /show-me-your-work keep a decision trail i can review when i'm back.
automate-me:       /automate-me
help:              /eastack-help which skill should i use to review this branch?
```

</details>

## The `eastack-agent` and Comment Sicko briefs

[`/eastack-mode`](./skills/eastack-mode/SKILL.md) runs in the thread that receives it. That thread owns the playbook, the todo list, and every subagent spawn.

eastack also ships [`eastack-agent`](./skills/eastack-mode/references/eastack-agent.md), the brief the parent pastes into every delegate spawned during a run. It has the delegate read `eastack-mode` in full, including its inline principles index, before doing any work. A delegate briefed without it skips that read and drifts. Do not paste `eastack-agent` into a brief to run the playbook itself.

[`/eastack-mode`](./skills/eastack-mode/SKILL.md) and [`eastack-agent`](./skills/eastack-mode/references/eastack-agent.md) route through the same wrapper.

eastack also ships [Comment Sicko](./skills/no-comments/references/comment-sicko.md), a read-only comment reviewer. Usually invoke it through [`/no-comments`](./skills/no-comments/SKILL.md), not directly.

## Principles

Twenty-four short skills, one principle each. `eastack-mode` indexes them inline and reads that index at task start. The standalone files are there so other skills can reference a principle by name, and so the index can point at the full rule for each.

<details>
<summary>All twenty-four principles</summary>

| principle | group | rule |
|---|---|---|
| [laziness-protocol](./skills/principle-laziness-protocol/SKILL.md) | core | Bias toward deletion and the smallest change that solves the problem. |
| [foundational-thinking](./skills/principle-foundational-thinking/SKILL.md) | core | Apply before writing logic: choosing core types and data structures, sequencing scaffold-vs-feature work, asking what concurrent actors share. Get the data structures right so downstream code becomes obvious. |
| [redesign-from-first-principles](./skills/principle-redesign-from-first-principles/SKILL.md) | core | Redesign as if the requirement had been a foundational assumption from day one, instead of bolting it on. |
| [attack-the-premise](./skills/principle-attack-the-premise/SKILL.md) | core | Apply when two or more fixes that share one premise have failed the same gate. Take a census of which actors hold the imbalance before the next fix, then question the premise instead of writing another fix that assumes it. |
| [subtract-before-you-add](./skills/principle-subtract-before-you-add/SKILL.md) | core | Remove dead weight, redundant validators, and stub references first, then build on the simpler base. |
| [minimize-reader-load](./skills/principle-minimize-reader-load/SKILL.md) | core | Count layers between question and answer, and hidden state in the reader's head; collapse one-caller wrappers and shrink mutable scope. |
| [outcome-oriented-execution](./skills/principle-outcome-oriented-execution/SKILL.md) | core | Apply during planned rewrites and migrations with explicit phase boundaries. Converge on the target architecture; don't preserve smooth intermediate states with throwaway compatibility code. |
| [experience-first](./skills/principle-experience-first/SKILL.md) | core | Choose user delight over implementation convenience; ship fewer polished features over more rough ones. |
| [exhaust-the-design-space](./skills/principle-exhaust-the-design-space/SKILL.md) | core | Build 2-3 competing prototypes and compare side by side before committing. |
| [build-the-lever](./skills/principle-build-the-lever/SKILL.md) | core | Apply to any non-trivial work, not just bulk work: edits, migrations, analyses, checks. Build the tool that does it or proves it (codemod, script, generator, or a skill your subagents follow) instead of working by hand. The tool is the artifact a reviewer can rerun. |
| [model-the-domain](./skills/principle-model-the-domain/SKILL.md) | architecture | Encode the domain in a structure instead of scattered conditionals. |
| [boundary-discipline](./skills/principle-boundary-discipline/SKILL.md) | architecture | Concentrate guards at system boundaries (CLI, config, network, external APIs); trust internal types and keep business logic in pure functions. |
| [type-system-discipline](./skills/principle-type-system-discipline/SKILL.md) | architecture | Make illegal states unrepresentable, brand semantic primitives, parse external data at boundaries, refuse to lie to the compiler, exhaust variants, derive from authoritative schemas. |
| [make-operations-idempotent](./skills/principle-make-operations-idempotent/SKILL.md) | architecture | Converge to the same end state regardless of partial prior runs. |
| [migrate-callers-then-delete-legacy-apis](./skills/principle-migrate-callers-then-delete-legacy-apis/SKILL.md) | architecture | Migrate callers and delete the old API in the same wave instead of preserving compatibility layers. |
| [separate-before-serializing-shared-state](./skills/principle-separate-before-serializing-shared-state/SKILL.md) | architecture | Eliminate the sharing first; serialize structurally only when one shared writer is a real invariant. |
| [prove-it-works](./skills/principle-prove-it-works/SKILL.md) | verification | Apply after completing a task, before declaring done. Verify against the real artifact (run the feature, read the actual value, inspect the diff), not a proxy, self-report, or 'it compiles.'. |
| [fix-root-causes](./skills/principle-fix-root-causes/SKILL.md) | verification | Trace each symptom to its root cause and fix it there; reproduce first, ask why until you reach it, resist nil-check guards that silence crashes. |
| [sequence-verifiable-units](./skills/principle-sequence-verifiable-units/SKILL.md) | verification | Apply to multi-step work (sweeps, migrations, runs of similar edits) and to how you stack commits and PRs. Break work into small units that each end in a verifiable state, check each before the next, and order delivery so the sequence proves itself to a reviewer. |
| [test-behavior-not-implementation](./skills/principle-test-behavior-not-implementation/SKILL.md) | verification | Apply when you write, change, or keep a test. Call the code the way its users do and assert the result they observe against a literal expected value. If the test would still pass when every imported function returns undefined, rewrite the assertion or delete the test. |
| [explain-the-number](./skills/principle-explain-the-number/SKILL.md) | verification | Apply before you trust, report, or act on a number you measured: a speedup, a regression, a throughput, a latency, or an eval result. Find what limits it, and rule out that it measured something other than the work you think. |
| [guard-the-context-window](./skills/principle-guard-the-context-window/SKILL.md) | delegation | Route bulk to subagents; keep summaries in the main thread, not raw payloads. |
| [never-block-on-the-human](./skills/principle-never-block-on-the-human/SKILL.md) | delegation | Proceed, present the result, let the human course-correct after the fact; reserve confirmation for irreversible actions. |
| [encode-lessons-in-structure](./skills/principle-encode-lessons-in-structure/SKILL.md) | meta | Encode the rule as a lint, metadata flag, runtime check, or script instead of more text. |

</details>

## Not shipped here

A few things pstack relies on come from Cursor's `cursor-team-kit` plugin or Cursor itself:

- `deslop` ships in `cursor-team-kit`. eastack vendors it unchanged as [`skills/deslop`](./skills/deslop/SKILL.md).
- `control-cli` (for CLIs and TUIs) and `control-ui` (for browser, Electron, web) ship in `cursor-team-kit` too, and are not vendored. eastack drives web UIs with T3's `preview_*` tools and simulators with its `device_*` tools. For a CLI, a TUI or an Electron app, use the repo's own driver; eastack has not yet verified CLI driving.
- `/create-skill` is a Cursor built-in. Here the [authoring a skill](./skills/eastack-mode/playbooks/authoring-a-skill.md) playbook does that job.

## Why are there no planning skills?

T3 Code's plan mode works well with eastack. But pstack's author doesn't believe in planning: the best spec is code. If you do want to make a plan, [`/eastack-mode`](./skills/eastack-mode/SKILL.md) covers it, but it's not a default.

## Make it yours

`eastack-mode` is poteto's style. You may not want exactly that.

Type [`/automate-me`](./skills/automate-me/SKILL.md). It mines your recent threads, drafts a `<your-name>-mode` skill from how you've actually worked, and routes through eastack underneath. You keep eastack as the base and end up with your own routing skill alongside `eastack-mode`.

Models are configurable too. Type [`/setup-eastack`](./skills/setup-eastack/SKILL.md). It detects the models you have access to and writes `eastack-models.md`, mapping each role (code, judgment, the review panels) to a model. Every skill reads it and falls back to sensible defaults when the file is absent, so you override only what you want.

When a default changes, a file written before the change still pins the old default. Delete those role lines, or delete the file, then run `/setup-eastack` again. A rerun keeps any role whose model differs from the default.

## Automations

pstack also ships a dormant benny automation pack. benny triages Slack issue reports, then reproduces and fixes confirmed bugs with real UI evidence. eastack does not port it: its setup registers two Cursor Automations triggered by Slack posts, and T3 has no Slack trigger.

## Credit

eastack adapts [pstack](https://github.com/cursor/plugins/tree/main/pstack) by [poteto](https://x.com/poteto), by way of [p3-stack](https://github.com/uzairansaruzi/p3-stack) by Uzair Ansar. The skills, principles, and language are hers; the T3 Code rewiring is p3-stack's and this repo's. `skills/deslop` comes from Cursor's [cursor-team-kit](https://github.com/cursor/plugins/tree/main/cursor-team-kit), MIT, copyright 2026 Cursor. MIT, see [LICENSE](LICENSE).
