# Lab 3 - Multi-agent workflow with model router (40 min)

## 1. Read the anatomy

`agents/03-maf-workflow-router/src/logic.py` - the whole design is here, and it
is pure data:

```python
ROLE_MODEL_HINTS = {
    "researcher": "cheap_b",   # many short tool calls -> cheapest model
    "analyst":    "router",    # variable difficulty -> let the router choose
    "writer":     "cheap_a",   # longer prose -> slightly better model
}
```

Three agents, three different model strategies, in one workflow.

## 2. Why a workflow instead of one clever agent

| One agent with a long prompt | A workflow of three |
|---|---|
| One context holds everything | Each role sees only what it needs |
| One model for every step | Cheap model for search, better one for prose |
| Hard to test a single step | Each role is separately testable |
| One trace, hard to read | Trace shows each handoff |

**Benefit:** you can change the researcher's model without touching the writer.

## 3. Model router

`model-router` is a deployment that picks a model per request from a pool.
The **analyst** uses it because analysis difficulty varies wildly. The other two
roles are pinned, because you want their behaviour stable.

## 4. Deploy and run

```bash
cd agents/03-maf-workflow-router
azd env new lab03 --no-prompt
azd env set FOUNDRY_PROJECT_ENDPOINT "$FOUNDRY_PROJECT_ENDPOINT"
azd env set WS_ROUTER_MODEL "model-router"
azd env set WS_CHAT_MODEL "gpt-5.4-mini"
azd env set WS_CHAT_MODEL_B "gpt-5.4-nano"
azd up
```

Then in the playground, ask something that needs all three roles:

> *"What changed in Foundry hosted agents this year, and what does it mean for
> a team running 50 agents?"*

## 5. Read the trace - this is the point of the lab

Portal -> **Tracing** -> your call. You should see:

- three spans, one per role, in order
- the researcher's MCP tool calls nested inside its span
- **a different model name on the analyst span than on the other two**

Find the analyst span. Which model did the router choose? Ask an easier question
and look again - did it choose differently?

## 6. Cost

```bash
python3 -c "
import sys; sys.path.insert(0,'../..')
sys.path.insert(0,'src')
import logic
print('model calls per turn:', logic.estimate_calls(logic.role_specs()))
"
```

Three roles = three model calls per turn, minimum. A workflow is not free. The
trade is: you spend more calls on cheaper models instead of one call on an
expensive one.

## Exercise

Change the writer from `cheap_a` to `router`. Redeploy. Compare the traces.
Did the router pick a more expensive model for prose than for search?
