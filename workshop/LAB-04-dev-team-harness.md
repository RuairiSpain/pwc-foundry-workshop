# Lab 4 - Magentic dev team, sandbox, worktrees and OBO (50 min)

## 1. What makes this one different

The previous agents follow a fixed order. This one does not. A **Magentic
manager** decides which specialist acts next based on progress so far - it
plans, delegates, watches the result, and re-plans.

Four sub-agents mimic a development team:

| Sub-agent | Job |
|---|---|
| `architect` | Plans the change. Writes no code |
| `developer` | Implements it in the worktree |
| `reviewer` | Reviews the diff for real defects |
| `tester` | Writes tests and reports actual output |

## 2. The harness - and swapping it

A *harness* is the runtime scaffolding that turns a model into an agent: it
drives tool calls, manages context, tracks todos, handles approvals. Roughly
98% of a coding agent's code is harness, not AI logic.

This agent runs on the **Microsoft Agent Framework harness** by default.
Swap it:

```bash
azd env set HARNESS_BACKEND github
azd env set GITHUB_TOKEN "<your PAT>"
azd deploy
```

Now the same four sub-agents run on the **GitHub Copilot SDK** harness instead.
`select_backend()` in `src/logic.py` is the switch.

> **Watch the difference.** MAF halts its own loop after a bounded number of
> round-trips. The Copilot SDK expects the *host* to supply the brake. Ask both
> for something open-ended and compare where they stop.

## 3. Per-session sandbox and git worktrees

Every session gets its own VM-isolated sandbox with a persistent filesystem.
That is what makes worktrees usable inside an agent.

```python
worktree_commands(repo, root, session_id, task)
# git -C /root fetch --all --prune
# git -C /root worktree add -b agent/a1b2c3d4/add-retry-logic /root/a1b2c3d4 origin/main
# git -C /root/a1b2c3d4 status --short
```

**Why worktrees, not clones:** one fetch, many cheap branches, and several
sub-agents can hold *different checkouts of the same repository at once*. The
developer works on its branch while the reviewer reads main.

`idleTimeoutSeconds: 1800` here - 30 minutes. Coding is bursty with long
think-time, and you do not want a worktree torn down mid-task. Compare with the
300s on Lab 2 and be able to say why they differ.

## 4. OBO - the agent acts as YOU

```yaml
devteam-tools:
  host: azure.ai.toolbox
  authMode: onBehalfOf
```

Without OBO, tool calls run as the agent's own identity - so every attendee's
agent has identical access. With **on-behalf-of**, the toolbox forwards *your*
signed-in identity to the tool, and the downstream service applies *your* RBAC.

**Benefit:** the agent can never do something you could not do yourself. This is
the difference between an agent with a service account and an agent with
delegated user permissions - and it is the thing your security team will ask about.

**Prove it:** ask the agent to read `proj-attendee-<neighbour>` resources. Under
OBO it fails, because *you* only have Reader on the hub.

## 5. Deploy and drive it

```bash
cd agents/04-harness-dev-team
azd env new lab04 --no-prompt
azd env set FOUNDRY_PROJECT_ENDPOINT "$FOUNDRY_PROJECT_ENDPOINT"
azd env set DEVTEAM_REPO_URL "https://github.com/<your-fork>/pwc-foundry-workshop"
azd env set HARNESS_BACKEND magentic
azd up
```

Ask it:

> *"Add a `--json` output option to run_tests.py, with a test for it. Work on a
> branch and show me the diff."*

## 6. Read the Magentic trace

The trace looks different from Lab 3. Look for:

- the **manager's plan**, written before any specialist runs
- specialists invoked out of order, or twice
- the manager **re-planning** after a result it did not expect

That dynamic re-planning is the whole difference between Magentic and the
sequential workflow in Lab 3.

## Exercise

Give it a task that needs the tester to fail first. Watch the manager route back
to the developer rather than pressing on.
