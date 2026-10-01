# Lab 0 - Start here (15 min)

## What you are about to build

Four agents, each teaching a different part of Microsoft Foundry:

| # | Agent | Shape | Teaches |
|---|---|---|---|
| 1 | `pwc-hello-agent` | prompt | Instructions, skills, versioning |
| 2 | `pwc-knowledge-agent` | hosted | Toolboxes, MCP, PDF grounding, memory, idle timeout |
| 3 | `pwc-workflow-agent` | hosted | MAF multi-agent workflow, model router |
| 4 | `pwc-dev-team-agent` | hosted | Magentic harness, sub-agents, sandbox, git worktrees, OBO |

You work in **your own Foundry project**. Everyone shares one hub, which owns
the model deployments, but your agents are yours alone.

## Step 1 - Get into your environment

1. Open the workshop repository on GitHub.
2. Click **Fork** (top right). Fork it to *your own* account.
   > Why fork? Codespaces compute bills to whoever owns the codespace. From
   > your fork, it bills to your personal free quota - 120 core-hours a month.
   > At 4 cores for 18 hours you will use ~72 of them. It costs you nothing.
3. In your fork: **Code -> Codespaces -> Create codespace on main**.
4. Choose the **4-core** machine. (8-core would exceed the free quota.)
5. Wait ~2 minutes for setup to finish.

## Step 2 - Sign in

In the terminal panel (`Ctrl+` ` if you cannot see it):

```bash
./login.sh 07          # <-- YOUR number from the card you were handed
source ~/.bashrc
```

A device code appears. Open <https://microsoft.com/devicelogin> in a new tab,
paste the code, sign in with the username and password on your card.

> **Why device code?** Browser-based Codespaces cannot complete the normal
> localhost redirect that `az login` uses. `--use-device-code` sidesteps that.
> This is the single most common failure in cloud-IDE labs - now you know why.

## Step 3 - Prove it worked

```powershell
$env:FOUNDRY_PROJECT_ENDPOINT
az account show --query user.name -o tsv
bash ../infra/50-smoke-test-agent.sh $env:ATTENDEE_NUMBER
```

You should see `workshop ready` come back from the model.

## Step 4 - See the boundary for yourself

```bash
# You can SEE your neighbour's project (Reader on the hub):
az cognitiveservices account project show \
  -g rg-pwc-agents-lab --name fdy-pwc-agents-hub \
  --project-name proj-attendee-08 --query name -o tsv

# But you CANNOT read what is inside it - this should fail with 403:
az rest --method get \
  --url "https://fdy-pwc-agents-hub.services.ai.azure.com/api/projects/proj-attendee-08/agents?api-version=2026-05-01" \
  --resource https://ai.azure.com
```

That is the difference between a **control-plane** role (Reader: see that it
exists) and a **data-plane** role (Foundry User: read and write what is inside).
You have Reader on the hub and Foundry User on your spoke only.

## Codespaces features worth knowing

- **Terminal**: full bash with `sudo`. `az`, `azd`, `git`, `python` all work.
- **Ports**: when an agent runs locally, VS Code forwards its port - click the
  toast to open it.
- **Stop it when you break**: Codespaces auto-suspends when idle, and you are
  not billed while suspended. You do not need to do anything.
- **Rebuild**: `Ctrl+Shift+P` -> *Rebuild Container* if setup went wrong.
- **Delete it afterwards**: github.com/codespaces. Storage bills while it exists.

Next: `LAB-01-prompt-agent.md`
