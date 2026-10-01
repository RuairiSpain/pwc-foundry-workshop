# Lab 5 - Publish, call, trace, and query the logs (45 min)

This lab ties all four agents together. Do it once per agent if time allows,
otherwise pick Agent 2.

## 1. Publish

```bash
azd deploy
azd ai agent list          # find your agent's endpoint
```

Portal -> your agent -> **Versions**. Note the version number. The endpoint URL
does not change between versions - that is the point of versioned endpoints
behind a stable address.

## 2. Call it with curl from the terminal

```powershell
$TOKEN = az account get-access-token --scope https://ai.azure.com/.default --query accessToken -o tsv

$ENDPOINT = "$env:FOUNDRY_PROJECT_ENDPOINT/agents/pwc-knowledge-agent/responses"

curl.exe -fsS $ENDPOINT `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/json" `
  -d '{"input":"What is the maximum idle timeout?","stream":false}'
```

Generate the command for any agent:

```bash
python3 -c "
import sys; sys.path.insert(0,'.')
from workshop_toolkit.config import WorkshopConfig
from workshop_toolkit.endpoints import agent_endpoint, build_curl, token_command
import os
cfg = WorkshopConfig.from_env()
url = agent_endpoint(cfg, int(os.environ['ATTENDEE_NUMBER']), 'pwc-knowledge-agent')
print(token_command()); print(build_curl(url, prompt='Hello from curl'))
"
```

## 3. Or use a chat UI inside Codespaces

The **Continue** extension is pre-installed. Point it at your agent:

`.continue/config.json`:
```json
{
  "models": [{
    "title": "My Foundry Agent",
    "provider": "openai",
    "model": "pwc-knowledge-agent",
    "apiBase": "<your FOUNDRY_PROJECT_ENDPOINT>",
    "apiKey": "<paste the token from step 2>"
  }]
}
```

The Responses protocol is OpenAI-compatible, which is why an OpenAI-shaped
client works against it. Swap `apiBase` to the **gateway URL** to compare paths.

> The token expires in about an hour. Re-run the `az account get-access-token`
> line when the UI starts failing.

## 4. Find the same call in the trace

Portal -> **Tracing**. Your curl call is there alongside your playground calls.
Expand it:

- **Input and output tokens** - the cost of that turn
- **Tool calls** - which tool, what arguments, what came back
- **Latency per span** - where the time actually went
- **The model name** - confirm which model answered

Copy the **correlation ID**. You need it for step 6.

## 5. Publishing through an AI gateway

Two ways to expose an agent:

| Direct | Through a gateway |
|---|---|
| Caller hits the agent endpoint | Caller hits the gateway, which forwards |
| Auth = Entra token for the project | Gateway can add keys, quotas, throttling |
| Logs in Foundry tracing | Also logs in gateway access logs |
| Simplest | Central policy, rate limits, per-consumer keys |

Use a gateway when several teams consume the same agent and you need per-consumer
quotas and one place to see all traffic.

> **Verify before teaching this section.** Gateway configuration differs between
> API Management and the built-in Foundry gateway; confirm the exact route and
> policy shape in your own tenant. The KQL in step 6 assumes API Management.

## 6. KQL - see the logs yourself

Portal -> Log Analytics -> `law-pwc-agents-lab` -> Logs.

**Always run this first** - table names depend on your diagnostic settings:

```kusto
search *
| where TimeGenerated > ago(1d)
| summarize Rows=count() by $table
| order by Rows desc
```

Then generate the rest:

```bash
python3 -c "
import sys; sys.path.insert(0,'.')
from workshop_toolkit import kql
print(kql.agent_requests('proj-attendee-07'))
print('---')
print(kql.agent_errors('proj-attendee-07'))
print('---')
print(kql.token_usage_by_model())
print('---')
print(kql.trace_by_correlation('<paste your correlation id>'))
"
```

Run each one. The last one follows a single conversation across Foundry traces,
app traces and dependencies - the same turn you watched in the portal, now as
raw rows you can join, alert on, and chart.

## 7. Evaluate with synthetic data

Portal -> your project -> **Evaluations** -> Create.

1. Generate a synthetic dataset from your agent's own domain (the evaluation
   tooling can produce question/answer pairs from your knowledge sources).
2. Pick built-in evaluators: **groundedness**, **relevance**, **coherence**.
3. Run against your agent.
4. Read the per-row scores, not just the average - the average hides the
   failures that matter.

**Benefit:** when you change a prompt in Lab 1, you can now prove whether you
made it better or just different.

## 8. Optimise

If your project offers **agent optimisation**, point it at your evaluation run.
It proposes instruction changes and re-scores them. Treat its output as a
suggestion to review, not a change to accept blindly - and re-run your own
evaluation after.

## Close the loop

You have now: built an agent, published it, called it three ways, watched the
trace, queried the raw logs, and measured quality. That is the full lifecycle.
