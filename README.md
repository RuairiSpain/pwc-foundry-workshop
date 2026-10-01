# PwC Agents Workshop — Microsoft Foundry

A complete, runnable 3-day workshop environment: 35 attendee identities, a
hub-and-spoke Foundry topology, four teaching agents, GitHub Codespaces setup,
and a full observability lab.

> **Read `VERIFY-BEFORE-YOU-RUN.md` first.** Parts of this stack are in public
> preview and move quickly. That file lists exactly what I verified against
> current documentation and what you must confirm in your own tenant.

---

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

Every grant traces to the Foundry hosted-agent permissions reference.

**Attendee (human):**

| Role | Scope | Why |
|---|---|---|
| **Reader** | hub | See the hub, its **shared model deployments**, and that sibling spokes exist |
| **Foundry Project Manager** | own spoke | Create agents **and connections** |
| **Cognitive Services OpenAI User** | hub | Memory-store embeddings (without it: silent 401) |
| **Cognitive Services Usages Reader** | subscription | Quota visibility in the portal |
| **AcrPush** | resource group | Push hosted-agent container images |
| **Monitoring Reader** | App Insights | **Read traces** (Lab 5) |
| **Log Analytics Reader** | workspace | **Run KQL** (Lab 5) |
| *Foundry Agent Consumer* | *demo project* | *Optional: invoke instructor agents, not edit them* |

**Project managed identity (per spoke):**

| Role | Scope | Why |
|---|---|---|
| **Foundry User** | hub | Project proxies inference to the shared deployments |
| **AcrPull** | resource group | Pull the agent image at runtime |
| **Log Analytics Reader** | workspace | Telemetry for the evaluations step |

**Why Project Manager and not Foundry User.** Every lab declares
`azure.ai.connection` services (the MCP servers). Creating a connection needs
`.../projects/connections/write` at project scope - "Foundry User: No. Foundry
Project Manager: Yes." Scoped to their own spoke, so it grants nothing over
anyone else's project.

**The limit to be aware of:** "read access to sibling spokes" works at the
*control plane* only. Reader lets an attendee see that `proj-attendee-08`
exists; it does NOT let them read its agents or data. Granting a Foundry
data-plane role at *hub* scope WOULD inherit to all 35 spokes and destroy the
isolation - `40-verify.sh` step 7 tests for exactly that, and
`tests/test_rbac.py` tests the planner that produces the assignments.

**Agents are not hub objects.** The hub holds model deployments and
connections; agents live inside projects. If you want attendees to reach
instructor demo agents, put them in a shared project and set `WS_DEMO_PROJECT`
- they get **Foundry Agent Consumer** there (invoke only, cannot modify).

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
| `35-ai103-sandboxes.sh` | **AI-103 only:** per-attendee resource group + Owner |
| `40-verify.sh` | 20+ read-only checks. Non-zero exit if anything is wrong |
| `45-verify-ai103.sh` | **AI-103 only:** sandbox checks + quota headroom |
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

## 2a. Attendees on locked-down laptops (no GitHub / no Codespaces)

If attendees cannot use GitHub Codespaces, use **one Azure VM per attendee
reached through Azure Bastion in the browser** - no install, no GitHub account,
no admin rights needed on their laptop.

```bash
cd infra-labvms
vim 00-labvm-config.sh     # subscription, tenant domain, LAB_COUNT=35, LAB_AUTO_COUNT=25
./10-create-labvms.sh      # ~25 min
./20-install-tools.sh      # ~15 min
./30-grant-access.sh       # ~2 min
./40-auto-shutdown.sh      # free native backstop at 14:00 daily
./41-schedule-power.sh --test   # auto start 08:30 / stop 14:00 on lab days
./42-passwordless-login.sh      # Entra ID sign-in - no VM password needed
./50-verify-labvms.sh      # confirms attendees have NO power rights
./start-reserve-vms.sh 26 27    # if extra attendees arrive
./test-vm.sh start|stop    # YOUR test VM - excluded from all schedules
```

Run `./05-check-prereqs.sh` first in `infra-labvms`; it checks providers and
whether the current regional/BS-family quota can support 35 B2ms attendee VMs
plus the B4ms instructor test VM.

