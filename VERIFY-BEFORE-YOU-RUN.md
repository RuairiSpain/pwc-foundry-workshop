# Verify before you run

I built this against current Microsoft documentation. Some of it is public
preview and moves fast. This file is an honest split between **what I verified**
and **what you must confirm in your own tenant**.

## Verified against current documentation

| Thing | Source |
|---|---|
| `sessionConfiguration.idleTimeoutSeconds`, min 300 / default 900 / max 3600 | Foundry samples: `hosted-agent-session-configuration` |
| `azure.yaml` service hosts: `azure.ai.project`, `.agent`, `.toolbox`, `.connection`, `.skill`, `.routine` | azure.yaml reference for hosted agents |
| Toolbox wiring: a toolbox must appear in **both** `uses:` and `toolboxes:` | Author azure.yaml for hosted agents |
| `container.resources` ranges: cpu "0.25"–"4.0", memory 0.5Gi–8.0Gi | Same |
| Never declare `FOUNDRY_PROJECT_ENDPOINT` in `env:` — platform-injected | Same |
| Microsoft Learn MCP: `https://learn.microsoft.com/api/mcp`, free, **no auth** | Learn MCP developer reference |
| Learn MCP tools: `microsoft_docs_search`, `microsoft_docs_fetch`, `microsoft_code_sample_search` | Same |
| `?maxTokenBudget=` query parameter | Learn MCP registry |
| `azd ext install microsoft.foundry` installs the whole `azd ai` surface | Install the azd Foundry extensions |
| There is **no `az ai` extension** — the agent CLI lives under `azd` | Same |
| Foundry role GUIDs; roles renamed (Azure AI User → Foundry User) | Foundry RBAC docs, azure-skills repo |
| Memory store needs **Cognitive Services OpenAI User** or writes fail 401 | Memory hosted-agent quickstart |
| Memory store created via postprovision hook + `FoundryMemoryProvider` | Same |
| Magentic orchestration: manager dynamically selects the next agent | MAF Magentic docs |
| Harness is swappable (MAF / GitHub Copilot SDK / Claude Agent SDK) | MAF harness docs, Build 2026 announcements |
| Per-session VM-isolated sandbox with persistent filesystem | Hosted agents concepts |
| Codespaces: billed to codespace owner; fork → personal free quota | GitHub Codespaces billing |
| Codespaces: default image storage is **not** counted; custom base image is | Same |
| Foundry resource vs classic hub: different providers, agent features only on new | Foundry architecture docs |

## Confirm in YOUR tenant before the workshop

1. **Model names and versions.** `gpt-5.4-mini`, `gpt-5.4-nano`,
   `model-router`, `text-embedding-3-small` and the version strings in
   `00-config.sh` are plausible current values, **not confirmed for your
   region**. Run:
   ```bash
   az cognitiveservices account list-models -g <rg> -n <acct> -o table
   ```
   Fix `00-config.sh` before `run-all.sh`.

2. **Quota.** The single most likely thing to ruin the day. Request an increase
   now — lead time is days.

3. **`authMode: onBehalfOf` on the toolbox (Lab 4).** OBO for toolboxes is
   documented at the concept level ("per-user context via Toolbox OBO"), but I
   could not confirm the exact `azure.yaml` field name against the schema.
   Validate with `azd provision` on one spoke before teaching it. The *concept*
   in Lab 4 is correct regardless; only the field name is at risk.

4. **AI gateway (Lab 5, step 5).** Gateway routing and policy differ between API
   Management and the built-in Foundry gateway. The `ApiManagementGatewayLogs`
   KQL assumes API Management. Confirm your gateway shape.

5. **KQL table names.** Which tables receive data depends on your diagnostic
   settings. **Always run `kql.table_discovery()` first** — Lab 5 tells
   attendees to do exactly that.

6. **Evaluation and optimisation UI (Lab 5, steps 7–8).** Menu names and the
   availability of agent optimisation vary by region and rollout. Walk the
   portal path yourself before the day.

7. **Python package versions.** `requirements.txt` pins are lower bounds
   believed current; `agent-framework-foundry-hosting` is prerelease. Run one
   agent end to end a week early.

8. **The `--force-change-password-next-sign-in false` flag** in
   `10-create-users.sh` may be blocked by tenant password policy. If user
   creation fails, that is the first thing to check.


## Permissions: what changed and what to watch

The role plan was corrected after review against the Foundry hosted-agent
permissions reference. Four gaps were found and fixed:

| Gap | Symptom it would have caused | Fix |
|---|---|---|
| Foundry User cannot create connections | `azd up` fails on the MCP connection in Labs 2-4 | Foundry Project Manager on own spoke |
| No Monitoring Reader | Lab 5 tracing shows metrics but **no traces** | Monitoring Reader on App Insights |
| No Log Analytics access | Lab 5 KQL returns "no access" | Log Analytics Reader on the workspace |
| AcrPull granted to humans, nothing to project MIs | Image push fails; agents cannot pull at runtime | AcrPush to users, AcrPull + LA Reader to each project MI |

**Still verify these two:**

1. **`authMode: onBehalfOf`** (Agent 4). Separately, note the permissions
   reference says the `UserIdentityImpersonation` data action for the
   `x-ms-user-identity` header "is not included in any built-in role" and that
   Foundry User/Owner **no longer** grant it - a custom role is required. That
   is middle-tier header delegation, which is *not* the same as toolbox OBO,
   but if your OBO lab needs impersonation you will need that custom role.
   Test one spoke end to end before teaching it.

2. **Publishing as an Agent Application.** Creating an `agentDeployment` object
   needs Foundry Project Manager at the **account** scope, not project scope.
   The labs use the agent *endpoint* path (which works at project scope). If you
   add an Agent Application step, attendees will need a wider grant.

## The one-hour rehearsal that de-risks everything

```bash
cd infra
WS_ATTENDEE_COUNT=2 ./run-all.sh      # build a 2-person version
./40-verify.sh
# sign in as attendee01 in a private browser window, run Labs 0-2 end to end
./99-teardown.sh                      # then rebuild at 35
```

If that hour works, the workshop works.
