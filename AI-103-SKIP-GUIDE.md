# AI-103 Days 1 & 2 — what to skip, what to substitute

Both days use **`microsoftlearning.github.io/mslearn-ai-agents/`**.

Attendees stay in **hub-and-spoke** throughout. They never create a Foundry
resource, never deploy a model, never delete a resource group.

---

## The three universal rules

Give attendees these on a card. They apply to **every** exercise.

> **1. Never create a project or resource.** Whenever a lab says "create a new
> project", select your existing project **`proj-attendee-NN`** instead.
>
> **2. Never deploy a model.** The model is already deployed on the shared hub.
> Wherever a lab says "deploy gpt-5", use **`<WS_CHAT_MODEL>`** instead.
>
> **3. Never do the "Clean up" section.** Deleting the resource group would
> destroy the shared environment for all 35 of you. Your permissions will block
> it, but do not try.

---

## Exercise 01 — Build AI agents with portal and VS Code

| Section | Action |
|---|---|
| Prerequisites | Skip local VS Code/Python/Git — you already have them in Codespaces |
| **"Create a Microsoft Foundry Project"** — the whole section | **SKIP.** Open `ai.azure.com`, confirm **New Foundry** toggle is on, and select `proj-attendee-NN` from the project dropdown |
| "…select Create agent. Set the Agent name to `it-support-agent`" | **DO.** Name it `it-support-agent-NN` |
| "an available deployed model is already selected for you" | **VERIFY** it is the shared hub deployment. If the portal offers to deploy a model, stop — you should not have that option |
| Configure instructions, upload `IT_Policy.txt`, add File search + Code interpreter | **DO ALL** — project-scoped, your role covers it |
| Upload `system_performance.csv` to Code interpreter | **DO** |
| Test in playground | **DO** |
| VS Code / Foundry Toolkit half | **DO.** Set Default Project → `proj-attendee-NN` |
| **Clean up** | **SKIP ENTIRELY** |

---

## Exercise 02 — Use a custom function in an AI agent

| Section | Action |
|---|---|
| **"Create a Foundry project with the Foundry Toolkit for VS Code extension"** | **SKIP the create.** Do install the extension. Then right-click the project → **Switch Default Project** → `proj-attendee-NN` |
| **"Deploy a model"** — the whole section | **SKIP.** No Model Catalog, no Deploy button |
| "Right-click the project deployment → Copy Project Endpoint" | **SKIP** — use `$FOUNDRY_PROJECT_ENDPOINT`, already set by `login.sh` |
| Clone repo, `pip install -r requirements.txt` | **DO** |
| Edit `.env` | **DO**, but set `MODEL_DEPLOYMENT_NAME=<WS_CHAT_MODEL>` and paste `echo $FOUNDRY_PROJECT_ENDPOINT` |
| All the code sections (`functions.py`, `agent.py`) | **DO ALL** |
| `az login` | **SKIP** — already signed in via `login.sh` |
| `python agent.py` | **DO** |
| Code line `project_client.agents.delete_version(...)` | **KEEP IT.** That deletes *your agent*, not the shared resources — it is correct and good hygiene |
| **Clean up → "Delete your model"** | **SKIP** — it is the shared hub model |
| **Clean up → "Delete the resource group"** | **SKIP** |

---

## Exercise 03 — Extend agents with MCP tools

| Section | Action |
|---|---|
| **"Create a Foundry project with the Foundry Toolkit…"** | **SKIP the create**, switch default project to yours |
| **"Deploy a model"** | **SKIP.** Note it says *"Raise the Tokens per Minute limit to 150000"* — you cannot, and the hub is already sized |
| "Copy Project Endpoint" | **SKIP** — use `$FOUNDRY_PROJECT_ENDPOINT` |
| Clone, venv, `.env` | **DO**, same substitution as Exercise 02 |
| `MCPTool(server_url="https://learn.microsoft.com/api/mcp")` | **DO** — public, free, no auth |
| Custom MCP server (`server.py`, `client.py`) | **DO ALL** — runs locally in your Codespace |
| `az login` | **SKIP** |
| **Clean up** (both parts) | **SKIP ENTIRELY** |

---

## Exercise 04 — Integrate an AI agent with Foundry IQ *(the AI Search one)*

