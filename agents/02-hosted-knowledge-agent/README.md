# Agent 2 — Hosted knowledge agent

**Shape:** hosted (your code, containerised, on managed infrastructure)
**Idle timeout:** 300s — deliberately short so the class watches scale-to-zero
**Lab:** `workshop/LAB-02-hosted-knowledge-agent.md`

## Anatomy — read in this order

| File | What it is | Why it exists |
|---|---|---|
| `azure.yaml` | Project, 2 MCP connections, toolbox, agent | The whole declarative surface |
| `src/logic.py` | Settings, instructions, memory decision | Pure — 100% unit tested |
| `src/main.py` | Builds the agent, serves Responses | Thin wiring, lazy SDK imports |
| `src/Dockerfile` | Container image | What actually runs |
| `src/requirements.txt` | Pinned SDKs | Reproducible builds |
| `scripts/provision_memory_store.py` | Creates the memory store | Run by the postprovision hook |

## Components: features and benefits

**Toolbox** — a named bundle of tools, wired to the agent by name.
*Benefit:* several agents reuse one bundle; auth and observability are handled
per tool call; you audit tool usage in one place instead of per agent.

**MCP connection (Microsoft Learn)** — a remote tool server at
`https://learn.microsoft.com/api/mcp`. Public, free, no authentication.
*Benefit:* the agent answers Microsoft questions from official current docs
instead of stale training data.

**Second MCP connection with `?maxTokenBudget=2000`** — the same server, capped.
*Benefit:* a concrete cost lever you can demonstrate by comparing two identical
questions.

**Scoped web search (`pwc_site_search`, `mslearn_site_search`)** — web search
restricted to named domains. *Benefit:* the agent cannot cite a random blog.

**File search over the two PDFs** — grounding on documents you control.
*Benefit:* workshop-specific answers no public source could give.

**Memory store** — extracts stable user facts, consolidates, recalls later.
*Benefit:* session two does not start from nothing. *Cost:* needs an embedding
deployment and the OpenAI User role, or writes fail 401 **silently**.

**`sessionConfiguration.idleTimeoutSeconds: 300`** — min 300, default 900,
max 3600. *Benefit of short:* pay nothing while idle. *Cost:* cold start on the
next turn. *Not a cost:* your files — the sandbox filesystem survives.

**`container.resources`** — cpu "0.5", memory 1.0Gi (ranges "0.25"–"4.0" and
0.5Gi–8.0Gi). *Benefit:* right-size per agent rather than one global default.

**`ENABLE_TRACING` + App Insights** — on from the first run.
*Benefit:* Lab 5 can trace a call you made in Lab 2.
