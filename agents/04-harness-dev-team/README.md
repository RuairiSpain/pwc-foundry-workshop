# Agent 4 — Magentic developer team

**Shape:** hosted, Magentic orchestration, swappable harness
**Idle timeout:** 1800s — coding is bursty with long think-time
**Lab:** `workshop/LAB-04-dev-team-harness.md`

## Anatomy

| File | What it is |
|---|---|
| `azure.yaml` | Toolbox with `authMode: onBehalfOf`, 2 cpu / 4 Gi, 1800s timeout |
| `src/logic.py` | Sub-agent team, harness selection, worktree commands. Pure, 100% tested |
| `src/main.py` | Magentic manager + four participants; backend switch |

## Components: features and benefits

**Magentic orchestration** — a manager plans, delegates, observes and re-plans,
choosing who acts next from context rather than a fixed order.
*Benefit:* handles open-ended tasks where the path is not known up front.
*Cost:* more model calls and a less predictable trace than Agent 3.

**Four sub-agents** (architect, developer, reviewer, tester) — each with a
narrow job and its own instructions. *Benefit:* the reviewer genuinely reviews,
because it never saw the developer's reasoning — only the diff.

**Swappable harness** — `HARNESS_BACKEND=magentic|github`. A harness is the
runtime that drives tools, context, approvals and looping; it is most of what a
coding agent actually is. *Benefit:* compare two runtimes with the same team and
the same task. Note MAF halts its own loop after a bounded number of round-trips
while the Copilot SDK expects the host to supply the brake.

**Per-session sandbox** — VM-isolated, persistent filesystem, survives
scale-to-zero. *Benefit:* a git worktree created on turn 1 still exists on
turn 20. This is what makes real code work possible inside an agent session.

**Git worktrees** — `git worktree add -b agent/<session>/<task>`.
*Benefit:* one fetch, many cheap branches, and several sub-agents can hold
different checkouts of the same repo simultaneously. A clone per sub-agent
would be slow and wasteful.

**OBO (`authMode: onBehalfOf`)** — tool calls carry the signed-in user's
identity, so downstream RBAC is the *user's*, not the agent's.
*Benefit:* the agent can never exceed what the human could do. This is the
control your security team will ask about.
