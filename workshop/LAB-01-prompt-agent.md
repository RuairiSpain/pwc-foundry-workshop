# Lab 1 - Your first agent: a prompt agent with skills (25 min)

Read `agents/01-hello-prompt-agent/README.md` first - it explains the anatomy.

## 1. Read before you run

Open `agents/01-hello-prompt-agent/azure.yaml`. Find and be able to explain:

- `kind: prompt` - no container, no code
- `instructions:` - the system prompt
- the two `azure.ai.skill` services, and why each skill is referenced **twice**
  (once in `uses:` for ordering, once in `skills:` for the agent to load it)
- `modelParameters.temperature: 0.2` - we set this explicitly. The default is
  1.0, which makes live demos non-repeatable.

Now open `skills/uk-english-style.md`. A skill is just markdown. That is the
point: behaviour you can review, diff and version on its own.

## 2. Deploy

```bash
cd agents/01-hello-prompt-agent
azd env new lab01 --no-prompt
azd env set FOUNDRY_PROJECT_ENDPOINT "$FOUNDRY_PROJECT_ENDPOINT"
azd env set WS_CHAT_MODEL "$WS_CHAT_MODEL"
azd up
```

## 3. Playground

Foundry portal -> your project -> **Agents** -> `pwc-hello-agent` -> Playground.

Ask: *"What is Microsoft Foundry, and when did you last verify that?"*

Watch the `cite-sources` skill force an honest answer instead of a confident one.

## 4. Change behaviour without touching the agent

Edit `skills/uk-english-style.md` - demand American spelling and require an
exclamation mark in every reply. Then:

```bash
azd deploy
```

Ask the same question. The agent definition never changed. **Benefit:** house
style is owned by one file, and changing it is a reviewable diff.

## 5. Trace

Portal -> **Tracing**. Find your call. Expand it. Note:

- the assembled context includes both skill documents
- token counts in and out
- total latency

Keep this trace open - Lab 5 comes back to it.

## 6. Versioning

Run `azd deploy` again. Portal -> your agent -> **Versions**. Each deploy is a
new immutable version behind one stable endpoint. **Benefit:** you can roll back
without the caller changing a URL.

## Exercise

Add `skills/refuse-pricing-questions.md` so the agent declines to quote prices.
Wire it into `uses:` and `skills:`. Prove it in the playground.
