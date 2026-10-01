# Architecture

## 1. Architecture

```
                    Microsoft Entra tenant (yours)
                    35 attendee users, attendee01..attendee35
                                   |
        +--------------------------+--------------------------+
        |                                                     |
   GitHub Codespaces                             Azure subscription
   (attendee personal accounts,                          |
    free 120 core-hrs/month)                             |
        |                                    Resource group: rg-pwc-agents-lab
   devcontainer.json                                     |
   - az, azd, python                    +----------------+----------------+
   - Foundry Toolkit ext                |                                 |
   - azd ext microsoft.foundry   Foundry HUB (shared)          Log Analytics
        |                       Microsoft.CognitiveServices    + App Insights
        |                       /accounts, kind: AIServices          ^
        |                               |                            |
   ./login.sh NN  ---- device code ---> |                      all agent traces
                                        |
            SHARED MODEL DEPLOYMENTS (hub-level, everyone uses these)
            - gpt-5.4-mini     (cheap serverless chat)
            - gpt-5.4-nano     (cheaper still, for the router lab)
            - model-router     (picks a model per request)
            - text-embedding-3-small (memory store indexing)
                                        |
        +-------------------+-----------+-----------+-------------------+
        |                   |                       |                   |
   proj-attendee-01   proj-attendee-02   ...   proj-attendee-34   proj-attendee-35
   (SPOKE)            (SPOKE)                  (SPOKE)            (SPOKE)
   4 agents each      4 agents each            4 agents each      4 agents each
```

**Why hub-and-spoke:** model deployments and quota are expensive to duplicate
and easy to share. Agents, threads, files and evaluations are cheap to isolate
and dangerous to share. So the hub owns models; the spokes own everything else.

### Access model

| Principal | Role | Scope | Effect |
|---|---|---|---|
| Attendee | **Reader** | hub | Sees the hub and sibling spokes exist. No data access |
| Attendee | **Foundry User** | own spoke | Full build/test rights on their own project |
| Attendee | **Cognitive Services OpenAI User** | own spoke | Memory store embeddings (without it: silent 401) |
| Attendee | **Cognitive Services Usages Reader** | subscription | Quota visibility in the portal |
| Attendee | **AcrPull** | resource group | Hosted-agent container pulls |
| Project MI | **Foundry User** | hub | Agent runtime reaches the shared models |

**The limit to be aware of:** "read access to sibling spokes" works at the
*control plane* only. Reader lets an attendee see that `proj-attendee-08` exists;
it does not let them read its agents or data. Granting `Foundry User` at hub
scope *would* give cross-spoke data access — and would destroy the isolation.
`infra/40-verify.sh` explicitly tests that this has not happened.

---

## 2. Quick start (instructor)

```bash
# 1. Fill in your tenant details — this is the ONLY file you edit
vim infra/00-config.sh        # WS_TENANT_ID, WS_SUBSCRIPTION_ID, WS_TENANT_DOMAIN

# 2. Build everything
cd infra && ./run-all.sh

# 3. Verify (run again the morning of the workshop)
./40-verify.sh

# 4. Print the cards
cat ../.out/attendees.csv
```

`run-all.sh` runs, in order: create users → create Foundry topology → enable
observability → assign RBAC → verify. Every script is **idempotent**: re-running
skips what already exists.

| Script | What it does |
|---|---|
| `00-config.sh` | All parameters. Sourced by everything else |
| `05-check-prereqs.sh` | Read-only subscription/provider/SKU checks |
| `10-create-users.sh` | 35 Entra users + `.out/attendees.csv` roster |
| `20-create-foundry.sh` | Hub (or reuses yours), 4 model deployments, 35 spokes |
| `25-observability.sh` | Log Analytics, App Insights, diagnostic settings |
| `30-assign-rbac.sh` | All role assignments, users and managed identities |
| `37-create-instructor-spoke.sh` | Instructor spoke project and matching permissions |
| `40-verify.sh` | 20+ read-only checks. Non-zero exit if anything is wrong |
| `50-smoke-test-agent.sh` | End-to-end model call as an attendee |
| `60-deploy-agents.sh` | Deploys the four sample agents to all attendee spokes plus the instructor spoke |
| `65-verify-agents.sh` | Confirms all four sample agents exist in each spoke |
| `99-teardown.sh` | Deletes everything. Confirms twice |

### Passwords

`PwcAgents-2026-NN!` — predictable per-attendee Entra passwords.

**This is deliberately memorable, not a durable-account pattern.** It is
acceptable only because the tenant and accounts are short-lived, attendees are
scoped to their own spoke, and `99-teardown.sh` deletes the accounts afterwards.
Do not reuse this pattern.
The roster CSV holds plaintext passwords — delete it after the event.

---

## 3. Which hub do I have?

You said your hub already exists. **Check which kind**, because it decides
whether any of this works:

```bash
az resource list -g <your-rg> --query "[].{name:name,type:type}" -o table
```

| You see | Meaning | Verdict |
|---|---|---|
| `Microsoft.CognitiveServices/accounts` | Foundry resource | ✅ Everything here works |
| `Microsoft.MachineLearningServices/workspaces` | Classic ML hub | ❌ Different provider, different roles, no new agent features |

`20-create-foundry.sh` checks this and refuses to continue on the wrong kind.
New agent and model capabilities only ship to Foundry projects — a classic hub
cannot run this workshop.

---


## Data flow for one agent turn

```
attendee (Codespaces terminal / playground / curl / Continue)
    |  Entra token (az account get-access-token --scope https://ai.azure.com)
    v
Foundry project endpoint  https://<hub>.services.ai.azure.com/api/projects/<spoke>
    |
    +-- prompt agent  -> model deployment on the HUB
    |
    +-- hosted agent  -> per-session VM-isolated sandbox (persistent filesystem)
                             |
                             +-- model deployment on the HUB
                             +-- toolbox -> MCP (learn.microsoft.com/api/mcp)
                             +-- toolbox -> web_search (scoped domains)
                             +-- toolbox -> file_search (the 2 PDFs)
                             +-- memory store (chat + embedding deployments)
                             |
                             v
                   OpenTelemetry spans -> App Insights -> Log Analytics
                                                              |
                                                          KQL (Lab 5)
```

## Why the logic/wiring split

Every hosted agent is two files:

- `logic.py` — pure functions and dataclasses. No network, no Azure SDK.
  100% unit tested.
- `main.py` — builds clients, attaches providers, starts the host. Imports the
  SDK lazily so the tests never need it installed.

This is what makes 100% coverage achievable on the parts that carry decisions,
while the untestable adapter code is isolated in files that contain almost
nothing but adapter code.
