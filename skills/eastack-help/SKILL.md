---
name: eastack-help
description: Guides users through eastack setup, /eastack-mode, and picking the skill, playbook, or principle for a task. Type /eastack-help with a question.
disable-model-invocation: true
---

# Eastack help

Answer the user's question about eastack, hand them a prompt they can send, and link the file the answer came from. For a help question, don't start the work. The user asked how, and an eastack run spends real tokens, so let them send the prompt.

A message that asks for work, such as "use eastack to fix this bug", is not a help question. Read [`eastack-mode`](../eastack-mode/SKILL.md), do the work under it, and mention once that invoking `/eastack-mode` keeps the work in this style.

This file maps questions to the skills and guide pages that hold the answers. Those files own the details. Read the file you route to before you quote it, and trust it when it disagrees with this map. The links here are repo-relative, so give the user the file's public copy: `https://github.com/dreyvek/eastack/blob/main/` followed by its path.

## Find out what they need

Infer the need from the message and the conversation. A named situation, such as "which skill reviews a PR?", goes straight to its section. If the need is still unclear, ask one multiple-choice question with these options, then answer only the section they pick:

- Get set up
- Start a task with `/eastack-mode`
- Pick a skill for a situation
- Fix a run that went wrong
- Make eastack my own

Check the state that changes the answer, and mention it only when it does:

- No `eastack-models.md` in the project root or `~/.agents/` means `/setup-eastack` hasn't run for this user, so every role uses its default model.
- No `verify-*` skill or other app harness in the project means agents have no scripted way to drive the app. Mention `/create-verification-skill` when the question is about proving a change works.

When `eastack-models.md` is missing and it matters, ask whether the user wants to pick a model for each role and a reasoning budget now. It matters when the user is new, the question is about setup or cost, or the answer depends on which models run. Ask at most once per thread. If the need is also unclear, ask both questions together. Offer two choices:

- Now: give them `/setup-eastack` to type, and answer their question too.
- Later: answer their question, and add one line saying every role keeps its default model until they run `/setup-eastack`.

## Get set up

1. Install by cloning the repo and running `./install.sh`. It links every skill into `~/.agents/skills/`, where T3 Code and Codex read skills, and mirrors each link into `~/.claude/skills/` for Claude Code; `./install.sh --project /path/to/repo` targets a project's `.agents/skills/` and `.claude/skills/` instead.
2. Run [`/setup-eastack`](../setup-eastack/SKILL.md). It asks for a reasoning budget, maps a model to each role, and writes `eastack-models.md`. The file applies to new threads.
3. Start a real task with `/eastack-mode`, a goal, and a check that can pass or fail.

Installing changes nothing until the user invokes a skill. Only `/setup-eastack` loads from the user's words. The [README](../../README.md) and [guide page 1](../../docs/guide/01-setup.md) have the details. Offer to word their first prompt with them, per [`references/prompting.md`](references/prompting.md).

If cost is the worry, say where the tokens go and how to spend fewer. eastack spends extra tokens on subagents and review panels. Rerun `/setup-eastack` and pick a smaller budget or cheaper models. A role set to `auto` or `inherit-parent` runs on the thread's model, which saves tokens when the thread runs on Auto or a cheaper model. A shorter panel list runs fewer subagents, one for each entry. Save `/eastack-mode` for work that needs rigor.

## Start a task with `/eastack-mode`

`/eastack-mode` matches the task to a playbook, copies the playbook's steps into the todo list, and runs the other skills as the steps need them. A step it skips stays in the list as `skip: <reason>`. A good prompt states the goal and how to tell it's done. It doesn't list skills, because a hand-written sequence tends to drop or reorder steps the playbook would keep. Read [`references/prompting.md`](references/prompting.md) before you help word one. [Guide page 2](../../docs/guide/02-eastack-mode.md) has examples.

Skills are invoked by name (`/eastack-mode`). In Claude Code the mode stays on for the rest of the thread once you send it. A hook adds a one-line reminder to every later message, so a new task needs no second `/eastack-mode`, and "eastack-mode off" ends it. Other providers have no hook, so start each new task there with `/eastack-mode`. Mid-chat, "new task" makes the mode match a fresh playbook. `/eastack-mode` already opens the briefs of the subagents its playbook steps spawn with [`references/eastack-agent.md`](../eastack-mode/references/eastack-agent.md). To get the same style from a subagent of your own, spawn it with `delegate_task` and open its brief with that text, its `<skills>` replaced by the absolute path of the directory that holds `eastack-mode`.

