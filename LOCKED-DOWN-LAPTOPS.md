# No Codespaces: options for locked-down laptops

Sessions: **Wed 30 Sep, Fri 2 Oct, Wed 7 Oct — 4 hours each.**
Assumption: attendees have a browser and can reach `portal.azure.com` and
`ai.azure.com`. If they cannot, nothing in this document works and the labs
have to be instructor-led demos.

---

## The options, ranked

| # | Option | Ready by tomorrow? | Cost (25 auto + 10 reserve, 12 h) | Real VS Code + extensions? |
|---|---|---|---|---|
| **1** | **Azure VM per attendee + Bastion** | **Yes — ~1 hour of your time** | **~$210–250** | **Yes** |
| 2 | Foundry portal only (browser) | Yes — zero setup | $0 | No |
| 3 | Azure Cloud Shell | Yes | ~$0 | **No — and Python is too old** |
| 4 | Microsoft Dev Box | **No** | ~$250 + M365 E3 licences | Yes |
| 5 | Windows 365 Cloud PC | **No** | ~$41/user/month | Yes |

---

## Why the ones I rejected are rejected

**Azure Cloud Shell — looks perfect, isn't.** Free, browser-based, `az` and Git
pre-installed, has a Monaco editor (`code .`). But it ships **Python 3.9**, and
the AI-103 labs require **3.13** (they state 3.14 is unsupported). You cannot
install a different Python because Cloud Shell gives you no root. There is no
VS Code extension host, so the Foundry Toolkit steps are impossible. **Use it
for `az` commands only.**

**Azure Bastion Developer SKU is free — and useless here.** It "supports one VM
connection at a time" and does not support VNet peering. One attendee at a time.
You need **Basic** ($0.19/hr), which gives 2 instances × 20 = **40 concurrent
RDP sessions** — enough for 35.

**Dev Box** needs Windows 11 Enterprise + Intune + Entra ID P1 per user (in
practice M365 E3), a dev center, a catalog, a pool and an image build. That is
a multi-day setup and a licensing conversation. Not by tomorrow.

**Windows 365** is per-user *monthly* licensing — you would pay a full month for
12 hours of use, and provisioning is not instant.

---

## Option 1 — Azure VM per attendee + Bastion  ← do this

Each attendee gets their own Windows desktop, reached **through the Azure portal
in a browser over HTTPS 443**. No RDP client, no software install, no GitHub
account, no admin rights on the laptop. Locked-down laptops cannot block it
without blocking the Azure portal itself.

****What they get:** Windows Server 2022, real VS Code with Foundry Toolkit +
Azure Resources + Python extensions, Python 3.13, Git, Azure CLI, `azd` with the
Foundry extensions, and the `mslearn-ai-agents` repo already cloned to `C:\Labs`.

### Run this now

```bash
cd infra-labvms
vim 00-labvm-config.sh        # subscription id, tenant domain, LAB_COUNT=35, LAB_AUTO_COUNT=25

./05-check-prereqs.sh         # read-only provider and VM quota checks
./10-create-labvms.sh         # ~25 min  VNet, Bastion, 35 B2ms attendee VMs + B4ms test VM
./20-install-tools.sh         # ~15 min  VS Code, Python, az, azd on all VMs
./30-grant-access.sh          # ~2 min   Reader on their own VM only

cat ../.out/labvm-credentials.csv   # print onto the attendee cards
```

**Total ~45 minutes of wall-clock, mostly waiting.** Start it now, not tonight.

### Before each session

```bash
./start-vms.sh     # 45 min before. Starts only the 25 auto-scheduled VMs.
```

If more attendees arrive, start reserve VMs manually:

```bash
./start-reserve-vms.sh 26          # start one reserve VM
./start-reserve-vms.sh 26 27 28    # start several
./start-reserve-vms.sh             # start all reserves, 26-35
```

### Immediately after each session

```bash
./stop-vms.sh              # stops the 25 auto-scheduled VMs
./stop-reserve-vms.sh      # stops any reserve VMs you started
```

### Who controls power state — you, not them

Attendees hold **Reader** on their own VM and nothing else. Reader grants
`*/read` only. Starting, stopping, restarting, resizing or deleting a VM all
require `Microsoft.Compute/virtualMachines/*/action` permissions that Reader
does not have.

