# Agent 3 — MAF workflow with model router

**Shape:** hosted. Three agents orchestrated sequentially, exposed as one agent.
**Idle timeout:** 600s — workflows take more turns than a Q&A agent
**Lab:** `workshop/LAB-03-workflow-model-router.md`

## Anatomy

| File | What it is |
|---|---|
| `azure.yaml` | Three model deployments: router + two cheap models |
| `src/logic.py` | Role definitions and the model-routing table. Pure, 100% tested |
| `src/main.py` | Builds three agents, wires them into a SequentialBuilder |

## The design in one table

| Role | Model strategy | Why |
|---|---|---|
| `researcher` | `cheap_b` (nano) | Many short tool calls — cheapest wins |
| `analyst` | `model-router` | Difficulty varies — let the router decide |
| `writer` | `cheap_a` (mini) | Longer prose needs a better model |

## Components: features and benefits

**Workflow vs one agent** — each role sees only what it needs, uses its own
model, and produces its own trace span. *Benefit:* change the researcher's model
without retesting the writer. *Cost:* three model calls per turn minimum.

**`SequentialBuilder`** — fixed order, deterministic. *Benefit:* predictable and
easy to reason about. Contrast with Agent 4's Magentic manager, which re-plans.

**`model-router`** — picks a model per request from a pool.
*Benefit:* cheap turns stay cheap, hard turns escalate automatically.
*Cost:* output characteristics vary between turns — pin a model when you need
stability.

**`Workflow.as_agent()`** — the whole workflow is published as one agent with
one endpoint. *Benefit:* callers do not need to know it is three agents inside.
