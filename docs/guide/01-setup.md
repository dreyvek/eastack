# Set up eastack

In this page you install the skills, pick which models eastack uses, and run your first task. Setup is one script plus a short conversation.

## Install the skills

Clone the repo and run the installer:

```bash
git clone https://github.com/dreyvek/eastack.git
cd eastack
./install.sh
```

`install.sh` links every skill into `~/.agents/skills/`, where T3 Code reads skills, and mirrors each link into `~/.claude/skills/` for Claude Code. Use `./install.sh --project /path/to/repo` to install into one project instead. The links point into your clone, so keep it where it is. The [README](../../README.md) has the details.

## Pick your models

Run:

```text
/setup-eastack
```

[`/setup-eastack`](../../skills/setup-eastack/SKILL.md) detects the models you have access to, asks for a reasoning budget, shows you each role (code delegates, judgment, the review panels), and asks what you want. Answer the questions. It writes `eastack-models.md`, a small file every eastack skill reads, at the project root or globally at `~/.agents/eastack-models.md`. A project file wins over the global one.

The defaults run at `xhigh` reasoning, the same as the `large` budget, except the code roles and `swarm workers`, which run at `high`. `unlimited` lifts each model to its highest tier, up to `max`. Opus goes to `max`. Grok tops out at `xhigh`, so it stays there. `medium` and `small` lower the reasoning and spend fewer tokens.

You only override what you care about. A role with no line in the file keeps the skill's default. To restore a default, delete that role's line. A rerun of `/setup-eastack` keeps any role whose model differs from the default. When a default changes, a file written before the change still pins the old default, so delete those role lines, or delete the file, then run `/setup-eastack` again.

You might be wondering what happens if you use Auto. Set a role to `inherit-parent` or `auto` and eastack omits the `delegate_task` `target`, so the subagent inherits your parent thread's model. Both values mean the same thing, and neither is a model slug. For a panel role the value is a list, and one subagent runs per entry, so the list length sets the panel size. Setup also configures `swarm workers`, the default model for every `/swarm` worker unless a race names a model for each arm.

## Accept the verification offer, or don't

At the end of setup, `/setup-eastack` looks for a way to prove app behavior in your project, either a `verify-*` skill or an existing harness. If it finds neither, it offers once to generate one with [`/create-verification-skill`](../../skills/create-verification-skill/SKILL.md).

Say yes and it writes `.agents/skills/verify-<app>/`, a project-local skill that teaches agents to drive your app the way a user does. It proves the skill works once before handing it over. Say no and setup moves on. You can run `/create-verification-skill` yourself any time. [Verify and ship](./06-verify-and-ship.md#create-a-project-verification-skill) covers it in depth.

If you're new to eastack, say yes. An agent that can check its own work keeps going until the check passes. An agent that can't hands every result back to you to check by hand. Of everything in this guide, the verification skill pays off the most.

After setup, start a new thread. `eastack-models.md` applies to new sessions.

## Keep the cost in check

eastack spends extra tokens on subagents and review panels. That's the price of the rigor. To spend fewer:

- Rerun `/setup-eastack` and pick a smaller reasoning budget or cheaper models. A strong model in the main thread with cheaper, faster models in the code roles is a good split.
- Set a role to `auto` or `inherit-parent` so it runs on the thread's own model.
- Shorten a panel list. Each entry runs one subagent.
- Save `/eastack-mode` for work that needs rigor. A small, obvious edit doesn't.

## Run your first task

Pick something real but small, and describe it the way you'd describe it to a colleague:

```text
/eastack-mode add a --json flag to this command. text output stays byte-identical. verify both.
```

Watch the todo list. Its first items are the matched playbook's steps copied in, the Feature playbook for this prompt. If `/eastack-mode` skips a step, the step stays in the list with `skip: <reason>`, so you can see what it chose not to do.

From here you can type normal follow-ups. In Claude Code the mode stays on for the rest of the thread. A hook adds a one-line reminder to each message, and "eastack-mode off" ends it. With other providers, `/eastack-mode` attaches the skill to one message and fades as the thread moves on, so start each new task with `/eastack-mode`.

Next: [Route work through `/eastack-mode`](./02-eastack-mode.md).
