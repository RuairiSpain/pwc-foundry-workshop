# Your lab environment — read this first

---

> ## ⚠️ YOUR LAB MACHINE SHUTS DOWN AUTOMATICALLY AT **14:00**
>
> Every training day your VM **starts at 08:30** and **shuts down at 14:00**,
> automatically. You cannot start it again yourself.
>
> **What this means for you:**
>
> - **Save your work before 14:00.** Anything unsaved when the machine stops
>   is gone.
> - **Your files survive the shutdown.** The disk persists — what you saved to
>   `C:\Labs` on Wednesday is still there on Friday. Only unsaved, in-memory
>   work is lost.
> - **Your Azure work is unaffected.** Agents, knowledge bases and files you
>   created in Microsoft Foundry live in Azure, not on this machine.
> - **There is no warning popup.** Watch the clock. Wrap up by 13:50.
> - **You cannot work on the labs between sessions.** The VM is switched off
>   and you do not have permission to start it. This is deliberate — it keeps
>   the cost of the workshop down.
>
> If you need something after 14:00, ask the instructor.

---

## Joining each day

1. Open **`portal.azure.com`** in your browser and sign in as
   **`attendeeNN@MngEnvMCAP063772.onmicrosoft.com`** (your number is on your card).
2. Search for **Virtual machines** and open **`labvm-NN`**.
   You will only see your own — that is expected.
3. Select **Connect → Bastion**.
4. Sign in:
   - **Preferred:** choose **Microsoft Entra ID** — no password needed, it uses
     the account you already signed in with.
   - **Fallback:** choose **Username and password** and use the credentials on
     your card.
5. A Windows desktop opens **in a browser tab**.

> **Allow pop-ups for `cdn.bastion.azure.com`** or the session window will be
> blocked.

## First time only — wait for "READY"

The first time you log in, a script installs the VS Code extensions. It takes
about **two minutes** and prints **READY** when done. It is not broken — wait
for it.

## What is already installed

- **Visual Studio Code** with Foundry Toolkit, Azure Resources, Python
- **Python 3.13**, **Git**, **Azure CLI**, **azd** with the Foundry extensions
- The lab repository, already cloned to **`C:\Labs`**

## Signing in to Azure inside the VM

```powershell
az login --use-device-code
```

Follow the code prompt and sign in as your `attendeeNN@MngEnvMCAP063772.onmicrosoft.com` account. Then:

```powershell
azd auth login --use-device-code --tenant-id 79915ee0-594c-4201-8653-6ad77a909f4d
```

## Copy and paste

Browser-based Bastion sessions do **not** pass Ctrl+V straight through. Use the
**arrows panel on the left edge** of the session window to move text in and out.
Practise this in the first five minutes — you will need it for the lab code.

## Your Foundry project

You have your own project: **`proj-attendee-NN`**. Everyone shares one Foundry
hub, which holds the models — that is why the model is already deployed and you
never need to create one.

**Three rules for every lab exercise:**

1. **Never create a project or a Foundry resource** — select your existing
   `proj-attendee-NN`.
2. **Never deploy a model** — it is already there on the shared hub.
3. **Never run a "Clean up" section** — it would delete the shared environment
   for the whole class. Your permissions will block it anyway.

## If something breaks

You have **read-only** rights on your VM, so you cannot restart it yourself.
Tell the instructor — a restart takes about a minute.

## Card checklist

Your card should show:

```
Attendee number  : NN
Azure sign-in    : attendeeNN@MngEnvMCAP063772.onmicrosoft.com
Entra password   : PwcAgents-2026-NN!
VM name          : labvm-NN
Windows fallback : labuser                      password: ...
Foundry project  : proj-attendee-NN
Chat model       : <model name>

VM hours: 08:30 - 14:00.  SAVE YOUR WORK BEFORE 14:00.
```
