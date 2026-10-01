# Lab 2 - Hosted agent: toolbox, MCP, PDFs, memory (45 min)

## 1. Read the anatomy

`agents/02-hosted-knowledge-agent/` - open these in order:

| File | What it is |
|---|---|
| `azure.yaml` | Everything declarative: project, connections, toolbox, agent |
| `src/logic.py` | Pure logic - settings, instructions, memory decision. Unit tested |
| `src/main.py` | Thin wiring: builds the agent and serves the Responses protocol |
| `src/Dockerfile` | The container image |
| `scripts/provision_memory_store.py` | Creates the memory store (postprovision hook) |

**The split matters.** `logic.py` has no network calls, so it is 100% unit
tested. `main.py` is the only part that needs Azure. Run `python3 run_tests.py`
from the repo root to see it.

## 2. The four things in the toolbox

Open `azure.yaml` and find the `knowledge-tools` service:

1. **`learn-mcp`** - Microsoft Learn MCP server, `https://learn.microsoft.com/api/mcp`.
   Public, free, no authentication. Tools: `microsoft_docs_search`,
   `microsoft_docs_fetch`, `microsoft_code_sample_search`.
2. **`learn-mcp-budget`** - the same server with `?maxTokenBudget=2000`.
   Same tools, capped response size. A cost-control knob.
3. **`pwc_site_search`** - web search scoped to `pwc.com`.
4. **`mslearn_site_search`** - web search scoped to `learn.microsoft.com`.
5. **`workshop_pdfs`** - file search over the two PDFs in `knowledge/`.

> Tools 1 and 4 hit the same content by different routes. Later you will ask a
> question that makes them disagree - and see how the agent handles it.

## 3. THE IDLE TIMEOUT - the teaching moment

```yaml
sessionConfiguration:
  idleTimeoutSeconds: 300
```

- **Minimum 300, default 900, maximum 3600.** Outside that range, deploy fails.
- A *session* is the stateful container that keeps your agent process alive
  between messages. When it times out, the sandbox scales to zero.
- **We set 300 deliberately** so you can watch it happen during this lab.

**Benefit of a short timeout:** you pay nothing while idle.
**Cost of a short timeout:** the next message pays a cold start.
**What does NOT happen:** you do not lose your files. The filesystem persists
across scale-to-zero and resumes intact. That is the whole point of per-session
sandboxes.

## 4. Deploy

```bash
cd agents/02-hosted-knowledge-agent
azd env new lab02 --no-prompt
azd env set FOUNDRY_PROJECT_ENDPOINT "$FOUNDRY_PROJECT_ENDPOINT"
azd env set WS_CHAT_MODEL "$WS_CHAT_MODEL"
azd env set WS_EMBEDDING_MODEL "text-embedding-3-small"
azd env set MEMORY_STORE_NAME "pwc-memory-$ATTENDEE_NUMBER"
azd env set APPLICATIONINSIGHTS_CONNECTION_STRING "<ask the instructor>"
azd up
```

The `postprovision` hook creates your memory store automatically.

## 5. Run it locally first

```bash
azd ai agent run --no-client
# in a second terminal:
azd ai agent invoke --local --new-session "What is a Foundry toolbox?"
```

Local run, remote models. Fast iteration without a deploy cycle.

## 6. Playground exercises

1. *"What is the maximum idleTimeoutSeconds for a hosted agent?"*
   -> should hit the **PDFs** (it is in Handbook 1).
2. *"What does the azd ai agent init command do?"*
   -> should hit **Learn MCP**.
3. *"What does PwC say about AI governance?"*
   -> should hit **pwc_site_search**.
4. *"My name is <your name> and I am building a claims triage agent."*
   Then start a **brand new session** and ask *"What am I building?"*
   -> **memory** recalls it across sessions.

## 7. Watch scale-to-zero

Send a message. Wait 6 minutes without touching it. Send another.
The second message is slower - that is the cold start. Ask it to list the files
in its working directory before and after: they are still there.

## Exercise

Change `idleTimeoutSeconds` to `60`. Run `azd deploy`. Read the error carefully -
it is rejected at deploy time, not at runtime. Now set it to `1800` and explain
to the person next to you when you would want that.
