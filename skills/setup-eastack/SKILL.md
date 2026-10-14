---
name: setup-eastack
description: Configure which models eastack uses per role and at what reasoning budget. Detects your available models and writes eastack-models.md, which overrides the skill defaults. Use for /setup-eastack, "configure eastack models", "eastack budget", or changing eastack's model choices.
---

# Setup eastack

Write `eastack-models.md`, a file that sets eastack's model per role. Default location is the current project root. Offer `~/.agents/eastack-models.md` as the global option, and ask which one. A project file wins over the global one.

## Steps

### 1. Detect available models

Call `orchestrator_capabilities`. That is the dependable source. Keep only the provider instances with `canRunChildTask: true`, since `delegate_task` rejects the others. The detected set is every slug that resolves against them, per Slug to target in the Subagents section of the **eastack-mode** skill. If you cannot detect any, show the user each provider's `constraints` and ask the user to paste the slugs they have access to. Ask the same for a usable instance whose catalog lists no models: T3 checks no model id against such an instance. Each slug the user confirms joins the detected set as `<providerInstanceId>/<model>`, with the instance the user names. The catalog lists no options for it, so write it with no effort or `-fast` token rather than guess an option. Never write a real slug you have not confirmed is available. The aliases `inherit-parent` and `auto` are always valid even though they are not detected slugs.

### 2. Load current state

The default role-to-model mapping is the file shape shown in step 5 below. If `eastack-models.md` already exists at the chosen location, read it and treat its `# budget` line and its role values as the current choices. Otherwise start from those defaults. A line whose role is not in step 5, such as `how critics`, is from a retired role. Drop it.

### 3. Budget, map, and confirm

**(a) Ask for a budget.** Ask plainly in the thread. Offer these four options with these exact labels, and name the current budget when the file records one. With no file, say that `large` matches the skill defaults apart from the code roles and `swarm workers`, which default to `high`.

- `unlimited — max reasoning`
- `large — xhigh reasoning`
- `medium — high reasoning`
- `small — medium reasoning`

**(b) Apply it.** Build the working table from the skill defaults, and on a re-run keep any role you changed by family, list, or alias (`inherit-parent`, `auto`). `unlimited`, `large`, `medium`, and `small` set the effort token of every real slug, panel entries included, to `max`, `xhigh`, `high`, or `medium`. The effort token is the last token, or the one before a trailing `fast`, on the ladder `max` > `xhigh` > `high` > `medium` > `low`. If the result is not a detected slug, use the same family's detected slug with the highest effort at or below the target, else mark the role as needing a choice. `inherit-parent` and `auto` do not change. So `unlimited` turns `claude-opus-5-5-xhigh` into `claude-opus-5-5-max`. Grok slugs top out at `xhigh`, so under `unlimited` the fallback puts Grok at `xhigh` and keeps `grok-4.7-xhigh-fast` as it is. `large` keeps the `xhigh` defaults and turns `claude-opus-5-5-high` into `claude-opus-5-5-xhigh`. `small` turns them into `claude-opus-5-5-medium` and `grok-4.7-medium-fast`.

**(c) Show the roles and confirm.** Show every role with its model, marking any real slug not in the detected set as needing a choice. When the slug's instance is in the catalog with `canRunChildTask: false`, quote its `constraints` beside it. When a chosen model is offered by more than one instance, show which instance the bare slug resolves to, and write the `<providerInstanceId>/` prefix only if the user wants another. Also list each line step 2 dropped. Ask whether to accept as-is or change specific roles, offering the detected models plus `inherit-parent` and `auto` (both mean: this role runs on the parent thread's model, which is how Auto users stay on Auto) as the options. Ask plainly in the thread. For panel roles (arena runners, architect runners, interrogate reviewers) the value is a list, and one subagent runs per entry, alias entries included, so the list length sets the count. `arena cross-judge pool` is also a list, but Arena selects one value from it whose model family differs from the parent's when possible. `swarm workers` is the default model for every worker unless a race or comparison assigns another model per arm. `verifier` is the model for each Shipping verifier.

### 4. Validate

Every real slug written must be in the detected set, which includes the slugs the user confirmed in step 1. `inherit-parent` and `auto` always pass. If a chosen real slug is not available, stop and ask again.

### 5. Write the file

Write `eastack-models.md` with a `# budget` line with the chosen label and its target effort, and one line per role, using the same labels eastack-mode uses. Overwrite the whole file so re-runs stay idempotent. Shape:

```
# eastack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent thread's model (omit the delegate_task `target`). Alias entries in a panel list still count toward its fan-out.
# budget: large (xhigh)
feature, refactoring: claude-opus-5-5-high
bug-fix: claude-opus-5-5-high
perf-issue: claude-opus-5-5-high
hillclimb: claude-opus-5-5-high
judgment and prose: claude-opus-5-5-xhigh
hardest tasks: claude-opus-5-5-xhigh
how explorer: grok-4.7-xhigh-fast
how explainer: claude-opus-5-5-xhigh
why investigators: grok-4.7-xhigh-fast
why synthesizer: claude-opus-5-5-xhigh
reflect tooling: grok-4.7-xhigh-fast
reflect judgment, divergent, synthesizer: claude-opus-5-5-xhigh
arena runners: gpt-6.1-sol-xhigh-fast, claude-opus-5-5-xhigh
arena cross-judge pool: gpt-6-astra-xhigh, claude-opus-5-5-xhigh
swarm workers: claude-opus-5-5-high
architect runners: claude-opus-5-5-xhigh, gpt-6.1-sol-xhigh-fast, gpt-6-astra-xhigh
interrogate reviewers: claude-opus-5-5-xhigh, gpt-6-astra-xhigh
verifier: gpt-6-astra-xhigh
```

### 6. Confirm

Tell the user the file was written, where, and that it applies to new sessions. Re-running this skill updates it.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with /create-verification-skill." On yes, invoke `/create-verification-skill` (resolves wherever eastack is installed: workspace or user). On no, move on without pushing.