~$8 per attendee for three 4-hour sessions. Full comparison of every option,
including why Cloud Shell and Bastion Developer SKU do **not** work:
**`LOCKED-DOWN-LAPTOPS.md`**.

---

## 2b. Running AI-103 as well? Read this first

**The AI-103 labs break hub-and-spoke.** Every exercise tells attendees to
create their own Foundry *resource*, AI Search service, storage account and
model deployments - none of which the hub-and-spoke permissions allow.

Fix: give each attendee a personal sandbox resource group.

```bash
cd infra
./35-ai103-sandboxes.sh     # rg-pwc-ai103-NN per attendee, Owner on their own
./45-verify-ai103.sh        # confirms it works AND that sandboxes don't leak
```

Both environments coexist: hub-and-spoke for the custom Foundry workshop,
personal sandboxes for AI-103. Full analysis, per-lab permission table and the
quota warning: **`AI-103-COMPATIBILITY.md`**.

**Only running Days 1 and 2 and skipping the resource steps?** You do not need
sandboxes at all - attendees stay in hub-and-spoke. See
**`AI-103-SKIP-GUIDE.md`** for the exercise-by-exercise skip list, and run
`infra/36-shared-ai-search.sh` first if you want the Foundry IQ (AI Search)
exercise.

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

## 4. Getting started with Codespaces

Attendees fork the repo and create a Codespace **from their fork**, so compute
bills to their own free quota (120 core-hours/month on a free personal account).

| Machine | Core-hours for 18 hrs | Free? |
|---|---|---|
| 2-core | 36 | ✅ |
| **4-core** | **72** | ✅ **use this** |
| 8-core | 144 | ❌ exceeds quota |

`devcontainer.json` deliberately specifies **no base image** — Codespaces built
on the default Linux image do not count the container against the 15 GB storage
quota, while a custom base image does.

Installed: `az`, `azd`, `azd ext install microsoft.foundry`, Python 3.12,
Docker-in-Docker, Foundry Toolkit, Azure Resources, Continue (chat UI).

### Login

```bash
./login.sh 07 && source ~/.bashrc
```

Device code flow — the only login that works reliably in a browser Codespace,
because the normal localhost redirect cannot reach the attendee's browser.
`login.sh` also pins `FOUNDRY_PROJECT_ENDPOINT` and sets the azd project
context, so every later command targets the right spoke.

---

## 5. Getting started with Foundry

| Concept | What it is | Where you meet it |
|---|---|---|
| **Foundry resource (hub)** | Governance boundary; owns models, networking, security | Architecture, Lab 0 |
| **Foundry project (spoke)** | Development boundary; owns agents, threads, files | Every lab |
| **Prompt agent** | Model + instructions + tools, declared in YAML. No code | Lab 1 |
| **Hosted agent** | Your code in a container on managed infra | Labs 2–4 |
| **Skill** | Reusable markdown behaviour module | Lab 1 |
| **Toolbox** | Named bundle of tools with auth + observability per call | Lab 2 |
| **MCP connection** | Remote tool server (we use Microsoft Learn, free, no auth) | Labs 2–4 |
| **Memory store** | Persistent user facts across sessions | Lab 2 |
| **Session / idle timeout** | Stateful sandbox; 300–3600s, default 900 | Lab 2 |
| **Workflow** | Multiple agents orchestrated as one | Lab 3 |
| **Model router** | Picks a model per request | Lab 3 |
| **Harness** | The runtime that drives tools, context, approvals | Lab 4 |
| **Magentic** | Manager dynamically picks who acts next | Lab 4 |
| **OBO** | Tool calls run as the signed-in user | Lab 4 |
| **Tracing / evaluation** | Spans per turn; scored quality runs | Lab 5 |

---

## 6. The four agents

| # | Agent | Kind | Idle timeout | Key components |
|---|---|---|---|---|
| 1 | `pwc-hello-agent` | prompt | n/a | 2 skills, explicit model parameters, versioning |
| 2 | `pwc-knowledge-agent` | hosted | **300s** | Toolbox, 2 MCP connections, 2 site searches, 2 PDFs, memory |
| 3 | `pwc-workflow-agent` | hosted | 600s | 3-agent MAF workflow, model-router + 2 cheap models |
| 4 | `pwc-dev-team-agent` | hosted | 1800s | Magentic, 4 sub-agents, swappable harness, worktrees, OBO |

