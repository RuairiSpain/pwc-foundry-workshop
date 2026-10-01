# AI-103 compatibility: does hub-and-spoke break?

**Short answer: yes, for AI-103 as written.** The labs tell every attendee to
create their own Foundry *resource*, not to use a project you provisioned for
them. Hub-and-spoke is still right for your custom Foundry workshop; it is the
wrong shape for AI-103. Run both side by side.

## The lab URLs in your OneDrive

`Documents/Customers/PWC/AI-103 - Azure AI App and Agent Developer/`

| Shortcut | URL |
|---|---|
| Day 1 - Develop generative AI solutions in Azure | `https://microsoftlearning.github.io/mslearn-ai-agents/` |
| Day 2 - Develop AI Agents in Azure | `https://microsoftlearning.github.io/mslearn-ai-agents/` |
| Day 3 - Develop AI Language and Speech solutions on Azure | `https://microsoftlearning.github.io/mslearn-ai-language/` |
| Day 4 - Develop computer vision solutions in Azure | `https://microsoftlearning.github.io/mslearn-ai-vision/` |

Note Day 1 and Day 2 point at the **same** repo. If Day 1 was meant to be
`mslearn-ai-studio` / the generative-AI repo, that shortcut needs fixing before
the event.

## Why hub-and-spoke breaks

Every lab opens with the same instruction. From
`mslearn-ai-agents` Exercise 01:

> "When prompted, create a new project ... Expand **Advanced options**:
> **Microsoft Foundry resource: A valid name for your Foundry resource** ...
> **Resource group: Select your resource group, or create a new one**"

And `mslearn-ai-language` Exercise 01:

> "**Foundry resource:** Use the default name for your resource
> (usually {project_name}-resource) ... **Resource group:** Create or select a
> resource group"

That is a new **Foundry account**, not a project on yours.

## What the attendee permissions do and do not cover

| Lab action | Needs | Your hub-and-spoke grant | Works? |
|---|---|---|---|
| Create a Foundry **resource** | Contributor / Owner / Foundry Account Owner @ RG | Foundry Project Manager @ own project | **No** |
| Create a **resource group** | Contributor @ subscription | none | **No** |
| Deploy a **model** | Contributor / Owner / Foundry Account Owner @ account | Reader @ hub | **No** |
| Create an **AI Search** resource (Foundry IQ lab) | Contributor @ RG | none | **No** |
| Create a **storage account** (Foundry IQ lab) | Contributor @ RG | none | **No** |
| Create an **Azure Bot Service** (Teams lab) | Contributor @ RG - Foundry roles carry **no** `Microsoft.BotService/*` | none | **No** |
| Create Speech / Language / Translator resources (Day 3) | Contributor @ RG | none | **No** |
| **Delete the resource group** (every lab's cleanup step) | Owner / Contributor @ RG | none | **No** |
| Create an **agent** inside a project | Foundry User / Project Manager (data plane) | granted on own spoke | Yes, but only on *your* spoke |

The permissions reference is explicit on the first row: *"Can assignee create a
Foundry account? Foundry User: No. Foundry Project Manager: No."*

## The fix: a personal sandbox per attendee

Run `infra/35-ai103-sandboxes.sh`. It creates `rg-pwc-ai103-NN` per attendee and
grants **Owner on that group only**.

**Why Owner and not Contributor.** Contributor creates resources but has no
data-plane rights, so the attendee could not create an agent inside the resource
they just made. The portal only auto-assigns Foundry User *"if the creator of
the project has the ability to assign the Foundry User role"* - and Contributor
cannot assign roles. Owner on one empty resource group is the least-friction
grant that actually works, and the blast radius is that group alone.

Verify with `infra/45-verify-ai103.sh`, which also checks that attendee01 has
**no** rights on attendee02's sandbox.

## The two environments side by side

```
Subscription
├── rg-pwc-agents-lab            <- YOUR custom workshop (hub-and-spoke)
│   └── fdy-pwc-agents-hub       shared models, 35 spoke projects
│        attendees: Reader on hub + Project Manager on own spoke
│
├── rg-pwc-ai103-01              <- AI-103 sandbox, attendee 01, Owner
├── rg-pwc-ai103-02              <- AI-103 sandbox, attendee 02, Owner
└── ...                             each builds their own Foundry resource
```

Both work at once. Tell attendees which one they are in for each session - that
is the single most common source of confusion when running these back to back.

## The thing that will actually bite you: quota

Hub-and-spoke shares **one** model deployment across 35 people. AI-103 has each
attendee deploy **their own**, and creating an agent in the portal auto-deploys
a default model. So:

- **35 x per-attendee capacity** must fit under your subscription's regional quota.
- Day 3 adds Speech, Language and Translator; Day 4 adds image generation and
  **Sora**, which has narrow regional availability and its own quota.
- The Foundry IQ lab adds an AI Search service **and** a storage account per
  attendee.

Request the increases now, per model and per region. This is the highest-risk
item on the whole plan and has the longest lead time.

## Labs to check or drop

| Lab | Issue |
|---|---|
| **Deploy agents to Teams and Copilot** (05a) | Needs Azure Bot Service plus the ability to sideload an app into your M365 tenant. Throwaway lab tenants usually block this. Test it or drop it |
| **Work IQ** (05b, marked optional) | Reads real M365 workplace data. Your attendee accounts have no mail, files or meetings, so it will demo nothing. Drop it |
| **Foundry IQ** (04) | Creates AI Search + storage per attendee. Uses **key** authentication and asks attendees into the Azure portal. Budget extra time |
| **Sora video** (vision day) | Narrow regional availability. Confirm your region before the day |

## Alternative if you want to keep hub-and-spoke

You would have to edit roughly 20 exercises to say "select your existing
project" instead of "create a project", and pre-deploy every model each lab
expects. That is a lot of editing against content that gets updated upstream,
and it breaks the cleanup steps. Not worth it for a four-day delivery - use the
sandboxes.

## Cleanup

`infra/99-teardown.sh` deletes the shared workshop group. Delete the sandboxes
separately:

```bash
for i in $(seq -w 1 35); do
  az group delete -n "rg-pwc-ai103-$i" --yes --no-wait
done
```