## Pick a skill

The default answer is `/eastack-mode`, which runs most of the others when its steps need them. Name a skill directly when the user wants more or less of something than the playbook gives. Read the skill before you recommend it, and give one example prompt.

| The user wants to | Skill |
|---|---|
| Do any non-trivial task with rigor | [`/eastack-mode`](../eastack-mode/SKILL.md) |
| Check that the agent understood their goal and the problem before it starts | [`/in-your-own-words`](../in-your-own-words/SKILL.md) |
| Aim a task higher before starting: more expert, more outcome-focused, not overspecified | [`/sharpen`](../sharpen/SKILL.md) |
| Know how code works now, or where new code should live | [`/how`](../how/SKILL.md) |
| Know why code is shaped this way, or where a number came from | [`/why`](../why/SKILL.md) |
| Understand a change or subsystem, explained plainly | [`/teach`](../teach/SKILL.md) |
| Catch up on their own recent work on a topic | [`/recall`](../recall/SKILL.md) |
| Catch up on what changed in this thread since their last message, in a few plain sentences and small visuals, with enough context to decide each action item | [`/ketchup`](../ketchup/SKILL.md) |
| Know what a small diff could break outside itself | [`/blast-radius`](../blast-radius/SKILL.md) |
| Settle types and module shape before code that crosses a function boundary | [`/architect`](../architect/SKILL.md) |
| Get several attempts at one brief, merged into the best one | [`/arena`](../arena/SKILL.md) |
| Run parallel checks over slices, or race workers, as delegated child tasks | [`/swarm`](../swarm/SKILL.md) |
| Have different models review a diff and try to break it | [`/interrogate`](../interrogate/SKILL.md) |
| Fix a bug test-first when a cheap local test exists | [`/tdd`](../tdd/SKILL.md) |
| Apply TypeScript rules to `.ts` or `.tsx` work | [`/typescript-best-practices`](../typescript-best-practices/SKILL.md) |
| Strip comments before review, using a reviewer that didn't write them | [`/no-comments`](../no-comments/SKILL.md) |
| Clean AI tells out of prose | [`/unslop`](../unslop/SKILL.md) |
| Write docs, an RFC, a README, a PR description, or a commit message to a standard | [`/technical-writing`](../technical-writing/SKILL.md) |
| Hear the last reply again in plain words | [`/bro`](../bro/SKILL.md) |
| Give agents a scripted way to drive the app and prove behavior | [`/create-verification-skill`](../create-verification-skill/SKILL.md) |
| Bring a verification skill and its feature map back in line with the app | [`/maintain-verification-skill`](../maintain-verification-skill/SKILL.md) |
| Vet a performance number before reporting or acting on it | [`/benchmark-checklist`](../benchmark-checklist/SKILL.md) |
| Run a large or cross-cutting change, or one to review after stepping away | [`/figure-it-out`](../figure-it-out/SKILL.md) |
| Keep a decision log during a run, and review it afterward | [`/show-me-your-work`](../show-me-your-work/SKILL.md) |
| Pick a model for each role and a reasoning budget | [`/setup-eastack`](../setup-eastack/SKILL.md) |
| Turn their own working habits into a personal mode skill | [`/automate-me`](../automate-me/SKILL.md) |
| Turn what a finished task taught into skill edits | [`/reflect`](../reflect/SKILL.md) |
| Stop agents from repeating the same mistakes in this repo | [`/correct`](../correct/SKILL.md) |
| Build a page whose buttons wake a bot over a webhook | [`/make-bot-ui`](../make-bot-ui/SKILL.md) |
| Find their way around eastack | `/eastack-help` |

If a skill directory next to this one is missing from the table, read its frontmatter and route by its description. The `principle-*` directories are covered under principles below.

Close calls:

- `/how` explains what the code does. `/why` explains the reasons. `/teach` runs one or both and explains the result plainly.
- `/arena` gives every worker the same brief and merges the best parts. `/swarm` splits work into slices or a race and returns one report.
- `/architect` implements right after it settles the design. Add "with checkpoint" to review the design before it writes code.
- `/interrogate` reviews the diff. `/blast-radius` looks for breakage outside the diff and proves the one fact that makes the change safe.
- `/recall` rebuilds context across recent threads. `/ketchup` covers only this thread since the user's last message. Resuming one specific thread or branch is the Session pickup playbook.
- `/figure-it-out` designs one rigorous run. The Orchestrate playbook runs a program that spans days and many PRs. The Autonomous run playbook drives one task to a finish condition.