| Action | Attendee | You |
|---|---|---|
| See their VM in the portal | Yes | Yes |
| Connect via Bastion | Yes | Yes |
| **Start a VM** | **No — 403** | Yes |
| **Stop / deallocate a VM** | **No — 403** | Yes |
| Restart, resize, delete | **No — 403** | Yes |
| See another attendee's VM | **No** | Yes |

So an attendee cannot spin a VM back up after class even if they want to. They
also cannot restart a VM they have wedged — that comes to you, which is the
trade-off for the control. In practice: if someone breaks their environment,
you run `az vm restart -g $LAB_RG -n labvm-NN`.

**The real risk is you forgetting `./stop-vms.sh`, not the attendees.**

| Forgotten for | 25 auto VMs cost |
|---|---|
| Overnight (16 h) | ~$158 |
| A weekend (60 h) | ~$594 |
| Fri → next Wed (5 days) | **~$1,188** |

That last one is the realistic failure mode for your schedule — the gap between
Friday and the following Wednesday. So set the free backstop:

```bash
./40-auto-shutdown.sh           # 19:00 Madrid time, every day
./40-auto-shutdown.sh 1800      # or pick your own time
```

Azure auto-shutdown costs nothing and deallocates the VM on a schedule whether
or not you remember. It is a backstop, not a replacement for running
`./stop-vms.sh` the moment class ends — the schedule only fires once a day, so
a 13:00 finish would still bill six idle hours.

Then confirm the whole picture:

```bash
./50-verify-labvms.sh
```

It prints every VM's power state, checks that sampled attendees hold **no**
power rights and cannot see a neighbour's VM, and confirms the auto-shutdown
schedules exist.

### Automating start 08:30 / stop 14:00

```bash
./41-schedule-power.sh --test    # creates schedules AND one that fires in 12 min
./41-schedule-power.sh --list    # confirm what is scheduled
```

This creates an Azure Automation account with a managed identity and a
**tag-driven** runbook. It starts and stops only the first 25 VMs tagged
`schedule=auto`, on
**2026-09-30, 2026-10-02 and 2026-10-07** at 08:30 and 14:00 Madrid time. Change
the dates in `LAB_DAYS` in `00-labvm-config.sh`.

**Run it with `--test` today.** An Automation schedule that has never fired is
the classic thing that silently does not work on the morning. The `--test` flag
adds a start 12 minutes out so you can watch it run under
**Automation account → Jobs**.

Keep `./40-auto-shutdown.sh` (14:00, native, free) as well. It is a completely
independent mechanism — if the Automation account has a bad day, the native
shutdown still protects you from a five-day billing accident.

### Your test VM

`labvm-test` is tagged `schedule=manual` and is **excluded from every schedule**
and from `start-vms.sh`, `stop-vms.sh`, and the reserve scripts. You control it:

```bash
./test-vm.sh start      # before you test
./test-vm.sh stop       # when you are done  (~$8/day if you forget)
./test-vm.sh status
```

**To test with student permissions:** connect to `labvm-test` through Bastion
using the local Windows credentials, then inside the VM run
`az login --use-device-code` and sign in as **`attendee35@MngEnvMCAP063772.onmicrosoft.com`**. The
Windows login is local and irrelevant to Azure — the identity you `az login`
with is what the labs actually exercise. That gives you a genuine student view
without touching anyone's VM.

### Auto-login: what actually works

**Windows auto-logon does not help.** RDP authenticates at the protocol
handshake, before Windows auto-logon would ever run, so attendees would still
hit a credential prompt in the Bastion blade.

Two things that genuinely reduce friction, both applied:

1. **One shared local password across every lab VM** (`00-labvm-config.sh` →
   `LAB_PASSWORD`). Attendees hold Reader on **their own VM only**, so they
   cannot even see, let alone launch Bastion against, anyone else's machine.
   A shared password costs you nothing here.

2. **Passwordless Entra ID sign-in** — run `./42-passwordless-login.sh`. It
   installs the `AADLoginForWindows` extension and grants *Virtual Machine User
   Login* plus the Reader roles Bastion needs (**including on the NIC**, which
   is easy to miss and breaks the Connect blade). Attendees then pick
   **Microsoft Entra ID** on the Connect blade and enter **no password at all** —
   portal Bastion connections are passwordless, and Basic SKU is enough.

   **This is public preview for RDP.** Test it on `labvm-test` first, and keep
   the shared password on the card as the fallback.

