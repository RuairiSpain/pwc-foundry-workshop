# Agent 1 - Hello World prompt agent (with two skills)

**Shape:** prompt agent. Configuration only - no container, no Dockerfile, no code.
**Cost:** tokens only. This is the cheapest agent in the workshop.
**Time:** ~15 minutes.

## Anatomy - read these files in this order

| File | What it is | What to look for |
|---|---|---|
| `azure.yaml` | The whole agent | `kind: prompt` - contrast with Agent 2's `kind: hosted` |
| `skills/uk-english-style.md` | A skill | Pure markdown. No code. Versioned separately |
| `skills/cite-sources.md` | A skill | Shapes *how* it answers, not *what* it can do |

## Why a prompt agent

A prompt agent is model + instructions + tools, declared in YAML. The platform
runs it. You get an endpoint, an identity, tracing and versioning without writing
or containerising anything.

Choose it when the agent's job is reasoning over a prompt and calling
platform-provided tools. Choose a **hosted** agent (Agent 2 onward) when you need
your own code, your own libraries, or a custom protocol.

## Features and benefits of each component

- **`instructions`** - the system prompt. Benefit: change behaviour without a
  deployment cycle.
- **Skills** - reusable behavioural modules discovered at runtime. Benefit: one
  house-style change updates every agent that references it; each skill is
  reviewable and versionable on its own.
- **`modelParameters`** - we have written out temperature, topP and
  maxOutputTokens rather than relying on defaults. Benefit: your demos are
  repeatable. Default temperature is 1.0, which makes a live demo a lottery.
- **`observability.tracing: true`** - on from the first run. Benefit: lab 5 can
  show you the trace of a call you made in lab 1.

## Steps

1. **Read the YAML.** Find `kind: prompt`. Find the two skills in `uses` *and*
   in `skills` - both are needed.
2. **Deploy:** `azd up`
3. **Playground:** Foundry portal -> your project -> Agents -> `pwc-hello-agent`.
   Ask: *"What is Microsoft Foundry, and when did you last verify that?"*
   Watch the `cite-sources` skill force an honest answer.
4. **Break a skill on purpose.** Edit `uk-english-style.md` to demand American
   spelling. Re-run `azd deploy`. Ask the same question. You changed behaviour
   without touching the agent definition.
5. **Trace:** portal -> Tracing. Find your call. Note that the skill text appears
   in the assembled context.
6. **Version:** `azd deploy` again and look at the version list. Each deploy is a
   new version against a stable endpoint.

## Exercise

Add a third skill, `refuse-pricing-questions.md`, that makes the agent decline to
quote prices. Wire it into `uses` and `skills`. Prove it works in the playground.