Not in eastack:

- `control-cli` and `control-ui` ship in the `cursor-team-kit` plugin, not in eastack. T3's `preview_*` tools drive web UIs and its `device_*` tools drive simulators. CLI and TUI driving is not verified yet, so use the repo's own harness.
- `/loop` and `/create-skill` are Cursor built-ins. Here, "run until done" routes to the Autonomous run playbook, and the [Authoring or modifying a skill playbook](../eastack-mode/playbooks/authoring-a-skill.md) drafts skills.
- eastack has no `/orchestrate` skill. Orchestrate is a `/eastack-mode` playbook. If the slash menu shows `/orchestrate`, another plugin provides it.

## Playbooks and principles

Playbooks are step lists inside `/eastack-mode`, not skills, so they have no slash command. Inside `/eastack-mode`, describing the task picks one, and these phrases name one directly:

- "babysit this pr" or "check on pr 123" runs Babysit. It drives the PR to merge-ready and stops there. It doesn't merge unless the user asks to merge, land, or ship.
- "land the stack" runs Shipping.
- "take over this branch" runs Session pickup.
- "pause safely" runs Pause safely.
- "full autopilot on this queue" runs Autopilot-full. "stack them, don't ship" runs Autopilot-stack.
- "run the eval playbook" runs Eval.

The Playbooks section of [`eastack-mode`](../eastack-mode/SKILL.md) lists every playbook and when it applies. [Guide page 6](../../docs/guide/06-verify-and-ship.md) covers opening, babysitting, and landing a PR.

eastack has no planning skill. T3's plan mode works alongside it. For work that spans phases or stacked PRs, asking `/eastack-mode` for a plan runs the [Multi-phase plan playbook](../eastack-mode/playbooks/multi-phase-plan.md), which writes the plan and doesn't implement it. For a design question, the Prototype playbook or `/architect` settles it in code first.

Principles are one-rule skills that `/eastack-mode` reads and cites in its replies. The user rarely invokes one. They steer with the names instead, as in "apply prove it works. show me the real output." Typing `/principle-<name>` still loads one on demand. [Guide page 8](../../docs/guide/08-principles.md) lists them.

## Fix a run that went wrong

| Symptom | Fix |
|---|---|
| The mode stopped applying after a few turns | In Claude Code, check that `install.sh` registered the hook under `hooks.UserPromptSubmit` in `.claude/settings.json`, then restart the agent session. With other providers, start each new task with `/eastack-mode`. |
| A question got treated as the next step of the last task | Say "new task", or say the turn doesn't need the mode. |
| A new model choice had no effect | The file from `/setup-eastack` applies to new threads. Start one. |
| Runs cost more than expected | See the cost paragraph under Get set up. |
| A skill didn't load on its own | Only `/setup-eastack` loads from the user's words. The others load when the user types them or when `/eastack-mode` runs them, and it doesn't run every skill. |
| Parallel agents overwrote each other | Give each worker its own worktree through `t3_thread_launch`, and keep one writer per worktree. |
| An overnight run moved but finished nothing | It needs a check that can pass or fail, not a duration. See [guide page 7](../../docs/guide/07-overnight.md). |
| The reply claims success from a green build | Ask for the real command, flow, stored value, or profile. That's the prove-it-works principle. |

For a run that drifts, [`references/prompting.md`](references/prompting.md) has one-line steers. [Guide page 10](../../docs/guide/10-recipes-and-pitfalls.md) has more pitfalls and the recipes worth copying.

## Make eastack my own

- [`/automate-me`](../automate-me/SKILL.md) drafts a personal mode skill from the user's own history, to use alongside `/eastack-mode`.
- [`/reflect`](../reflect/SKILL.md) after a session turns its lessons into skill edits the user approves.
- `/eastack-mode write a skill for <workflow>` runs the authoring playbook. The eval playbook tests a skill change blind.
- Fix a misbehaving skill in its own PR, not inside the feature work where it went wrong.

[Guide page 9](../../docs/guide/09-make-it-yours.md) covers each of these.

## Reply

Lead with the answer. Give at most one example prompt in a code block, adapted from [`references/recipes.md`](references/recipes.md) when one fits, then the link to that file. Keep it short unless the user asked for the whole map.