### Your daily rhythm

| When | What happens |
|---|---|
| 08:30 on a training day | Automation starts the 25 auto VMs |
| 14:00 on a training day | Automation stops the 25 auto VMs |
| 14:00 every day | Native auto-shutdown fires too (independent backstop) |
| Extra attendees arrive | `./start-reserve-vms.sh 26 27` |
| Class ends early | `./stop-vms.sh` and `./stop-reserve-vms.sh` to stop paying sooner |
| Anything wrong | `./50-verify-labvms.sh` |
| Your test VM | `./test-vm.sh start` / `stop` — never scheduled |
| After 7 Oct | `./99-teardown-labvms.sh` |

### Cost

| Item | 25 auto attendees, 3 × 4 h |
|---|---|
| Compute — B2ms (2 vCPU/8 GB) 300 VM-hours | Lower than the previous B4ms estimate |
| Disks — 36 × 128 GB Standard SSD, ~9 days | Higher than the previous 30-disk estimate |
| Bastion Basic, left up throughout | ~$41 |
| **Total** | **Check pricing calculator for your agreement** |

Delete the Bastion between sessions and recreate it and that drops to ~$209 —
not worth the risk for $37. **Deallocating VMs between sessions is worth it:**
leave them running for nine days and compute alone is ~$2,100.

Rates are list pay-as-you-go for West Europe and should be treated as estimates —
**check the pricing calculator against your own agreement.**

### What attendees do

1. Browser → `portal.azure.com` → sign in as `attendeeNN@MngEnvMCAP063772.onmicrosoft.com`
2. Search **Virtual machines** → open `labvm-NN` (they only see their own)
3. **Connect → Bastion**, enter the username and password from their card
4. A Windows desktop opens **in the browser tab**
5. First login runs a script that installs the VS Code extensions (~2 min), then
   prints "READY"
6. Labs are in `C:\Labs`. Sign in with `az login --use-device-code`

### Things that will bite you

- **First logon takes ~2 minutes** while extensions install. Tell them to wait
  for "READY" rather than assuming it is broken.
- **Copy/paste in the browser Bastion session** uses the arrows panel on the
  left edge, not Ctrl+V into the session directly. Demo this in minute one.
- **Bastion Basic caps at 40 concurrent RDP sessions.** Fine for 35, not for
  more. If the class grows, switch `LAB_BASTION_SKU=Standard`.
- **`az login --use-device-code`** is still the right command — inside the VM the
  normal browser redirect can also work, but device code is predictable.
- **Test one VM end to end before the session**: connect, open VS Code, confirm
  the Foundry Toolkit icon appears, run `python --version` and `azd version`.

---

## Option 2 — Foundry portal only (free, zero setup)

A surprising amount of AI-103 Days 1–2 is pure portal work and needs nothing but
a browser:

| Works in the browser alone | Needs a dev environment |
|---|---|
| Create agents, set instructions | Exercise 02 custom function tools (Python) |
| Upload grounding files, File Search | Exercise 03 custom MCP server (Python) |
| Code Interpreter | The Foundry Toolkit VS Code halves |
| Foundry IQ knowledge bases (Exercise 04) | `agent_client.py` in Exercise 04 |
| Playground, tracing, versioning | |
| Remote MCP tools (Learn MCP) | |

**Use this as your fallback plan for tomorrow if the VMs are not ready.** Run
Exercise 01 portal half and Exercise 04 as a portal-only session, and push the
code exercises to Friday. It costs nothing and cannot fail.

---

## What I would actually do today

1. **Start the VM build now** (~45 min of waiting, ~10 min of attention).
2. **Test one VM yourself** this afternoon — connect through Bastion, open VS
   Code, run `python --version` and `azd version`.
3. **Prepare the portal-only running order for tomorrow anyway.** If the VMs are
   good, you use them; if anything is off, you run Exercise 01 + 04 in the portal
   and lose nothing.
4. **Print the cards tonight**: attendee number, Entra UPN + password, VM name +
   local Windows username/password, their Foundry project name.

The VM path is the only one that gives the full experience you designed, it is
about $8 a head, and it is the one that can genuinely be ready by tomorrow.