**Yes, this works — with one change.** You pre-create the Search service and
storage account; attendees do only the Foundry-side steps.

Run first: `infra/36-shared-ai-search.sh`. It creates one **S1** search service
(50-index limit — enough for 35 attendees at one knowledge base each; Basic's
15 is not), one storage account, uploads the three Contoso PDFs, and writes a
handout with both keys to `.out/foundry-iq-handout.txt`.

| Section | Action |
|---|---|
| **"Create a Foundry project"** | **SKIP.** Use `proj-attendee-NN` |
| "select Create agent… it will deploy the default model" | **DO** — name it `product-expert-agent-NN`. The model is already there |
| Set instructions, Save | **DO** |
| "Knowledge → Add → Connect to Foundry IQ" | **DO** |
| **"Connect to an AI Search resource" → "Create new resource"** | **SKIP the create.** Select the existing **`<search service from your handout>`** |
| **Download + extract `contoso-products.zip`** | **SKIP** — already uploaded |
| **Create a storage account in the Azure portal** | **SKIP** — use the one on your handout |
| **Create container `contosoproducts`, upload 3 PDFs** | **SKIP** — already done |
| "Security + networking → Keys → set API Access control to Both" | **SKIP** — already set |
| "Create a knowledge base… Name: `ks-contosoproducts`" | **DO — but name it `ks-contosoproducts-NN`.** All 35 of you share one search service; identical names collide |
| Storage account name / Container name | Use the values on your handout |
| Authentication type: **API Key** | **DO** — paste the storage key from the handout |
| Embedding model | Select `<WS_EMBEDDING_MODEL>` (already on the hub) |
| Chat completions model | Select `<WS_CHAT_MODEL>` |
| "Manage → Connected resources → Key authentication → paste search key" | **DO** — search key is on your handout |
| Test in playground, VS Code approval config, `agent_client.py` | **DO ALL** |
| `az login` | **SKIP** |
| **Clean up → "Delete resource group"** | **SKIP ENTIRELY** — it would delete everyone's search service |

**Watch for:** the lab's approval-flow step uses the Foundry Toolkit to set
"Ask for approval for all tools" on the `kb-knowledgebase…` tool. That is
project-scoped and works fine.

---

## Exercises 05a / 05b — drop both

| Exercise | Why |
|---|---|
| **05a Deploy agents to Teams and Copilot** | Needs an **Azure Bot Service** (Contributor at RG — not granted; Foundry roles carry no `Microsoft.BotService/*` permissions at all) plus app sideloading into your M365 tenant. Drop it, or demo it yourself from your own subscription |
| **05b Work IQ** *(already marked optional)* | Reads real M365 mail, files and meetings. Your attendee accounts have none, so it will demonstrate nothing |

---

## Exercises 06–09 — same pattern

`06-build-workflow-ms-foundry`, `07-agent-framework`,
`08-agent-framework-multi-agents`, `09-multi-remote-agents-with-a2a`.

I verified Exercises 01–04 line by line. These four follow the same structure,
so apply the three universal rules:

1. Skip "Create a Foundry project" → use `proj-attendee-NN`
2. Skip "Deploy a model" → use `<WS_CHAT_MODEL>` in `.env`
3. Skip every "Clean up" section
4. Skip `az login` (already done), keep in-code `delete_version` calls

**Walk these four yourself before the day** to confirm nothing new appears —
06 in particular builds a workflow in the portal and may create extra objects.

---

## What your attendees CAN still do

Everything that matters, because it is all project-scoped and covered by
**Foundry Project Manager** on their own spoke:

create agents · upload files · File Search · Code Interpreter · custom
function tools · MCP connections (remote and local) · knowledge bases ·
connections · playground · tracing · versioning · delete their own agents

---

## Instructor checklist

```bash
cd infra
./36-shared-ai-search.sh          # before Exercise 04
cat ../.out/foundry-iq-handout.txt   # print onto the attendee cards
./40-verify.sh                     # morning of
```

Add to each attendee card:

```
Your project : proj-attendee-NN
Chat model   : <WS_CHAT_MODEL>
Embed model  : <WS_EMBEDDING_MODEL>
Endpoint     : echo $FOUNDRY_PROJECT_ENDPOINT

NEVER: create a project · deploy a model · delete a resource group
```