Every `azure.yaml` writes out its defaults explicitly rather than relying on
them, so the class can see and change each one. Idle timeouts differ **on
purpose** — Lab 2 asks attendees to explain why.

Each agent folder has its own README covering anatomy, features and benefits
per component, and a step-by-step walkthrough.

### No agent-name clashes

Each attendee deploys into their own spoke, so identical agent names across
attendees never collide. Within one spoke, all four agents have distinct names —
`tests/test_shipped_manifests.py::test_agent_names_are_unique_across_the_workshop`
enforces it.

---

## 7. Labs

| Lab | Time | Covers |
|---|---|---|
| `LAB-00-START-HERE.md` | 15 min | Fork, Codespace, login, see the RBAC boundary |
| `LAB-01-prompt-agent.md` | 25 min | Prompt agent, skills, playground, trace, versions |
| `LAB-02-hosted-knowledge-agent.md` | 45 min | Toolbox, MCP, PDFs, memory, **idle timeout** |
| `LAB-03-workflow-model-router.md` | 40 min | Multi-agent workflow, model router, cost |
| `LAB-04-dev-team-harness.md` | 50 min | Magentic, sub-agents, sandbox, worktrees, OBO |
| `LAB-05-publish-test-observe.md` | 45 min | Publish, curl, chat UI, gateway, traces, **KQL**, evaluation |

---

## 8. Tests

```bash
python3 -m pip install -r requirements-dev.txt
python3 run_tests.py
```

**151 tests, 100% line coverage** on all nine measured modules. The runner does
not need pytest or coverage, but the manifest tests need PyYAML from
`requirements-dev.txt`.

```
workshop_toolkit/config.py       74 stmts   0 miss   100.0%
workshop_toolkit/identity.py     45 stmts   0 miss   100.0%
workshop_toolkit/rbac.py         35 stmts   0 miss   100.0%
workshop_toolkit/endpoints.py    26 stmts   0 miss   100.0%
workshop_toolkit/manifest.py     62 stmts   0 miss   100.0%
workshop_toolkit/kql.py          29 stmts   0 miss   100.0%
agents/02/src/logic.py           25 stmts   0 miss   100.0%
agents/03/src/logic.py           25 stmts   0 miss   100.0%
agents/04/src/logic.py           38 stmts   0 miss   100.0%
TOTAL                           359 stmts   0 miss   100.0%
```

The design that makes this possible: every agent splits **pure logic**
(`logic.py`, no network) from **wiring** (`main.py`, Azure SDK calls). Only
`logic.py` is coverage-measured; `main.py` is a thin adapter that cannot be
meaningfully unit tested without mocking the whole SDK. That is the intended
10% — and it is isolated in files that contain almost nothing else.

`tests/test_shipped_manifests.py` validates every `azure.yaml` we ship. **It
already caught a real bug**: `${VAR}` inside a YAML flow mapping (`{ a: ${X} }`)
is a parse error, and three manifests had it. Run the tests before every deploy.

---

## 9. Costs

| Item | 25 attendees, 3 days |
|---|---|
| Codespaces (4-core, their own free quota) | **£0** |
| Foundry model tokens | dominant cost — depends on usage |
| Hosted agents | scale to zero when idle |
| Log Analytics | pennies at this volume |

**The real constraint is model quota, not money.** 25–35 people sharing one
deployment will hit TPM limits. Request a quota increase in your region **now** —
lead time is days. Capacities in `00-config.sh` are starting points; raise them.

---

## 10. Layout

```
├── README.md, ARCHITECTURE.md, VERIFY-BEFORE-YOU-RUN.md, SECURITY.md
├── run_tests.py                 # unittest + trace coverage runner
├── requirements-dev.txt         # test-only dependency: PyYAML
├── login.sh                     # attendee login
├── .devcontainer/               # Codespaces
├── infra/                       # 8 provisioning scripts
├── workshop_toolkit/            # tested logic: config, identity, rbac, endpoints, manifest, kql
├── tests/                       # 129 tests
├── knowledge/                   # 2 PDFs used as grounding
└── agents/01..04/               # four agents, each with README + azure.yaml + src
```
